import 'dart:html';
import 'dart:math' as math;

import '../../../dataset/constant/common.dart';
import '../../../dataset/enum/common.dart' show MaxHeightRatio;
import '../../../dataset/enum/editor.dart';
import '../../../interface/draw.dart';
import '../../../interface/editor.dart';
import '../../../interface/element.dart';
import '../../../interface/footer.dart';
import '../../../interface/position.dart';
import '../../../interface/row.dart';
import '../../position/position.dart';
import '../../zone/zone.dart';
import '../draw.dart';

class Footer {
  Footer(Draw draw, [List<IElement>? data])
      : _draw = draw,
        _position = draw.getPosition() as Position,
        _zone = draw.getZone(),
        _options = draw.getOptions(),
        _elementList = List<IElement>.from(data ?? const <IElement>[]),
        _rowList = <IRow>[],
        _positionList = <IElementPosition>[];

  final Draw _draw;
  final Position _position;
  final Zone _zone;
  final IEditorOption _options;

  List<IElement> _elementList;
  List<IRow> _rowList;
  List<IElementPosition> _positionList;

  // F4.6: variantes por página (first/even), como no header.
  List<IElement> _firstElementList = <IElement>[];
  List<IElement> _evenElementList = <IElement>[];
  List<IRow> _firstRowList = <IRow>[];
  List<IRow> _evenRowList = <IRow>[];
  List<IElementPosition> _firstPositionList = <IElementPosition>[];
  List<IElementPosition> _evenPositionList = <IElementPosition>[];
  bool _titlePage = false;
  bool _evenAndOdd = false;

  void setVariants({
    List<IElement>? first,
    List<IElement>? even,
    bool titlePage = false,
    bool evenAndOdd = false,
  }) {
    _firstElementList = List<IElement>.from(first ?? const <IElement>[]);
    _evenElementList = List<IElement>.from(even ?? const <IElement>[]);
    _titlePage = titlePage;
    _evenAndOdd = evenAndOdd;
  }

  bool _useFirstOn(int pageNo) =>
      _titlePage && pageNo == 0 && _firstElementList.isNotEmpty;

  bool _useEvenOn(int pageNo) =>
      _evenAndOdd && pageNo.isOdd && _evenElementList.isNotEmpty;

  // F4.6: edição in-place da variante (ver Header).
  String _activeVariant = 'default';

  void setActiveVariantForPage(int pageNo) {
    _activeVariant = _useFirstOn(pageNo)
        ? 'first'
        : _useEvenOn(pageNo)
            ? 'even'
            : 'default';
  }

  void resetActiveVariant() {
    _activeVariant = 'default';
  }

  dynamic _drawDynamic<T>(T Function(dynamic target) callback) {
    try {
      return callback(_draw as dynamic);
    } catch (_) {
      return null;
    }
  }

  List<IRow> getRowList() => switch (_activeVariant) {
        'first' => _firstRowList,
        'even' => _evenRowList,
        _ => _rowList,
      };

  void setElementList(List<IElement> elementList) {
    _elementList = elementList;
  }

  List<IElement> getElementList() => switch (_activeVariant) {
        'first' => _firstElementList,
        'even' => _evenElementList,
        _ => _elementList,
      };

  List<IElementPosition> getPositionList() => switch (_activeVariant) {
        'first' => _firstPositionList,
        'even' => _evenPositionList,
        _ => _positionList,
      };

  void compute() {
    recovery();
    _rowList = _computeRowListFor(_elementList);
    _computePositionListFor(_rowList, _positionList);
    if (_titlePage && _firstElementList.isNotEmpty) {
      _firstRowList = _computeRowListFor(_firstElementList);
      _computePositionListFor(_firstRowList, _firstPositionList);
    }
    if (_evenAndOdd && _evenElementList.isNotEmpty) {
      _evenRowList = _computeRowListFor(_evenElementList);
      _computePositionListFor(_evenRowList, _evenPositionList);
    }
  }

  void recovery() {
    _rowList = <IRow>[];
    _positionList = <IElementPosition>[];
    _firstRowList = <IRow>[];
    _firstPositionList = <IElementPosition>[];
    _evenRowList = <IRow>[];
    _evenPositionList = <IElementPosition>[];
  }

