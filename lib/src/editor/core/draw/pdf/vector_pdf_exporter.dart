import 'dart:typed_data';

import '../../../../document/pdf/pdf_content.dart';
import '../../../../document/pdf/pdf_image.dart';
import '../../../../document/pdf/pdf_writer.dart';
import '../../../dataset/constant/common.dart';
import '../../../dataset/constant/list.dart' as list_constants;
import '../../../dataset/constant/page_number.dart';
import '../../../dataset/enum/common.dart';
import '../../../dataset/enum/control.dart';
import '../../../dataset/enum/editor.dart';
import '../../../dataset/enum/element.dart';
import '../../../dataset/enum/list.dart';
import '../../../dataset/enum/row.dart';
import '../../../dataset/enum/table/table.dart';
import '../../../interface/draw.dart';
import '../../../interface/editor.dart';
import '../../../interface/element.dart';
import '../../../interface/header.dart';
import '../../../interface/page_number.dart';
import '../../../interface/position.dart';
import '../../../interface/row.dart';
import '../../../interface/table/td.dart';
import '../../../interface/watermark.dart';
import '../draw.dart';
import '../frame/footer.dart';
import '../frame/header.dart';
import '../frame/page_number.dart';

/// Exportador PDF **vetorial**: percorre o layout já computado pelo editor
/// (pageRowList + positionList) e emite texto real (selecionável e
/// pesquisável, fontes standard-14 WinAnsi), linhas/retângulos de tabelas,
/// realces, sublinhados e imagens como XObjects — nada de rasterização.
///
/// A fidelidade de posicionamento é a do próprio layout: cada elemento é
/// posicionado com as coordenadas do canvas, então não há deriva por
/// diferença de métricas de fonte.
class VectorPdfExporter {
  VectorPdfExporter(this._draw)
      : _options = _draw.getOptions(),
        _scale = (_draw.getOptions().scale ?? 1).toDouble();

  final Draw _draw;
  final IEditorOption _options;
  final double _scale;

  final PdfWriter _writer = PdfWriter();

  /// Cache dataURL → id do XObject (imagens repetidas entram uma vez).
  final Map<String, int> _imageIds = <String, int>{};

  late double _pageHeightPt;
  late double _k;

  Uint8List export({String title = 'Documento'}) {
    final double widthPt = _draw.getOriginalWidth() * 72 / 96;
    _pageHeightPt = _draw.getOriginalHeight() * 72 / 96;
    _k = (72 / 96) / _scale;

    final List<List<IRow>> pageRowList = _draw.getPageRowList();
    final dynamic position = _draw.getPosition();
    final List<IElementPosition> mainPositions =
        (position.getOriginalMainPositionList() as List<dynamic>)
            .whereType<IElementPosition>()
            .toList();
    final List<IElement> mainElements = _draw.getOriginalMainElementList();
    final bool isPaging = _draw.getIsPagingMode();

    for (int pageNo = 0; pageNo < pageRowList.length; pageNo++) {
      final _PageContext page = _PageContext(
        PdfContentBuilder(pageHeightPt: _pageHeightPt, k: _k),
      );
      if (isPaging && _options.watermark?.data != null) {
        _drawWatermark(page);
      }
      _drawFloatImages(page, pageNo, const <ImageDisplay>[
        ImageDisplay.floatBottom,
      ]);
      _drawRows(page, pageRowList[pageNo], mainPositions, mainElements);
      if (isPaging) {
        if (_options.header?.disabled != true) {
          _drawHeader(page, pageNo);
        }
        if (_options.pageNumber?.disabled != true) {
          _drawPageNumber(page, pageNo);
        }
        if (_options.footer?.disabled != true) {
          _drawFooter(page, pageNo);
        }
      }
      _drawFloatImages(page, pageNo, const <ImageDisplay>[
        ImageDisplay.floatTop,
        ImageDisplay.surround,
      ]);
      _writer.addPage(
        widthPt: widthPt,
        heightPt: _pageHeightPt,
        content: page.content.build(),
        xObjects: page.xObjects,
        annotationIds: page.annotations,
      );
    }
    return _writer.build(title: title);
  }

  // ── Linhas/elementos ──────────────────────────────────────────────────

