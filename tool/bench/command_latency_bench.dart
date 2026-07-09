// Benchmark dos comandos que costumam travar no TR.
//
// Uso:
//   dart run tool/bench/command_latency_bench.dart
//
// Mede comandos em dois cenarios:
// - fast path: selecao/edicao em paragrafo compativel com layout local;
// - fallback/full: selecao que invalida o fast path ou insercao forçada sem
//   `isFastLayout`, para expor o custo do caminho normal.

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

bool _isTextCandidate(editor_core.IElement element) {
  final value = element.value;
  final type = element.type;
  return value.trim().isNotEmpty &&
      value != '​' &&
      (type == null || type == editor_core.ElementType.text);
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
    if (type != null &&
        type != editor_core.ElementType.text &&
        type != editor_core.ElementType.superscript &&
        type != editor_core.ElementType.subscript) {
      return false;
    }
    if (el.listId != null ||
        el.areaId != null ||
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
    if (_isTextCandidate(elements[i]) && _isFastCompatibleParagraph(elements, i)) {
      return i;
    }
  }
  return -1;
}

int _findFallbackTextIndex(EditorApp app) {
  final elements = app.editor.getDraw().getOriginalMainElementList();
  for (var i = 0; i < elements.length; i++) {
    if (_isTextCandidate(elements[i]) && !_isFastCompatibleParagraph(elements, i)) {
      return i;
    }
  }
  return -1;
}

int _selectMode(EditorApp app, String mode) {
  final index = mode == 'fallback'
      ? _findFallbackTextIndex(app)
      : _findFastTextIndex(app);
  if (index < 0) return -1;
  app.editor.command.executeSetPositionContext(
    range_model.IRange(startIndex: index - 1, endIndex: index),
  );
  app.editor.command.executeSetRange(index - 1, index);
  return index;
}

int _collapseMode(EditorApp app, String mode) {
  final index = mode == 'fallback'
      ? _findFallbackTextIndex(app)
      : _findFastTextIndex(app);
  if (index < 0) return -1;
  app.editor.command.executeSetPositionContext(
    range_model.IRange(startIndex: index, endIndex: index),
  );
  app.editor.command.executeSetRange(index, index);
  return index;
}

String _selectionInfo(EditorApp app) {
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
  final fastCompatible = _isFastCompatibleParagraph(elements, index);
  return 'index=$index start=$start end=$end value=${elements[index].value} '
      'fastCompatible=$fastCompatible flags=$flags';
}

List<editor_core.IElement> _textPayload(String text) {
  return editor_core.splitText(text)
      .map((value) => editor_core.IElement(value: value))
      .toList(growable: false);
}

void _runFormatCommand(EditorApp app, String command) {
  switch (command) {
    case 'font':
      app.editor.command.executeFont('Times New Roman');
      return;
    case 'size':
      app.editor.command.executeSize(18);
      return;
    case 'size_add':
      app.editor.command.executeSizeAdd();
      return;
    case 'size_minus':
      app.editor.command.executeSizeMinus();
      return;
    case 'bold':
      app.editor.command.executeBold();
      return;
    case 'italic':
      app.editor.command.executeItalic();
      return;
    case 'underline':
      app.editor.command.executeUnderline();
      return;
    case 'strikeout':
      app.editor.command.executeStrikeout();
      return;
    case 'superscript':
      app.editor.command.executeSuperscript();
      return;
    case 'subscript':
      app.editor.command.executeSubscript();
      return;
    case 'color':
      app.editor.command.executeColor('#C00000');
      return;
    case 'highlight':
      app.editor.command.executeHighlight('#FFF2CC');
      return;
  }
  throw ArgumentError('Comando de formatacao desconhecido: $command');
}

double _measureFormatCommand(EditorApp app, String command, String mode) {
  if (_selectMode(app, mode) < 0) return -1;
  return _time(() => _runFormatCommand(app, command));
}

