// Benchmark curto dos comandos que costumam travar no TR.
//
// Uso:
//   dart run tool/bench/command_latency_bench.dart

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
import 'package:canvas_text_editor/src/editor/index.dart' as editor_core;
import 'package:canvas_text_editor/src/editor/interface/element.dart'
    as element_model;
import 'package:canvas_text_editor/src/editor/interface/position.dart'
    as position_model;
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

double _time(void Function() action) {
  final start = html.window.performance.now();
  action();
  return (html.window.performance.now() - start).toDouble();
}

int _findTextIndex(EditorApp app, String needle) {
  final elements = app.editor.getDraw().getOriginalMainElementList();
  for (var i = 0; i < elements.length; i++) {
    if (elements[i].value == needle) {
      return i;
    }
  }
  for (var i = 0; i < elements.length; i++) {
    final e = elements[i];
    if (e.type == null && e.value.trim().isNotEmpty && e.value != '​') {
      return i;
    }
  }
  return -1;
}

bool _isFastCompatibleParagraph(List<editor_core.IElement> elements, int index) {
  if (index < 0 || index >= elements.length) return false;
  var start = index;
  while (start > 0 && elements[start].value != '​') {
    start--;
  }
  var end = index + 1;
  while (end < elements.length && elements[end].value != '​') {
    end++;
  }
  editor_core.RowFlex? rowFlex;
  var rowFlexSeen = false;
  for (var i = start; i < end; i++) {
    final el = elements[i];
    final type = el.type;
    if (type != null && type != editor_core.ElementType.text) return false;
    if (el.areaId != null ||
        el.controlId != null ||
        el.imgDisplay != null ||
        el.pagingId != null) return false;
    if (!rowFlexSeen) {
      rowFlex = el.rowFlex;
      rowFlexSeen = true;
    } else if (el.rowFlex != rowFlex) {
      return false;
    }
  }
  return true;
}

int _findFastTextIndex(EditorApp app) {
  final elements = app.editor.getDraw().getOriginalMainElementList();
  for (var i = 0; i < elements.length; i++) {
    final e = elements[i];
    if (e.type == null &&
        e.value.trim().isNotEmpty &&
        e.value != '​' &&
        _isFastCompatibleParagraph(elements, i)) {
      return i;
    }
  }
  return _findTextIndex(app, 'O');
}

List<editor_core.IElement> _textPayload(String text) {
  return editor_core.splitText(text)
      .map((value) => editor_core.IElement(value: value))
      .toList(growable: false);
}