  void _drawRows(
    _PageContext page,
    List<IRow> rowList,
    List<IElementPosition> positionList,
    List<IElement> elementList,
  ) {
    for (final IRow curRow in rowList) {
      for (int j = 0; j < curRow.elementList.length; j++) {
        final IRowElement element = curRow.elementList[j];
        final int elementIndex = curRow.startIndex + j;
        if (elementIndex < 0 || elementIndex >= positionList.length) {
          continue;
        }
        final IElementPosition pos = positionList[elementIndex];
        final List<double> leftTop =
            pos.coordinate['leftTop'] ?? const <double>[0, 0];
        final double x = leftTop.isNotEmpty ? leftTop[0] : 0;
        final double y = leftTop.length > 1 ? leftTop[1] : 0;
        final double baseline = y + pos.ascent;
        final bool isHidden =
            element.hide == true || element.control?.hide == true;
        if (isHidden) continue;

        _drawElementHighlight(page, element, curRow, x, y);

        final ElementType? type = element.type;
        if (type == ElementType.image) {
          final ImageDisplay? display = element.imgDisplay;
          if (display != ImageDisplay.surround &&
              display != ImageDisplay.floatTop &&
              display != ImageDisplay.floatBottom) {
            _drawImageElement(page, element, x, baseline);
          }
        } else if (type == ElementType.table) {
          _drawTable(page, element, x, y);
        } else if (type == ElementType.hyperlink) {
          _drawHyperlink(page, element, curRow, x, y, baseline);
        } else if (type == ElementType.superscript) {
          _drawText(page, element, x, baseline - element.metrics.height / 2);
        } else if (type == ElementType.subscript) {
          _drawText(page, element, x, baseline + element.metrics.height / 2);
        } else if (type == ElementType.separator) {
          _drawSeparator(page, element, x, y);
        } else if (type == ElementType.pageBreak) {
          // Marca visual de quebra não aparece na impressão.
        } else if (type == ElementType.checkbox ||
            element.controlComponent == ControlComponent.checkbox) {
          _drawCheckbox(page, element, x, baseline);
        } else if (type == ElementType.radio ||
            element.controlComponent == ControlComponent.radio) {
          _drawRadio(page, element, x, baseline);
        } else if (type == ElementType.tab ||
            type == ElementType.block ||
            type == ElementType.latex) {
          // Sem representação vetorial (tab é espaço; block/latex fora do v1).
        } else {
          _drawText(page, element, x, baseline);
        }

        _drawElementDecorations(page, element, curRow, x, y, baseline);

        if (type == ElementType.table) {
          _drawTableContents(page, element);
        }
      }
      _drawListMarker(page, curRow, positionList);
    }
  }

  void _drawText(
    _PageContext page,
    IRowElement element,
    double x,
    double baseline,
  ) {
    final String encoded = encodeWinAnsi(element.value);
    if (encoded.isEmpty) return;
    final double sizePx = _draw.getElementSize(element) * _scale;
    final String baseFont = standardFontFor(
      family: element.font ?? _options.defaultFont,
      bold: element.bold == true,
      italic: element.italic == true,
    );
    page.content.text(
      fontResource: _writer.fontResourceName(baseFont),
      sizePx: sizePx,
      winAnsiText: encoded,
      x: x,
      baselineY: baseline,
      color: element.color ?? '#000000',
    );
  }

  void _drawElementHighlight(
    _PageContext page,
    IRowElement element,
    IRow curRow,
    double x,
    double y,
  ) {
    final String? highlight = element.highlight;
    if (highlight == null || highlight.isEmpty) return;
    final double marginHeight = _draw.getDefaultBasicRowMarginHeight();
    final double highlightMargin = _draw.getHighlightMarginHeight();
    final double offsetX = element.left ?? 0;
    page.content.fillRect(
      x - offsetX,
      y + marginHeight - highlightMargin,
      element.metrics.width + offsetX,
      curRow.height - 2 * marginHeight + 2 * highlightMargin,
      _lightenColor(highlight, 0.5),
    );
  }