  List<IRow> _computeRowListFor(List<IElement> elementList) {
    final double innerWidth = _draw.getInnerWidth();
    final List<IRow> rows = _drawDynamic((dynamic target) {
          final dynamic result = target.computeRowList(
            IComputeRowListPayload(
              innerWidth: innerWidth,
              elementList: elementList,
            ),
          );
          if (result is List) {
            return result.whereType<IRow>().toList();
          }
          return <IRow>[];
        }) as List<IRow>? ??
        const <IRow>[];
    return List<IRow>.from(rows);
  }

  void _computePositionListFor(
      List<IRow> rowList, List<IElementPosition> positionList) {
    final double footerBottom = getFooterBottom();
    final double footerHeight = getHeight();
    final double pageHeight = _draw.getHeight();
    final double innerWidth = _draw.getInnerWidth();
    final List<double> margins = _draw.getMargins();
    final double startX = margins[3];
    final double startY = pageHeight - footerBottom - footerHeight;
    _position.computePageRowPosition(
      IComputePageRowPositionPayload(
        positionList: positionList,
        rowList: rowList,
        pageNo: 0,
        startRowIndex: 0,
        startIndex: 0,
        startX: startX,
        startY: startY,
        innerWidth: innerWidth,
        zone: EditorZone.footer,
      ),
    );
  }

  double getFooterBottom() {
    final IFooter footer = _resolveFooter();
    if (footer.disabled == true) {
      return 0;
    }
    final double bottom = (footer.bottom ?? 0).toDouble();
    final double scale = (_options.scale ?? 1).toDouble();
    return (bottom * scale).floorToDouble();
  }

  double getMaxHeight() {
    final IFooter footer = _resolveFooter();
    final MaxHeightRatio ratio =
        footer.maxHeightRadio ?? MaxHeightRatio.quarter;
    final double mapping = maxHeightRadioMapping[ratio] ?? 0;
    final double height = _draw.getHeight();
    return math.min(height, height * mapping).floorToDouble();
  }

  double getHeight() {
    final IFooter footer = _resolveFooter();
    if (footer.disabled == true) {
      return 0;
    }
    final double maxHeight = getMaxHeight();
    final double rowHeight = getRowHeight();
    return rowHeight > maxHeight ? maxHeight : rowHeight;
  }

  double getRowHeight() {
    double total = 0;
    for (final IRow row in _rowList) {
      total += row.height;
    }
    return total;
  }

  double getExtraHeight() {
    final List<double> margins = _draw.getMargins();
    final double footerHeight = getHeight();
    final double footerBottom = getFooterBottom();
    final double extraHeight = footerBottom + footerHeight - margins[2];
    return extraHeight <= 0 ? 0 : extraHeight;
  }

  void render(CanvasRenderingContext2D ctx, int pageNo) {
    ctx.save();
    final IFooter footer = _resolveFooter();
    ctx.globalAlpha = _zone.isFooterActive() ? 1 : (footer.inactiveAlpha ?? 1);
    final double innerWidth = _draw.getInnerWidth();
    final double maxHeight = getMaxHeight();
    // F4.6: variante por página (first/even) SEMPRE (edição in-place).
    List<IElement> elementList = _elementList;
    List<IRow> rowSource = _rowList;
    List<IElementPosition> positionList = _positionList;
    if (_useFirstOn(pageNo)) {
      elementList = _firstElementList;
      rowSource = _firstRowList;
      positionList = _firstPositionList;
    } else if (_useEvenOn(pageNo)) {
      elementList = _evenElementList;
      rowSource = _evenRowList;
      positionList = _evenPositionList;
    }
    final List<IRow> renderRows = <IRow>[];
    double curHeight = 0;
    for (final IRow row in rowSource) {
      if (curHeight + row.height > maxHeight) {
        break;
      }
      renderRows.add(row);
      curHeight += row.height;
    }
    _drawDynamic((dynamic target) {
      target.drawRow(
        ctx,
        IDrawRowPayload(
          elementList: elementList,
          positionList: positionList,
          rowList: renderRows,
          pageNo: pageNo,
          startIndex: 0,
          innerWidth: innerWidth,
          zone: EditorZone.footer,
        ),
      );
      return null;
    });
    ctx.restore();
  }

  IFooter _resolveFooter() {
    final IFooter footer = _options.footer ??= IFooter();
    footer.disabled ??= false;
    footer.bottom ??= 0;
    footer.inactiveAlpha ??= 0.6;
    footer.maxHeightRadio ??= MaxHeightRatio.quarter;
    return footer;
  }
}
