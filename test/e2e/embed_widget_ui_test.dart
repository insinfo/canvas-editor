import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:puppeteer/puppeteer.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';
import 'package:test/test.dart';

const String _fixtureMain = r'''
import 'dart:convert';
import 'dart:html';
import 'dart:js_util' as js_util;

import 'package:canvas_text_editor/canvas_text_editor.dart';

void main() {
  String? loadedName;
  Object? lastError;
  final host = document.querySelector('#host') as DivElement;
  final widget = CanvasEditorWidget(
    host,
    config: CanvasEditorConfig(
      appearance: CanvasEditorAppearance.word,
      height: '520px',
      documentTitle: 'Teste Word completo',
      onDocumentLoaded: (name) => loadedName = name,
      onError: (error) => lastError = error,
      data: IEditorData(
        main: splitText('Teste negrito')
            .map((value) => IElement(value: value))
            .toList(growable: false),
      ),
    ),
  );

  js_util.setProperty(window, '__embedTest', js_util.jsify({
    'reset': js_util.allowInterop(() {
      widget.command.executeSetValue(
        IEditorData(
          main: splitText('Teste negrito')
              .map((value) => IElement(value: value))
              .toList(growable: false),
        ),
      );
      widget.command.executeSetRange(0, 7);
    }),
    'mainJson': js_util.allowInterop(() => jsonEncode([
      for (final element in widget.value.data.main)
        {'value': element.value, 'bold': element.bold},
    ])),
    'loadedName': js_util.allowInterop(() => loadedName),
    'lastError': js_util.allowInterop(() => lastError?.toString()),
    'setViewer': js_util.allowInterop(() {
      widget.setMode(CanvasEditorWidgetMode.viewer);
    }),
  }));
  js_util.setProperty(window, '__embedReady', true);
}
''';

const String _fixtureHtml = '''<!doctype html>
<html><head><meta charset="utf-8">
<link rel="stylesheet" href="packages/canvas_text_editor/assets/icons/tabler/tabler-icons.css">
<link rel="stylesheet" href="packages/canvas_text_editor/assets/canvas_editor.css">
<script defer src="main.dart.js"></script></head>
<body><div id="host"></div></body></html>''';

