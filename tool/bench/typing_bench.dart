// Benchmark de performance do editor (doc/plano_otimizacao_performance.md, A7).
//
// Mede, em build release (dart compile js -O2), com os DOCX reais de
// `resources/`:
//   1. tempo de abertura (parse + convert + render) do ETP e do TR;
//   2. latência média de digitação com o documento aberto (teclas reais via
//      CDP no meio do documento).
//
// Uso: dart run tool/bench/typing_bench.dart [--chars=N] [--skip-tr]
//
// Reutiliza o padrão do harness E2E (test/e2e/support/editor_e2e_support.dart):
// build isolado em .dart_tool/, servidor shelf_static e Chrome do puppeteer.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:puppeteer/puppeteer.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';

const _benchMainSource = r'''
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';

import 'package:canvas_text_editor/src/editor.dart';
import 'package:canvas_text_editor/src/editor/core/draw/draw.dart' as draw_lib;
import 'package:canvas_text_editor/src/editor/interface/range.dart'
    as range_model;

Future<double> _openFromUrl(EditorApp app, String url) async {
  final request = await html.HttpRequest.request(
    url,
    responseType: 'arraybuffer',
  );
  final buffer = request.response as ByteBuffer;
  final bytes = buffer.asUint8List();
  final start = html.window.performance.now();
  await app.openDocxBytes(url, bytes);
  return (html.window.performance.now() - start).toDouble();
}

void main() {
  html.window.onLoad.listen((_) async {
    draw_lib.Draw.debugRenderTiming = true;
    final app = EditorApp(isApple: false);
    await app.initialize();

    js_util.setProperty(
      html.window,
      '__perf',
      js_util.jsify({
        'openDocxFromUrl': js_util.allowInterop((String url, Object cb) {
          _openFromUrl(app, url).then(
            (ms) => js_util.callMethod(cb, 'call', <Object?>[null, ms]),
            onError: (Object error) => js_util
                .callMethod(cb, 'call', <Object?>[null, -1, '$error']),
          );
        }),
        // Posiciona o cursor num elemento de texto perto do meio do documento
        // e foca o textarea de entrada. Retorna o índice usado ou -1.
        'focusMiddleText': js_util.allowInterop(() {
          final draw = app.editor.getDraw();
          final elements = draw.getOriginalMainElementList();
          if (elements.isEmpty) {
            return -1;
          }
          int index = -1;
          final middle = elements.length ~/ 2;
          for (var offset = 0; offset < elements.length ~/ 2; offset++) {
            for (final candidate in <int>[middle + offset, middle - offset]) {
              if (candidate <= 0 || candidate >= elements.length) {
                continue;
              }
              final element = elements[candidate];
              if (element.type == null && element.value != '​') {
                index = candidate;
                break;
              }
            }
            if (index != -1) {
              break;
            }
          }
          if (index == -1) {
            return -1;
          }
          app.editor.command.executeSetPositionContext(
            range_model.IRange(startIndex: index, endIndex: index),
          );
          app.editor.command.executeSetRange(index, index);
          final input = html.document.querySelector('.ce-inputarea');
          if (input is html.TextAreaElement) {
            input.focus();
          }
          return index;
        }),
        'pageCount': js_util.allowInterop(() {
          return app.editor.getDraw().getPageList().length;
        }),
        // F5.4a: nº de canvases com backing store vivo (largura > 1) vs total,
        // e memória aproximada do backing store (MB).
        'canvasMemStats': js_util.allowInterop(() {
          final pages = app.editor.getDraw().getPageList();
          var live = 0;
          num livemb = 0;
          for (final c in pages) {
            if (c is html.CanvasElement && (c.width ?? 0) > 1) {
              live++;
              livemb += (c.width ?? 0) * (c.height ?? 0) * 4;
            }
          }
          return 'live=$live/${pages.length} '
              'backingMB=${(livemb / 1048576).toStringAsFixed(1)}';
        }),
        // Depuração F4.5: visão agregada das tabelas no documento aberto.
        'tableStats': js_util.allowInterop(() {
          final draw = app.editor.getDraw();
          final els = draw.getOriginalMainElementList();
          var tables = 0, parts = 0, trsTotal = 0;
          double hTotal = 0;
          final tallest = <Map<String, Object?>>[];
          for (final el in els) {
            if (el.type?.name != 'table') continue;
            tables++;
            if (el.pagingId != null) parts++;
            trsTotal += el.trList?.length ?? 0;
            hTotal += el.height ?? 0;
            tallest.add({
              'h': (el.height ?? 0).round(),
              'trs': el.trList?.length ?? 0,
              'tds0': el.trList?.isNotEmpty == true
                  ? el.trList!.first.tdList.length
                  : 0,
              'chars': el.trList?.fold<int>(
                  0,
                  (p, tr) => p! +
                      tr.tdList.fold<int>(
                          0,
                          (q, td) => q +
                              td.value.fold<int>(
                                  0, (r, e) => r + e.value.length))),
            });
          }
          tallest.sort((a, b) => (b['h']! as int).compareTo(a['h']! as int));
          return 'tables=$tables parts=$parts trsTotal=$trsTotal '
              'hTotal=${hTotal.round()} innerW=${draw.getInnerWidth()} '
              'pageH=${draw.getHeight()} top3=${tallest.take(3).toList()}';
        }),
        // Depuração F4.3: primeiras rows (altura/offset) + elementos com os
        // campos de espaçamento, como JSON.
        'rowStats': js_util.allowInterop(() {
          final draw = app.editor.getDraw();
          final rows = draw.getRowList().take(8).map((row) => {
                'h': row.height.toStringAsFixed(1),
                'oy': row.offsetY?.toStringAsFixed(1),
                'n': row.elementList.length,
              });
          final els = draw.getOriginalMainElementList().take(12).map((el) => {
                'v': el.value == '​' ? 'ZERO' : el.value,
                't': el.type?.name,
                'rm': el.rowMargin,
                'lsr': el.lineSpacingRule,
                'lsv': el.lineSpacingValue,
                'b': el.paraSpacingBefore,
                'a': el.paraSpacingAfter,
                'sz': el.size,
                'f': el.font,
              });
          return '${rows.toList()} || ${els.toList()}';
        }),
      }),
    );
    js_util.setProperty(html.window, '__perfReady', true);
  });
}
''';

