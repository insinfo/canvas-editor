import 'dart:async';
import 'dart:html';

import '../../../../dataset/constant/editor.dart';
import '../../../../dataset/enum/table/table_tool.dart';
import '../../../../interface/draw.dart';
import '../../../../interface/editor.dart';
import '../../../../interface/element.dart';
import '../../../../interface/position.dart';
import '../../../../interface/table/td.dart';
import '../../draw.dart';
import 'table_particle.dart';

class TableTool {
  TableTool(this._draw)
      : _options = _draw.getOptions(),
        _position = _draw.getPosition(),
        _rangeManager = _draw.getRange(),
        _container = _draw.getContainer(),
        _tableParticle = _draw.getTableParticle() as TableParticle? {
    _canvas = _resolveCurrentCanvas();
  }

  static const double _minTdWidth = 20;
  static const double _rowColOffset = 18;
  static const double _rowColQuickWidth = 16;
  static const double _rowColQuickOffset = 5;
  static const double _borderValue = 4;
  static const double _tableSelectOffset = 20;

  final Draw _draw;
  final IEditorOption _options;
  final dynamic _position;
  final dynamic _rangeManager;
  final DivElement _container;
  final TableParticle? _tableParticle;

  CanvasElement? _canvas;
  DivElement? _toolRowContainer;
  DivElement? _toolRowAddBtn;
  DivElement? _toolColAddBtn;
  DivElement? _toolTableSelectBtn;
  DivElement? _toolColContainer;
  DivElement? _toolBorderContainer;
  DivElement? _anchorLine;
  double _mousedownX = 0;
  double _mousedownY = 0;

  double _scale() => (_options.scale ?? 1).toDouble();

  CanvasElement? _resolveCurrentCanvas() {
    final List<Element> pageList = _draw.getPageList();
    if (pageList.isEmpty) {
      return null;
    }
    int pageIndex = _draw.getPageNo();
    if (pageIndex < 0 || pageIndex >= pageList.length) {
      pageIndex = 0;
    }
    final Element element = pageList[pageIndex];
    return element is CanvasElement ? element : null;
  }

  void dispose() {
    _toolRowContainer?.remove();
    _toolRowAddBtn?.remove();
    _toolColAddBtn?.remove();
    _toolTableSelectBtn?.remove();
    _toolColContainer?.remove();
    _toolBorderContainer?.remove();
    _toolRowContainer = null;
    _toolRowAddBtn = null;
    _toolColAddBtn = null;
    _toolTableSelectBtn = null;
    _toolColContainer = null;
    _toolBorderContainer = null;
  }