void main() {
  html.window.onLoad.listen((_) async {
    final app = EditorApp(isApple: false);
    await app.initialize();

    js_util.setProperty(
      html.window,
      '__cmdPerf',
      js_util.jsify({
        'openDocxFromUrl': js_util.allowInterop((String url, Object cb) {
          _openFromUrl(app, url).then(
            (ms) => js_util.callMethod(cb, 'call', <Object?>[null, ms]),
            onError: (Object error) => js_util
                .callMethod(cb, 'call', <Object?>[null, -1, '$error']),
          );
        }),
        'pageCount': js_util.allowInterop(() {
          return app.editor.getDraw().getPageList().length;
        }),
        'selectWordNearStart': js_util.allowInterop(() {
          final index = _findFastTextIndex(app);
          if (index < 0) return -1;
          app.editor.command.executeSetPositionContext(
            range_model.IRange(startIndex: index - 1, endIndex: index),
          );
          app.editor.command.executeSetRange(index - 1, index);
          return index;
        }),
        'selectionInfo': js_util.allowInterop(() {
          final draw = app.editor.getDraw();
          final elements = draw.getOriginalMainElementList();
          final range = draw.getRange().getRange();
          final index = range.endIndex;
          if (index < 0 || index >= elements.length) return 'no-selection';
          var start = index;
          while (start > 0 && elements[start].value != '​') start--;
          var end = index + 1;
          while (end < elements.length && elements[end].value != '​') end++;
          final flags = <String, int>{
            'list': 0,
            'area': 0,
            'control': 0,
            'img': 0,
            'paging': 0,
            'nonText': 0,
            'rowFlex': 0,
          };
          editor_core.RowFlex? rowFlex;
          var rowFlexSeen = false;
          for (var i = start; i < end; i++) {
            final el = elements[i];
            if (el.listId != null) flags['list'] = flags['list']! + 1;
            if (el.areaId != null) flags['area'] = flags['area']! + 1;
            if (el.controlId != null) flags['control'] = flags['control']! + 1;
            if (el.imgDisplay != null) flags['img'] = flags['img']! + 1;
            if (el.pagingId != null) flags['paging'] = flags['paging']! + 1;
            if (el.type != null && el.type != editor_core.ElementType.text) {
              flags['nonText'] = flags['nonText']! + 1;
            }
            if (!rowFlexSeen) {
              rowFlex = el.rowFlex;
              rowFlexSeen = true;
            } else if (el.rowFlex != rowFlex) {
              flags['rowFlex'] = flags['rowFlex']! + 1;
            }
          }
          return 'index=$index start=$start end=$end value=${elements[index].value} flags=$flags';
        }),
        'boldSelection': js_util.allowInterop(() {
          return _time(() => app.editor.command.executeBold());
        }),
        'pasteInline3x': js_util.allowInterop(() {
          final payload = _textPayload(
            ' CONDICOES GERAIS DA CONTRATACAO funcional entre componentes.',
          );
          return _time(() {
            for (var i = 0; i < 3; i++) {
              app.editor.command.executeInsertElementList(
                payload,
                element_model.IInsertElementListOption(
                  isDeltaHistory: true,
                  isFastLayout: true,
                ),
              );
            }
          });
        }),
        'undo': js_util.allowInterop(() {
          return _time(() => app.editor.command.executeUndo());
        }),
        'redo': js_util.allowInterop(() {
          return _time(() => app.editor.command.executeRedo());
        }),
        'deleteFirstTable': js_util.allowInterop(() {
          final draw = app.editor.getDraw();
          final elements = draw.getOriginalMainElementList();
          for (var i = 0; i < elements.length; i++) {
            final table = elements[i];
            if (table.type != editor_core.ElementType.table ||
                table.trList == null ||
                table.trList!.isEmpty ||
                table.trList!.first.tdList.isEmpty) {
              continue;
            }
            final tr = table.trList!.first;
            final td = tr.tdList.first;
            draw.getPosition().setPositionContext(
              position_model.IPositionContext(
                isTable: true,
                index: i,
                trIndex: 0,
                tdIndex: 0,
                tableId: table.id,
                trId: tr.id,
                tdId: td.id,
              ),
            );
            app.editor.command.executeSetRange(0, 0);
            return _time(() => app.editor.command.executeDeleteTable());
          }
          return -1;
        }),
      }),
    );
    js_util.setProperty(html.window, '__cmdPerfReady', true);
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
        window.__cmdPerf.openDocxFromUrl(url, (ms) => resolve(ms)))''',
        args: <dynamic>[url],
      )
      .timeout(const Duration(minutes: 8));
  final ms = (result ?? -1).toDouble();
  if (ms < 0) {
    throw StateError('Falha ao abrir $url.');
  }
  return ms;
}

Future<double> _timeCommand(Page page, String name) async {
  final value = await page.evaluate<num?>('() => window.__cmdPerf.$name()');
  return (value ?? -1).toDouble();
}

Future<void> main() async {
  final revisionInfo = await downloadChrome(cachePath: '.local-chrome');
  final buildDir = Directory(
    p.join('.dart_tool', 'canvas_editor_command_bench',
        DateTime.now().microsecondsSinceEpoch.toString()),
  )..createSync(recursive: true);

  await _copyDirectory(Directory('web'), buildDir);
  final mainPath = p.join(buildDir.path, 'main.dart');
  File(mainPath).writeAsStringSync(_benchMainSource);

  stdout.writeln('[cmdbench] compilando dart2js -O2...');
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
  final results = <String, Object?>{};
  void report(String key, Object? value) {
    results[key] = value;
    stdout.writeln('RESULT $key=$value');
  }

  try {
    browser = await puppeteer.launch(
      executablePath: revisionInfo.executablePath,
      headless: true,
      args: const <String>['--no-sandbox', '--disable-setuid-sandbox'],
    );
    final page = await browser.newPage();
    page.onDialog.listen((dialog) => dialog.accept());
    await page.goto('http://127.0.0.1:${server.port}',
        wait: Until.networkIdle);
    await page.waitForFunction('() => window.__cmdPerfReady === true',
        timeout: const Duration(seconds: 30));

    report('open_tr_ms', await _openDocx(page, 'tr.docx'));
    await page.waitForFunction('() => window.__cmdPerf.pageCount() > 100',
        timeout: const Duration(minutes: 2));
    report('tr_pages', await page.evaluate<num?>('() => window.__cmdPerf.pageCount()'));

    await page.evaluate('() => window.__cmdPerf.selectWordNearStart()');
    report('selection_info',
        await page.evaluate<String?>('() => window.__cmdPerf.selectionInfo()'));
    report('bold_ms', await _timeCommand(page, 'boldSelection'));
    report('undo_bold_ms', await _timeCommand(page, 'undo'));
    report('redo_bold_ms', await _timeCommand(page, 'redo'));
    report('paste_3x_ms', await _timeCommand(page, 'pasteInline3x'));
    report('undo_paste_ms', await _timeCommand(page, 'undo'));
    report('redo_paste_ms', await _timeCommand(page, 'redo'));
    report('delete_table_ms', await _timeCommand(page, 'deleteFirstTable'));
    report('undo_delete_table_ms', await _timeCommand(page, 'undo'));

    stdout
      ..writeln('')
      ..writeln('=== RESULTADOS ===')
      ..writeln(const JsonEncoder.withIndent('  ').convert(results));
  } finally {
    await browser?.close();
    await server.close(force: true);
    try {
      buildDir.deleteSync(recursive: true);
    } catch (_) {}
  }
}