void main() {
  Directory? fixtureDir;
  Browser? browser;
  Page? page;
  SendPort? serverControl;
  String? baseUrl;

  setUpAll(() async {
    final chrome = await downloadChrome(cachePath: '.local-chrome');
    fixtureDir = Directory(p.join('.dart_tool', 'embed_widget_ui_test'))
      ..createSync(recursive: true);
    File(p.join(fixtureDir!.path, 'index.html'))
        .writeAsStringSync(_fixtureHtml);
    final File mainFile = File(p.join(fixtureDir!.path, 'main.dart'))
      ..writeAsStringSync(_fixtureMain);
    await _copyDirectory(
      Directory(p.join('lib', 'assets')),
      Directory(p.join(
        fixtureDir!.path,
        'packages',
        'canvas_text_editor',
        'assets',
      )),
    );
    final ProcessResult compile = await Process.run('dart', <String>[
      'compile',
      'js',
      '-O1',
      '-o',
      p.join(fixtureDir!.path, 'main.dart.js'),
      mainFile.path,
    ]);
    expect(compile.exitCode, 0, reason: '${compile.stdout}\n${compile.stderr}');

    final ReceivePort receivePort = ReceivePort();
    await Isolate.spawn<_ServeArgs>(
      _serve,
      _ServeArgs(fixtureDir!.path, receivePort.sendPort),
    );
    final Map<dynamic, dynamic> init =
        await receivePort.first as Map<dynamic, dynamic>;
    serverControl = init['control'] as SendPort;
    baseUrl = 'http://127.0.0.1:${init['port']}';
    browser = await puppeteer.launch(
      executablePath: chrome.executablePath,
      headless: true,
      args: const <String>['--no-sandbox', '--disable-setuid-sandbox'],
    );
  });

  tearDownAll(() async {
    await browser?.close();
    serverControl?.send('close');
    if (fixtureDir?.existsSync() == true) {
      fixtureDir!.deleteSync(recursive: true);
    }
  });

  setUp(() async {
    page = await browser!.newPage();
    await page!.goto(baseUrl!, wait: Until.networkIdle);
    await page!.waitForSelector('.ce-word-titlebar');
    expect(
      await page!.evaluate<bool>('() => window.__embedReady === true'),
      isTrue,
    );
  });

  tearDown(() async => page?.close());

  test('renderiza a aparência Word completa com ribbon dinâmica', () async {
    expect(await page!.$$('.ce-word-tabs [data-ce-tab]'), hasLength(6));
    expect(await page!.$$('[data-ce-tab="review"]'), hasLength(1));
    await page!.click('[data-ce-tab="review"]');
    expect(await page!.$$('[data-ce-command="comments"]'), hasLength(1));
    expect(await page!.$$('.ce-word-panel.active .ce-word-group'), isNotEmpty);
    expect(await page!.$$('.ce-embed__scroll'), hasLength(1));
  });

  test('abre um DOCX pelo seletor de arquivo da UI', () async {
    await page!.click('[data-ce-tab="file"]');
    final Future<FileChooser> chooserFuture = page!.waitForFileChooser();
    await page!.click('[data-ce-command="open"]');
    final FileChooser chooser = await chooserFuture;
    final File docx = File(p.join(
      'resources',
      'PGCTIC1_-_ETP_-_Sistema_de_Gestão_Pública.docx',
    ));
    await chooser.accept(<File>[docx.absolute]);
    await _waitUntil(page!, '() => window.__embedTest.loadedName() !== null',
        timeout: const Duration(seconds: 30));
    expect(
      await page!.evaluate<String?>('() => window.__embedTest.loadedName()'),
      endsWith('.docx'),
    );
    expect(
      await page!.evaluate<String?>('() => window.__embedTest.lastError()'),
      isNull,
    );
  });

  test('negrito conserva redo depois de undo', () async {
    await page!.evaluate<void>('() => window.__embedTest.reset()');
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await page!.click('[data-ce-command="bold"]');
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(await _hasBold(page!), isTrue);
    final String boldCanvas = await _canvasData(page!);

    await page!.click('[data-ce-command="undo"]');
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(await _hasBold(page!), isFalse);
    final String undoCanvas = await _canvasData(page!);
    expect(undoCanvas, isNot(boldCanvas));

    await page!.click('[data-ce-command="redo"]');
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(await _hasBold(page!), isTrue);
    expect(await _canvasData(page!), boldCanvas);
  });

  test('modo viewer oculta ribbon e entrada de edição', () async {
    await page!.evaluate<void>('() => window.__embedTest.setViewer()');
    expect(
        await page!
            .$eval('.ce-word-ribbon', '(e) => getComputedStyle(e).display'),
        'none');
    expect(
        await page!
            .$eval('.ce-inputarea', '(e) => getComputedStyle(e).display'),
        'none');
  });
}

Future<bool> _hasBold(Page page) async {
  final String json =
      await page.evaluate<String>('() => window.__embedTest.mainJson()');
  final List<dynamic> elements = jsonDecode(json) as List<dynamic>;
  return elements
      .any((dynamic item) => (item as Map<String, dynamic>)['bold'] == true);
}

Future<String> _canvasData(Page page) async =>
    await page.$eval<String>(
      '.ce-page-container canvas',
      '(canvas) => canvas.toDataURL()',
    ) ??
    '';

Future<void> _waitUntil(
  Page page,
  String expression, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final Stopwatch stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < timeout) {
    if (await page.evaluate<bool>(expression)) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  fail('Timeout aguardando: $expression');
}

class _ServeArgs {
  const _ServeArgs(this.directory, this.sendPort);
  final String directory;
  final SendPort sendPort;
}

Future<void> _serve(_ServeArgs args) async {
  final handler =
      createStaticHandler(args.directory, defaultDocument: 'index.html');
  final HttpServer server = await shelf_io.serve(handler, '127.0.0.1', 0);
  final ReceivePort control = ReceivePort();
  args.sendPort.send(<String, Object>{
    'port': server.port,
    'control': control.sendPort,
  });
  await for (final Object? message in control) {
    if (message == 'close') {
      await server.close(force: true);
      control.close();
      break;
    }
  }
}

Future<void> _copyDirectory(Directory source, Directory target) async {
  target.createSync(recursive: true);
  await for (final FileSystemEntity entity in source.list(recursive: false)) {
    final String destination = p.join(target.path, p.basename(entity.path));
    if (entity is Directory) {
      await _copyDirectory(entity, Directory(destination));
    } else if (entity is File) {
      File(destination)
        ..createSync(recursive: true)
        ..writeAsBytesSync(entity.readAsBytesSync());
    }
  }
}