Future<void> _copyDirectory(Directory source, Directory target) async {
  if (!target.existsSync()) {
    target.createSync(recursive: true);
  }
  await for (final entity in source.list(recursive: false)) {
    final basename = p.basename(entity.path);
    final targetPath = p.join(target.path, basename);
    if (entity is Directory) {
      await _copyDirectory(entity, Directory(targetPath));
    } else if (entity is File) {
      File(targetPath).writeAsBytesSync(entity.readAsBytesSync());
    }
  }
}

Future<double> _openDocx(Page page, String url) async {
  final result = await page
      .evaluate<num?>(
        '''(url) => new Promise((resolve) =>
        window.__perf.openDocxFromUrl(url, (ms) => resolve(ms)))''',
        args: <dynamic>[url],
      )
      .timeout(const Duration(minutes: 8));
  final ms = (result ?? -1).toDouble();
  if (ms < 0) {
    throw StateError('Falha ao abrir $url no editor.');
  }
  return ms;
}

/// Digita até [chars] teclas, com orçamento de tempo: se o total estourar
/// [budget], para e calcula a média com as teclas já enviadas (o baseline em
/// documentos grandes leva dezenas de segundos por tecla — sem o orçamento o
/// bench nunca termina/pode derrubar o renderer).
Future<double> _typeChars(
  Page page,
  int chars, {
  Duration budget = const Duration(minutes: 3),
}) async {
  final middleIndex = await page.evaluate<num?>(
    '() => window.__perf.focusMiddleText()',
  );
  if (middleIndex == null || middleIndex.toInt() < 0) {
    throw StateError('Não foi possível posicionar o cursor no meio do doc.');
  }
  // Aquecimento: primeira tecla paga custos de JIT/caches frios.
  await page.keyboard.type('a').timeout(budget);
  final stopwatch = Stopwatch()..start();
  var typed = 0;
  for (var i = 0; i < chars; i++) {
    await page.keyboard
        .type(String.fromCharCode(0x61 + (i % 26)))
        .timeout(budget);
    typed += 1;
    if (stopwatch.elapsed > budget) {
      stdout.writeln('[bench] orçamento de digitação estourado após '
          '$typed teclas (${stopwatch.elapsedMilliseconds} ms)');
      break;
    }
  }
  stopwatch.stop();
  return stopwatch.elapsedMilliseconds / typed;
}

