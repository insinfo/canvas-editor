
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
import 'package:canvas_text_editor/src/editor/interface/draw.dart'
  as draw_model;
import 'package:canvas_text_editor/src/editor/interface/area.dart'
  as area_model;
import 'package:canvas_text_editor/src/editor/interface/control.dart'
  as control_model;
import 'package:canvas_text_editor/src/editor/interface/range.dart'
  as range_model;
import 'package:canvas_text_editor/src/mock.dart' as mock_data;
import 'package:canvas_text_editor/src/editor/utils/clipboard.dart'
  as clipboard_utils;

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

    String flattenElementText(List<editor_core.IElement>? elements) {
      if (elements == null || elements.isEmpty) {
        return '';
      }
      final buffer = StringBuffer();
      for (final element in elements) {
        if (element.value.isNotEmpty && element.value != '\u200B') {
          buffer.write(element.value);
        }
        if (element.valueList != null && element.valueList!.isNotEmpty) {
          buffer.write(flattenElementText(element.valueList));
        }
        if (element.control?.value?.isNotEmpty == true) {
          buffer.write(flattenElementText(element.control!.value));
        }
      }
      return buffer.toString();
    }

    js_util.setProperty(
      html.window,
      '__editorTest',
      js_util.jsify({
        'focusInput': js_util.allowInterop(() {
          focusInput();
        }),
        'setRange': js_util.allowInterop((num start, num end) {
          app.editor.command.executeSetPositionContext(
            range_model.IRange(
              startIndex: start.toInt(),
              endIndex: end.toInt(),
            ),
          );
          app.editor.command.executeSetRange(start.toInt(), end.toInt());
          focusInput();
        }),
        'resetContent': js_util.allowInterop((String text) {
          final elements = editor_core.splitText(text)
        'setRangeBeforeTextValue': js_util.allowInterop((String text) {
          final elements = app.editor.getDraw().getOriginalMainElementList();
          final index = elements.indexWhere((element) => element.value == text);
          if (index == -1) {
            return false;
          }
          app.editor.command.executeSetPositionContext(
            range_model.IRange(
              startIndex: index,
              endIndex: index,
            ),
          );
          app.editor.command.executeSetRange(index, index);
          focusInput();
          return true;
        }),
              .map((value) => editor_core.IElement(value: value))
              .toList(growable: false);
          app.editor.command.executeSetValue(
            editor_core.IEditorData(main: elements),
          );
          app.editor.command.executeSetRange(0, 0);
          focusInput();
        }),
        'resetMockContent': js_util.allowInterop(() {
          app.editor.command.executeSetValue(
            editor_core.IEditorData(main: mock_data.data),
          );
          app.editor.command.executeSetRange(0, 0);
          focusInput();
        }),
        'selectAll': js_util.allowInterop(() {
          app.editor.command.executeSelectAll();
          focusInput();
        }),
        'copySelection': js_util.allowInterop(() async {
          await app.editor.command.executeCopy();
          focusInput();
        }),
        'pasteStoredClipboard': js_util.allowInterop(() {
          final payload = clipboard_utils.getClipboardData();
          if (payload == null) {
            return;
          }
          app.editor.command.executeInsertElementList(payload.elementList);
          focusInput();
        }),
        'storeLatexClipboard': js_util.allowInterop((String value) {
          clipboard_utils.setClipboardData(
            clipboard_utils.ClipboardDataPayload(
              text: value,
              elementList: <editor_core.IElement>[
                editor_core.IElement(
                  type: editor_core.ElementType.latex,
                  value: value,
                ),
              ],
            ),
          );
        }),
        'undo': js_util.allowInterop(() {
          app.editor.command.executeUndo();
          focusInput();
        }),
        'redo': js_util.allowInterop(() {
          app.editor.command.executeRedo();
          focusInput();
        }),
        'setFont': js_util.allowInterop((String value) {
          app.editor.command.executeFont(value);
          focusInput();
        }),
        'setColor': js_util.allowInterop((String value) {
          app.editor.command.executeColor(value);
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
        'mainElements': js_util.allowInterop(() {
          final result = app.editor.command.getValue(
            draw_model.IGetValueOption(
              extraPickAttrs: <String>['laTexSVG'],
            ),
          );
          return js_util.jsify(
            result.data.main
                .map(
                  (element) => <String, Object?>{
                    'type': element.type?.name,
                    'value': element.value,
                    'width': element.width,
                    'height': element.height,
                    'laTexSVG': element.laTexSVG,
                    'font': element.font,
                    'color': element.color,
                    'areaId': element.areaId,
                    'controlId': element.controlId,
                    'controlType': element.control?.type.name,
                    'controlPlaceholder': element.control?.placeholder,
                    'controlValue': element.control?.value
                        ?.map((value) => value.value)
                        .join(''),
                    'controlValueSetCount':
                        element.control?.valueSets.length ?? 0,
                    'tableRowCount': element.trList?.length ?? 0,
                    'tableColCount':
                        element.trList?.isNotEmpty == true
                            ? element.trList!.first.tdList.length
                            : 0,
                    'tableColgroupCount': element.colgroup?.length ?? 0,
                    'tableColWidths': element.colgroup
                      ?.map((col) => col.width)
                      .toList(growable: false),
                    'tableTexts': element.trList
                        ?.map(
                          (tr) => tr.tdList
                              .map(
                                (td) => flattenElementText(td.value),
                              )
                              .toList(growable: false),
                        )
                        .toList(growable: false),
                    'tableCellSpans': element.trList
                        ?.map(
                          (tr) => tr.tdList
                              .map(
                                (td) => <String, Object?>{
                                  'rowspan': td.rowspan,
                                  'colspan': td.colspan,
                                },
                              )
                              .toList(growable: false),
                        )
                        .toList(growable: false),
                  },
                )
                .toList(growable: false),
          );
        }),
        'controlIds': js_util.allowInterop(() {
          return js_util.jsify(
            app.editor.command
                .getControlList()
                .map((element) => element.controlId)
                .whereType<String>()
                .toList(growable: false),
          );
        }),
        'areaExists': js_util.allowInterop((String id) {
          return app.editor.command.getAreaValue(
                area_model.IGetAreaValueOption(id: id),
              ) !=
              null;
        }),
        'insertLatex': js_util.allowInterop((String value) {
          app.editor.command.executeInsertElementList(
            <editor_core.IElement>[
              editor_core.IElement(
                type: editor_core.ElementType.latex,
                value: value,
              ),
            ],
          );
          focusInput();
        }),
        'importHtml': js_util.allowInterop((String htmlText) {
          final elements = editor_core.getElementListByHTML(
            htmlText,
            const editor_core.GetElementListByHtmlOption(innerWidth: 794),
          );
          app.editor.command.executeInsertElementList(elements);
          focusInput();
        }),
        'insertTable': js_util.allowInterop((num row, num col) {
          app.editor.command.executeInsertTable(row.toInt(), col.toInt());
          focusInput();
        }),
        'insertTableTopRow': js_util.allowInterop(() {
          app.editor.command.executeInsertTableTopRow();
          focusInput();
        }),
        'insertTableBottomRow': js_util.allowInterop(() {
          app.editor.command.executeInsertTableBottomRow();
          focusInput();
        }),
        'insertTableLeftCol': js_util.allowInterop(() {
          app.editor.command.executeInsertTableLeftCol();
          focusInput();
        }),
        'insertTableRightCol': js_util.allowInterop(() {
          app.editor.command.executeInsertTableRightCol();
          focusInput();
        }),
        'deleteTableRow': js_util.allowInterop(() {
          app.editor.command.executeDeleteTableRow();
          focusInput();
        }),
        'deleteTableCol': js_util.allowInterop(() {
          app.editor.command.executeDeleteTableCol();
          focusInput();
        }),
        'deleteTable': js_util.allowInterop(() {
          app.editor.command.executeDeleteTable();
          focusInput();
        }),
        'deleteFirstTableCol': js_util.allowInterop(() {
          final result = app.editor.command.getValue(
            draw_model.IGetValueOption(extraPickAttrs: <String>['id']),
          );
          final elements = result.data.main;
          final tableIndex = elements.indexWhere(
            (element) => element.type == editor_core.ElementType.table,
          );
          if (tableIndex == -1) {
            return false;
          }
          final table = elements[tableIndex];
          if (table.id == null) {
            return false;
          }
          app.editor.command.executeSetPositionContext(
            range_model.IRange(
              startIndex: 0,
              endIndex: 0,
              tableId: table.id,
              startTdIndex: 0,
              endTdIndex: 0,
              startTrIndex: 0,
              endTrIndex: 0,
            ),
          );
          app.editor.command.executeSetRange(0, 0, table.id, 0, 0, 0, 0);
          app.editor.command.executeDeleteTableCol();
          focusInput();
          return true;
        }),
        'deleteFirstTable': js_util.allowInterop(() {
          final result = app.editor.command.getValue(
            draw_model.IGetValueOption(extraPickAttrs: <String>['id']),
          );
          final elements = result.data.main;
          final tableIndex = elements.indexWhere(
            (element) => element.type == editor_core.ElementType.table,
          );
          if (tableIndex == -1) {
            return false;
          }
          final table = elements[tableIndex];
          if (table.id == null) {
            return false;
          }
          app.editor.command.executeSetPositionContext(
            range_model.IRange(
              startIndex: 0,
              endIndex: 0,
              tableId: table.id,
              startTdIndex: 0,
              endTdIndex: 0,
              startTrIndex: 0,
              endTrIndex: 0,
            ),
          );
          app.editor.command.executeSetRange(0, 0, table.id, 0, 0, 0, 0);
          app.editor.command.executeDeleteTable();
          focusInput();
          return true;
        }),
        'focusFirstTableCell': js_util.allowInterop(() {
          final result = app.editor.command.getValue(
            draw_model.IGetValueOption(extraPickAttrs: <String>['id']),
          );
          final elements = result.data.main;
          final tableIndex = elements.indexWhere(
            (element) => element.type == editor_core.ElementType.table,
          );
          if (tableIndex == -1) {
            return false;
          }
          final table = elements[tableIndex];
          final trList = table.trList;
          if (table.id == null || trList == null || trList.isEmpty) {
            return false;
          }
          final firstTr = trList.first;
          if (firstTr.tdList.isEmpty) {
            return false;
          }
          app.editor.command.executeSetPositionContext(
            range_model.IRange(
              startIndex: 0,
              endIndex: 0,
              tableId: table.id,
              startTdIndex: 0,
              endTdIndex: 0,
              startTrIndex: 0,
              endTrIndex: 0,
            ),
          );
          app.editor.command.executeSetRange(0, 0, table.id, 0, 0, 0, 0);
          app.editor.getDraw().getTableTool()?.render();
          focusInput();
          return true;
        }),
        'insertTextControl': js_util.allowInterop(
          (String placeholder, String value) {
            app.editor.command.executeInsertControl(
              editor_core.IElement(
                type: editor_core.ElementType.control,
                value: '',
                control: control_model.IControl(
                  type: editor_core.ControlType.text,
                  placeholder: placeholder,
                  value: value.isEmpty
                      ? null
                      : <editor_core.IElement>[
                          editor_core.IElement(value: value),
                        ],
                  valueSets: <control_model.IValueSet>[],
                  flexDirection: editor_core.FlexDirection.row,
                ),
              ),
            );
            focusInput();
          },
        ),
        'insertCheckboxControl': js_util.allowInterop(() {
          app.editor.command.executeInsertControl(
            editor_core.IElement(
              type: editor_core.ElementType.control,
              value: '',
              control: control_model.IControl(
                type: editor_core.ControlType.checkbox,
                value: null,
                valueSets: <control_model.IValueSet>[
                  control_model.IValueSet(value: 'Sim', code: '1'),
                  control_model.IValueSet(value: 'Nao', code: '2'),
                ],
                flexDirection: editor_core.FlexDirection.row,
              ),
            ),
          );
          focusInput();
        }),
        'insertArea': js_util.allowInterop((String id, String text) {
          final elements = editor_core.splitText(text)
              .map((value) => editor_core.IElement(value: value))
              .toList(growable: false);
          app.editor.command.executeInsertArea(
            area_model.IInsertAreaOption<editor_core.IElement>(
              id: id,
              area: area_model.IArea(),
              value: elements,
            ),
          );
          focusInput();
        }),
        'deleteArea': js_util.allowInterop((String id) {
          app.editor.command.executeDeleteArea(
            area_model.IDeleteAreaOption(id: id),
          );
          focusInput();
        }),
        'locationControl': js_util.allowInterop((String controlId) {
          app.editor.command.executeLocationControl(
            controlId,
            control_model.ILocationControlOption(
              position: editor_core.LocationPosition.before,
            ),
          );
          focusInput();
        }),
        'jumpControl': js_util.allowInterop(() {
          app.editor.command.executeJumpControl();
          focusInput();
        }),
        'hideCursor': js_util.allowInterop(() {
          app.editor.command.executeHideCursor();
        }),
        'cursorDisplay': js_util.allowInterop(() {
          final cursor = html.document.querySelector('.ce-cursor');
          if (cursor is html.HtmlElement) {
            return cursor.style.display;
          }
          return null;
        }),
        'remainingContentHeight': js_util.allowInterop(() {
          return app.editor.command.getRemainingContentHeight();
        }),
        'computeTextHeight': js_util.allowInterop((String text) {
          final elements = editor_core.splitText(text)
              .map((value) => editor_core.IElement(value: value))
              .toList(growable: false);
          return app.editor.command.executeComputeElementListHeight(elements);
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

Future<void> _resetMockContent(Page page) async {
  await page.evaluate<void>('() => window.__editorTest.resetMockContent()');
  await Future<void>.delayed(const Duration(milliseconds: 180));
}

Future<bool> _focusFirstTableCell(Page page) async {
  final bool? value = await page.evaluate<bool?>(
    '() => window.__editorTest.focusFirstTableCell()',
  );
  await Future<void>.delayed(const Duration(milliseconds: 180));
  return value ?? false;
}

Future<void> _setRange(Page page, int start, int end) async {
  await page.evaluate<void>('() => window.__editorTest.setRange($start, $end)');
  await Future<void>.delayed(const Duration(milliseconds: 80));
}

Future<bool> _setRangeBeforeTextValue(Page page, String text) async {
  final String encoded = jsonEncode(text);
  final bool? value = await page.evaluate<bool?>(
    '() => window.__editorTest.setRangeBeforeTextValue($encoded)',
  );
  await Future<void>.delayed(const Duration(milliseconds: 80));
  return value ?? false;
}

Future<String> _readMainText(Page page) async {
  return await page.evaluate<String?>('() => window.__editorTest.mainText()') ??
      '';
}

Future<List<Map<String, dynamic>>> _readMainElements(Page page) async {
  final String json = await page.evaluate<String?>(
        '() => JSON.stringify(window.__editorTest.mainElements())',
      ) ??
      '[]';
  return (jsonDecode(json) as List<dynamic>)
      .map((entry) => Map<String, dynamic>.from(entry as Map<dynamic, dynamic>))
      .toList(growable: false);
}

Map<String, dynamic>? _firstTable(List<Map<String, dynamic>> elements) {
  for (final element in elements) {
    if (element['type'] == 'table') {
      return element;
    }
  }
  return null;
}

Future<void> _insertLatex(Page page, String value) async {
  final String encoded = jsonEncode(value);
  await page.evaluate<void>('() => window.__editorTest.insertLatex($encoded)');
  await Future<void>.delayed(const Duration(milliseconds: 120));
}

Future<void> _copySelection(Page page) async {
  await page.evaluate<void>('() => window.__editorTest.copySelection()');
  await Future<void>.delayed(const Duration(milliseconds: 120));
}

Future<void> _pasteStoredClipboard(Page page) async {
  await page.evaluate<void>('() => window.__editorTest.pasteStoredClipboard()');
  await Future<void>.delayed(const Duration(milliseconds: 120));
}

Future<void> _storeLatexClipboard(Page page, String value) async {
  final String encoded = jsonEncode(value);
  await page.evaluate<void>(
    '() => window.__editorTest.storeLatexClipboard($encoded)',
  );
}

Future<void> _undo(Page page) async {
  await page.evaluate<void>('() => window.__editorTest.undo()');
  await Future<void>.delayed(const Duration(milliseconds: 120));
}

Future<void> _redo(Page page) async {
  await page.evaluate<void>('() => window.__editorTest.redo()');
  await Future<void>.delayed(const Duration(milliseconds: 120));
}

Future<void> _setFont(Page page, String value) async {
  final String encoded = jsonEncode(value);
  await page.evaluate<void>('() => window.__editorTest.setFont($encoded)');
  await Future<void>.delayed(const Duration(milliseconds: 120));
}

Future<void> _setColor(Page page, String value) async {
  final String encoded = jsonEncode(value);
  await page.evaluate<void>('() => window.__editorTest.setColor($encoded)');
  await Future<void>.delayed(const Duration(milliseconds: 120));
}

Future<void> _importHtml(Page page, String htmlText) async {
  final String encoded = jsonEncode(htmlText);
  await page.evaluate<void>('() => window.__editorTest.importHtml($encoded)');
  await Future<void>.delayed(const Duration(milliseconds: 220));
}

Future<void> _insertTable(Page page, int row, int col) async {
  await page.evaluate<void>(
    '() => window.__editorTest.insertTable($row, $col)',
  );
  await Future<void>.delayed(const Duration(milliseconds: 120));
}

Future<void> _insertTableTopRow(Page page) async {
  await page.evaluate<void>('() => window.__editorTest.insertTableTopRow()');
  await Future<void>.delayed(const Duration(milliseconds: 120));
}

Future<void> _insertTableBottomRow(Page page) async {
  await page.evaluate<void>('() => window.__editorTest.insertTableBottomRow()');
  await Future<void>.delayed(const Duration(milliseconds: 120));
}

Future<void> _insertTableLeftCol(Page page) async {
  await page.evaluate<void>('() => window.__editorTest.insertTableLeftCol()');
  await Future<void>.delayed(const Duration(milliseconds: 120));
}

Future<void> _insertTableRightCol(Page page) async {
  await page.evaluate<void>('() => window.__editorTest.insertTableRightCol()');
  await Future<void>.delayed(const Duration(milliseconds: 120));
}

Future<void> _deleteTableRow(Page page) async {
  await page.evaluate<void>('() => window.__editorTest.deleteTableRow()');
  await Future<void>.delayed(const Duration(milliseconds: 120));
}

Future<void> _deleteTableCol(Page page) async {
  await page.evaluate<void>('() => window.__editorTest.deleteTableCol()');
  await Future<void>.delayed(const Duration(milliseconds: 120));
}

Future<void> _insertTextControl(
  Page page,
  String placeholder,
  String value,
) async {
  final String placeholderJson = jsonEncode(placeholder);
  final String valueJson = jsonEncode(value);
  await page.evaluate<void>(
    '() => window.__editorTest.insertTextControl($placeholderJson, $valueJson)',
  );
  await Future<void>.delayed(const Duration(milliseconds: 120));
}

Future<void> _insertCheckboxControl(Page page) async {
  await page.evaluate<void>('() => window.__editorTest.insertCheckboxControl()');
  await Future<void>.delayed(const Duration(milliseconds: 120));
}

Future<Map<String, dynamic>> _readRange(Page page) async {
  final String json = await page.evaluate<String?>(
        '() => JSON.stringify(window.__editorTest.range())',
      ) ??
      '{}';
  return Map<String, dynamic>.from(jsonDecode(json) as Map<String, dynamic>);
}

Future<void> _deleteArea(Page page, String id) async {
  final String idJson = jsonEncode(id);
  await page.evaluate<void>('() => window.__editorTest.deleteArea($idJson)');
  await Future<void>.delayed(const Duration(milliseconds: 120));
}

Future<void> _locationControl(Page page, String controlId) async {
  final String idJson = jsonEncode(controlId);
  await page.evaluate<void>(
    '() => window.__editorTest.locationControl($idJson)',
  );
  await Future<void>.delayed(const Duration(milliseconds: 120));
}

Future<void> _jumpControl(Page page) async {
  await page.evaluate<void>('() => window.__editorTest.jumpControl()');
  await Future<void>.delayed(const Duration(milliseconds: 120));
}

Future<void> _hideCursor(Page page) async {
  await page.evaluate<void>('() => window.__editorTest.hideCursor()');
  await Future<void>.delayed(const Duration(milliseconds: 80));
}

Future<String?> _readCursorDisplay(Page page) async {
  return page.evaluate<String?>('() => window.__editorTest.cursorDisplay()');
}

Future<double> _readRemainingContentHeight(Page page) async {
  final num? value = await page.evaluate<num?>(
    '() => window.__editorTest.remainingContentHeight()',
  );
  return value?.toDouble() ?? 0;
}

Future<double> _computeTextHeight(Page page, String text) async {
  final String encoded = jsonEncode(text);
  final num? value = await page.evaluate<num?>(
    '() => window.__editorTest.computeTextHeight($encoded)',
  );
  return value?.toDouble() ?? 0;
}

Future<List<String>> _readControlIds(Page page) async {
  final String json = await page.evaluate<String?>(
        '() => JSON.stringify(window.__editorTest.controlIds())',
      ) ??
      '[]';
  return (jsonDecode(json) as List<dynamic>)
      .map((entry) => entry.toString())
      .toList(growable: false);
}

Future<bool> _areaExists(Page page, String id) async {
  final String encoded = jsonEncode(id);
  return await page.evaluate<bool>(
    '() => window.__editorTest.areaExists($encoded)',
  );
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

    test('supports latex insertion with generated SVG metadata', () async {
      if (skipReason != null) {
        print('Skipping test: $skipReason');
        return;
      }

      await _resetContent(page!, '');
      await _setRange(page!, 0, 0);
      await _insertLatex(page!, r'x^2 + y^2 = z^2');

      final elements = await _readMainElements(page!);
      final latexElement = elements.cast<Map<String, dynamic>?>().firstWhere(
            (element) => element?['type'] == 'latex',
            orElse: () => null,
          );

      expect(latexElement, isNotNull);
      expect(latexElement!['value'], r'x^2 + y^2 = z^2');
      expect((latexElement['width'] as num?)?.toDouble() ?? 0, greaterThan(0));
      expect(
        (latexElement['height'] as num?)?.toDouble() ?? 0,
        greaterThan(0),
      );
      expect(latexElement['laTexSVG'], isA<String>());
      expect((latexElement['laTexSVG'] as String), startsWith('data:image/svg+xml;base64,'));
    });

    test('supports copy paste and undo redo for text selections', () async {
      if (skipReason != null) {
        print('Skipping test: $skipReason');
        return;
      }

      await _resetContent(page!, 'abcd');
      await _setRange(page!, 1, 3);
      await _copySelection(page!);
      await _setRange(page!, 4, 4);
      await _pasteStoredClipboard(page!);
      expect(await _readMainText(page!), 'abcdbc');

      await _undo(page!);
      expect(await _readMainText(page!), 'abcd');

      await _redo(page!);
      expect(await _readMainText(page!), 'abcdbc');
    });

    test('supports latex paste from editor clipboard with SVG metadata', () async {
      if (skipReason != null) {
        print('Skipping test: $skipReason');
        return;
      }

      await _resetContent(page!, '');
      await _setRange(page!, 0, 0);
      await _storeLatexClipboard(page!, r'\frac{a}{b}');
      await _pasteStoredClipboard(page!);

      final elements = await _readMainElements(page!);
      final latexElement = elements.cast<Map<String, dynamic>?>().firstWhere(
            (element) => element?['type'] == 'latex',
            orElse: () => null,
          );

      expect(latexElement, isNotNull);
      expect(latexElement!['value'], r'\frac{a}{b}');
      expect((latexElement['width'] as num?)?.toDouble() ?? 0, greaterThan(0));
      expect((latexElement['height'] as num?)?.toDouble() ?? 0, greaterThan(0));
      expect((latexElement['laTexSVG'] as String), startsWith('data:image/svg+xml;base64,'));
    });

    test('imports HTML tables into table elements', () async {
      if (skipReason != null) {
        print('Skipping test: $skipReason');
        return;
      }

      await _resetContent(page!, '');
      await _setRange(page!, 0, 0);
      await _importHtml(
        page!,
        '<table><tr><td>A1</td><td>B1</td></tr><tr><td>A2</td><td>B2</td></tr></table>',
      );

      final elements = await _readMainElements(page!);
      final tableElement = elements.cast<Map<String, dynamic>?>().firstWhere(
            (element) => element?['type'] == 'table',
            orElse: () => null,
          );

      expect(tableElement, isNotNull);
      expect(tableElement!['tableRowCount'], 2);
      expect(tableElement['tableColCount'], 2);
      expect(tableElement['tableTexts'], isA<List<dynamic>>());
    });

    test('supports table insertion and undo redo', () async {
      if (skipReason != null) {
        print('Skipping test: $skipReason');
        return;
      }

      await _resetContent(page!, '');
      await _setRange(page!, 0, 0);
      await _insertTable(page!, 2, 2);

      var elements = await _readMainElements(page!);
      expect(elements.any((element) => element['type'] == 'table'), isTrue);

      await _undo(page!);
      elements = await _readMainElements(page!);
      expect(elements.any((element) => element['type'] == 'table'), isFalse);

      await _redo(page!);
      elements = await _readMainElements(page!);
      expect(elements.any((element) => element['type'] == 'table'), isTrue);
    });

    test('ships the demo mock with a preloaded table sample', () async {
      if (skipReason != null) {
        print('Skipping test: $skipReason');
        return;
      }

      await _resetMockContent(page!);

      final elements = await _readMainElements(page!);
      final tableElement = _firstTable(elements);

      expect(tableElement, isNotNull);
      expect(tableElement!['tableRowCount'], 3);
      expect(tableElement['tableColgroupCount'], 4);
      expect(tableElement['tableTexts'], isA<List<dynamic>>());
    });

    test('renders table editing controls for the focused table cell', () async {
      if (skipReason != null) {
        print('Skipping test: $skipReason');
        return;
      }

      await _resetMockContent(page!);
      expect(await _focusFirstTableCell(page!), isTrue);

      final Map<String, dynamic> metrics = Map<String, dynamic>.from(
        jsonDecode(
          await page!.evaluate<String>('''() => JSON.stringify({
            rowItems: document.querySelectorAll('.ce-table-tool__row__item').length,
            colItems: document.querySelectorAll('.ce-table-tool__col__item').length,
            quickAdds: document.querySelectorAll('.ce-table-tool__quick__add').length,
            hasSelect: !!document.querySelector('.ce-table-tool__select'),
            hasBorder: !!document.querySelector('.ce-table-tool__border'),
            rowHeight: document.querySelector('.ce-table-tool__row')?.getBoundingClientRect().height ?? 0,
            colWidth: document.querySelector('.ce-table-tool__col')?.getBoundingClientRect().width ?? 0
          })'''),
        ) as Map<String, dynamic>,
      );
      expect(metrics['rowItems'], greaterThan(0));
      expect(metrics['colItems'], greaterThan(0));
      expect(metrics['quickAdds'], 2);
      expect(metrics['hasSelect'], isTrue);
      expect(metrics['hasBorder'], isTrue);
      expect((metrics['rowHeight'] as num).toDouble(), greaterThan(0));
      expect((metrics['colWidth'] as num).toDouble(), greaterThan(0));
    });

    test('supports public row and column mutations on a simple table', () async {
      if (skipReason != null) {
        print('Skipping test: $skipReason');
        return;
      }

      await _resetContent(page!, '');
      await _setRange(page!, 0, 0);
      await _insertTable(page!, 2, 2);
      expect(await _focusFirstTableCell(page!), isTrue);

      await _insertTableTopRow(page!);
      var elements = await _readMainElements(page!);
      var tableElement = _firstTable(elements);
      expect(tableElement, isNotNull);
      expect(tableElement!['tableRowCount'], 3);

      expect(await _focusFirstTableCell(page!), isTrue);
      await _insertTableLeftCol(page!);
      elements = await _readMainElements(page!);
      tableElement = _firstTable(elements);
      expect(tableElement, isNotNull);
      expect(tableElement!['tableColgroupCount'], 3);

      expect(await _focusFirstTableCell(page!), isTrue);
      await _insertTableBottomRow(page!);
      elements = await _readMainElements(page!);
      tableElement = _firstTable(elements);
      expect(tableElement, isNotNull);
      expect(tableElement!['tableRowCount'], 4);

      expect(await _focusFirstTableCell(page!), isTrue);
      await _insertTableRightCol(page!);
      elements = await _readMainElements(page!);
      tableElement = _firstTable(elements);
      expect(tableElement, isNotNull);
      expect(tableElement!['tableColgroupCount'], 4);

      expect(await _focusFirstTableCell(page!), isTrue);
      await _deleteTableRow(page!);
      elements = await _readMainElements(page!);
      tableElement = _firstTable(elements);
      expect(tableElement, isNotNull);
      expect(tableElement!['tableRowCount'], 3);

      expect(await _focusFirstTableCell(page!), isTrue);
      await _deleteTableCol(page!);
      elements = await _readMainElements(page!);
      tableElement = _firstTable(elements);
      expect(tableElement, isNotNull);
      expect(tableElement!['tableColgroupCount'], 3);
    });

    test('inserts a new table into a filled document without removing the existing one', () async {
      if (skipReason != null) {
        print('Skipping test: $skipReason');
        return;
      }

      await _resetMockContent(page!);
      expect(
        await _setRangeBeforeTextValue(page!, 'Observações finais: '),
        isTrue,
      );

      final beforeElements = await _readMainElements(page!);
      final beforeTableCount = beforeElements
          .where((element) => element['type'] == 'table')
          .length;
      final beforeControlCount = beforeElements
          .where((element) => element['type'] == 'control')
          .length;

      expect(beforeTableCount, 1);

      await _insertTable(page!, 2, 2);

      final afterElements = await _readMainElements(page!);
      final afterTableCount = afterElements
          .where((element) => element['type'] == 'table')
          .length;
      final afterControlCount = afterElements
          .where((element) => element['type'] == 'control')
          .length;
      final firstTable = _firstTable(afterElements);

      expect(afterTableCount, 2);
      expect(afterControlCount, beforeControlCount);
      expect(firstTable, isNotNull);
      expect(firstTable!['tableRowCount'], 3);
      expect(firstTable['tableColgroupCount'], 4);
    });

    test('supports embedded control insertion scenarios', () async {
      if (skipReason != null) {
        print('Skipping test: $skipReason');
        return;
      }

      await _resetContent(page!, '');
      await _setRange(page!, 0, 0);
      await _insertTextControl(page!, 'Nome completo', 'Maria');
      await _insertCheckboxControl(page!);

      final elements = await _readMainElements(page!);
      final textControl = elements.cast<Map<String, dynamic>?>().firstWhere(
            (element) => element?['type'] == 'control' &&
                element?['controlType'] == 'text',
            orElse: () => null,
          );
      final checkboxControl = elements.cast<Map<String, dynamic>?>().firstWhere(
            (element) => element?['type'] == 'control' &&
                element?['controlType'] == 'checkbox',
            orElse: () => null,
          );

      expect(textControl, isNotNull);
      expect(textControl!['controlPlaceholder'], 'Nome completo');
      expect(textControl['controlValue'], 'Maria');

      expect(checkboxControl, isNotNull);
      expect(checkboxControl!['controlValueSetCount'], 2);
    });

    test('exposes cursor and height utility commands', () async {
      if (skipReason != null) {
        print('Skipping test: $skipReason');
        return;
      }

      await _resetContent(page!, 'Utilitarios');
      await _setRange(page!, 2, 2);

      expect(await _readCursorDisplay(page!), 'block');

      await _hideCursor(page!);
      expect(await _readCursorDisplay(page!), 'none');

      final remainingHeight = await _readRemainingContentHeight(page!);
      final emptyHeight = await _computeTextHeight(page!, '');
      final textHeight = await _computeTextHeight(page!, 'Altura de teste');

      expect(remainingHeight, greaterThan(0));
      expect(emptyHeight, 0);
      expect(textHeight, greaterThan(0));
    });

    test('supports jumping to the next control through the public command', () async {
      if (skipReason != null) {
        print('Skipping test: $skipReason');
        return;
      }

      await _resetContent(page!, '');
      await _setRange(page!, 0, 0);
      await _insertTextControl(page!, 'Primeiro', 'A');
      await _insertTextControl(page!, 'Segundo', 'B');

      final List<String> controlIds = await _readControlIds(page!);
      expect(controlIds.length, greaterThanOrEqualTo(2));

      final String firstControlId = controlIds.first;

      await _locationControl(page!, firstControlId);
      final beforeRange = await _readRange(page!);
      await _jumpControl(page!);

      final afterRange = await _readRange(page!);
      expect(afterRange['startIndex'], afterRange['endIndex']);
      expect(afterRange['startIndex'], isNot(beforeRange['startIndex']));
    });

    test('keeps document stable when deleting a missing area through the public command', () async {
      if (skipReason != null) {
        print('Skipping test: $skipReason');
        return;
      }

      await _resetContent(page!, 'Texto base');
      final beforeText = await _readMainText(page!);
      expect(await _areaExists(page!, 'area-inexistente'), isFalse);

      await _deleteArea(page!, 'area-inexistente');

      expect(await _areaExists(page!, 'area-inexistente'), isFalse);
      expect(await _readMainText(page!), beforeText);
    });

    test('applies font and color without runtime type errors', () async {
      if (skipReason != null) {
        print('Skipping test: $skipReason');
        return;
      }

      await _resetContent(page!, 'FonteCor');
      await _setRange(page!, 0, 8);
      await _setFont(page!, 'Arial');
      await _setColor(page!, '#ff0000');

      final elements = await _readMainElements(page!);
      final styledElement = elements.cast<Map<String, dynamic>?>().firstWhere(
            (element) =>
                element?['value'] == 'FonteCor' &&
                element?['font'] == 'Arial' &&
                element?['color'] == '#ff0000',
            orElse: () => null,
          );

      expect(styledElement, isNotNull);
    });

    test('applies toolbar color through native input events', () async {
      if (skipReason != null) {
        print('Skipping test: $skipReason');
        return;
      }

      await _resetContent(page!, 'Cor');
      await _setRange(page!, 0, 3);
      await page!.evaluate<void>('''() => {
        const colorInput = document.querySelector('#color');
        colorInput.value = '#00ff00';
        colorInput.dispatchEvent(new Event('input', { bubbles: true }));
      }''');
      await Future<void>.delayed(const Duration(milliseconds: 120));

      final elements = await _readMainElements(page!);
      final styledElement = elements.cast<Map<String, dynamic>?>().firstWhere(
            (element) =>
                element?['value'] == 'Cor' &&
                element?['color'] == '#00ff00',
            orElse: () => null,
          );

      expect(styledElement, isNotNull);
    });

    test('applies toolbar color through native change events', () async {
      if (skipReason != null) {
        print('Skipping test: $skipReason');
        return;
      }

      await _resetContent(page!, 'Change');
      await _setRange(page!, 0, 6);
      await page!.evaluate<void>('''() => {
        const colorInput = document.querySelector('#color');
        colorInput.value = '#008000';
        colorInput.dispatchEvent(new Event('change', { bubbles: true }));
      }''');
      await Future<void>.delayed(const Duration(milliseconds: 120));

      final elements = await _readMainElements(page!);
      final styledElement = elements.cast<Map<String, dynamic>?>().firstWhere(
            (element) =>
                element?['value'] == 'Change' &&
                element?['color'] == '#008000',
            orElse: () => null,
          );

      expect(styledElement, isNotNull);
    });
  });
}
