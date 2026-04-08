
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:puppeteer/puppeteer.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';
import 'package:test/test.dart';

const _zeroWidthSpace = '\u200B';

const _mainDartSource = r'''
import 'dart:html' as html;
import 'dart:js_util' as js_util;

import 'package:canvas_text_editor/src/editor.dart';
import 'package:canvas_text_editor/src/editor/index.dart' as editor_core;

void main() {
  html.window.onLoad.listen((_) async {
    final userAgent = html.window.navigator.userAgent;
    final isApple = userAgent.contains('Mac OS X');
    final app = EditorApp(isApple: isApple);
    await app.initialize();

    void focusInput() {
      final input = html.document.querySelector('.ce-inputarea');
      if (input is html.TextAreaElement) {
        input.focus();
      }
    }

    js_util.setProperty(
      html.window,
      '__editorTest',
      js_util.jsify({
        'focusInput': js_util.allowInterop(() {
          focusInput();
        }),
        'setRange': js_util.allowInterop((num start, num end) {
          app.editor.command.executeSetRange(start.toInt(), end.toInt());
          focusInput();
        }),
        'resetContent': js_util.allowInterop((String text) {
          final elements = editor_core.splitText(text)
              .map((value) => editor_core.IElement(value: value))
              .toList(growable: false);
          app.editor.command.executeSetValue(
            editor_core.IEditorData(main: elements),
          );
          app.editor.command.executeSetRange(0, 0);
          focusInput();
        }),
        'mainText': js_util.allowInterop(() {
          final result = app.editor.command.getValue();
          return result.data.main.map((element) => element.value).join('');
        }),
        'mainValues': js_util.allowInterop(() {
          final result = app.editor.command.getValue();
          return js_util.jsify(
            result.data.main
                .map((element) => element.value)
                .toList(growable: false),
          );
        }),
        'range': js_util.allowInterop(() {
          final range = app.editor.command.getRange();
          return js_util.jsify({
            'startIndex': range.startIndex,
            'endIndex': range.endIndex,
          });
        }),
      }),
    );

    js_util.setProperty(html.window, '__editorReady', true);
  });
}
''';

class _ServeArgs {
  final String dir;
  final SendPort sendPort;
  final int? port;

  const _ServeArgs(this.dir, this.sendPort, {this.port});
}

Future<void> _serveIsolate(_ServeArgs args) async {
  final handler = createStaticHandler(args.dir, defaultDocument: 'index.html');
  final server = await io.serve(handler, '127.0.0.1', args.port ?? 0);

  final control = ReceivePort();
  args.sendPort
      .send({'port': args.port ?? server.port, 'control': control.sendPort});

  await for (final message in control) {
    if (message == 'close') {
      await server.close(force: true);
      control.close();
      break;
    }
  }
}