Future<void> main(List<String> args) async {
  final chars = int.tryParse(
        args
            .firstWhere((a) => a.startsWith('--chars='), orElse: () => '')
            .replaceFirst('--chars=', ''),
      ) ??
      20;
  final skipTr = args.contains('--skip-tr');

  final revisionInfo = await downloadChrome(cachePath: '.local-chrome');

  final buildDir = Directory(
    p.join('.dart_tool', 'canvas_editor_bench',
        DateTime.now().microsecondsSinceEpoch.toString()),
  )..createSync(recursive: true);

  stdout.writeln('[bench] build dir: ${buildDir.path}');
  await _copyDirectory(Directory('web'), buildDir);
  final mainPath = p.join(buildDir.path, 'main.dart');
  File(mainPath).writeAsStringSync(_benchMainSource);

  stdout.writeln('[bench] compilando dart2js -O2...');
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
      ..writeln('[bench] compilação falhou:')
      ..writeln(compile.stdout)
      ..writeln(compile.stderr);
    exitCode = 1;
    return;
  }

  File(p.join('resources', 'PGCTIC1_-_ETP_-_Sistema_de_Gestão_Pública.docx'))
      .copySync(p.join(buildDir.path, 'etp.docx'));
  File(p.join(
    'resources',
    'PGCTIC1_-_TR_-_SISTEMA_GESTAO_PUBLICA__Recuperação_Automática_.docx',
  )).copySync(p.join(buildDir.path, 'tr.docx'));

  final handler =
      createStaticHandler(buildDir.path, defaultDocument: 'index.html');
  final server = await io.serve(handler, '127.0.0.1', 0);
  stdout.writeln('[bench] servidor: http://127.0.0.1:${server.port}');

  Browser? browser;
  try {
    browser = await puppeteer.launch(
      executablePath: revisionInfo.executablePath,
      headless: true,
      args: const <String>['--no-sandbox', '--disable-setuid-sandbox'],
    );
    final page = await browser.newPage();
    page.onConsole.listen((msg) {
      if (msg.type == ConsoleMessageType.error) {
        stderr.writeln('[page:error] ${msg.text}');
      } else if ((msg.text?.startsWith('[render]') ?? false) ||
          (msg.text?.startsWith('[open]') ?? false)) {
        stdout.writeln(msg.text);
      }
    });
    // window.alert/confirm bloqueiam o headless até serem tratados — o fluxo
    // de erro do editor usa alert, então sem isto o bench congela.
    page.onDialog.listen((dialog) {
      stderr.writeln('[page:dialog] ${dialog.message}');
      dialog.accept();
    });
    await page.goto('http://127.0.0.1:${server.port}',
        wait: Until.networkIdle);
    await page.waitForFunction('() => window.__perfReady === true',
        timeout: const Duration(seconds: 30));

    final results = <String, Object?>{};
    void report(String key, Object? value) {
      results[key] = value;
      stdout.writeln('RESULT $key=$value');
    }

    stdout.writeln('[bench] abrindo ETP...');
    report('open_etp_ms', await _openDocx(page, 'etp.docx'));
    report(
        'etp_pages',
        (await page.evaluate<num?>('() => window.__perf.pageCount()'))
            ?.toInt());
    stdout.writeln('[rowStats] '
        '${await page.evaluate<String?>('() => window.__perf.rowStats()')}');
    stdout.writeln('[bench] digitando $chars teclas no ETP...');
    report('typing_etp_ms_per_key', await _typeChars(page, chars));

    if (!skipTr) {
      stdout.writeln('[bench] abrindo TR (140 págs)...');
      report('open_tr_ms', await _openDocx(page, 'tr.docx'));
      report(
          'tr_pages',
          (await page.evaluate<num?>('() => window.__perf.pageCount()'))
              ?.toInt());
      // F5.5: aguarda a paginação progressiva async terminar e confirma o
      // total (deve bater com o layout completo).
      await Future<void>.delayed(const Duration(seconds: 6));
      report(
          'tr_pages_final',
          (await page.evaluate<num?>('() => window.__perf.pageCount()'))
              ?.toInt());
      stdout.writeln('[tableStats] '
          '${await page.evaluate<String?>('() => window.__perf.tableStats()')}');
      stdout.writeln('[canvasMem] '
          '${await page.evaluate<String?>('() => window.__perf.canvasMemStats()')}');
      final trChars = chars < 10 ? chars : 10;
      stdout.writeln('[bench] digitando $trChars teclas no TR...');
      report('typing_tr_ms_per_key', await _typeChars(page, trChars));
    }

    stdout
      ..writeln('')
      ..writeln('=== RESULTADOS ===')
      ..writeln(const JsonEncoder.withIndent('  ').convert(results));
  } finally {
    await browser?.close();
    await server.close(force: true);
    if (buildDir.existsSync()) {
      try {
        buildDir.deleteSync(recursive: true);
      } catch (_) {
        // Windows às vezes segura handles do Chrome; diretório fica p/ limpeza.
      }
    }
  }
}
