// Benchmark release do hot path estrutural de texto no DOCX TR real.
//
// Mede separadamente:
//   * Enter + digitação repetidos;
//   * Delete de uma seleção com vários parágrafos;
//   * um relayout global explícito, para comparação com o fallback antigo.
//
// Uso: dart run tool/bench/mutation_latency_bench.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:puppeteer/puppeteer.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';

const String _benchMainSource = r'''
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';

import 'package:canvas_text_editor/src/editor.dart';
import 'package:canvas_text_editor/src/editor/core/draw/draw.dart' as draw_lib;
import 'package:canvas_text_editor/src/editor/interface/draw.dart';
import 'package:canvas_text_editor/src/editor/interface/range.dart';

const String zero = '​';

Future<double> openFromUrl(EditorApp app, String url) async {
  final request = await html.HttpRequest.request(url, responseType: 'arraybuffer');
  final bytes = (request.response as ByteBuffer).asUint8List();
  final start = html.window.performance.now();
  await app.openDocxBytes(url, bytes);
  return (html.window.performance.now() - start).toDouble();
}

bool isPlain(dynamic element) {
  return element.type == null &&
      element.listId == null &&
      element.areaId == null &&
      element.controlId == null &&
      element.imgDisplay == null &&
      element.pagingId == null;
}

List<int> findPlainBlock(dynamic draw) {
  final elements = draw.getOriginalMainElementList();
  for (var i = 1; i < elements.length; i++) {
    if (!isPlain(elements[i]) || elements[i].value != zero) continue;
    var boundaries = 0;
    var chars = 0;
    final limit = i + 4000 < elements.length ? i + 4000 : elements.length;
    for (var j = i + 1; j < limit; j++) {
      final element = elements[j];
      if (!isPlain(element)) break;
      if (element.value == zero) {
        boundaries += 1;
        if (boundaries >= 6 && chars >= 20) {
          return <int>[i, j - 1];
        }
      } else {
        chars += 1;
      }
    }
  }
  return const <int>[];
}

void focusInput() {
  final input = html.document.querySelector('.ce-inputarea');
  if (input is html.TextAreaElement) input.focus();
}

void setRange(EditorApp app, int start, int end) {
  final range = IRange(startIndex: start, endIndex: end);
  app.editor.command.executeSetPositionContext(range);
  app.editor.command.executeSetRange(start, end);
  focusInput();
}

void main() {
  html.window.onLoad.listen((_) async {
    draw_lib.Draw.debugRenderTiming = true;
    final app = EditorApp(isApple: false);
    await app.initialize();
    var cursorIndex = 0;

    js_util.setProperty(html.window, '__mutationPerf', js_util.jsify({
      'open': js_util.allowInterop((String url, Object callback) {
        openFromUrl(app, url).then(
          (value) => js_util.callMethod(callback, 'call', <Object?>[null, value]),
          onError: (Object error) => js_util.callMethod(
            callback,
            'call',
            <Object?>[null, -1, '$error'],
          ),
        );
      }),
      'finishLayout': js_util.allowInterop(() {
        app.editor.getDraw().finishProgressiveLayout();
      }),
      'preparePlainText': js_util.allowInterop(() {
        final block = findPlainBlock(app.editor.getDraw());
        if (block.isEmpty) return -1;
        final elements = app.editor.getDraw().getOriginalMainElementList();
        cursorIndex = block.first;
        while (cursorIndex < block.last && elements[cursorIndex].value == zero) {
          cursorIndex += 1;
        }
        return cursorIndex;
      }),
      'focusPreparedText': js_util.allowInterop(() {
        final start = html.window.performance.now();
        setRange(app, cursorIndex, cursorIndex);
        return (html.window.performance.now() - start).toDouble();
      }),
      'focusPlainText': js_util.allowInterop(() {
        final draw = app.editor.getDraw();
        final block = findPlainBlock(draw);
        if (block.isEmpty) return -1;
        final elements = draw.getOriginalMainElementList();
        cursorIndex = block.first;
        while (cursorIndex < block.last && elements[cursorIndex].value == zero) {
          cursorIndex += 1;
        }
        setRange(app, cursorIndex, cursorIndex);
        return cursorIndex;
      }),
      'selectPlainBlock': js_util.allowInterop(() {
        final draw = app.editor.getDraw();
        final block = findPlainBlock(draw);
        if (block.isEmpty) return '';
        cursorIndex = block.first;
        setRange(app, block.first, block.last);
        return '${block.first}:${block.last}';
      }),
      'elementCount': js_util.allowInterop(() {
        return app.editor.getDraw().getOriginalMainElementList().length;
      }),
      'resetLayoutDiagnostics': js_util.allowInterop(() {
        app.editor.getDraw().resetLayoutDiagnostics();
      }),
      'deepHistorySnapshots': js_util.allowInterop(() {
        return app.editor.getDraw().getHistoryDiagnostics()['deepSnapshots'] ?? 0;
      }),
      'layoutDiagnostics': js_util.allowInterop(() {
        final draw = app.editor.getDraw();
        final stats = draw.getLayoutDiagnostics();
        return 'mode=${draw.getLastLayoutMode()},' +
            stats.entries.map((entry) => '${entry.key}=${entry.value}').join(',');
      }),
      'layoutStats': js_util.allowInterop(() {
        final draw = app.editor.getDraw();
        final rows = draw.getRowList();
        final pages = draw.getPageRowList();
        var height = 0.0;
        for (final row in rows) {
          height += row.height + (row.offsetY ?? 0);
        }
        return 'elements=${draw.getOriginalMainElementList().length},' +
            'rows=${rows.length},pages=${pages.length},' +
            'height=${height.toStringAsFixed(3)}';
      }),
      'fullRender': js_util.allowInterop(() {
        final start = html.window.performance.now();
        app.editor.getDraw().render(IDrawOption(
          curIndex: cursorIndex,
          isSubmitHistory: false,
        ));
        return (html.window.performance.now() - start).toDouble();
      }),
    }));
    js_util.setProperty(html.window, '__mutationPerfReady', true);
  });
}
''';