double _measureInlineInsert(EditorApp app, bool fastLayout, int count) {
  if (_collapseMode(app, 'fast') < 0) return -1;
  return _time(() {
    for (var i = 0; i < count; i++) {
      app.editor.command.executeInsertElementList(
        _textPayload(
          ' CONDICOES GERAIS DA CONTRATACAO funcional entre componentes.',
        ),
        element_model.IInsertElementListOption(
          isDeltaHistory: true,
          isFastLayout: fastLayout,
        ),
      );
    }
  });
}

double _measureBackspace(EditorApp app, String mode) {
  if (_collapseMode(app, mode) < 0) return -1;
  return _time(() => app.editor.command.executeBackspace());
}

bool _selectFirstTable(EditorApp app) {
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
    return true;
  }
  return false;
}

double _measureTableCommand(EditorApp app, String command) {
  if (!_selectFirstTable(app)) return -1;
  return _time(() {
    switch (command) {
      case 'insert_top_row':
        app.editor.command.executeInsertTableTopRow();
        return;
      case 'insert_bottom_row':
        app.editor.command.executeInsertTableBottomRow();
        return;
      case 'insert_left_col':
        app.editor.command.executeInsertTableLeftCol();
        return;
      case 'insert_right_col':
        app.editor.command.executeInsertTableRightCol();
        return;
      case 'delete_row':
        app.editor.command.executeDeleteTableRow();
        return;
      case 'delete_col':
        app.editor.command.executeDeleteTableCol();
        return;
      case 'delete_table':
        app.editor.command.executeDeleteTable();
        return;
    }
    throw ArgumentError('Comando de tabela desconhecido: $command');
  });
}

double _undoMany(EditorApp app, int count) {
  return _time(() {
    for (var i = 0; i < count; i++) {
      app.editor.command.executeUndo();
    }
  });
}