  void _drawElementDecorations(
    _PageContext page,
    IRowElement element,
    IRow curRow,
    double x,
    double y,
    double baseline,
  ) {
    if (element.underline == true || element.control?.underline == true) {
      final double rowMargin = _draw.getElementRowMargin(element);
      final double offsetX = element.left ?? 0;
      double underlineOffset = 0;
      if (element.type == ElementType.subscript) {
        underlineOffset = element.metrics.height / 2;
      }
      final String color = element.control?.underline == true
          ? (_options.underlineColor ?? '#000000')
          : (element.color ?? '#000000');
      page.content.strokeLine(
        x - offsetX,
        y + curRow.height - rowMargin + underlineOffset,
        x - offsetX + element.metrics.width + offsetX,
        y + curRow.height - rowMargin + underlineOffset,
        color: color,
        widthPx: _scale,
      );
    }
    if (element.strikeout == true) {
      final double sizePx = _draw.getElementSize(element) * _scale;
      double strikeY = baseline - sizePx * 0.29;
      if (element.type == ElementType.subscript) {
        strikeY += element.metrics.height / 2;
      } else if (element.type == ElementType.superscript) {
        strikeY -= element.metrics.height / 2;
      }
      page.content.strokeLine(
        x,
        strikeY,
        x + element.metrics.width,
        strikeY,
        color: element.color ?? '#000000',
        widthPx: _scale,
      );
    }
  }

  void _drawHyperlink(
    _PageContext page,
    IRowElement element,
    IRow curRow,
    double x,
    double y,
    double baseline,
  ) {
    final String encoded = encodeWinAnsi(element.value);
    if (encoded.isEmpty) return;
    final double sizePx = _draw.getElementSize(element) * _scale;
    final String baseFont = standardFontFor(
      family: element.font ?? _options.defaultFont,
      bold: element.bold == true,
      italic: element.italic == true,
    );
    final String color = element.color ?? '#0000ff';
    page.content.text(
      fontResource: _writer.fontResourceName(baseFont),
      sizePx: sizePx,
      winAnsiText: encoded,
      x: x,
      baselineY: baseline,
      color: color,
    );
    final String? url = element.url;
    if (url != null && url.isNotEmpty) {
      page.annotations.add(_writer.addLinkAnnotation(
        <double>[
          x * _k,
          _pageHeightPt - (y + curRow.height) * _k,
          (x + element.metrics.width) * _k,
          _pageHeightPt - y * _k,
        ],
        url,
      ));
    }
  }

  void _drawSeparator(
    _PageContext page,
    IRowElement element,
    double x,
    double y,
  ) {
    final double lineWidth =
        (_options.separator?.lineWidth ?? 1).toDouble() * _scale;
    final String color =
        element.color ?? _options.separator?.strokeStyle ?? '#000000';
    final double width =
        (element.width ?? element.metrics.width / _scale) * _scale;
    page.content.strokeLine(
      x,
      y.roundToDouble() + lineWidth / 2,
      x + width,
      y.roundToDouble() + lineWidth / 2,
      color: color,
      widthPx: lineWidth,
      dashPx: element.dashArray,
    );
  }

  void _drawCheckbox(
    _PageContext page,
    IRowElement element,
    double x,
    double baseline,
  ) {
    final double side = (_options.checkbox?.width ?? 14).toDouble() * _scale;
    final double gap = (_options.checkbox?.gap ?? 5).toDouble() * _scale;
    final String fillStyle = _options.checkbox?.fillStyle ?? '#5175f4';
    final double left = x + gap;
    final double top = baseline - side;
    final bool checked = element.checkbox?.value == true;
    if (checked) {
      page.content.fillRect(left, top, side, side, fillStyle);
      // Marca de seleção: duas linhas brancas.
      page.content.strokeLine(left + side * 0.22, top + side * 0.52,
          left + side * 0.42, top + side * 0.72,
          color: '#ffffff', widthPx: 1.5 * _scale);
      page.content.strokeLine(left + side * 0.42, top + side * 0.72,
          left + side * 0.8, top + side * 0.3,
          color: '#ffffff', widthPx: 1.5 * _scale);
    } else {
      page.content.strokeRect(left, top, side, side,
          color: '#d0d5dd', widthPx: _scale);
    }
  }

  void _drawRadio(
    _PageContext page,
    IRowElement element,
    double x,
    double baseline,
  ) {
    final double side = (_options.radio?.width ?? 14).toDouble() * _scale;
    final double gap = (_options.radio?.gap ?? 5).toDouble() * _scale;
    final double cx = x + gap + side / 2;
    final double cy = baseline - side / 2;
    final bool checked = element.radio?.value == true;
    _strokeCircle(page, cx, cy, side / 2, '#d0d5dd', _scale);
    if (checked) {
      _fillCircle(page, cx, cy, side / 4,
          _options.radio?.fillStyle ?? '#5175f4');
    }
  }

