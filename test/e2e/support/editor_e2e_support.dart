part of '../editor_smoke_test.dart';

const _zeroWidthSpace = '\u200B';

Directory? buildDir;
SendPort? serverControl;
Browser? browser;
Page? page;
String? baseUrl;
String? skipReason;

const _mainDartSource = r'''
import 'dart:html' as html;
import 'dart:js_util' as js_util;

import 'package:canvas_text_editor/src/editor.dart';
import 'package:canvas_text_editor/src/editor/index.dart' as editor_core;
import 'package:canvas_text_editor/src/editor/interface/draw.dart'
  as draw_model;
import 'package:canvas_text_editor/src/editor/interface/area.dart'
  as area_model;
import 'package:canvas_text_editor/src/editor/interface/background.dart'
  as background_model;
import 'package:canvas_text_editor/src/editor/interface/control.dart'
  as control_model;
import 'package:canvas_text_editor/src/editor/interface/editor.dart'
  as editor_model;
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
    int labelMousedownCount = 0;
    String? lastLabelValue;

    app.editor.eventBus.on('labelMousedown', (dynamic payload) {
      labelMousedownCount += 1;
      final dynamic element = payload is Map ? payload['element'] : null;
      if (element is editor_core.IElement) {
        lastLabelValue = element.value;
      }
    });

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

    Map<String, Object?>? firstImageClientRect() {
      final draw = app.editor.getDraw();
      final elements = draw.getElementList();
      final positions = draw.getPosition().getPositionList();
      final index = elements.indexWhere(
        (element) => element.type == editor_core.ElementType.image,
      );
      if (index < 0) {
        return null;
      }

      final element = elements[index];
      final position = index < positions.length ? positions[index] : null;
      final floatPosition = element.imgFloatPosition;
      int pageNo = position?.pageNo ?? 0;
      if (floatPosition != null && floatPosition['pageNo'] != null) {
        pageNo = (floatPosition['pageNo'] as num).toInt();
      }

      final pageList = draw.getPageList();
      if (pageNo < 0 || pageNo >= pageList.length) {
        return null;
      }
      final page = pageList[pageNo];
      if (page is! html.CanvasElement) {
        return null;
      }

      final rect = page.getBoundingClientRect();
      final scale = draw.getOptions().scale ?? 1;
      double left = 0;
      double top = 0;
      double width = (element.width ?? 0) * scale;
      double height = (element.height ?? 0) * scale;

      if (floatPosition != null) {
        final pageOffsetY = pageNo * (draw.getHeight() + draw.getPageGap());
        left = ((floatPosition['x'] ?? 0) as num).toDouble() * scale;
        top = ((floatPosition['y'] ?? 0) as num).toDouble() * scale +
            pageOffsetY;
      } else if (position != null) {
        final leftTop = position.coordinate['leftTop'] ?? const <double>[0, 0];
        final rightTop = position.coordinate['rightTop'] ?? const <double>[0, 0];
        left = leftTop.isNotEmpty ? leftTop[0] : 0;
        top = leftTop.length > 1 ? leftTop[1] + position.ascent : 0;
        if (width <= 0 && rightTop.isNotEmpty && leftTop.isNotEmpty) {
          width = rightTop[0] - leftTop[0];
        }
        if (height <= 0) {
          height = position.lineHeight.toDouble();
        }
      }

      return <String, Object?>{
        'x': rect.left + left + width / 2,
        'y': rect.top + top + height / 2,
        'width': width,
        'height': height,
      };
    }

    Map<String, Object?>? dragSelectionPoints(int startIndex, int endIndex) {
      final draw = app.editor.getDraw();
      final positions = draw.getPosition().getPositionList();
      if (startIndex < 0 ||
          endIndex < 0 ||
          startIndex >= positions.length ||
          endIndex >= positions.length) {
        return null;
      }

      final start = positions[startIndex];
      final end = positions[endIndex];
      if (start.pageNo != end.pageNo) {
        return null;
      }

      final pageList = draw.getPageList();
      final pageNo = start.pageNo;
      if (pageNo < 0 || pageNo >= pageList.length) {
        return null;
      }
      final page = pageList[pageNo];
      if (page is! html.CanvasElement) {
        return null;
      }

      final rect = page.getBoundingClientRect();
      final startLeftTop = start.coordinate['leftTop'] ?? const <double>[0, 0];
      final startRightTop = start.coordinate['rightTop'] ?? const <double>[0, 0];
      final startLeftBottom =
          start.coordinate['leftBottom'] ?? const <double>[0, 0];
      final endLeftTop = end.coordinate['leftTop'] ?? const <double>[0, 0];
      final endRightTop = end.coordinate['rightTop'] ?? const <double>[0, 0];
      final endLeftBottom = end.coordinate['leftBottom'] ?? const <double>[0, 0];
      if (startLeftTop.length < 2 || endLeftTop.length < 2) {
        return null;
      }

      final startWidth = startRightTop.isNotEmpty
          ? startRightTop[0] - startLeftTop[0]
          : 0;
      final endWidth = endRightTop.isNotEmpty ? endRightTop[0] - endLeftTop[0] : 0;
      final startInset = startWidth > 6 ? startWidth * 0.75 : 1;
      final endInset = endWidth > 6 ? endWidth / 4 : 1;
      final startBottomY = startLeftBottom.length > 1
          ? startLeftBottom[1]
          : startLeftTop[1] + start.lineHeight;
      final endBottomY = endLeftBottom.length > 1
          ? endLeftBottom[1]
          : endLeftTop[1] + end.lineHeight;

      return <String, Object?>{
        'startX': rect.left + startLeftTop[0] + startInset,
        'startY': rect.top + (startLeftTop[1] + startBottomY) / 2,
        'endX': rect.left + endRightTop[0] - endInset,
        'endY': rect.top + (endLeftTop[1] + endBottomY) / 2,
      };
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
          labelMousedownCount = 0;
          lastLabelValue = null;
          final elements = editor_core.splitText(text)
              .map((value) => editor_core.IElement(value: value))
              .toList(growable: false);
          app.editor.command.executeSetValue(
            editor_core.IEditorData(main: elements),
          );
          app.editor.command.executeSetRange(0, 0);
          focusInput();
        }),
        'setRangeBeforeTextValue': js_util.allowInterop((String text) {
          final elements = app.editor.getDraw().getOriginalMainElementList();
          final buffer = StringBuffer();
          final elementIndexes = <int>[];
          for (var index = 0; index < elements.length; index += 1) {
            final value = elements[index].value;
            if (value.isEmpty || value == '\u200B') {
              continue;
            }
            buffer.write(value);
            for (var offset = 0; offset < value.length; offset += 1) {
              elementIndexes.add(index);
            }
          }
          final matchOffset = buffer.toString().indexOf(text);
          if (matchOffset == -1 || matchOffset >= elementIndexes.length) {
            return false;
          }
          final index = elementIndexes[matchOffset];
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
        'resetMockContent': js_util.allowInterop(() {
          labelMousedownCount = 0;
          lastLabelValue = null;
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
        'setMode': js_util.allowInterop((String value) {
          final mode = editor_core.EditorMode.values.firstWhere(
            (candidate) => candidate.name == value,
            orElse: () => editor_core.EditorMode.edit,
          );
          app.editor.command.executeMode(mode);
          if (mode != editor_core.EditorMode.graffiti) {
            focusInput();
          }
        }),
        'setPrintModeOptions': js_util.allowInterop((
          bool backgroundDisabled,
          bool filterEmptyControl,
          String? backgroundColor,
        ) {
          final updateOption = editor_model.IUpdateOption()
            ..background = background_model.IBackgroundOption(
              color: backgroundColor,
            )
            ..modeRule = editor_model.IModeRule(
              print: editor_model.IPrintModeRule(
                imagePreviewerDisabled: false,
                backgroundDisabled: backgroundDisabled,
                filterEmptyControl: filterEmptyControl,
              ),
            );
          app.editor.command.executeUpdateOptions(updateOption);
          focusInput();
        }),
        'setWhiteSpaceVisible': js_util.allowInterop((bool visible) {
          final draw = app.editor.getDraw();
          final options = draw.getOptions();
          options.whiteSpace?.disabled = !visible;
          draw.render(
            draw_model.IDrawOption(
              isCompute: false,
              isSetCursor: false,
              isSubmitHistory: false,
            ),
          );
        }),
        'insertLabel': js_util.allowInterop((String value) {
          app.editor.command.executeInsertElementList(
            <editor_core.IElement>[
              editor_core.IElement(
                type: editor_core.ElementType.label,
                value: value,
                labelId: 'label-$value',
              ),
            ],
          );
          focusInput();
        }),
        'labelMousedownState': js_util.allowInterop(() {
          return js_util.jsify(
            <String, Object?>{
              'count': labelMousedownCount,
              'value': lastLabelValue,
            },
          );
        }),
        'firstLabelClientRect': js_util.allowInterop(() {
          final draw = app.editor.getDraw();
          final elements = draw.getElementList();
          final positions = draw.getPosition().getPositionList();
          final index = elements.indexWhere(
            (element) => element.type == editor_core.ElementType.label,
          );
          if (index < 0 || index >= positions.length) {
            return null;
          }
          final position = positions[index];
          final pageList = draw.getPageList();
          final pageNo = position.pageNo;
          if (pageNo < 0 || pageNo >= pageList.length) {
            return null;
          }
          final page = pageList[pageNo];
          if (page is! html.CanvasElement) {
            return null;
          }
          final rect = page.getBoundingClientRect();
          final leftTop = position.coordinate['leftTop'] ?? const <double>[0, 0];
          final rightTop = position.coordinate['rightTop'] ?? const <double>[0, 0];
          final leftBottom = position.coordinate['leftBottom'] ?? const <double>[0, 0];
          final width = rightTop.isNotEmpty && leftTop.isNotEmpty
              ? rightTop[0] - leftTop[0]
              : 0;
          final height = leftBottom.length > 1 && leftTop.length > 1
              ? leftBottom[1] - leftTop[1]
              : 0;
          return js_util.jsify(
            <String, Object?>{
              'x': rect.left + (leftTop.isNotEmpty ? leftTop[0] + width / 2 : 0),
              'y': rect.top + (leftTop.length > 1 ? leftTop[1] + height / 2 : 0),
              'width': width,
              'height': height,
            },
          );
        }),
        'firstImageClientRect': js_util.allowInterop(() {
          final rect = firstImageClientRect();
          return rect == null ? null : js_util.jsify(rect);
        }),
        'dragSelectionPoints': js_util.allowInterop((num start, num end) {
          final points = dragSelectionPoints(start.toInt(), end.toInt());
          return points == null ? null : js_util.jsify(points);
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
              extraPickAttrs: <String>[
                'laTexSVG',
                'imgCrop',
                'imgCaption',
                'imgDisplay',
                'imgFloatPosition',
                'label',
                'labelId',
              ],
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
                    'imgCrop': element.imgCrop == null
                        ? null
                        : <String, Object?>{
                            'x': element.imgCrop!.x,
                            'y': element.imgCrop!.y,
                            'width': element.imgCrop!.width,
                            'height': element.imgCrop!.height,
                          },
                    'imgCaption': element.imgCaption == null
                        ? null
                        : <String, Object?>{
                            'value': element.imgCaption!.value,
                            'color': element.imgCaption!.color,
                            'font': element.imgCaption!.font,
                            'size': element.imgCaption!.size,
                            'top': element.imgCaption!.top,
                          },
                    'imgDisplay': element.imgDisplay?.name,
                    'imgFloatPosition': element.imgFloatPosition == null
                        ? null
                        : <String, Object?>{
                            'x': element.imgFloatPosition!['x'],
                            'y': element.imgFloatPosition!['y'],
                            'pageNo': element.imgFloatPosition!['pageNo'],
                          },
                    'labelId': element.labelId,
                    'label': element.label == null
                        ? null
                        : <String, Object?>{
                            'color': element.label!.color,
                            'backgroundColor': element.label!.backgroundColor,
                            'borderRadius': element.label!.borderRadius,
                            'padding': element.label!.padding?.toList(),
                          },
                    'font': element.font,
                    'color': element.color,
                    'areaId': element.areaId,
                    'controlId': element.controlId,
                    'controlComponent': element.controlComponent?.name,
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
                    'tableBorderType': element.borderType?.name,
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
                    'tableCellBorders': element.trList
                        ?.map(
                          (tr) => tr.tdList
                              .map(
                                (td) => <String, Object?>{
                                  'borderTypes': td.borderTypes
                                      ?.map((border) => border.name)
                                      .toList(growable: false),
                                  'slashTypes': td.slashTypes
                                      ?.map((slash) => slash.name)
                                      .toList(growable: false),
                                },
                              )
                              .toList(growable: false),
                        )
                        .toList(growable: false),
                    'tableVerticalAligns': element.trList
                        ?.map(
                          (tr) => tr.tdList
                              .map((td) => td.verticalAlign?.name)
                              .toList(growable: false),
                        )
                        .toList(growable: false),
                  },
                )
                .toList(growable: false),
          );
        }),
        'drawElements': js_util.allowInterop(() {
          final elements = app.editor.getDraw().getElementList();
          return js_util.jsify(
            elements
                .map(
                  (element) => <String, Object?>{
                    'type': element.type?.name,
                    'value': element.value,
                    'controlId': element.controlId,
                    'controlComponent': element.controlComponent?.name,
                    'controlType': element.control?.type.name,
                  },
                )
                .toList(growable: false),
          );
        }),
        'graffitiData': js_util.allowInterop(() {
          final result = app.editor.command.getValue();
          return js_util.jsify(
            result.data.graffiti
                    ?.map(
                      (item) => <String, Object?>{
                        'pageNo': item.pageNo,
                        'strokes': item.strokes
                            .map(
                              (stroke) => <String, Object?>{
                                'lineColor': stroke.lineColor,
                                'lineWidth': stroke.lineWidth,
                                'points': stroke.points.toList(growable: false),
                              },
                            )
                            .toList(growable: false),
                      },
                    )
                    .toList(growable: false) ??
                const <Object?>[],
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
        'insertImage': js_util.allowInterop((String value, num width, num height) {
          app.editor.command.executeImage(
            draw_model.IDrawImagePayload(
              value: value,
              width: width.toDouble(),
              height: height.toDouble(),
            ),
          );
          focusInput();
        }),
        'openFirstImagePreviewer': js_util.allowInterop(() {
          final draw = app.editor.getDraw();
          final elements = draw.getElementList();
          final positions = draw.getPosition().getPositionList();
          final index = elements.indexWhere(
            (element) => element.type == editor_core.ElementType.image,
          );
          if (index < 0 || index >= positions.length) {
            return false;
          }
          final previewer = draw.getPreviewer();
          previewer?.drawResizer(elements[index], positions[index]);
          previewer?.render();
          return true;
        }),
        'dragPreviewerImage': js_util.allowInterop((num startX, num startY, num endX, num endY) {
          final previewer = html.document.querySelector('.ce-image-previewer');
          final image = html.document.querySelector('.ce-image-previewer .ce-image-container img');
          if (previewer == null || image == null) {
            return false;
          }
          image.dispatchEvent(
            html.MouseEvent(
              'mousedown',
              canBubble: true,
              cancelable: true,
              clientX: startX.toInt(),
              clientY: startY.toInt(),
              button: 0,
              view: html.window,
            ),
          );
          previewer.dispatchEvent(
            html.MouseEvent(
              'mousemove',
              canBubble: true,
              cancelable: true,
              clientX: endX.toInt(),
              clientY: endY.toInt(),
              button: 0,
              view: html.window,
            ),
          );
          previewer.dispatchEvent(
            html.MouseEvent(
              'mouseup',
              canBubble: true,
              cancelable: true,
              clientX: endX.toInt(),
              clientY: endY.toInt(),
              button: 0,
              view: html.window,
            ),
          );
          return true;
        }),
        'wheelPreviewer': js_util.allowInterop((num deltaY) {
          final previewer = html.document.querySelector('.ce-image-previewer');
          if (previewer == null) {
            return false;
          }
          previewer.dispatchEvent(
            html.WheelEvent(
              'wheel',
              canBubble: true,
              cancelable: true,
              deltaY: deltaY.toDouble(),
              view: html.window,
            ),
          );
          return true;
        }),
        'dragResizerHandle': js_util.allowInterop((num handleIndex, num deltaX, num deltaY) {
          final handle = html.document.querySelector(
            '.ce-resizer-selection .handle-${handleIndex.toInt()}',
          );
          if (handle == null) {
            return false;
          }
          final rect = handle.getBoundingClientRect();
          final startX = rect.left + rect.width / 2;
          final startY = rect.top + rect.height / 2;
          handle.dispatchEvent(
            html.MouseEvent(
              'mousedown',
              canBubble: true,
              cancelable: true,
              clientX: startX.round(),
              clientY: startY.round(),
              button: 0,
              view: html.window,
            ),
          );
          html.document.dispatchEvent(
            html.MouseEvent(
              'mousemove',
              canBubble: true,
              cancelable: true,
              clientX: (startX + deltaX.toDouble()).round(),
              clientY: (startY + deltaY.toDouble()).round(),
              button: 0,
              view: html.window,
            ),
          );
          html.document.dispatchEvent(
            html.MouseEvent(
              'mouseup',
              canBubble: true,
              cancelable: true,
              clientX: (startX + deltaX.toDouble()).round(),
              clientY: (startY + deltaY.toDouble()).round(),
              button: 0,
              view: html.window,
            ),
          );
          focusInput();
          return true;
        }),
        'setImageCrop': js_util.allowInterop((num x, num y, num width, num height) {
          final elements = app.editor.getDraw().getOriginalMainElementList();
          final index = elements.indexWhere(
            (element) => element.type == editor_core.ElementType.image,
          );
          if (index == -1) {
            return false;
          }
          app.editor.command.executeSetPositionContext(
            range_model.IRange(startIndex: index, endIndex: index),
          );
          app.editor.command.executeSetRange(index, index);
          app.editor.command.executeSetImageCrop(
            editor_core.IImageCrop(
              x: x,
              y: y,
              width: width,
              height: height,
            ),
          );
          focusInput();
          return true;
        }),
        'setImageCaption': js_util.allowInterop((String value) {
          final elements = app.editor.getDraw().getOriginalMainElementList();
          final index = elements.indexWhere(
            (element) => element.type == editor_core.ElementType.image,
          );
          if (index == -1) {
            return false;
          }
          app.editor.command.executeSetPositionContext(
            range_model.IRange(startIndex: index, endIndex: index),
          );
          app.editor.command.executeSetRange(index, index);
          app.editor.command.executeSetImageCaption(
            editor_core.IImageCaption(value: value),
          );
          focusInput();
          return true;
        }),
        'pageImages': js_util.allowInterop((Object callback) async {
          final images = await app.editor.command.getImage();
          js_util.callMethod<void>(
            callback,
            'call',
            <Object?>[null, js_util.jsify(images)],
          );
        }),
        'seedGraffitiStroke': js_util.allowInterop((
          num startX,
          num startY,
          num endX,
          num endY,
        ) {
          final draw = app.editor.getDraw();
          final graffiti = draw.getGraffiti();
          if (graffiti == null) {
            return false;
          }
          final data = graffiti.getValue();
          final pageNo = draw.getPageNo();
          editor_core.IGraffitiData? pageData;
          for (final item in data) {
            if (item.pageNo == pageNo) {
              pageData = item;
              break;
            }
          }
          pageData ??= editor_core.IGraffitiData(
            pageNo: pageNo,
            strokes: <editor_core.IGraffitiStroke>[],
          );
          if (!data.contains(pageData)) {
            data.add(pageData);
          }
          pageData.strokes.add(
            editor_core.IGraffitiStroke(
              lineColor: app.editor.command.getValue().options.graffiti?.defaultLineColor,
              lineWidth: app.editor.command.getValue().options.graffiti?.defaultLineWidth,
              points: <double>[
                startX.toDouble(),
                startY.toDouble(),
                endX.toDouble(),
                endY.toDouble(),
              ],
            ),
          );
          graffiti.setValue(data);
          draw.render(
            draw_model.IDrawOption(
              isCompute: false,
              isSetCursor: false,
              isSubmitHistory: false,
            ),
          );
          return true;
        }),
        'clearGraffiti': js_util.allowInterop(() {
          app.editor.command.executeClearGraffiti();
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
        'focusTableRange': js_util.allowInterop((num startRow, num startCol, num endRow, num endCol) {
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
          final int startTrIndex = startRow.toInt();
          final int startTdIndex = startCol.toInt();
          final int endTrIndex = endRow.toInt();
          final int endTdIndex = endCol.toInt();
          if (startTrIndex < 0 || endTrIndex >= trList.length) {
            return false;
          }
          if (startTdIndex < 0 || endTdIndex >= trList[startTrIndex].tdList.length) {
            return false;
          }
          app.editor.command.executeSetPositionContext(
            range_model.IRange(
              startIndex: 0,
              endIndex: 0,
              tableId: table.id,
              startTdIndex: startTdIndex,
              endTdIndex: endTdIndex,
              startTrIndex: startTrIndex,
              endTrIndex: endTrIndex,
              isCrossRowCol:
                  startTrIndex != endTrIndex || startTdIndex != endTdIndex,
            ),
          );
          app.editor.command.executeSetRange(
            0,
            0,
            table.id,
            startTdIndex,
            endTdIndex,
            startTrIndex,
            endTrIndex,
          );
          app.editor.getDraw().getTableTool()?.render();
          focusInput();
          return true;
        }),
        'openFocusedContextMenu': js_util.allowInterop(() {
          final container = app.editor.getDraw().getContainer();
          final rect = container.getBoundingClientRect();
          final event = html.MouseEvent(
            'contextmenu',
            canBubble: true,
            cancelable: true,
            clientX: (rect.left + 40).round(),
            clientY: (rect.top + 40).round(),
            button: 2,
            view: html.window,
          );
          return container.dispatchEvent(event);
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

  const _ServeArgs(this.dir, this.sendPort);
}

void _registerHarnessLifecycle() {
  setUpAll(() async {
    try {
      final revisionInfo = await downloadChrome(cachePath: '.local-chrome');

      buildDir = Directory(
        p.join(
          '.dart_tool',
          'canvas_editor_e2e',
          DateTime.now().microsecondsSinceEpoch.toString(),
        ),
      )..createSync(recursive: true);
      await _copyDirectory(Directory('web'), buildDir!);

      final mainPath = p.join(buildDir!.path, 'main.dart');
      File(mainPath).writeAsStringSync(_mainDartSource);

      final result = await Process.run(
        'dart',
        <String>[
          'compile',
          'js',
          '-O1',
          '-o',
          p.join(buildDir!.path, 'main.dart.js'),
          mainPath,
        ],
      );
      if (result.exitCode != 0) {
        final String stderrText = (result.stderr as Object?).toString();
        final String stdoutText = (result.stdout as Object?).toString();
        fail(
          'Puppeteer build setup failed while compiling $mainPath\n'
          'exitCode: ${result.exitCode}\n'
          'stdout:\n$stdoutText\n'
          'stderr:\n$stderrText',
        );
      }

      final receivePort = ReceivePort();
      await Isolate.spawn(
        _serveIsolate,
        _ServeArgs(buildDir!.path, receivePort.sendPort),
      );
      final init = await receivePort.first as Map<dynamic, dynamic>;
      serverControl = init['control'] as SendPort;
      baseUrl = 'http://127.0.0.1:${init['port']}';

      browser = await puppeteer.launch(
        executablePath: revisionInfo.executablePath,
        headless: true,
        args: const <String>['--no-sandbox', '--disable-setuid-sandbox'],
      );
    } on TestFailure {
      rethrow;
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
    final tempBuildDir = buildDir;
    if (tempBuildDir != null && tempBuildDir.existsSync()) {
      tempBuildDir.deleteSync(recursive: true);
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
}

Future<void> _serveIsolate(_ServeArgs args) async {
  final handler = createStaticHandler(args.dir, defaultDocument: 'index.html');
  final server = await io.serve(handler, '127.0.0.1', 0);

  final control = ReceivePort();
  args.sendPort.send({'port': server.port, 'control': control.sendPort});

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

Future<bool> _focusTableRange(
  Page page,
  int startRow,
  int startCol,
  int endRow,
  int endCol,
) async {
  final bool? value = await page.evaluate<bool?>(
    '() => window.__editorTest.focusTableRange($startRow, $startCol, $endRow, $endCol)',
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

    Future<List<Map<String, dynamic>>> _readDrawElements(Page page) async {
      final String json = await page.evaluate<String?>(
        '() => JSON.stringify(window.__editorTest.drawElements())',
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

Future<void> _insertImage(
  Page page,
  String value,
  double width,
  double height,
) async {
  final String encoded = jsonEncode(value);
  await page.evaluate<void>(
    '() => window.__editorTest.insertImage($encoded, $width, $height)',
  );
  await Future<void>.delayed(const Duration(milliseconds: 180));
}

Future<void> _insertLabel(Page page, String value) async {
  final String encoded = jsonEncode(value);
  await page.evaluate<void>('() => window.__editorTest.insertLabel($encoded)');
  await Future<void>.delayed(const Duration(milliseconds: 120));
}

Future<bool> _openFirstImagePreviewer(Page page) async {
  final bool? value = await page.evaluate<bool?>(
    '() => window.__editorTest.openFirstImagePreviewer()',
  );
  await Future<void>.delayed(const Duration(milliseconds: 120));
  return value ?? false;
}

Future<bool> _dragPreviewerImage(
  Page page,
  double startX,
  double startY,
  double endX,
  double endY,
) async {
  final bool? value = await page.evaluate<bool?>(
    '() => window.__editorTest.dragPreviewerImage($startX, $startY, $endX, $endY)',
  );
  await Future<void>.delayed(const Duration(milliseconds: 120));
  return value ?? false;
}

Future<bool> _wheelPreviewer(Page page, double deltaY) async {
  final bool? value = await page.evaluate<bool?>(
    '() => window.__editorTest.wheelPreviewer($deltaY)',
  );
  await Future<void>.delayed(const Duration(milliseconds: 120));
  return value ?? false;
}

Future<bool> _dragResizerHandle(
  Page page,
  int handleIndex,
  double deltaX,
  double deltaY,
) async {
  final bool? value = await page.evaluate<bool?>(
    '() => window.__editorTest.dragResizerHandle($handleIndex, $deltaX, $deltaY)',
  );
  await Future<void>.delayed(const Duration(milliseconds: 180));
  return value ?? false;
}

Future<Map<String, dynamic>?> _readPreviewerImageRect(Page page) async {
  final String? json = await page.evaluate<String?>(
    '() => { const image = document.querySelector(\'.ce-image-previewer .ce-image-container img\'); const rect = image?.getBoundingClientRect(); return rect ? JSON.stringify({ x: rect.left, y: rect.top, width: rect.width, height: rect.height }) : null; }',
  );
  if (json == null) {
    return null;
  }
  return Map<String, dynamic>.from(
    jsonDecode(json) as Map<dynamic, dynamic>,
  );
}

Future<Map<String, dynamic>?> _readPreviewerCropSelectionRect(Page page) async {
  final String? json = await page.evaluate<String?>(
    '() => { const selection = document.querySelector(\'.ce-image-previewer .ce-image-crop-selection\'); const rect = selection?.getBoundingClientRect(); return rect ? JSON.stringify({ x: rect.left, y: rect.top, width: rect.width, height: rect.height }) : null; }',
  );
  if (json == null) {
    return null;
  }
  return Map<String, dynamic>.from(
    jsonDecode(json) as Map<dynamic, dynamic>,
  );
}

Future<bool> _clickPreviewerAction(Page page, String selector) async {
  final String encoded = jsonEncode(selector);
  final bool? value = await page.evaluate<bool?>(
    '() => { const target = document.querySelector($encoded); if (!target) return false; target.dispatchEvent(new MouseEvent(\'click\', { bubbles: true, view: window })); return true; }',
  );
  await Future<void>.delayed(const Duration(milliseconds: 120));
  return value ?? false;
}

Future<bool> _dragPreviewerCropSelection(
  Page page,
  double startX,
  double startY,
  double endX,
  double endY,
) async {
  final bool? value = await page.evaluate<bool?>(
    '''() => {
      const layer = document.querySelector('.ce-image-previewer .ce-image-crop-layer');
      const previewer = document.querySelector('.ce-image-previewer');
      if (!layer || !previewer) {
        return false;
      }
      layer.dispatchEvent(new MouseEvent('mousedown', {
        bubbles: true,
        cancelable: true,
        clientX: $startX,
        clientY: $startY,
        button: 0,
        view: window,
      }));
      previewer.dispatchEvent(new MouseEvent('mousemove', {
        bubbles: true,
        cancelable: true,
        clientX: $endX,
        clientY: $endY,
        button: 0,
        view: window,
      }));
      previewer.dispatchEvent(new MouseEvent('mouseup', {
        bubbles: true,
        cancelable: true,
        clientX: $endX,
        clientY: $endY,
        button: 0,
        view: window,
      }));
      return true;
    }''',
  );
  await Future<void>.delayed(const Duration(milliseconds: 120));
  return value ?? false;
}

Future<bool> _movePreviewerCropSelection(
  Page page,
  double deltaX,
  double deltaY,
) async {
  final bool? value = await page.evaluate<bool?>(
    '''() => {
      const selection = document.querySelector('.ce-image-previewer .ce-image-crop-selection');
      const previewer = document.querySelector('.ce-image-previewer');
      if (!selection || !previewer) {
        return false;
      }
      const rect = selection.getBoundingClientRect();
      const startX = rect.left + rect.width / 2;
      const startY = rect.top + rect.height / 2;
      selection.dispatchEvent(new MouseEvent('mousedown', {
        bubbles: true,
        cancelable: true,
        clientX: startX,
        clientY: startY,
        button: 0,
        view: window,
      }));
      previewer.dispatchEvent(new MouseEvent('mousemove', {
        bubbles: true,
        cancelable: true,
        clientX: startX + $deltaX,
        clientY: startY + $deltaY,
        button: 0,
        view: window,
      }));
      previewer.dispatchEvent(new MouseEvent('mouseup', {
        bubbles: true,
        cancelable: true,
        clientX: startX + $deltaX,
        clientY: startY + $deltaY,
        button: 0,
        view: window,
      }));
      return true;
    }''',
  );
  await Future<void>.delayed(const Duration(milliseconds: 120));
  return value ?? false;
}

Future<bool> _dragPreviewerCropHandle(
  Page page,
  String handle,
  double deltaX,
  double deltaY,
) async {
  final String encodedSelector = jsonEncode(
    '.ce-image-previewer .ce-image-crop-handle[data-handle="$handle"]',
  );
  final bool? value = await page.evaluate<bool?>(
    '''() => {
      const target = document.querySelector($encodedSelector);
      const previewer = document.querySelector('.ce-image-previewer');
      if (!target || !previewer) {
        return false;
      }
      const rect = target.getBoundingClientRect();
      const startX = rect.left + rect.width / 2;
      const startY = rect.top + rect.height / 2;
      target.dispatchEvent(new MouseEvent('mousedown', {
        bubbles: true,
        cancelable: true,
        clientX: startX,
        clientY: startY,
        button: 0,
        view: window,
      }));
      previewer.dispatchEvent(new MouseEvent('mousemove', {
        bubbles: true,
        cancelable: true,
        clientX: startX + $deltaX,
        clientY: startY + $deltaY,
        button: 0,
        view: window,
      }));
      previewer.dispatchEvent(new MouseEvent('mouseup', {
        bubbles: true,
        cancelable: true,
        clientX: startX + $deltaX,
        clientY: startY + $deltaY,
        button: 0,
        view: window,
      }));
      return true;
    }''',
  );
  await Future<void>.delayed(const Duration(milliseconds: 120));
  return value ?? false;
}

Future<bool> _setImageCrop(
  Page page,
  double x,
  double y,
  double width,
  double height,
) async {
  final bool? value = await page.evaluate<bool?>(
    '() => window.__editorTest.setImageCrop($x, $y, $width, $height)',
  );
  await Future<void>.delayed(const Duration(milliseconds: 180));
  return value ?? false;
}

Future<bool> _setImageCaption(Page page, String value) async {
  final String encoded = jsonEncode(value);
  final bool? result = await page.evaluate<bool?>(
    '() => window.__editorTest.setImageCaption($encoded)',
  );
  await Future<void>.delayed(const Duration(milliseconds: 180));
  return result ?? false;
}

Future<List<String>> _readPageImages(Page page) async {
  final String json = await page.evaluate<String?>(
        '() => new Promise((resolve) => window.__editorTest.pageImages((images) => resolve(JSON.stringify(images))))',
      ) ??
      '[]';
  return (jsonDecode(json) as List<dynamic>)
      .map((entry) => entry as String)
      .toList(growable: false);
}

Future<Map<String, dynamic>> _readLabelMousedownState(Page page) async {
  final String json = await page.evaluate<String?>(
        '() => JSON.stringify(window.__editorTest.labelMousedownState())',
      ) ??
      '{}';
  return Map<String, dynamic>.from(
    jsonDecode(json) as Map<dynamic, dynamic>,
  );
}

Future<bool> _clickFirstLabel(Page page) async {
  final String? json = await page.evaluate<String?>(
    '() => { const rect = window.__editorTest.firstLabelClientRect(); return rect ? JSON.stringify(rect) : null; }',
  );
  if (json == null) {
    return false;
  }
  final Map<String, dynamic> rect = Map<String, dynamic>.from(
    jsonDecode(json) as Map<dynamic, dynamic>,
  );
  await page.mouse.click(
    Point<num>(
      (rect['x'] as num).toDouble(),
      (rect['y'] as num).toDouble(),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 120));
  return true;
}

Future<Map<String, dynamic>?> _readFirstImageClientRect(Page page) async {
  final String? json = await page.evaluate<String?>(
    '() => { const rect = window.__editorTest.firstImageClientRect(); return rect ? JSON.stringify(rect) : null; }',
  );
  if (json == null) {
    return null;
  }
  return Map<String, dynamic>.from(
    jsonDecode(json) as Map<dynamic, dynamic>,
  );
}

Future<bool> _clickFirstImage(Page page) async {
  final rect = await _readFirstImageClientRect(page);
  if (rect == null) {
    return false;
  }
  await page.mouse.click(
    Point<num>(
      (rect['x'] as num).toDouble(),
      (rect['y'] as num).toDouble(),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 120));
  return true;
}

Future<bool> _openContextMenuAtFirstImage(Page page) async {
  final rect = await _readFirstImageClientRect(page);
  if (rect == null) {
    return false;
  }
  final double x = (rect['x'] as num).toDouble();
  final double y = (rect['y'] as num).toDouble();
  await page.evaluate<void>(
    '''() => {
      const x = $x;
      const y = $y;
      const target = document.elementFromPoint(x, y);
      if (!target) {
        return;
      }
      target.dispatchEvent(new MouseEvent('contextmenu', {
        bubbles: true,
        cancelable: true,
        clientX: x,
        clientY: y,
        button: 2,
        buttons: 2,
        view: window,
      }));
    }''',
  );
  await Future<void>.delayed(const Duration(milliseconds: 120));
  return await page.evaluate<bool>(
    '() => !!document.querySelector(\'.ce-contextmenu-container\')',
  );
}

Future<bool> _openContextMenuOnEditor(Page page) async {
  await page.evaluate<bool>('() => window.__editorTest.openFocusedContextMenu()');
  await Future<void>.delayed(const Duration(milliseconds: 120));
  return await page.evaluate<bool>(
    '() => !!document.querySelector(\'.ce-contextmenu-container\')',
  );
}

Future<bool> _hoverContextMenuItem(Page page, String label) async {
  final String encoded = jsonEncode(label);
  final bool? result = await page.evaluate<bool?>(
    '''() => {
      const label = $encoded;
      const items = Array.from(document.querySelectorAll('.ce-contextmenu-item'));
      const target = items.find((item) =>
        Array.from(item.querySelectorAll('span')).some(
          (span) => (span.textContent || '').trim() === label,
        ),
      );
      if (!target) return false;
      target.dispatchEvent(new MouseEvent('mouseenter', { bubbles: true, view: window }));
      return true;
    }''',
  );
  await Future<void>.delayed(const Duration(milliseconds: 120));
  return result ?? false;
}

Future<bool> _clickContextMenuItem(Page page, String label) async {
  final String encoded = jsonEncode(label);
  final bool? result = await page.evaluate<bool?>(
    '''() => {
      const label = $encoded;
      const items = Array.from(document.querySelectorAll('.ce-contextmenu-item'));
      const target = items.find((item) =>
        Array.from(item.querySelectorAll('span')).some(
          (span) => (span.textContent || '').trim() === label,
        ),
      );
      if (!target) return false;
      target.dispatchEvent(new MouseEvent('click', { bubbles: true, view: window }));
      return true;
    }''',
  );
  await Future<void>.delayed(const Duration(milliseconds: 120));
  return result ?? false;
}

Future<Map<String, dynamic>?> _readDragSelectionPoints(
  Page page,
  int start,
  int end,
) async {
  final String? json = await page.evaluate<String?>(
    '() => { const points = window.__editorTest.dragSelectionPoints($start, $end); return points ? JSON.stringify(points) : null; }',
  );
  if (json == null) {
    return null;
  }
  return Map<String, dynamic>.from(
    jsonDecode(json) as Map<dynamic, dynamic>,
  );
}

Future<bool> _dragMouseSelection(Page page, int start, int end) async {
  final points = await _readDragSelectionPoints(page, start, end);
  if (points == null) {
    return false;
  }
  await page.mouse.move(
    Point<num>(
      (points['startX'] as num).toDouble(),
      (points['startY'] as num).toDouble(),
    ),
  );
  await page.mouse.down();
  await page.mouse.move(
    Point<num>(
      (points['endX'] as num).toDouble(),
      (points['endY'] as num).toDouble(),
    ),
  );
  await page.mouse.up();
  await Future<void>.delayed(const Duration(milliseconds: 180));
  return true;
}

Future<void> _setMode(Page page, String mode) async {
  final String encoded = jsonEncode(mode);
  await page.evaluate<void>('() => window.__editorTest.setMode($encoded)');
  await Future<void>.delayed(const Duration(milliseconds: 120));
}

Future<void> _setPrintModeOptions(
  Page page, {
  bool backgroundDisabled = false,
  bool filterEmptyControl = true,
  String? backgroundColor,
}) async {
  final String colorArg = backgroundColor == null ? 'null' : jsonEncode(backgroundColor);
  await page.evaluate<void>(
    '() => window.__editorTest.setPrintModeOptions($backgroundDisabled, $filterEmptyControl, $colorArg)',
  );
  await Future<void>.delayed(const Duration(milliseconds: 120));
}

Future<void> _setWhiteSpaceVisible(Page page, bool visible) async {
  final String encoded = jsonEncode(visible);
  await page.evaluate<void>(
    '() => window.__editorTest.setWhiteSpaceVisible($encoded)',
  );
  await Future<void>.delayed(const Duration(milliseconds: 120));
}

Future<List<Map<String, dynamic>>> _readGraffitiData(Page page) async {
  final String json = await page.evaluate<String?>(
        '() => JSON.stringify(window.__editorTest.graffitiData())',
      ) ??
      '[]';
  return (jsonDecode(json) as List<dynamic>)
      .map((entry) => Map<String, dynamic>.from(entry as Map<dynamic, dynamic>))
      .toList(growable: false);
}

Future<void> _clearGraffiti(Page page) async {
  await page.evaluate<void>('() => window.__editorTest.clearGraffiti()');
  await Future<void>.delayed(const Duration(milliseconds: 120));
}

Future<bool> _seedGraffitiStroke(
  Page page, {
  double startX = 80,
  double startY = 80,
  double endX = 180,
  double endY = 140,
}) async {
  final bool? result = await page.evaluate<bool?>(
    '() => window.__editorTest.seedGraffitiStroke($startX, $startY, $endX, $endY)',
  );
  await Future<void>.delayed(const Duration(milliseconds: 180));
  return result ?? false;
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