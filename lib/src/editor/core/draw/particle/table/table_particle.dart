import 'dart:html';

import '../../../../dataset/enum/element.dart';
import '../../../../dataset/enum/table/table.dart';
import '../../../../interface/editor.dart';
import '../../../../interface/element.dart';
import '../../../../interface/range.dart';
import '../../../../interface/table/table.dart';
import '../../../../interface/table/td.dart';
import '../../draw.dart';

class TableParticle {
  TableParticle(this._draw)
      : _rangeManager = _draw.getRange(),
        _options = _draw.getOptions();

  final Draw _draw;
  final dynamic _rangeManager;
  final IEditorOption _options;

  ITableOption? get _tableOption => _options.table;

  double _scale() => (_options.scale ?? 1).toDouble();

  List<ITr> getTrListGroupByCol(List<ITr> payload) {
    final List<ITr> trList = payload
        .map(
          (ITr tr) => ITr(
            id: tr.id,
            extension: tr.extension,
            externalId: tr.externalId,
            height: tr.height,
            tdList: List<ITd>.from(tr.tdList),
            minHeight: tr.minHeight,
            pagingRepeat: tr.pagingRepeat,
          ),
        )
        .toList();

    for (int t = 0; t < payload.length; t++) {
      final ITr tr = trList[t];
      for (int d = tr.tdList.length - 1; d >= 0; d--) {
        final ITd td = tr.tdList[d];
        final int? rowIndex = td.rowIndex;
        final int? colIndex = td.colIndex;
        if (rowIndex == null || colIndex == null) {
          continue;
        }
        final int curRowIndex = rowIndex + td.rowspan - 1;
        if (curRowIndex != d) {
          final ITd changeTd = tr.tdList.removeAt(d);
          if (curRowIndex >= 0 && curRowIndex < trList.length) {
            final List<ITd> targetTdList = trList[curRowIndex].tdList;
            final int insertIndex =
                colIndex.clamp(0, targetTdList.length).toInt();
            targetTdList.insert(insertIndex, changeTd);
          }
        }
      }
    }

    return trList;
  }

  List<List<ITd>>? getRangeRowCol() {
    final dynamic position = _draw.getPosition();
    final dynamic positionContext = position?.getPositionContext();
    if (positionContext == null || positionContext.isTable != true) {
      return null;
    }

    final dynamic rawRange = _rangeManager?.getRange();
    if (rawRange is! IRange) {
      return null;
    }

    final dynamic rawIndex = positionContext.index;
    final dynamic rawTrIndex = positionContext.trIndex;
    final dynamic rawTdIndex = positionContext.tdIndex;
    final int? index = rawIndex is int ? rawIndex : null;
    final int? trIndex = rawTrIndex is int ? rawTrIndex : null;
    final int? tdIndex = rawTdIndex is int ? rawTdIndex : null;
    if (index == null) {
      return null;
    }

    final List<IElement> elementList = _draw.getOriginalElementList();
    if (index < 0 || index >= elementList.length) {
      return null;
    }
    final IElement element = elementList[index];
    final List<ITr>? trList = element.trList;
    if (trList == null || trIndex == null || tdIndex == null) {
      return null;
    }

    if (rawRange.isCrossRowCol != true) {
      return <List<ITd>>[
        <ITd>[trList[trIndex].tdList[tdIndex]],
      ];
    }

    ITd startTd = trList[rawRange.startTrIndex!].tdList[rawRange.startTdIndex!];
    ITd endTd = trList[rawRange.endTrIndex!].tdList[rawRange.endTdIndex!];

    if ((startTd.x ?? 0) > (endTd.x ?? 0) ||
        (startTd.y ?? 0) > (endTd.y ?? 0)) {
      final ITd temp = startTd;
      startTd = endTd;
      endTd = temp;
    }

    final int? startColIndex = startTd.colIndex;
    final int? endColIndex =
        endTd.colIndex != null ? endTd.colIndex! + endTd.colspan - 1 : null;
    final int? startRowIndex = startTd.rowIndex;
    final int? endRowIndex =
        endTd.rowIndex != null ? endTd.rowIndex! + endTd.rowspan - 1 : null;
    if (startColIndex == null ||
        endColIndex == null ||
        startRowIndex == null ||
        endRowIndex == null) {
      return null;
    }

    final List<List<ITd>> rowCol = <List<ITd>>[];
    for (final ITr tr in trList) {
      final List<ITd> tdList = <ITd>[];
      for (final ITd td in tr.tdList) {
        final int? tdColIndex = td.colIndex;
        final int? tdRowIndex = td.rowIndex;
        if (tdColIndex == null || tdRowIndex == null) {
          continue;
        }
        final bool inColRange =
            tdColIndex >= startColIndex && tdColIndex <= endColIndex;
        final bool inRowRange =
            tdRowIndex >= startRowIndex && tdRowIndex <= endRowIndex;
        if (inColRange && inRowRange) {
          tdList.add(td);
        }
      }
      if (tdList.isNotEmpty) {
        rowCol.add(tdList);
      }
    }

    return rowCol.isEmpty ? null : rowCol;
  }