  // ── Tabela ────────────────────────────────────────────────────────────

  void _drawTable(
    _PageContext page,
    IRowElement element,
    double startX,
    double startY,
  ) {
    final List<ITr>? trList = element.trList;
    if (trList == null) return;
    // Fundo das células.
    for (final ITr tr in trList) {
      for (final ITd td in tr.tdList) {
        final String? backgroundColor = td.backgroundColor;
        if (backgroundColor == null || backgroundColor.isEmpty) continue;
        page.content.fillRect(
          (td.x ?? 0) * _scale + startX,
          (td.y ?? 0) * _scale + startY,
          (td.width ?? 0) * _scale,
          (td.height ?? 0) * _scale,
          backgroundColor,
        );
      }
    }
    _drawTableBorders(page, element, startX, startY);
  }

  void _drawTableBorders(
    _PageContext page,
    IRowElement element,
    double startX,
    double startY,
  ) {
    final List<ITr>? trList = element.trList;
    final List<dynamic>? colgroup = element.colgroup;
    if (trList == null || colgroup == null) return;
    final TableBorder? borderType = element.borderType;
    final bool isEmpty = borderType == TableBorder.empty;
    final bool isExternal = borderType == TableBorder.external;
    final bool isInternal = borderType == TableBorder.internal;
    final String color = element.borderColor ??
        _options.table?.defaultBorderColor ??
        '#d9d9d9';
    final double borderWidth = (element.borderWidth ?? 1) * _scale;
    final double? externalWidth = element.borderExternalWidth != null
        ? element.borderExternalWidth! * _scale
        : null;
    final List<double>? dash =
        borderType == TableBorder.dash ? const <double>[3, 3] : null;

    if (!isEmpty && !isInternal) {
      page.content.strokeRect(
        startX,
        startY,
        (element.width ?? 0) * _scale,
        (element.height ?? 0) * _scale,
        color: color,
        widthPx: (externalWidth ?? borderWidth) / _scale * _scale,
        dashPx: dash,
      );
    }

    for (final ITr tr in trList) {
      for (final ITd td in tr.tdList) {
        final double width = (td.width ?? 0) * _scale;
        final double height = (td.height ?? 0) * _scale;
        final double right = (td.x ?? 0) * _scale + startX + width;
        final double top = (td.y ?? 0) * _scale + startY;

        // Diagonais (slash) da célula.
        final List<TdSlash>? slashTypes = td.slashTypes;
        if (slashTypes != null && slashTypes.isNotEmpty) {
          if (slashTypes.contains(TdSlash.forward)) {
            page.content.strokeLine(right, top, right - width, top + height,
                color: color, widthPx: borderWidth, dashPx: dash);
          }
          if (slashTypes.contains(TdSlash.back)) {
            page.content.strokeLine(
                right - width, top, right, top + height,
                color: color, widthPx: borderWidth, dashPx: dash);
          }
        }

        final List<TdBorder>? borderTypes = td.borderTypes;
        final bool hasCustomBorders =
            borderTypes != null && borderTypes.isNotEmpty;
        if (!hasCustomBorders && (isEmpty || isExternal)) continue;

        if (hasCustomBorders) {
          if (borderTypes.contains(TdBorder.top)) {
            page.content.strokeLine(right - width, top, right, top,
                color: color, widthPx: borderWidth, dashPx: dash);
          }
          if (borderTypes.contains(TdBorder.right)) {
            page.content.strokeLine(right, top, right, top + height,
                color: color, widthPx: borderWidth, dashPx: dash);
          }
          if (borderTypes.contains(TdBorder.bottom)) {
            page.content.strokeLine(right, top + height, right - width,
                top + height,
                color: color, widthPx: borderWidth, dashPx: dash);
          }
          if (borderTypes.contains(TdBorder.left)) {
            page.content.strokeLine(
                right - width, top, right - width, top + height,
                color: color, widthPx: borderWidth, dashPx: dash);
          }
        }

        if (!isEmpty && !isExternal) {
          final int? colIndex = td.colIndex;
          final int? rowIndex = td.rowIndex;
          if (colIndex != null) {
            final bool isRightEdge = colIndex + td.colspan >= colgroup.length;
            if (!isInternal || !isRightEdge) {
              final double lineWidth = externalWidth != null &&
                      externalWidth != borderWidth &&
                      isRightEdge
                  ? externalWidth
                  : borderWidth;
              page.content.strokeLine(right, top, right, top + height,
                  color: color, widthPx: lineWidth, dashPx: dash);
            }
          }
          if (rowIndex != null) {
            final bool isBottomEdge = rowIndex + td.rowspan >= trList.length;
            if (!isInternal || !isBottomEdge) {
              final double lineWidth = externalWidth != null &&
                      externalWidth != borderWidth &&
                      isBottomEdge
                  ? externalWidth
                  : borderWidth;
              page.content.strokeLine(
                  right, top + height, right - width, top + height,
                  color: color, widthPx: lineWidth, dashPx: dash);
            }
          }
        }
      }
    }
  }