double _redoMany(EditorApp app, int count) {
  return _time(() {
    for (var i = 0; i < count; i++) {
      app.editor.command.executeRedo();
    }
  });
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
        'selectMode': js_util.allowInterop((String mode) {
          return _selectMode(app, mode);
        }),
        'selectionInfo': js_util.allowInterop(() {
          return _selectionInfo(app);
        }),
        'formatCommand': js_util.allowInterop((String command, String mode) {
          return _measureFormatCommand(app, command, mode);
        }),
        'inlineInsert': js_util.allowInterop((bool fastLayout, int count) {
          return _measureInlineInsert(app, fastLayout, count);
        }),
        'backspace': js_util.allowInterop((String mode) {
          return _measureBackspace(app, mode);
        }),
        'tableCommand': js_util.allowInterop((String command) {
          return _measureTableCommand(app, command);
        }),
        'undoMany': js_util.allowInterop((int count) {
          return _undoMany(app, count);
        }),
        'redoMany': js_util.allowInterop((int count) {
          return _redoMany(app, count);
        }),
      }),
    );
    js_util.setProperty(html.window, '__cmdPerfReady', true);
  });
}
''';

const _formatCommands = <String>[
  'font',
  'size',
  'size_add',
  'size_minus',
  'bold',
  'italic',
  'underline',
  'strikeout',
  'superscript',
  'subscript',
  'color',
  'highlight',
];

const _formatModes = <String>['fast', 'fallback'];

const _tableCommands = <String>[
  'insert_top_row',
  'insert_bottom_row',
  'insert_left_col',
  'insert_right_col',
  'delete_row',
  'delete_col',
  'delete_table',
];

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
  final result = await page.evaluate<num?>(
    '''(url) => new Promise((resolve) =>
        window.__cmdPerf.openDocxFromUrl(url, (ms) => resolve(ms)))''',
    args: <dynamic>[url],
  ).timeout(const Duration(minutes: 8));
  final ms = (result ?? -1).toDouble();
  if (ms < 0) {
    throw StateError('Falha ao abrir $url.');
  }
  return ms;
}

Future<double> _timeCommand(
  Page page,
  String name, [
  List<dynamic> args = const <dynamic>[],
]) async {
  final value = await page.evaluate<num?>(
    '(name, args) => window.__cmdPerf[name].apply(null, args)',
    args: <dynamic>[name, args],
  );
  return (value ?? -1).toDouble();
}

Future<String?> _selectionInfo(Page page) {
  return page.evaluate<String?>('() => window.__cmdPerf.selectionInfo()');
}

Future<void> _selectMode(Page page, String mode) async {
  await page.evaluate<num?>(
    '(mode) => window.__cmdPerf.selectMode(mode)',
    args: <dynamic>[mode],
  );
}

Future<void> main() async {
  final revisionInfo = await downloadChrome(cachePath: '.local-chrome');
  final buildDir = Directory(
    p.join(
      '.dart_tool',
      'canvas_editor_command_bench',
      DateTime.now().microsecondsSinceEpoch.toString(),
    ),
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
    await page.goto(
      'http://127.0.0.1:${server.port}',
      wait: Until.networkIdle,
    );
    await page.waitForFunction(
      '() => window.__cmdPerfReady === true',
      timeout: const Duration(seconds: 30),
    );

    report('open_tr_ms', await _openDocx(page, 'tr.docx'));
    await page.waitForFunction(
      '() => window.__cmdPerf.pageCount() > 100',
      timeout: const Duration(minutes: 2),
    );
    report(
      'tr_pages',
      await page.evaluate<num?>('() => window.__cmdPerf.pageCount()'),
    );

    for (final mode in _formatModes) {
      await _selectMode(page, mode);
      report('${mode}_selection_info', await _selectionInfo(page));
      for (final command in _formatCommands) {
        report(
          '${mode}_format_${command}_ms',
          await _timeCommand(page, 'formatCommand', <dynamic>[command, mode]),
        );
        report(
          '${mode}_format_${command}_undo_ms',
          await _timeCommand(page, 'undoMany', const <dynamic>[1]),
        );
      }
    }

    report(
      'edit_insert_inline_fast_1x_ms',
      await _timeCommand(page, 'inlineInsert', const <dynamic>[true, 1]),
    );
    report(
      'edit_insert_inline_fast_1x_undo_ms',
      await _timeCommand(page, 'undoMany', const <dynamic>[1]),
    );
    report(
      'edit_insert_inline_full_1x_ms',
      await _timeCommand(page, 'inlineInsert', const <dynamic>[false, 1]),
    );
    report(
      'edit_insert_inline_full_1x_undo_ms',
      await _timeCommand(page, 'undoMany', const <dynamic>[1]),
    );
    report(
      'edit_insert_inline_fast_3x_ms',
      await _timeCommand(page, 'inlineInsert', const <dynamic>[true, 3]),
    );
    report(
      'edit_insert_inline_fast_3x_undo3_ms',
      await _timeCommand(page, 'undoMany', const <dynamic>[3]),
    );
    report(
      'edit_insert_inline_full_3x_ms',
      await _timeCommand(page, 'inlineInsert', const <dynamic>[false, 3]),
    );
    report(
      'edit_insert_inline_full_3x_undo3_ms',
      await _timeCommand(page, 'undoMany', const <dynamic>[3]),
    );

    for (final mode in _formatModes) {
      report(
        'edit_backspace_${mode}_ms',
        await _timeCommand(page, 'backspace', <dynamic>[mode]),
      );
      report(
        'edit_backspace_${mode}_undo_ms',
        await _timeCommand(page, 'undoMany', const <dynamic>[1]),
      );
    }

    for (final command in _tableCommands) {
      report(
        'table_${command}_ms',
        await _timeCommand(page, 'tableCommand', <dynamic>[command]),
      );
      report(
        'table_${command}_undo_ms',
        await _timeCommand(page, 'undoMany', const <dynamic>[1]),
      );
    }

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