  void _drawOuterBorder({
    required CanvasRenderingContext2D ctx,
    required double startX,
    required double startY,
    required double width,
    required double height,
    double? borderExternalWidth,
    bool isDrawFullBorder = false,
  }) {
    final double scale = _scale();
    final double originalLineWidth = ctx.lineWidth.toDouble();

    if (borderExternalWidth != null) {
      ctx.lineWidth = borderExternalWidth * scale;
    }

    ctx.beginPath();
    final double x = startX.roundToDouble();
    final double y = startY.roundToDouble();
    ctx.translate(0.5, 0.5);
    if (isDrawFullBorder) {
      ctx.rect(x, y, width, height);
    } else {
      ctx.moveTo(x, y + height);
      ctx.lineTo(x, y);
      ctx.lineTo(x + width, y);
    }
    ctx.stroke();

    if (borderExternalWidth != null) {
      ctx.lineWidth = originalLineWidth;
    }
    ctx.translate(-0.5, -0.5);
  }

  void _drawSlash(
    CanvasRenderingContext2D ctx,
    ITd td,
    double startX,
    double startY,
  ) {
    final double scale = _scale();
    ctx.save();
    ctx.beginPath();
    final double width = (td.width ?? 0) * scale;
    final double height = (td.height ?? 0) * scale;
    final double x = ((td.x ?? 0) * scale + startX).roundToDouble();
    final double y = ((td.y ?? 0) * scale + startY).roundToDouble();
    final List<TdSlash>? slashTypes = td.slashTypes;

    if (slashTypes?.contains(TdSlash.forward) == true) {
      ctx.moveTo(x + width, y);
      ctx.lineTo(x, y + height);
    }
    if (slashTypes?.contains(TdSlash.back) == true) {
      ctx.moveTo(x, y);
      ctx.lineTo(x + width, y + height);
    }
    ctx.stroke();
    ctx.restore();
  }