  void _drawTableContents(_PageContext page, IRowElement element) {
    final List<ITr>? trList = element.trList;
    if (trList == null) return;
    for (final ITr tr in trList) {
      for (final ITd td in tr.tdList) {
        final List<IRow>? tdRowList = td.rowList;
        final List<IElementPosition>? tdPositions = td.positionList;
        if (tdRowList == null || tdPositions == null) continue;
        _drawRows(page, tdRowList, tdPositions, td.value);
      }
    }
  }

  // ── Lista (marcadores) ───────────────────────────────────────────────

  void _drawListMarker(
    _PageContext page,
    IRow row,
    List<IElementPosition> positionList,
  ) {
    if (row.isList != true ||
        row.startIndex < 0 ||
        row.startIndex >= positionList.length ||
        row.elementList.isEmpty) {
      return;
    }
    final IRowElement startElement = row.elementList.first;
    if (startElement.value != ZERO || startElement.listWrap == true) {
      return;
    }
    if (startElement.listStyle == ListStyle.checkbox) {
      return; // checkbox de lista é desenhado pelo fluxo de checkbox
    }
    double tabWidth = 0;
    final double defaultTabWidth =
        (_options.defaultTabWidth ?? 32).toDouble();
    for (int i = 1; i < row.elementList.length; i++) {
      if (row.elementList[i].type != ElementType.tab) break;
      tabWidth += defaultTabWidth * _scale;
    }
    final IElementPosition startPosition = positionList[row.startIndex];
    final List<double> leftTop =
        startPosition.coordinate['leftTop'] ?? const <double>[0, 0];
    final double startX = leftTop.isNotEmpty ? leftTop[0] : 0;
    final double startY = leftTop.length > 1 ? leftTop[1] : 0;
    final double x = startX - (row.offsetX ?? 0) + tabWidth;
    final double y = startY + row.ascent;
    String text;
    if (startElement.listType == ListType.unordered) {
      final UlStyle? ulStyle = _toUlStyle(startElement.listStyle);
      text = list_constants.ulStyleMapping[ulStyle] ??
          list_constants.ulStyleMapping[UlStyle.disc] ??
          '';
    } else {
      text = '${(row.listIndex ?? 0) + 1}.';
    }
    final String encoded = encodeWinAnsi(text);
    if (encoded.isEmpty) return;
    final double sizePx = (_options.defaultSize ?? 16).toDouble() * _scale;
    page.content.text(
      fontResource: _writer.fontResourceName(
        standardFontFor(family: _options.defaultFont),
      ),
      sizePx: sizePx,
      winAnsiText: encoded,
      x: x,
      baselineY: y,
      color: '#000000',
    );
  }

  UlStyle? _toUlStyle(ListStyle? listStyle) {
    switch (listStyle) {
      case ListStyle.circle:
        return UlStyle.circle;
      case ListStyle.square:
        return UlStyle.square;
      case ListStyle.disc:
        return UlStyle.disc;
      default:
        return null;
    }
  }

  // ── Imagens ───────────────────────────────────────────────────────────