  void render() {
    final dynamic positionContext = _position?.getPositionContext();
    if (positionContext == null || positionContext.isTable != true) {
      dispose();
      return;
    }

    final int? index = positionContext.index as int?;
    final int? trIndex = positionContext.trIndex as int?;
    final int? tdIndex = positionContext.tdIndex as int?;
    if (index == null || trIndex == null || tdIndex == null) {
      dispose();
      return;
    }

    dispose();

    final List<IElement> elementList = _draw.getOriginalElementList();
    if (index < 0 || index >= elementList.length) {
      return;
    }
    final IElement element = elementList[index];
    if (element.tableToolDisabled == true && !_draw.isDesignMode()) {
      return;
    }

    final double scale = _scale();
    final bool overflow = _options.table?.overflow ?? false;
    final List<IElementPosition> positionList =
        _position?.getOriginalPositionList() as List<IElementPosition>? ??
            <IElementPosition>[];
    if (index < 0 || index >= positionList.length) {
      return;
    }
    final IElementPosition currentPosition = positionList[index];
    final List<ITr>? trList = element.trList;
    final List<IColgroup>? colgroup = element.colgroup;
    if (trList == null || colgroup == null) {
      return;
    }

    final List<double>? leftTop =
        currentPosition.coordinate['leftTop']?.toList(growable: false);
    if (leftTop == null || leftTop.length < 2) {
      return;
    }

    final double height = _draw.getHeight();
    final double pageGap = _draw.getPageGap();
    final double pageOffset = _draw.getPageNo() * (height + pageGap);
    final double tableX = leftTop[0];
    final double tableY = leftTop[1] + pageOffset;
    if (trIndex < 0 || trIndex >= trList.length) {
      return;
    }
    final ITr tr = trList[trIndex];
    if (tdIndex < 0 || tdIndex >= tr.tdList.length) {
      return;
    }
    final ITd td = tr.tdList[tdIndex];
    final int? rowIndex = td.rowIndex;
    final int? colIndex = td.colIndex;
    if (rowIndex == null || colIndex == null) {
      return;
    }

    final double tableHeight = (element.height ?? 0) * scale;
    final double tableWidth = (element.width ?? 0) * scale;

    _canvas = _resolveCurrentCanvas();
    if (_canvas == null) {
      return;
    }

    final DivElement tableSelectBtn = DivElement()
  ..classes.add('$editorPrefix-table-tool__select')
      ..style.height = '${tableHeight * scale}px'
      ..style.left = '${tableX}px'
      ..style.top = '${tableY}px'
      ..style.transform =
          'translate(-${_tableSelectOffset * scale}px, ${-_tableSelectOffset * scale}px)';
    tableSelectBtn.onClick.listen((_) {
      final dynamic tableOperate = _draw.getTableOperate();
      tableOperate?.tableSelectAll();
    });
    _container.append(tableSelectBtn);
    _toolTableSelectBtn = tableSelectBtn;

    final DivElement rowContainer = DivElement()
  ..classes.add('$editorPrefix-table-tool__row')
      ..style.transform = 'translateX(-${_rowColOffset * scale}px)'
      ..style.left = '${tableX}px'
      ..style.top = '${tableY}px';
    final List<double> rowHeightList =
        trList.map((ITr entry) => entry.height).toList();
    for (int r = 0; r < rowHeightList.length; r++) {
      final double rowHeight = rowHeightList[r] * scale;
      final DivElement rowItem = DivElement()
  ..classes.add('$editorPrefix-table-tool__row__item')
        ..style.height = '${rowHeight}px';
      if (r == rowIndex) {
        rowItem.classes.add('active');
      }
      rowItem.onClick.listen((_) {
        final TableParticle? tableParticle = _tableParticle;
        if (tableParticle == null) {
          return;
        }
        final List<ITd> tdList = tableParticle.getTdListByRowIndex(trList, r);
        if (tdList.isEmpty) {
          return;
        }
        final ITd firstTd = tdList.first;
        final ITd lastTd = tdList.last;
        final IPositionContext context = IPositionContext(
          isTable: true,
          index: index,
          trIndex: firstTd.trIndex,
          tdIndex: firstTd.tdIndex,
          tableId: element.id,
        );
        _position?.setPositionContext(context);
        _rangeManager?.setRange(
          0,
          0,
          element.id,
          firstTd.tdIndex,
          lastTd.tdIndex,
          firstTd.trIndex,
          lastTd.trIndex,
        );
        _draw.render(IDrawOption(
          curIndex: 0,
          isCompute: false,
          isSubmitHistory: false,
        ));
        _setAnchorActive(rowContainer, r);
      });

      final DivElement anchor = DivElement()
        ..classes.add('$editorPrefix-table-tool__anchor');
      anchor.onMouseDown.listen((MouseEvent evt) {
        _onMouseDown(
          evt,
          element,
          r,
          TableOrder.row,
        );
      });
      rowItem.append(anchor);
      rowContainer.append(rowItem);
    }
    _container.append(rowContainer);
    _toolRowContainer = rowContainer;

    final double rowQuickPosition =
        _rowColOffset + (_rowColOffset - _rowColQuickWidth) / 2;
    final DivElement rowAddBtn = DivElement()
  ..classes.add('$editorPrefix-table-tool__quick__add')
      ..style.height = '${tableHeight * scale}px'
      ..style.left = '${tableX}px'
      ..style.top = '${tableY + tableHeight}px'
      ..style.transform =
          'translate(-${rowQuickPosition * scale}px, ${_rowColQuickOffset * scale}px)';
    rowAddBtn.onClick.listen((_) {
      _position?.setPositionContext(
        IPositionContext(
          isTable: true,
          index: index,
          trIndex: trList.length - 1,
          tdIndex: 0,
          tableId: element.id,
        ),
      );
      _draw.getTableOperate()?.insertTableBottomRow();
    });
    _container.append(rowAddBtn);
    _toolRowAddBtn = rowAddBtn;

    final DivElement colContainer = DivElement()
  ..classes.add('$editorPrefix-table-tool__col')
      ..style.transform = 'translateY(-${_rowColOffset * scale}px)'
      ..style.left = '${tableX}px'
      ..style.top = '${tableY}px';
    final List<double> colWidthList =
        colgroup.map((IColgroup col) => col.width).toList();
    for (int c = 0; c < colWidthList.length; c++) {
      final double colWidth = colWidthList[c] * scale;
      final DivElement colItem = DivElement()
  ..classes.add('$editorPrefix-table-tool__col__item')
        ..style.width = '${colWidth}px';
      if (c == colIndex) {
        colItem.classes.add('active');
      }
      colItem.onClick.listen((_) {
        final TableParticle? tableParticle = _tableParticle;
        if (tableParticle == null) {
          return;
        }
        final List<ITd> tdList = tableParticle.getTdListByColIndex(trList, c);
        if (tdList.isEmpty) {
          return;
        }
        final ITd firstTd = tdList.first;
        final ITd lastTd = tdList.last;
        _position?.setPositionContext(
          IPositionContext(
            isTable: true,
            index: index,
            trIndex: firstTd.trIndex,
            tdIndex: firstTd.tdIndex,
            tableId: element.id,
          ),
        );
        _rangeManager?.setRange(
          0,
          0,
          element.id,
          firstTd.tdIndex,
          lastTd.tdIndex,
          firstTd.trIndex,
          lastTd.trIndex,
        );
        _draw.render(IDrawOption(
          curIndex: 0,
          isCompute: false,
          isSubmitHistory: false,
        ));
        _setAnchorActive(colContainer, c);
      });

      final DivElement anchor = DivElement()
        ..classes.add('$editorPrefix-table-tool__anchor');
      anchor.onMouseDown.listen((MouseEvent evt) {
        _onMouseDown(
          evt,
          element,
          c,
          TableOrder.col,
        );
      });
      colItem.append(anchor);
      colContainer.append(colItem);
    }
    _container.append(colContainer);
    _toolColContainer = colContainer;

    final DivElement colAddBtn = DivElement()
  ..classes.add('$editorPrefix-table-tool__quick__add')
      ..style.height = '${tableHeight * scale}px'
      ..style.left = '${tableX + tableWidth}px'
      ..style.top = '${tableY}px'
      ..style.transform =
          'translate(${_rowColQuickOffset * scale}px, -${rowQuickPosition * scale}px)';
    colAddBtn.onClick.listen((_) {
      int targetTdIndex = 0;
      if (trList.isNotEmpty) {
        final List<ITd> tdList = trList.first.tdList;
        targetTdIndex = tdList.isEmpty ? 0 : tdList.length - 1;
      }
      _position?.setPositionContext(
        IPositionContext(
          isTable: true,
          index: index,
          trIndex: 0,
          tdIndex: targetTdIndex,
          tableId: element.id,
        ),
      );
      _draw.getTableOperate()?.insertTableRightCol();
    });
    _container.append(colAddBtn);
    _toolColAddBtn = colAddBtn;

    final DivElement borderContainer = DivElement()
  ..classes.add('$editorPrefix-table-tool__border')
      ..style.height = '${tableHeight}px'
      ..style.width = '${tableWidth}px'
      ..style.left = '${tableX}px'
      ..style.top = '${tableY}px';

    for (final ITr currentTr in trList) {
      for (final ITd currentTd in currentTr.tdList) {
        final double tdWidth = (currentTd.width ?? 0) * scale;
        final double tdHeight = (currentTd.height ?? 0) * scale;
        final double tdX = (currentTd.x ?? 0) * scale;
        final double tdY = (currentTd.y ?? 0) * scale;

        final DivElement rowBorder = DivElement()
          ..classes.add('$editorPrefix-table-tool__border__row')
          ..style.width = '${tdWidth}px'
          ..style.height = '${_borderValue}px'
          ..style.top = '${tdY + tdHeight - _borderValue / 2}px'
          ..style.left = '${tdX}px';
        rowBorder.onMouseDown.listen((MouseEvent evt) {
          _onMouseDown(
            evt,
            element,
            (currentTd.rowIndex ?? 0) + currentTd.rowspan - 1,
            TableOrder.row,
          );
        });
        borderContainer.append(rowBorder);

        final DivElement colBorder = DivElement()
          ..classes.add('$editorPrefix-table-tool__border__col')
          ..style.width = '${_borderValue}px'
          ..style.height = '${tdHeight}px'
          ..style.top = '${tdY}px'
          ..style.left = '${tdX + tdWidth - _borderValue / 2}px';
        colBorder.onMouseDown.listen((MouseEvent evt) {
          _onMouseDown(
            evt,
            element,
            (currentTd.colIndex ?? 0) + currentTd.colspan - 1,
            TableOrder.col,
          );
        });
        borderContainer.append(colBorder);

        if (overflow && (currentTd.colIndex ?? 0) == 0) {
          final DivElement leftBorder = DivElement()
            ..classes.add('$editorPrefix-table-tool__border__col')
            ..style.width = '${_borderValue}px'
            ..style.height = '${tdHeight}px'
            ..style.top = '${tdY}px'
            ..style.left = '${tdX - _borderValue / 2}px';
          leftBorder.onMouseDown.listen((MouseEvent evt) {
            _onMouseDown(
              evt,
              element,
              0,
              TableOrder.col,
              isLeftStartBorder: true,
            );
          });
          borderContainer.append(leftBorder);
        }
      }
    }
    _container.append(borderContainer);
    _toolBorderContainer = borderContainer;
  }