  void _drawBorder(
    CanvasRenderingContext2D ctx,
    IElement element,
    double startX,
    double startY,
  ) {
    final List<IColgroup>? colgroup = element.colgroup;
    final List<ITr>? trList = element.trList;
    final TableBorder? borderType = element.borderType;
    final String? borderColor = element.borderColor;
    final double borderWidth = element.borderWidth ?? 1;
    final double? borderExternalWidth = element.borderExternalWidth;

    if (colgroup == null || trList == null) {
      return;
    }

    final double scale = _scale();
    final String? defaultBorderColor = _tableOption?.defaultBorderColor;
    final double tableWidth = (element.width ?? 0) * scale;
    final double tableHeight = (element.height ?? 0) * scale;

    final bool isEmptyBorderType = borderType == TableBorder.empty;
    final bool isExternalBorderType = borderType == TableBorder.external;
    final bool isInternalBorderType = borderType == TableBorder.internal;

    ctx.save();
    if (borderType == TableBorder.dash) {
      ctx.setLineDash(<double>[3, 3]);
    }
    ctx.lineWidth = borderWidth * scale;
    ctx.strokeStyle = borderColor ?? defaultBorderColor ?? '#d9d9d9';

    if (!isEmptyBorderType && !isInternalBorderType) {
      _drawOuterBorder(
        ctx: ctx,
        startX: startX,
        startY: startY,
        width: tableWidth,
        height: tableHeight,
        borderExternalWidth: borderExternalWidth,
        isDrawFullBorder: isExternalBorderType,
      );
    }

    for (final ITr tr in trList) {
      for (final ITd td in tr.tdList) {
        if (td.slashTypes?.isNotEmpty == true) {
          _drawSlash(ctx, td, startX, startY);
        }
        if ((td.borderTypes == null || td.borderTypes!.isEmpty) &&
            (isEmptyBorderType || isExternalBorderType)) {
          continue;
        }

        final double width = (td.width ?? 0) * scale;
        final double height = (td.height ?? 0) * scale;
        final double x = ((td.x ?? 0) * scale + startX + width).roundToDouble();
        final double y = ((td.y ?? 0) * scale + startY).roundToDouble();
        ctx.translate(0.5, 0.5);
        ctx.beginPath();

        final List<TdBorder>? borderTypes = td.borderTypes;
        if (borderTypes?.contains(TdBorder.top) == true) {
          ctx.moveTo(x - width, y);
          ctx.lineTo(x, y);
          ctx.stroke();
        }
        if (borderTypes?.contains(TdBorder.right) == true) {
          ctx.moveTo(x, y);
          ctx.lineTo(x, y + height);
          ctx.stroke();
        }
        if (borderTypes?.contains(TdBorder.bottom) == true) {
          ctx.moveTo(x, y + height);
          ctx.lineTo(x - width, y + height);
          ctx.stroke();
        }
        if (borderTypes?.contains(TdBorder.left) == true) {
          ctx.moveTo(x - width, y);
          ctx.lineTo(x - width, y + height);
          ctx.stroke();
        }

        if (!isEmptyBorderType && !isExternalBorderType) {
          final int? colIndex = td.colIndex;
          final int? rowIndex = td.rowIndex;
          if (colIndex != null) {
            final bool isRightEdge =
                colIndex + td.colspan >= colgroup.length;
            if (!isInternalBorderType || !isRightEdge) {
              ctx.moveTo(x, y);
              ctx.lineTo(x, y + height);
              if (borderExternalWidth != null &&
                  borderExternalWidth != borderWidth &&
                  isRightEdge) {
                final double lineWidth = ctx.lineWidth.toDouble();
                ctx.lineWidth = borderExternalWidth * scale;
                ctx.stroke();
                ctx.beginPath();
                ctx.lineWidth = lineWidth;
              }
            }
          }

          if (rowIndex != null) {
            final bool isBottomEdge =
                rowIndex + td.rowspan >= trList.length;
            if (!isInternalBorderType || !isBottomEdge) {
              final bool isSetExternalBottomBorder =
                  borderExternalWidth != null &&
                      borderExternalWidth != borderWidth &&
                      isBottomEdge;
              if (isSetExternalBottomBorder) {
                ctx.stroke();
                ctx.beginPath();
              }
              ctx.moveTo(x, y + height);
              ctx.lineTo(x - width, y + height);
              if (isSetExternalBottomBorder) {
                final double lineWidth = ctx.lineWidth.toDouble();
                ctx.lineWidth = borderExternalWidth * scale;
                ctx.stroke();
                ctx.beginPath();
                ctx.lineWidth = lineWidth;
              }
            }
          }
          ctx.stroke();
        }

        ctx.translate(-0.5, -0.5);
      }
    }
    ctx.restore();
  }