  void _drawImageElement(
    _PageContext page,
    IElement element,
    double x,
    double y,
  ) {
    final double width = (element.width ?? 0) * _scale;
    final double height = (element.height ?? 0) * _scale;
    if (width <= 0 || height <= 0) return;
    final String? name = _resolveImageResource(page, element.value);
    if (name == null) {
      // Formato não suportado: marca a área para não sumir silenciosamente.
      page.content.strokeRect(x, y, width, height,
          color: '#c0c0c0', widthPx: _scale);
      return;
    }
    page.content.drawImage(name, x, y, width, height);
  }

  String? _resolveImageResource(_PageContext page, String dataUrl) {
    int? objectId = _imageIds[dataUrl];
    if (objectId == null) {
      final PdfImageData? decoded = decodeDataUrlImage(dataUrl);
      if (decoded == null) return null;
      objectId = _writer.addImage(decoded);
      _imageIds[dataUrl] = objectId;
    }
    for (final MapEntry<String, int> entry in page.xObjects.entries) {
      if (entry.value == objectId) return entry.key;
    }
    final String name = 'Im${page.xObjects.length + 1}';
    page.xObjects[name] = objectId;
    return name;
  }

  void _drawFloatImages(
    _PageContext page,
    int pageNo,
    List<ImageDisplay> displays,
  ) {
    final dynamic position = _draw.getPosition();
    final List<dynamic> floats =
        position.getFloatPositionList() as List<dynamic>;
    for (final dynamic floatPosition in floats) {
      final IElement element = floatPosition.element as IElement;
      final ImageDisplay? display = element.imgDisplay;
      final int floatPageNo = (floatPosition.pageNo as num?)?.toInt() ?? -1;
      final EditorZone? zone = floatPosition.zone as EditorZone?;
      if ((floatPageNo == pageNo ||
              zone == EditorZone.header ||
              zone == EditorZone.footer) &&
          display != null &&
          displays.contains(display) &&
          element.type == ElementType.image) {
        final Map<String, num>? floatMap = element.imgFloatPosition;
        if (floatMap == null) continue;
        _drawImageElement(
          page,
          element,
          (floatMap['x'] ?? 0).toDouble() * _scale,
          (floatMap['y'] ?? 0).toDouble() * _scale,
        );
      }
    }
  }

  // ── Header / footer / nº de página / marca d'água ────────────────────

  void _drawHeader(_PageContext page, int pageNo) {
    final Header header = _draw.getHeader();
    final List<IRow> renderRows = _clipRowsToMaxHeight(
      header.getRowList(),
      header.getMaxHeight(),
    );
    _drawRows(
        page, renderRows, header.getPositionList(), header.getElementList());
    _drawHeaderTextBoxes(page, header);
  }

  void _drawFooter(_PageContext page, int pageNo) {
    final Footer footer = _draw.getFooter();
    final List<IRow> renderRows = _clipRowsToMaxHeight(
      footer.getRowList(),
      footer.getMaxHeight(),
    );
    _drawRows(
        page, renderRows, footer.getPositionList(), footer.getElementList());
  }

  List<IRow> _clipRowsToMaxHeight(List<IRow> rowList, double maxHeight) {
    final List<IRow> renderRows = <IRow>[];
    double curHeight = 0;
    for (final IRow row in rowList) {
      if (curHeight + row.height > maxHeight) break;
      renderRows.add(row);
      curHeight += row.height;
    }
    return renderRows;
  }