  void _setAnchorActive(DivElement container, int index) {
    for (int i = 0; i < container.children.length; i++) {
    final Element child = container.children[i];
      if (i == index) {
        child.classes.add('active');
      } else {
        child.classes.remove('active');
      }
    }
  }

  void _onMouseDown(
    MouseEvent evt,
    IElement element,
    int index,
    TableOrder order, {
    bool isLeftStartBorder = false,
  }) {
    _canvas = _resolveCurrentCanvas();
    final CanvasElement? canvas = _canvas;
    if (canvas == null) {
      return;
    }

    final double scale = _scale();
    final bool overflow = _options.table?.overflow ?? false;
    final double width = _draw.getWidth();
    final double height = _draw.getHeight();
    final double pageGap = _draw.getPageGap();
    final double pageOffset = _draw.getPageNo() * (height + pageGap);
    _mousedownX = evt.client.x.toDouble();
    _mousedownY = evt.client.y.toDouble();

    final Rectangle<num> canvasRect = canvas.getBoundingClientRect();
    final String cursor = order == TableOrder.row ? 'row-resize' : 'col-resize';
    if (document.body != null) {
      document.body!.style.cursor = cursor;
    }
    canvas.style.cursor = cursor;

    final DivElement anchorLine = DivElement()
      ..classes.add('$editorPrefix-table-anchor__line');
    double startX = 0;
    double startY = 0;
    if (order == TableOrder.row) {
  anchorLine.classes.add('$editorPrefix-table-anchor__line__row');
      anchorLine.style.width = '${width}px';
      startX = 0;
      startY = pageOffset + _mousedownY - canvasRect.top;
    } else {
  anchorLine.classes.add('$editorPrefix-table-anchor__line__col');
      anchorLine.style.height = '${height}px';
      startX = _mousedownX - canvasRect.left;
      startY = pageOffset;
    }
    anchorLine.style.left = '${startX}px';
    anchorLine.style.top = '${startY}px';
    _container.append(anchorLine);
    _anchorLine = anchorLine;

    double dx = 0;
    double dy = 0;

    StreamSubscription<MouseEvent>? moveSub;
    moveSub = document.onMouseMove.listen((MouseEvent moveEvt) {
      final _MoveResult? result = _onMouseMove(moveEvt, order, startX, startY);
      if (result != null) {
        dx = result.dx;
        dy = result.dy;
      }
    });

    StreamSubscription<MouseEvent>? upSub;
    upSub = document.onMouseUp.listen((MouseEvent upEvt) {
      bool isChangeSize = false;
      if (order == TableOrder.row) {
        final List<ITr>? trList = element.trList;
        if (trList != null && trList.isNotEmpty) {
          final ITr? targetTr =
              trList.length > index ? trList[index] : (index > 0 ? trList[index - 1] : null);
          if (targetTr != null) {
            final double defaultTrMinHeight =
                (_options.table?.defaultTrMinHeight ?? 0).toDouble();
            if (dy < 0 && targetTr.height + dy < defaultTrMinHeight) {
              dy = defaultTrMinHeight - targetTr.height;
            }
            if (dy != 0) {
              targetTr.height += dy;
              targetTr.minHeight = targetTr.height;
              isChangeSize = true;
            }
          }
        }
      } else {
    final List<IColgroup>? colgroup = element.colgroup;
        if (colgroup != null && colgroup.isNotEmpty) {
          if (overflow && isLeftStartBorder) {
            if (index >= 0 && index < colgroup.length) {
              final double adjustedWidth =
                  colgroup[index].width - dx / scale;
              if (adjustedWidth <= _minTdWidth) {
                dx = (colgroup[index].width - _minTdWidth) * scale;
              }
              colgroup[index].width -= dx / scale;
              element.width = (element.width ?? 0) - dx / scale;
              element.translateX = (element.translateX ?? 0) + dx / scale;
              isChangeSize = true;
            }
          } else if (index >= 0 && index < colgroup.length) {
            final double innerWidth = _draw.getInnerWidth();
            final double currentWidth = colgroup[index].width;
            if (dx < 0 && currentWidth + dx < _minTdWidth) {
              dx = _minTdWidth - currentWidth;
            }
            final double? nextWidth =
                index + 1 < colgroup.length ? colgroup[index + 1].width : null;
            if (dx > 0 && nextWidth != null && nextWidth - dx < _minTdWidth) {
              dx = nextWidth - _minTdWidth;
            }
            final double moveWidth = currentWidth + dx;
            if (!overflow && index == colgroup.length - 1) {
              double moveTableWidth = 0;
              for (int c = 0; c < colgroup.length; c++) {
                final IColgroup group = colgroup[c];
                if (c == index + 1) {
                  moveTableWidth -= dx;
                }
                if (c == index) {
                  moveTableWidth += moveWidth;
                }
                if (c != index) {
                  moveTableWidth += group.width;
                }
              }
              final double tableWidth = element.width ?? 0;
              if (moveTableWidth > innerWidth) {
                dx = innerWidth - tableWidth;
              }
            }
            if (dx != 0) {
              if (index != colgroup.length - 1) {
                colgroup[index + 1].width -= dx / scale;
              }
              colgroup[index].width += dx / scale;
              isChangeSize = true;
            }
          }
        }
      }

      if (isChangeSize) {
        _draw.render(IDrawOption(isSetCursor: false));
      }

      _anchorLine?.remove();
      moveSub?.cancel();
      upSub?.cancel();
      if (document.body != null) {
        document.body!.style.cursor = '';
      }
      canvas.style.cursor = 'text';
      upEvt.preventDefault();
    });

    evt.preventDefault();
  }

  _MoveResult? _onMouseMove(
    MouseEvent evt,
    TableOrder order,
    double startX,
    double startY,
  ) {
    final DivElement? anchorLine = _anchorLine;
    if (anchorLine == null) {
      return null;
    }
    final double dx = evt.client.x.toDouble() - _mousedownX;
    final double dy = evt.client.y.toDouble() - _mousedownY;
    if (order == TableOrder.row) {
      anchorLine.style.top = '${startY + dy}px';
    } else {
      anchorLine.style.left = '${startX + dx}px';
    }
    evt.preventDefault();
    return _MoveResult(dx: dx, dy: dy);
  }
}

class _MoveResult {
  const _MoveResult({required this.dx, required this.dy});

  final double dx;
  final double dy;
}