  void _drawBackgroundColor(
    CanvasRenderingContext2D ctx,
    IElement element,
    double startX,
    double startY,
  ) {
    final List<ITr>? trList = element.trList;
    if (trList == null) {
      return;
    }

    final double scale = _scale();
    for (final ITr tr in trList) {
      for (final ITd td in tr.tdList) {
        final String? backgroundColor = td.backgroundColor;
        if (backgroundColor == null || backgroundColor.isEmpty) {
          continue;
        }
        ctx.save();
        final double width = (td.width ?? 0) * scale;
        final double height = (td.height ?? 0) * scale;
        final double x = ((td.x ?? 0) * scale + startX).roundToDouble();
        final double y = ((td.y ?? 0) * scale + startY).roundToDouble();
        ctx.fillStyle = backgroundColor;
        ctx.fillRect(x, y, width, height);
        ctx.restore();
      }
    }
  }

  double getTableWidth(IElement element) {
    final List<IColgroup>? colgroup = element.colgroup;
    if (colgroup == null) {
      return 0;
    }
    return colgroup.fold<double>(0, (double pre, IColgroup cur) => pre + cur.width);
  }

  double getTableHeight(IElement element) {
    final List<ITr>? trList = element.trList;
    if (trList == null || trList.isEmpty) {
      return 0;
    }
    return getTdListByColIndex(trList, 0)
        .fold<double>(0, (double pre, ITd cur) => pre + (cur.height ?? 0));
  }

  int getRowCountByColIndex(List<ITr> trList, int colIndex) {
    return getTdListByColIndex(trList, colIndex)
        .fold<int>(0, (int pre, ITd cur) => pre + cur.rowspan);
  }

  List<ITd> getTdListByColIndex(List<ITr> trList, int colIndex) {
    final List<ITd> data = <ITd>[];
    for (final ITr tr in trList) {
      for (final ITd td in tr.tdList) {
        final int? min = td.colIndex;
        final int? max = min != null ? min + td.colspan - 1 : null;
        if (min == null || max == null) {
          continue;
        }
        if (colIndex >= min && colIndex <= max) {
          data.add(td);
        }
      }
    }
    return data;
  }

  List<ITd> getTdListByRowIndex(List<ITr> trList, int rowIndex) {
    final List<ITd> data = <ITd>[];
    for (final ITr tr in trList) {
      for (final ITd td in tr.tdList) {
        final int? min = td.rowIndex;
        final int? max = min != null ? min + td.rowspan - 1 : null;
        if (min == null || max == null) {
          continue;
        }
        if (rowIndex >= min && rowIndex <= max) {
          data.add(td);
        }
      }
    }
    return data;
  }

  void computeRowColInfo(IElement element) {
    final List<IColgroup>? colgroup = element.colgroup;
    final List<ITr>? trList = element.trList;
    if (colgroup == null || trList == null) {
      return;
    }

    double preX = 0;
    for (int t = 0; t < trList.length; t++) {
      final ITr tr = trList[t];
      final bool isLastTr = t == trList.length - 1;

      for (int d = 0; d < tr.tdList.length; d++) {
        final ITd td = tr.tdList[d];
        int colIndex = 0;
        if (trList.length > 1 && t != 0) {
          final ITd? preTd = d > 0 ? tr.tdList[d - 1] : null;
          final int start = preTd != null
              ? (preTd.colIndex ?? 0) + preTd.colspan
              : d;
          for (int c = start; c < colgroup.length; c++) {
            final int rowCount =
                getRowCountByColIndex(trList.sublist(0, t), c);
            if (rowCount == t) {
              colIndex = c;
              double preColWidth = 0;
              for (int preC = 0; preC < c; preC++) {
                preColWidth += colgroup[preC].width;
              }
              preX = preColWidth;
              break;
            }
          }
        } else {
          final ITd? preTd = d > 0 ? tr.tdList[d - 1] : null;
          if (preTd != null) {
            colIndex = (preTd.colIndex ?? 0) + preTd.colspan;
          }
        }

        double width = 0;
        for (int col = 0; col < td.colspan; col++) {
          final int target = col + colIndex;
          if (target >= 0 && target < colgroup.length) {
            width += colgroup[target].width;
          }
        }

        double height = 0;
        for (int row = 0; row < td.rowspan; row++) {
          final int targetRow = row + t;
          final ITr curTr =
              targetRow < trList.length ? trList[targetRow] : trList[t];
          height += curTr.height;
        }

        final bool isLastRowTd = d == tr.tdList.length - 1;
        bool isLastColTd = isLastTr;
        if (!isLastColTd && td.rowspan > 1) {
          final int nextTrLength = trList.length - 1 - t;
          isLastColTd = td.rowspan - 1 == nextTrLength;
        }
        final bool isLastTd = isLastTr && isLastRowTd;

        td.isLastRowTd = isLastRowTd;
        td.isLastColTd = isLastColTd;
        td.isLastTd = isLastTd;
        td.x = preX;

        double preY = 0;
        for (int preR = 0; preR < t; preR++) {
          final List<ITd> preTdList = trList[preR].tdList;
          for (final ITd preTd in preTdList) {
            final int? preColIndex = preTd.colIndex;
            if (preColIndex == null) {
              continue;
            }
            if (colIndex >= preColIndex &&
                colIndex < preColIndex + preTd.colspan) {
              preY += preTd.height ?? 0;
              break;
            }
          }
        }

        td.y = preY;
        td.width = width;
        td.height = height;
        td.rowIndex = t;
        td.colIndex = colIndex;
        td.trIndex = t;
        td.tdIndex = d;

        preX += width;
        if (isLastRowTd && !isLastTd) {
          preX = 0;
        }
      }
    }
  }