  void _drawHeaderTextBoxes(_PageContext page, Header header) {
    final List<IHeaderTextBox> textBoxes = header.getTextBoxes();
    if (textBoxes.isEmpty) return;
    final double innerWidth = _draw.getInnerWidth();
    final List<double> margins = _draw.getMargins();
    final double headerTop = header.getHeaderTop();
    const double pad = 4;
    final dynamic position = _draw.getPosition();
    for (final IHeaderTextBox tb in textBoxes) {
      final double w = tb.widthPx * _scale;
      final double left = tb.offsetXPx != null
          ? margins[3] + tb.offsetXPx! * _scale
          : margins[3] + (tb.alignRight ? (innerWidth - w) : 0);
      final double top = headerTop + tb.offsetYPx * _scale;
      final double innerBoxWidth = w - 2 * pad * _scale;
      final dynamic rawRows = _draw.computeRowList(
        IComputeRowListPayload(
          innerWidth: innerBoxWidth,
          elementList: tb.elements,
        ),
      );
      final List<IRow> rows =
          rawRows is List ? rawRows.whereType<IRow>().toList() : <IRow>[];
      double contentHeight = 0;
      for (final IRow row in rows) {
        contentHeight += row.height + (row.offsetY ?? 0);
      }
      final double h = tb.heightPx * _scale > contentHeight + 2 * pad * _scale
          ? tb.heightPx * _scale
          : contentHeight + 2 * pad * _scale;
      if (tb.fillColor != null) {
        page.content.fillRect(left, top, w, h, tb.fillColor!);
      }
      page.content.strokeRect(left, top, w, h,
          color: tb.borderColor ?? '#000000',
          widthPx: tb.borderWidthPx * _scale);
      final List<IElementPosition> positions = <IElementPosition>[];
      position.computePageRowPosition(IComputePageRowPositionPayload(
        positionList: positions,
        rowList: rows,
        pageNo: 0,
        startRowIndex: 0,
        startIndex: 0,
        startX: left + pad * _scale,
        startY: top + pad * _scale,
        innerWidth: innerBoxWidth,
        zone: EditorZone.header,
      ));
      _drawRows(page, rows, positions, tb.elements);
    }
  }

  void _drawPageNumber(_PageContext page, int pageNo) {
    final IPageNumber? option = _options.pageNumber;
    if (option == null || option.disabled == true) return;
    final int fromPageNo = option.fromPageNo ?? 0;
    final int startPageNo = option.startPageNo ?? 1;
    final int? maxPageNo = option.maxPageNo;
    if (pageNo < fromPageNo || (maxPageNo != null && pageNo >= maxPageNo)) {
      return;
    }
    String text = option.format ?? PageNumberFormatPlaceholder.pageNo;
    final RegExp pageNoReg =
        RegExp(PageNumberFormatPlaceholder.pageNo, caseSensitive: false);
    if (pageNoReg.hasMatch(text)) {
      text = PageNumber.formatNumberPlaceholder(
        text,
        pageNo + startPageNo - fromPageNo,
        pageNoReg,
        option.numberType,
      );
    }
    final RegExp pageCountReg =
        RegExp(PageNumberFormatPlaceholder.pageCount, caseSensitive: false);
    if (pageCountReg.hasMatch(text)) {
      text = PageNumber.formatNumberPlaceholder(
        text,
        _draw.getPageCount() - fromPageNo,
        pageCountReg,
        option.numberType,
      );
    }
    final double sizePx = (option.size ?? 12).toDouble() * _scale;
    final String family = option.font ?? 'sans-serif';
    final double textWidth = _approximateTextWidth(text, sizePx, family);
    final double width = _draw.getWidth();
    final double y = _draw.getHeight() - _draw.getPageNumberBottom();
    final List<double> margins = _draw.getMargins();
    final RowFlex alignment = option.rowFlex ?? RowFlex.center;
    double x;
    switch (alignment) {
      case RowFlex.right:
        x = width - textWidth - margins[1];
        break;
      case RowFlex.center:
        x = (width - textWidth) / 2;
        break;
      default:
        x = margins[3];
    }
    page.content.text(
      fontResource:
          _writer.fontResourceName(standardFontFor(family: family)),
      sizePx: sizePx,
      winAnsiText: encodeWinAnsi(text),
      x: x,
      baselineY: y,
      color: option.color ?? '#000000',
    );
  }

  void _drawWatermark(_PageContext page) {
    final IWatermark? watermark = _options.watermark;
    final String? data = watermark?.data;
    if (watermark == null || data == null || data.isEmpty) return;
    final double sizePx = (watermark.size ?? 120).toDouble() * _scale;
    final double sizePt = sizePx * _k;
    final String color = _lightenColor(
        watermark.color ?? '#000000', 1 - (watermark.opacity ?? 0.3));
    final double textWidthPt =
        _approximateTextWidth(data, sizePx, watermark.font ?? 'sans-serif') *
            _k;
    // Texto rotacionado 45° com o centro da linha no centro da página.
    final double cxPt = (_draw.getWidth() / 2) * _k;
    final double cyPt = _pageHeightPt - (_draw.getHeight() / 2) * _k;
    const double cos45 = 0.70710678;
    final double txPt = cxPt - (textWidthPt / 2) * cos45;
    final double tyPt = cyPt - (textWidthPt / 2) * cos45;
    final String fontResource = _writer
        .fontResourceName(standardFontFor(family: watermark.font));
    page.content
      ..rawOp('q')
      ..setFillColor(color)
      ..rawOp('BT')
      ..rawOp('$fontResource ${pdfFormatNumber(sizePt)} Tf')
      ..rawOp('$cos45 $cos45 -$cos45 $cos45 '
          '${pdfFormatNumber(txPt)} ${pdfFormatNumber(tyPt)} Tm')
      ..rawOp('(${escapePdfString(encodeWinAnsi(data))}) Tj')
      ..rawOp('ET')
      ..rawOp('Q')
      ..invalidateGraphicsState();
  }