Future<void> _copyDirectory(Directory source, Directory destination) async {
  await for (final entity in source.list(recursive: false)) {
    final target = p.join(destination.path, p.basename(entity.path));
    if (entity is Directory) {
      final directory = Directory(target)..createSync(recursive: true);
      await _copyDirectory(entity, directory);
    } else if (entity is File) {
      await entity.copy(target);
    }
  }
}

Future<double> _open(Page page) async {
  final num? value = await page.evaluate<num?>(
    '''() => new Promise((resolve, reject) => {
      window.__mutationPerf.open('tr.docx', (value, error) => {
        if (error) reject(new Error(error)); else resolve(value);
      });
    })''',
  );
  if (value == null || value < 0) throw StateError('Falha ao abrir o TR.');
  await page.evaluate<void>('() => window.__mutationPerf.finishLayout()');
  return value.toDouble();
}

double _average(List<int> samples) =>
    samples.fold<int>(0, (sum, value) => sum + value) / samples.length;

Future<void> main() async {
  final revision = await downloadChrome(cachePath: '.local-chrome');
  final buildDir = Directory(p.join(
    '.dart_tool',
    'canvas_editor_mutation_bench',
    DateTime.now().microsecondsSinceEpoch.toString(),
  ))
    ..createSync(recursive: true);
  await _copyDirectory(
    Directory(p.join('test', 'e2e', 'fixtures', 'legacy_shell')),
    buildDir,
  );
  final mainPath = p.join(buildDir.path, 'main.dart');
  File(mainPath).writeAsStringSync(_benchMainSource);

  stdout.writeln('[mutation-bench] compilando release -O2...');
  final compile = await Process.run('dart', <String>[
    'compile',
    'js',
    '-O2',
    '-o',
    p.join(buildDir.path, 'main.dart.js'),
    mainPath,
  ]);
  if (compile.exitCode != 0) {
    stderr
      ..writeln(compile.stdout)
      ..writeln(compile.stderr);
    exitCode = 1;
    return;
  }
  File(p.join(
    'resources',
    'PGCTIC1_-_TR_-_SISTEMA_GESTAO_PUBLICA__Recuperação_Automática_.docx',
  )).copySync(p.join(buildDir.path, 'tr.docx'));

  final server = await io.serve(
    createStaticHandler(buildDir.path, defaultDocument: 'index.html'),
    '127.0.0.1',
    0,
  );
  Browser? browser;
  try {
    browser = await puppeteer.launch(
      executablePath: revision.executablePath,
      headless: true,
      args: const <String>['--no-sandbox', '--disable-setuid-sandbox'],
    );
    final page = await browser.newPage();
    page.onConsole.listen((message) {
      if (message.text?.startsWith('[render]') == true ||
          message.text?.startsWith('[mutation]') == true) {
        stdout.writeln(message.text);
      }
    });
    await page.goto('http://127.0.0.1:${server.port}', wait: Until.networkIdle);
    await page.waitForFunction('() => window.__mutationPerfReady === true');

    final results = <String, Object?>{};
    void report(String key, Object? value) {
      results[key] = value;
      stdout.writeln('RESULT $key=$value');
    }

    report('open_tr_ms', await _open(page));
    final prepared = await page.evaluate<num?>(
      '() => window.__mutationPerf.preparePlainText()',
    );
    if (prepared == null || prepared < 0) {
      throw StateError('Sem bloco textual plano.');
    }
    final num snapshotsBeforeFocus = await page.evaluate<num>(
      '() => window.__mutationPerf.deepHistorySnapshots()',
    );
    report('history_snapshots_before_first_focus', snapshotsBeforeFocus);
    report(
      'first_focus_selection_ms',
      await page
          .evaluate<num?>('() => window.__mutationPerf.focusPreparedText()'),
    );
    final num snapshotsAfterFocus = await page.evaluate<num>(
      '() => window.__mutationPerf.deepHistorySnapshots()',
    );
    report('history_snapshots_after_first_focus', snapshotsAfterFocus);
    if (snapshotsAfterFocus != snapshotsBeforeFocus) {
      throw StateError(
        'O primeiro foco criou um snapshot profundo tardio: '
        '$snapshotsBeforeFocus -> $snapshotsAfterFocus',
      );
    }

    // Aquece histórico, canvas e caches antes da amostra estrutural.
    await page.keyboard.type('x');
    await page.keyboard.press(Key.backspace);
    await page.evaluate<void>(
      '() => window.__mutationPerf.resetLayoutDiagnostics()',
    );
    final enterSamples = <int>[];
    for (var i = 0; i < 5; i++) {
      final stopwatch = Stopwatch()..start();
      await page.keyboard.press(Key.enter);
      await page.keyboard.type(String.fromCharCode(97 + i));
      stopwatch.stop();
      enterSamples.add(stopwatch.elapsedMilliseconds);
    }
    report('enter_plus_typing_avg_ms', _average(enterSamples));
    report('enter_plus_typing_samples_ms', enterSamples.join(','));
    report(
      'enter_layout',
      await page.evaluate<String?>(
        '() => window.__mutationPerf.layoutDiagnostics()',
      ),
    );
    report(
      'enter_fast_layout_stats',
      await page.evaluate<String?>('() => window.__mutationPerf.layoutStats()'),
    );
    report(
      'explicit_full_render_ms',
      await page.evaluate<num?>('() => window.__mutationPerf.fullRender()'),
    );
    final String? firstFullLayoutStats = await page.evaluate<String?>(
      '() => window.__mutationPerf.layoutStats()',
    );
    report(
      'enter_full_layout_stats',
      firstFullLayoutStats,
    );
    report(
      'explicit_second_full_render_ms',
      await page.evaluate<num?>('() => window.__mutationPerf.fullRender()'),
    );
    final String? secondFullLayoutStats = await page.evaluate<String?>(
      '() => window.__mutationPerf.layoutStats()',
    );
    report(
      'enter_second_full_layout_stats',
      secondFullLayoutStats,
    );
    if (firstFullLayoutStats == null ||
        secondFullLayoutStats == null ||
        firstFullLayoutStats != secondFullLayoutStats) {
      throw StateError(
        'Table paging nao convergiu apos o primeiro relayout completo: '
        'first=$firstFullLayoutStats second=$secondFullLayoutStats',
      );
    }

    // Documento limpo para a deleção de bloco.
    await _open(page);
    await page.evaluate<num?>('() => window.__mutationPerf.focusPlainText()');
    await page.keyboard.type('x');
    await page.keyboard.press(Key.backspace);
    final selected = await page.evaluate<String?>(
      '() => window.__mutationPerf.selectPlainBlock()',
    );
    if (selected == null || selected.isEmpty) {
      throw StateError('Sem seleção multiparágrafo plana.');
    }
    final before = await page.evaluate<num?>(
      '() => window.__mutationPerf.elementCount()',
    );
    await page.evaluate<void>(
      '() => window.__mutationPerf.resetLayoutDiagnostics()',
    );
    final deleteWatch = Stopwatch()..start();
    await page.keyboard.press(Key.delete);
    deleteWatch.stop();
    final after = await page.evaluate<num?>(
      '() => window.__mutationPerf.elementCount()',
    );
    report('delete_block_ms', deleteWatch.elapsedMilliseconds);
    report('delete_block_removed_elements', (before ?? 0) - (after ?? 0));
    report(
      'delete_layout',
      await page.evaluate<String?>(
        '() => window.__mutationPerf.layoutDiagnostics()',
      ),
    );

    stdout.writeln(const JsonEncoder.withIndent('  ').convert(results));
  } finally {
    await browser?.close();
    await server.close(force: true);
    if (buildDir.existsSync()) {
      try {
        buildDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }
}