  void drawRange(
    CanvasRenderingContext2D ctx,
    IElement element,
    double startX,
    double startY,
  ) {
    if (element.type != ElementType.table || element.trList == null) {
      return;
    }

    final dynamic rawRange = _rangeManager?.getRange();
    if (rawRange is! IRange || rawRange.isCrossRowCol != true) {
      return;
    }

    final double scale = _scale();
    final double rangeAlpha = _options.rangeAlpha ?? 1;
    final String rangeColor = _options.rangeColor ?? '#409eff';

    ITd startTd =
        element.trList![rawRange.startTrIndex!].tdList[rawRange.startTdIndex!];
    ITd endTd =
        element.trList![rawRange.endTrIndex!].tdList[rawRange.endTdIndex!];

    if ((startTd.x ?? 0) > (endTd.x ?? 0) ||
        (startTd.y ?? 0) > (endTd.y ?? 0)) {
      final ITd temp = startTd;
      startTd = endTd;
      endTd = temp;
    }

    final int? startColIndex = startTd.colIndex;
    final int? endColIndex =
        endTd.colIndex != null ? endTd.colIndex! + endTd.colspan - 1 : null;
    final int? startRowIndex = startTd.rowIndex;
    final int? endRowIndex =
        endTd.rowIndex != null ? endTd.rowIndex! + endTd.rowspan - 1 : null;
    if (startColIndex == null ||
        endColIndex == null ||
        startRowIndex == null ||
        endRowIndex == null) {
      return;
    }

    ctx.save();
    for (final ITr tr in element.trList!) {
      for (final ITd td in tr.tdList) {
        final int? tdColIndex = td.colIndex;
        final int? tdRowIndex = td.rowIndex;
        if (tdColIndex == null || tdRowIndex == null) {
          continue;
        }
        final bool inColRange =
            tdColIndex >= startColIndex && tdColIndex <= endColIndex;
        final bool inRowRange =
            tdRowIndex >= startRowIndex && tdRowIndex <= endRowIndex;
        if (!inColRange || !inRowRange) {
          continue;
        }

        final double x = (td.x ?? 0) * scale;
        final double y = (td.y ?? 0) * scale;
        final double width = (td.width ?? 0) * scale;
        final double height = (td.height ?? 0) * scale;
        ctx.globalAlpha = rangeAlpha;
        ctx.fillStyle = rangeColor;
        ctx.fillRect(x + startX, y + startY, width, height);
      }
    }
    ctx.restore();
  }

  void render(
    CanvasRenderingContext2D ctx,
    IElement element,
    double startX,
    double startY,
  ) {
    _drawBackgroundColor(ctx, element, startX, startY);
    _drawBorder(ctx, element, startX, startY);
  }
}