  double _approximateTextWidth(String text, double sizePx, String family) {
    // Aproximação suficiente para centralizar nº de página/marca d'água.
    double units = 0;
    for (final int cp in text.runes) {
      if (cp == 0x20) {
        units += 0.28;
      } else if (cp >= 0x30 && cp <= 0x39) {
        units += 0.556;
      } else if (cp >= 0x41 && cp <= 0x5a) {
        units += 0.667;
      } else {
        units += 0.5;
      }
    }
    return units * sizePx;
  }

  // ── Formas auxiliares ─────────────────────────────────────────────────

  static const double _kappa = 0.5522847498;

  void _strokeCircle(_PageContext page, double cx, double cy, double r,
      String color, double widthPx) {
    page.content.setStrokeStyle(color, widthPx);
    _circlePath(page, cx, cy, r);
    page.content.rawOp('S');
  }

  void _fillCircle(
      _PageContext page, double cx, double cy, double r, String color) {
    page.content.setFillColor(color);
    _circlePath(page, cx, cy, r);
    page.content.rawOp('f');
  }

  void _circlePath(_PageContext page, double cx, double cy, double r) {
    final double k = _k;
    final double x = cx * k;
    final double y = _pageHeightPt - cy * k;
    final double rp = r * k;
    final double o = rp * _kappa;
    String n(double v) => pdfFormatNumber(v);
    page.content
      ..rawOp('${n(x + rp)} ${n(y)} m')
      ..rawOp('${n(x + rp)} ${n(y + o)} ${n(x + o)} ${n(y + rp)} '
          '${n(x)} ${n(y + rp)} c')
      ..rawOp('${n(x - o)} ${n(y + rp)} ${n(x - rp)} ${n(y + o)} '
          '${n(x - rp)} ${n(y)} c')
      ..rawOp('${n(x - rp)} ${n(y - o)} ${n(x - o)} ${n(y - rp)} '
          '${n(x)} ${n(y - rp)} c')
      ..rawOp('${n(x + o)} ${n(y - rp)} ${n(x + rp)} ${n(y - o)} '
          '${n(x + rp)} ${n(y)} c');
  }

  /// Mistura [css] com branco ([amount]=0 mantém, 1 = branco) para aproximar
  /// transparências sem ExtGState.
  String _lightenColor(String css, double amount) {
    final double t = amount.clamp(0.0, 1.0);
    int r = 0, g = 0, b = 0;
    final String value = css.trim();
    if (value.startsWith('#')) {
      final String hex = value.substring(1);
      if (hex.length == 3) {
        r = int.tryParse(hex[0] * 2, radix: 16) ?? 0;
        g = int.tryParse(hex[1] * 2, radix: 16) ?? 0;
        b = int.tryParse(hex[2] * 2, radix: 16) ?? 0;
      } else if (hex.length >= 6) {
        r = int.tryParse(hex.substring(0, 2), radix: 16) ?? 0;
        g = int.tryParse(hex.substring(2, 4), radix: 16) ?? 0;
        b = int.tryParse(hex.substring(4, 6), radix: 16) ?? 0;
      }
    } else {
      return value; // rgb()/nomes: usa como está
    }
    int mix(int c) => (c + (255 - c) * t).round().clamp(0, 255);
    String hex2(int c) => c.toRadixString(16).padLeft(2, '0');
    return '#${hex2(mix(r))}${hex2(mix(g))}${hex2(mix(b))}';
  }
}

class _PageContext {
  _PageContext(this.content);

  final PdfContentBuilder content;
  final Map<String, int> xObjects = <String, int>{};
  final List<int> annotations = <int>[];
}