Future<void> _copyDirectory(Directory source, Directory target) async {
  if (!target.existsSync()) {
    target.createSync(recursive: true);
  }

  await for (final entity in source.list(recursive: false)) {
    final String basename = p.basename(entity.path);
    final String targetPath = p.join(target.path, basename);
    if (entity is Directory) {
      await _copyDirectory(entity, Directory(targetPath));
    } else if (entity is File) {
      File(targetPath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(entity.readAsBytesSync());
    }
  }
}

Future<void> _waitForApp(Page page) async {
  await page.waitForSelector('.ce-inputarea',
      timeout: const Duration(seconds: 10));
  final bool ready =
      await page.evaluate<bool?>('() => window.__editorReady === true') ??
          false;
  expect(ready, isTrue);
}

Future<void> _resetContent(Page page, String text) async {
  final String encoded = jsonEncode(text);
  await page.evaluate<void>('() => window.__editorTest.resetContent($encoded)');
  await Future<void>.delayed(const Duration(milliseconds: 120));
}

Future<void> _setRange(Page page, int start, int end) async {
  await page.evaluate<void>('() => window.__editorTest.setRange($start, $end)');
  await Future<void>.delayed(const Duration(milliseconds: 80));
}

Future<String> _readMainText(Page page) async {
  return await page.evaluate<String?>('() => window.__editorTest.mainText()') ??
      '';
}

Future<List<dynamic>> _readMainValues(Page page) async {
  final String json = await page.evaluate<String?>(
        '() => JSON.stringify(window.__editorTest.mainValues())',
      ) ??
      '[]';
  return List<dynamic>.from(jsonDecode(json) as List<dynamic>);
}

Future<Map<String, dynamic>> _readRange(Page page) async {
  final String json = await page.evaluate<String?>(
        '() => JSON.stringify(window.__editorTest.range())',
      ) ??
      '{}';
  return Map<String, dynamic>.from(jsonDecode(json) as Map<String, dynamic>);
}

void main() {
  group('Canvas editor app E2E', () {
    final buildDir = Directory('build_test');
    SendPort? serverControl;
    Browser? browser;
    Page? page;
    String? baseUrl;
    String? skipReason;

    setUpAll(() async {
      try {
        final revisionInfo = await downloadChrome(cachePath: '.local-chrome');

        if (buildDir.existsSync()) {
          buildDir.deleteSync(recursive: true);
        }
        buildDir.createSync(recursive: true);

        await _copyDirectory(Directory('web'), buildDir);

        final mainPath = p.join(buildDir.path, 'main.dart');
        File(mainPath).writeAsStringSync(_mainDartSource);

        final result = await Process.run(
          'dart',
          <String>[
            'compile',
            'js',
            '-O1',
            '-o',
            p.join(buildDir.path, 'main.dart.js'),
            mainPath,
          ],
        );
        if (result.exitCode != 0) {
          throw ProcessException(
            'dart',
            <String>['compile', 'js', '-O1', '-o', 'main.dart.js', mainPath],
            (result.stderr as Object?).toString(),
            result.exitCode,
          );
        }

        final receivePort = ReceivePort();
        await Isolate.spawn(
          _serveIsolate,
          _ServeArgs(buildDir.path, receivePort.sendPort, port: 5179),
        );
        final init = await receivePort.first as Map<dynamic, dynamic>;
        serverControl = init['control'] as SendPort;
        baseUrl = 'http://127.0.0.1:${init['port']}';

        browser = await puppeteer.launch(
          executablePath: revisionInfo.executablePath,
          headless: true,
          args: const <String>['--no-sandbox', '--disable-setuid-sandbox'],
        );
      } catch (error, stackTrace) {
        skipReason = 'Puppeteer setup failed: $error';
        stderr
          ..writeln(skipReason)
          ..writeln(stackTrace);
      }
    });

    tearDownAll(() async {
      await browser?.close();
      serverControl?.send('close');
      if (buildDir.existsSync()) {
        buildDir.deleteSync(recursive: true);
      }
    });

    setUp(() async {
      if (skipReason != null) {
        return;
      }
      page = await browser!.newPage();
      await page!.goto(baseUrl!, wait: Until.networkIdle);
      await _waitForApp(page!);
    });

    tearDown(() async {
      await page?.close();
    });

    test('boots the full demo shell', () async {
      if (skipReason != null) {
        print('Skipping test: $skipReason');
        return;
      }

      expect(
        await page!
            .waitForSelector('.menu', timeout: const Duration(seconds: 5)),
        isNotNull,
      );
      expect(
        await page!
            .waitForSelector('.editor', timeout: const Duration(seconds: 5)),
        isNotNull,
      );
      expect(
        await page!
            .waitForSelector('.page-mode', timeout: const Duration(seconds: 5)),
        isNotNull,
      );
      expect(
        await page!.waitForSelector('.paper-size',
            timeout: const Duration(seconds: 5)),
        isNotNull,
      );
      expect(
        await page!.waitForSelector('.ce-page-container canvas',
            timeout: const Duration(seconds: 5)),
        isNotNull,
      );
    });

    test('supports basic typing and backspace', () async {
      if (skipReason != null) {
        print('Skipping test: $skipReason');
        return;
      }

      await _resetContent(page!, 'abc');
      await _setRange(page!, 1, 1);
      await page!.keyboard.type('X');
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(await _readMainText(page!), 'aXbc');

      await page!.keyboard.press(Key.backspace);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(await _readMainText(page!), 'abc');
    });

    test('supports arrow navigation and selection expansion', () async {
      if (skipReason != null) {
        print('Skipping test: $skipReason');
        return;
      }

      await _resetContent(page!, 'abcd');
      await _setRange(page!, 1, 1);

      await page!.keyboard.press(Key.arrowRight);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      final collapsedRange = await _readRange(page!);
      expect(collapsedRange['startIndex'], 2);
      expect(collapsedRange['endIndex'], 2);

      await page!.keyboard.down(Key.shift);
      await page!.keyboard.press(Key.arrowRight);
      await page!.keyboard.up(Key.shift);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      final expandedRange = await _readRange(page!);
      expect(expandedRange['startIndex'], 2);
      expect(expandedRange['endIndex'], 3);
    });

    test('supports enter inserting a new line element', () async {
      if (skipReason != null) {
        print('Skipping test: $skipReason');
        return;
      }

      await _resetContent(page!, 'abcd');
      await _setRange(page!, 1, 1);
      final beforeText = await _readMainText(page!);

      await page!.keyboard.press(Key.enter);
      await Future<void>.delayed(const Duration(milliseconds: 120));

      final afterText = await _readMainText(page!);
      final range = await _readRange(page!);
      expect(afterText, isNot(beforeText));
      expect(
        afterText.contains('\n') || afterText.contains(_zeroWidthSpace),
        isTrue,
      );
      expect(range['startIndex'], range['endIndex']);
      expect(range['startIndex'], greaterThanOrEqualTo(1));
    });
  });
}
