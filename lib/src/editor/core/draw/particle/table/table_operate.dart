import 'dart:math';

import '../../../../dataset/constant/common.dart';
import '../../../../dataset/enum/element.dart';
import '../../../../dataset/enum/table/table.dart';
import '../../../../dataset/enum/vertical_align.dart';
import '../../../../interface/draw.dart';
import '../../../../interface/editor.dart';
import '../../../../interface/element.dart';
import '../../../../interface/position.dart';
import '../../../../interface/range.dart';
import '../../../../interface/table/td.dart';
import '../../../../utils/element.dart' as element_utils;
import '../../../../utils/index.dart';
import '../../../range/range_manager.dart';
import '../../draw.dart';
import 'table_particle.dart';
import 'table_tool.dart';

class TableOperate {
	TableOperate(this._draw)
			: _options = _draw.getOptions(),
				_rangeManager = _draw.getRange() as RangeManager?,
				_position = _draw.getPosition();

	final Draw _draw;
	final IEditorOption _options;
	final RangeManager? _rangeManager;
	final dynamic _position;

	TableTool? get _tableTool => _draw.getTableTool() as TableTool?;

	TableParticle? get _tableParticle =>
			_draw.getTableParticle() as TableParticle?;

	RangeManager? get _range => _rangeManager ??
			(_draw.getRange() as RangeManager?);

	void insertTable(int row, int col) {
		final RangeManager? rangeManager = _range;
		if (rangeManager == null) {
			return;
		}
		final IRange range = rangeManager.getRange();
		final int startIndex = range.startIndex;
		final int endIndex = range.endIndex;
		if (startIndex == -1 && endIndex == -1) {
			return;
		}

		final List<IElement> elementList = _draw.getElementList();
		double offsetX = 0;
		if (startIndex >= 0 && startIndex < elementList.length &&
				elementList[startIndex].listId != null) {
			try {
				final List<dynamic> positionList =
						_position?.getPositionList() as List<dynamic>? ??
								<dynamic>[];
				if (startIndex < positionList.length) {
					final dynamic positionItem = positionList[startIndex];
					final int rowIndex = positionItem?.rowIndex as int? ?? -1;
					if (rowIndex >= 0) {
						final List<dynamic>? rowList = _getRowList();
						if (rowList != null && rowIndex < rowList.length) {
							final dynamic row = rowList[rowIndex];
							offsetX = (row?.offsetX as num?)?.toDouble() ?? 0;
						}
					}
				}
			} catch (_) {}
		}

		final double innerWidth = max(0, _getContextInnerWidth() - offsetX);
		final List<IColgroup> colgroup = <IColgroup>[];
		final double colWidth = col > 0 ? innerWidth / col : innerWidth;
		for (int c = 0; c < col; c++) {
			colgroup.add(IColgroup(width: colWidth));
		}

		final List<ITr> trList = <ITr>[];
		final double defaultTrMinHeight =
				(_options.table?.defaultTrMinHeight ?? 0).toDouble();
		for (int r = 0; r < row; r++) {
			final List<ITd> tdList = <ITd>[];
			final ITr tr = ITr(height: defaultTrMinHeight, tdList: tdList);
			for (int c = 0; c < col; c++) {
				tdList.add(ITd(colspan: 1, rowspan: 1, value: <IElement>[]));
			}
			trList.add(tr);
		}

		final IElement tableElement = IElement(
			type: ElementType.table,
			value: '',
			colgroup: colgroup,
			trList: trList,
		);

		element_utils.formatElementList(
			<IElement>[tableElement],
			element_utils.FormatElementListOption(editorOptions: _options),
		);
		element_utils.formatElementContext(
			elementList,
			<IElement>[tableElement],
			startIndex,
			options: element_utils.FormatElementContextOption(
				editorOptions: _options,
			),
		);

		final int insertIndex = startIndex + 1;
		_draw.spliceElementList(
			elementList,
			insertIndex,
			startIndex == endIndex ? 0 : endIndex - startIndex,
			<IElement>[tableElement],
		);
		rangeManager.setRange(insertIndex, insertIndex);
		_draw.render(
			IDrawOption(curIndex: insertIndex, isSetCursor: false),
		);
	}

	void insertTableTopRow() {
		final dynamic positionContext = _position?.getPositionContext();
		if (positionContext == null || positionContext.isTable != true) {
			return;
		}

		final int? index = positionContext.index as int?;
		final int? trIndex = positionContext.trIndex as int?;
		final String? tableId = positionContext.tableId as String?;
		if (index == null || trIndex == null) {
			return;
		}

		final List<IElement> elementList = _draw.getOriginalElementList();
		if (index < 0 || index >= elementList.length) {
			return;
		}
		final IElement element = elementList[index];
		final List<ITr>? trList = element.trList;
		final List<IColgroup>? colgroup = element.colgroup;
		if (trList == null || colgroup == null ||
				trIndex < 0 || trIndex >= trList.length) {
			return;
		}

		final ITr currentTr = trList[trIndex];
		if (currentTr.tdList.length < colgroup.length) {
			final int currentRowIndex = currentTr.tdList.isEmpty
					? 0
					: (currentTr.tdList.first.rowIndex ?? trIndex);
			for (int t = 0; t < trIndex; t++) {
				final ITr tr = trList[t];
				for (final ITd td in tr.tdList) {
					final int? rowIndex = td.rowIndex;
					if (rowIndex == null) {
						continue;
					}
					if (td.rowspan > 1 && rowIndex + td.rowspan >= currentRowIndex + 1) {
						td.rowspan += 1;
					}
				}
			}
		}

		final String newTrId = getUUID();
		final ITr newTr = ITr(
			height: currentTr.height,
			id: newTrId,
			tdList: <ITd>[],
		);
		for (final ITd td in currentTr.tdList) {
			final String newTdId = getUUID();
			newTr.tdList.add(
				ITd(
					id: newTdId,
					rowspan: 1,
					colspan: td.colspan,
					value: <IElement>[
						IElement(
							value: ZERO,
							size: 16,
							tableId: tableId,
							trId: newTrId,
							tdId: newTdId,
						),
					],
				),
			);
		}
		trList.insert(trIndex, newTr);

		_position?.setPositionContext(
			IPositionContext(
				isTable: true,
				index: index,
				trIndex: trIndex,
				tdIndex: 0,
				tdId: newTr.tdList.isNotEmpty ? newTr.tdList.first.id : null,
				trId: newTr.id,
				tableId: tableId,
			),
		);
		_range?.setRange(0, 0);
		_draw.render(IDrawOption(curIndex: 0));
		_tableTool?.render();
	}

	void insertTableBottomRow() {
		final dynamic positionContext = _position?.getPositionContext();
		if (positionContext == null || positionContext.isTable != true) {
			return;
		}

		final int? index = positionContext.index as int?;
		final int? trIndex = positionContext.trIndex as int?;
		final String? tableId = positionContext.tableId as String?;
		if (index == null || trIndex == null) {
			return;
		}

		final List<IElement> elementList = _draw.getOriginalElementList();
		if (index < 0 || index >= elementList.length) {
			return;
		}
		final IElement element = elementList[index];
		final List<ITr>? trList = element.trList;
		final List<IColgroup>? colgroup = element.colgroup;
		if (trList == null || colgroup == null ||
				trIndex < 0 || trIndex >= trList.length) {
			return;
		}

		final ITr currentTr = trList[trIndex];
		final ITr anchorTr = trIndex == trList.length - 1
				? currentTr
				: trList[trIndex + 1];

		if (anchorTr.tdList.length < colgroup.length) {
			final int currentRowIndex = anchorTr.tdList.isEmpty
					? 0
					: (anchorTr.tdList.first.rowIndex ?? trIndex);
			for (int t = 0; t <= trIndex; t++) {
				final ITr tr = trList[t];
				for (final ITd td in tr.tdList) {
					final int? rowIndex = td.rowIndex;
					if (rowIndex == null) {
						continue;
					}
					if (td.rowspan > 1 && rowIndex + td.rowspan >= currentRowIndex + 1) {
						td.rowspan += 1;
					}
				}
			}
		}

		final String newTrId = getUUID();
		final ITr newTr = ITr(
			height: anchorTr.height,
			id: newTrId,
			tdList: <ITd>[],
		);
		for (final ITd td in anchorTr.tdList) {
			final String newTdId = getUUID();
			newTr.tdList.add(
				ITd(
					id: newTdId,
					rowspan: 1,
					colspan: td.colspan,
					value: <IElement>[
						IElement(
							value: ZERO,
							size: 16,
							tableId: tableId ?? element.id,
							trId: newTrId,
							tdId: newTdId,
						),
					],
				),
			);
		}
		trList.insert(trIndex + 1, newTr);

		_position?.setPositionContext(
			IPositionContext(
				isTable: true,
				index: index,
				trIndex: trIndex + 1,
				tdIndex: 0,
				tdId: newTr.tdList.isNotEmpty ? newTr.tdList.first.id : null,
				trId: newTr.id,
				tableId: element.id,
			),
		);
		_range?.setRange(0, 0);
		_draw.render(IDrawOption(curIndex: 0));
	}

	void adjustColWidth(IElement element) {
		if (element.type != ElementType.table) {
			return;
		}
		final List<IColgroup>? colgroup = element.colgroup;
		if (colgroup == null || colgroup.isEmpty) {
			return;
		}
		final double defaultColMinWidth =
				(_options.table?.defaultColMinWidth ?? 0).toDouble();
		final double colgroupWidth = colgroup.fold<double>(
			0,
			(double previousValue, IColgroup group) => previousValue + group.width,
		);
		final double width = _draw.getOriginalInnerWidth();
		if (colgroupWidth <= width) {
			return;
		}

		final List<IColgroup> adjustableCols = colgroup
				.where((IColgroup group) => group.width > defaultColMinWidth)
				.toList();
		if (adjustableCols.isEmpty) {
			return;
		}
		final double adjustWidth =
				(colgroupWidth - width) / adjustableCols.length;
		for (final IColgroup group in colgroup) {
			if (group.width - adjustWidth >= defaultColMinWidth) {
				group.width -= adjustWidth;
			}
		}
	}

	void insertTableLeftCol() {
		final dynamic positionContext = _position?.getPositionContext();
		if (positionContext == null || positionContext.isTable != true) {
			return;
		}

		final int? index = positionContext.index as int?;
		final int? tdIndex = positionContext.tdIndex as int?;
		final String? tableId = positionContext.tableId as String?;
		if (index == null || tdIndex == null) {
			return;
		}

		final List<IElement> elementList = _draw.getOriginalElementList();
		if (index < 0 || index >= elementList.length) {
			return;
		}
		final IElement element = elementList[index];
		final List<ITr>? trList = element.trList;
		final List<IColgroup>? colgroup = element.colgroup;
		if (trList == null || colgroup == null) {
			return;
		}

		for (final ITr tr in trList) {
			final String tdId = getUUID();
			tr.tdList.insert(
				tdIndex,
				ITd(
					id: tdId,
					rowspan: 1,
					colspan: 1,
					value: <IElement>[
						IElement(
							value: ZERO,
							size: 16,
							tableId: tableId ?? element.id,
							trId: tr.id,
							tdId: tdId,
						),
					],
				),
			);
		}

		final double defaultColMinWidth =
				(_options.table?.defaultColMinWidth ?? 0).toDouble();
		colgroup.insert(tdIndex, IColgroup(width: defaultColMinWidth));
		adjustColWidth(element);

		_position?.setPositionContext(
			IPositionContext(
				isTable: true,
				index: index,
				trIndex: 0,
				tdIndex: tdIndex,
				tdId: trList.first.tdList[tdIndex].id,
				trId: trList.first.id,
				tableId: tableId,
			),
		);
		_range?.setRange(0, 0);
		_draw.render(IDrawOption(curIndex: 0));
		_tableTool?.render();
	}

	void insertTableRightCol() {
		final dynamic positionContext = _position?.getPositionContext();
		if (positionContext == null || positionContext.isTable != true) {
			return;
		}

		final int? index = positionContext.index as int?;
		final int? tdIndex = positionContext.tdIndex as int?;
		final String? tableId = positionContext.tableId as String?;
		if (index == null || tdIndex == null) {
			return;
		}

		final List<IElement> elementList = _draw.getOriginalElementList();
		if (index < 0 || index >= elementList.length) {
			return;
		}
		final IElement element = elementList[index];
		final List<ITr>? trList = element.trList;
		final List<IColgroup>? colgroup = element.colgroup;
		if (trList == null || colgroup == null) {
			return;
		}

		final int insertIndex = tdIndex + 1;
		for (final ITr tr in trList) {
			final String tdId = getUUID();
			tr.tdList.insert(
				insertIndex,
				ITd(
					id: tdId,
					rowspan: 1,
					colspan: 1,
					value: <IElement>[
						IElement(
							value: ZERO,
							size: 16,
							tableId: tableId ?? element.id,
							trId: tr.id,
							tdId: tdId,
						),
					],
				),
			);
		}

		final double defaultColMinWidth =
				(_options.table?.defaultColMinWidth ?? 0).toDouble();
		colgroup.insert(insertIndex, IColgroup(width: defaultColMinWidth));
		adjustColWidth(element);

		_position?.setPositionContext(
			IPositionContext(
				isTable: true,
				index: index,
				trIndex: 0,
				tdIndex: insertIndex,
				tdId: trList.first.tdList[insertIndex].id,
				trId: trList.first.id,
				tableId: element.id,
			),
		);
		_range?.setRange(0, 0);
		_draw.render(IDrawOption(curIndex: 0));
	}

	void deleteTableRow() {
		final dynamic positionContext = _position?.getPositionContext();
		if (positionContext == null || positionContext.isTable != true) {
			return;
		}

		final int? index = positionContext.index as int?;
		final int? trIndex = positionContext.trIndex as int?;
		final int? tdIndex = positionContext.tdIndex as int?;
		if (index == null || trIndex == null || tdIndex == null) {
			return;
		}

		final List<IElement> elementList = _draw.getOriginalElementList();
		if (index < 0 || index >= elementList.length) {
			return;
		}
		final IElement element = elementList[index];
		final List<ITr>? trList = element.trList;
		if (trList == null || trIndex < 0 || trIndex >= trList.length) {
			return;
		}

		final ITr currentTr = trList[trIndex];
		if (tdIndex < 0 || tdIndex >= currentTr.tdList.length) {
			return;
		}
		final int curTdRowIndex =
				currentTr.tdList[tdIndex].rowIndex ?? trIndex;

		if (trList.length <= 1 && (element.pagingIndex ?? 0) == 0) {
			deleteTable();
			return;
		}

		for (int r = 0; r < curTdRowIndex; r++) {
			final ITr tr = trList[r];
			for (final ITd td in tr.tdList) {
				final int? rowIndex = td.rowIndex;
				if (rowIndex == null) {
					continue;
				}
				if (rowIndex + td.rowspan > curTdRowIndex) {
					td.rowspan -= 1;
				}
			}
		}

		for (int d = 0; d < currentTr.tdList.length; d++) {
			final ITd td = currentTr.tdList[d];
			if (td.rowspan > 1 && trIndex + 1 < trList.length) {
				final String tdId = getUUID();
				final ITr nextTr = trList[trIndex + 1];
				nextTr.tdList.insert(
					d,
					ITd(
						id: tdId,
						rowspan: td.rowspan - 1,
						colspan: td.colspan,
						value: <IElement>[
							IElement(
								value: ZERO,
								size: 16,
								tableId: element.id,
								trId: nextTr.id,
								tdId: tdId,
							),
						],
					),
				);
			}
		}

		trList.removeAt(trIndex);
		_position?.setPositionContext(IPositionContext(isTable: false));
		_range?.clearRange();
		_draw.render(IDrawOption(curIndex: index));
		_tableTool?.dispose();
	}

	void deleteTableCol() {
		final dynamic positionContext = _position?.getPositionContext();
		if (positionContext == null || positionContext.isTable != true) {
			return;
		}

		final int? index = positionContext.index as int?;
		final int? tdIndex = positionContext.tdIndex as int?;
		final int? trIndex = positionContext.trIndex as int?;
		if (index == null || tdIndex == null || trIndex == null) {
			return;
		}

		final List<IElement> elementList = _draw.getOriginalElementList();
		if (index < 0 || index >= elementList.length) {
			return;
		}
		final IElement element = elementList[index];
		final List<ITr>? trList = element.trList;
		if (trList == null || trIndex < 0 || trIndex >= trList.length) {
			return;
		}

		final ITd currentTd = trList[trIndex].tdList[tdIndex];
		final int curColIndex = currentTd.colIndex ?? tdIndex;

		final bool hasMultiCol =
			trList.any((ITr tr) => tr.tdList.length > 1);
		if (!hasMultiCol) {
			deleteTable();
			return;
		}

		for (final ITr tr in trList) {
			int d = 0;
			while (d < tr.tdList.length) {
				final ITd td = tr.tdList[d];
				final int? colIndex = td.colIndex;
				if (colIndex == null) {
					d++;
					continue;
				}
				final bool isOverlap =
						colIndex <= curColIndex && colIndex + td.colspan > curColIndex;
				if (!isOverlap) {
					d++;
					continue;
				}
				if (td.colspan > 1) {
					td.colspan -= 1;
					d++;
				} else {
					tr.tdList.removeAt(d);
				}
			}
		}

		element.colgroup?.removeAt(curColIndex);
		_position?.setPositionContext(IPositionContext(isTable: false));
		_range?.setRange(0, 0);
		_draw.render(IDrawOption(curIndex: index));
		_tableTool?.dispose();
	}

	void deleteTable() {
		final dynamic positionContext = _position?.getPositionContext();
		if (positionContext == null || positionContext.isTable != true) {
			return;
		}

		final List<IElement> elementList = _draw.getOriginalElementList();
		final int? index = positionContext.index as int?;
		if (index == null || index < 0 || index >= elementList.length) {
			return;
		}
		final IElement element = elementList[index];

		int deleteCount = 1;
		int deleteStartIndex = index;
		if (element.pagingId != null) {
			deleteStartIndex = index - (element.pagingIndex ?? 0);
			for (int i = deleteStartIndex + 1; i < elementList.length; i++) {
				if (elementList[i].pagingId == element.pagingId) {
					deleteCount += 1;
				} else {
					break;
				}
			}
		}

		elementList.removeRange(deleteStartIndex, deleteStartIndex + deleteCount);
		final int curIndex = deleteStartIndex - 1;
		_position?.setPositionContext(
			IPositionContext(isTable: false, index: curIndex),
		);
		_range?.setRange(curIndex, curIndex);
		_draw.render(IDrawOption(curIndex: curIndex));
		_tableTool?.dispose();
	}

	void mergeTableCell() {
		final dynamic positionContext = _position?.getPositionContext();
		if (positionContext == null || positionContext.isTable != true) {
			return;
		}

		final RangeManager? rangeManager = _range;
		if (rangeManager == null) {
			return;
		}
		final IRange range = rangeManager.getRange();
		if (range.isCrossRowCol != true) {
			return;
		}

		final int? index = positionContext.index as int?;
		if (index == null) {
			return;
		}

		final List<IElement> elementList = _draw.getOriginalElementList();
		if (index < 0 || index >= elementList.length) {
			return;
		}
		final IElement element = elementList[index];
		final List<ITr>? trList = element.trList;
		if (trList == null) {
			return;
		}

		ITd startTd = trList[range.startTrIndex!].tdList[range.startTdIndex!];
		ITd endTd = trList[range.endTrIndex!].tdList[range.endTdIndex!];
		if ((startTd.x ?? 0) > (endTd.x ?? 0) ||
				(startTd.y ?? 0) > (endTd.y ?? 0)) {
			final ITd temp = startTd;
			startTd = endTd;
			endTd = temp;
		}

		final int? startColIndex = startTd.colIndex;
		final int? endColIndex = endTd.colIndex != null
				? endTd.colIndex! + endTd.colspan - 1
				: null;
		final int? startRowIndex = startTd.rowIndex;
		final int? endRowIndex = endTd.rowIndex != null
				? endTd.rowIndex! + endTd.rowspan - 1
				: null;
		if (startColIndex == null || endColIndex == null ||
				startRowIndex == null || endRowIndex == null) {
			return;
		}

		final List<List<ITd>> rowCol = <List<ITd>>[];
		for (final ITr tr in trList) {
			final List<ITd> tdRow = <ITd>[];
			for (final ITd td in tr.tdList) {
				final int? colIndex = td.colIndex;
				final int? rowIndex = td.rowIndex;
				if (colIndex == null || rowIndex == null) {
					continue;
				}
				final bool inColRange =
						colIndex >= startColIndex && colIndex <= endColIndex;
				final bool inRowRange =
						rowIndex >= startRowIndex && rowIndex <= endRowIndex;
				if (inColRange && inRowRange) {
					tdRow.add(td);
				}
			}
			if (tdRow.isNotEmpty) {
				rowCol.add(tdRow);
			}
		}
		if (rowCol.isEmpty) {
			return;
		}

		final List<ITd> lastRow = rowCol.last;
		final ITd leftTop = rowCol.first.first;
		final ITd rightBottom = lastRow.last;
		final double startX = leftTop.x ?? 0;
		final double startY = leftTop.y ?? 0;
		final double endX = (rightBottom.x ?? 0) + (rightBottom.width ?? 0);
		final double endY = (rightBottom.y ?? 0) + (rightBottom.height ?? 0);
		for (final List<ITd> tr in rowCol) {
			for (final ITd td in tr) {
				final double tdStartX = td.x ?? 0;
				final double tdStartY = td.y ?? 0;
				final double tdEndX = tdStartX + (td.width ?? 0);
				final double tdEndY = tdStartY + (td.height ?? 0);
				if (startX > tdStartX || startY > tdStartY ||
						endX < tdEndX || endY < tdEndY) {
					return;
				}
			}
		}

		final List<String> mergeTdIdList = <String>[];
		final ITd anchorTd = rowCol.first.first;
		final IElement anchorElement = anchorTd.value.first;
		for (int r = 0; r < rowCol.length; r++) {
			final List<ITd> tr = rowCol[r];
			for (int c = 0; c < tr.length; c++) {
				final ITd td = tr[c];
				final bool isAnchor = r == 0 && c == 0;
				if (!isAnchor) {
					mergeTdIdList.add(td.id ?? '');
					final int startValueIndex = td.value.length > 1 ? 0 : 1;
					for (int v = startValueIndex; v < td.value.length; v++) {
						final IElement tdElement = td.value[v];
						_copyTableContext(anchorElement, tdElement);
						anchorTd.value.add(tdElement);
					}
				}
				if (r == 0 && c != 0) {
					anchorTd.colspan += td.colspan;
				}
				if (r != 0 && anchorTd.colIndex == td.colIndex) {
					anchorTd.rowspan += td.rowspan;
				}
			}
		}

		for (final ITr tr in trList) {
			int d = 0;
			while (d < tr.tdList.length) {
				final ITd td = tr.tdList[d];
				if (mergeTdIdList.contains(td.id)) {
					tr.tdList.removeAt(d);
					continue;
				}
				d++;
			}
		}

			final IElement? anchorContext =
					anchorTd.value.isNotEmpty ? anchorTd.value.first : null;
			_position?.setPositionContext(
				IPositionContext(
					isTable: true,
					index: index,
					trIndex: anchorTd.trIndex,
					tdIndex: anchorTd.tdIndex,
					tdId: anchorTd.id,
					trId: anchorContext?.trId,
					tableId: anchorContext?.tableId,
				),
			);
		final int curIndex = anchorTd.value.length - 1;
		_range?.setRange(curIndex, curIndex);
		_draw.render();
		_tableTool?.render();
	}

	void cancelMergeTableCell() {
		final dynamic positionContext = _position?.getPositionContext();
		if (positionContext == null || positionContext.isTable != true) {
			return;
		}

		final int? index = positionContext.index as int?;
		final int? tdIndex = positionContext.tdIndex as int?;
		final int? trIndex = positionContext.trIndex as int?;
		if (index == null || tdIndex == null || trIndex == null) {
			return;
		}

		final List<IElement> elementList = _draw.getOriginalElementList();
		if (index < 0 || index >= elementList.length) {
			return;
		}
		final IElement element = elementList[index];
		final List<ITr>? trList = element.trList;
		if (trList == null || trIndex < 0 || trIndex >= trList.length) {
			return;
		}

		final ITr tr = trList[trIndex];
		if (tdIndex < 0 || tdIndex >= tr.tdList.length) {
			return;
		}
		final ITd td = tr.tdList[tdIndex];
		if (td.rowspan == 1 && td.colspan == 1) {
			return;
		}

		final int originalColspan = td.colspan;
		if (td.colspan > 1) {
			for (int c = 1; c < td.colspan; c++) {
				final String tdId = getUUID();
				tr.tdList.insert(
					tdIndex + c,
					ITd(
						id: tdId,
						rowspan: 1,
						colspan: 1,
						value: <IElement>[
							IElement(
								value: ZERO,
								size: 16,
								tableId: element.id,
								trId: tr.id,
								tdId: tdId,
							),
						],
					),
				);
			}
			td.colspan = 1;
		}

		if (td.rowspan > 1) {
			for (int r = 1; r < td.rowspan; r++) {
				final int targetIndex = trIndex + r;
				if (targetIndex >= trList.length) {
					break;
				}
				final ITr targetTr = trList[targetIndex];
				for (int c = 0; c < originalColspan; c++) {
					final String tdId = getUUID();
					targetTr.tdList.insert(
						td.colIndex ?? 0,
						ITd(
							id: tdId,
							rowspan: 1,
							colspan: 1,
							value: <IElement>[
								IElement(
									value: ZERO,
									size: 16,
									tableId: element.id,
									trId: targetTr.id,
									tdId: tdId,
								),
							],
						),
					);
				}
			}
			td.rowspan = 1;
		}

		final int curIndex = td.value.length - 1;
		_range?.setRange(curIndex, curIndex);
		_draw.render();
		_tableTool?.render();
	}

	void splitVerticalTableCell() {
		final dynamic positionContext = _position?.getPositionContext();
		if (positionContext == null || positionContext.isTable != true) {
			return;
		}

		final RangeManager? rangeManager = _range;
		if (rangeManager == null || rangeManager.getRange().isCrossRowCol == true) {
			return;
		}

		final int? index = positionContext.index as int?;
		final int? tdIndex = positionContext.tdIndex as int?;
		final int? trIndex = positionContext.trIndex as int?;
		if (index == null || tdIndex == null || trIndex == null) {
			return;
		}

		final List<IElement> elementList = _draw.getOriginalElementList();
		if (index < 0 || index >= elementList.length) {
			return;
		}
		final IElement element = elementList[index];
		final List<ITr>? trList = element.trList;
		final List<IColgroup>? colgroup = element.colgroup;
		if (trList == null || colgroup == null ||
				trIndex < 0 || trIndex >= trList.length) {
			return;
		}

		final ITr tr = trList[trIndex];
		if (tdIndex < 0 || tdIndex >= tr.tdList.length) {
			return;
		}
		final ITd td = tr.tdList[tdIndex];

		colgroup.insert(
			tdIndex + 1,
			IColgroup(width: (_options.table?.defaultColMinWidth ?? 0).toDouble()),
		);

		for (int t = 0; t < trList.length; t++) {
			final ITr currentTr = trList[t];
			int d = 0;
			while (d < currentTr.tdList.length) {
				final ITd currentTd = currentTr.tdList[d];
				if (currentTd.rowIndex != td.rowIndex) {
					final int? colIndex = currentTd.colIndex;
					if (colIndex != null && td.colIndex != null &&
							colIndex <= td.colIndex! &&
							colIndex + currentTd.colspan > td.colIndex!) {
						currentTd.colspan += 1;
					}
					d++;
					continue;
				}
				if (currentTd.id == td.id) {
					final String tdId = getUUID();
					currentTr.tdList.insert(
						d + td.colspan,
						ITd(
							id: tdId,
							rowspan: td.rowspan,
							colspan: 1,
							value: <IElement>[
								IElement(
									value: ZERO,
									size: 16,
									tableId: element.id,
									trId: currentTr.id,
									tdId: tdId,
								),
							],
						),
					);
					d += td.colspan + 1;
				} else {
					d++;
				}
			}
		}

		_draw.render();
		_tableTool?.render();
	}

	void splitHorizontalTableCell() {
		final dynamic positionContext = _position?.getPositionContext();
		if (positionContext == null || positionContext.isTable != true) {
			return;
		}

		final RangeManager? rangeManager = _range;
		if (rangeManager == null || rangeManager.getRange().isCrossRowCol == true) {
			return;
		}

		final int? index = positionContext.index as int?;
		final int? tdIndex = positionContext.tdIndex as int?;
		final int? trIndex = positionContext.trIndex as int?;
		if (index == null || tdIndex == null || trIndex == null) {
			return;
		}

		final List<IElement> elementList = _draw.getOriginalElementList();
		if (index < 0 || index >= elementList.length) {
			return;
		}
		final IElement element = elementList[index];
		final List<ITr>? trList = element.trList;
		if (trList == null || trIndex < 0 || trIndex >= trList.length) {
			return;
		}

		final ITr tr = trList[trIndex];
		if (tdIndex < 0 || tdIndex >= tr.tdList.length) {
			return;
		}
		final ITd td = tr.tdList[tdIndex];

		int appendTrIndex = -1;
		int t = 0;
		while (t < trList.length) {
			if (t == appendTrIndex) {
				t++;
				continue;
			}
			final ITr currentTr = trList[t];
			int d = 0;
			while (d < currentTr.tdList.length) {
				final ITd currentTd = currentTr.tdList[d];
				if (currentTd.id == td.id) {
					final String trId = getUUID();
					final String tdId = getUUID();
					trList.insert(
						t + td.rowspan,
						ITr(
							id: trId,
							height: (_options.table?.defaultTrMinHeight ?? 0).toDouble(),
							tdList: <ITd>[
								ITd(
									id: tdId,
									rowspan: 1,
									colspan: td.colspan,
									value: <IElement>[
										IElement(
											value: ZERO,
											size: 16,
											tableId: element.id,
											trId: trId,
											tdId: tdId,
										),
									],
								),
							],
						),
					);
					appendTrIndex = t + td.rowspan;
				} else if (currentTd.rowIndex != null && currentTd.rowIndex! >= td.rowIndex! &&
						currentTd.rowIndex! < td.rowIndex! + td.rowspan &&
						currentTd.rowIndex! + currentTd.rowspan >=
								td.rowIndex! + td.rowspan) {
					currentTd.rowspan += 1;
				}
				d++;
			}
			t++;
		}

		_draw.render();
		_tableTool?.render();
	}

	void tableTdVerticalAlign(VerticalAlign payload) {
		final TableParticle? tableParticle = _tableParticle;
		if (tableParticle == null) {
			return;
		}
		final List<List<ITd>>? rowCol = tableParticle.getRangeRowCol();
		if (rowCol == null) {
			return;
		}
		for (final List<ITd> row in rowCol) {
			for (final ITd td in row) {
				if (td.verticalAlign == payload ||
						(td.verticalAlign == null && payload == VerticalAlign.top)) {
					continue;
				}
				td.verticalAlign = payload;
			}
		}
		final RangeManager? rangeManager = _range;
		final int endIndex = rangeManager?.getRange().endIndex ?? 0;
		_draw.render(IDrawOption(curIndex: endIndex));
	}

	void tableBorderType(TableBorder payload) {
		final dynamic positionContext = _position?.getPositionContext();
		if (positionContext == null || positionContext.isTable != true) {
			return;
		}

		final int? index = positionContext.index as int?;
		if (index == null) {
			return;
		}

		final List<IElement> elementList = _draw.getOriginalElementList();
		if (index < 0 || index >= elementList.length) {
			return;
		}
		final IElement element = elementList[index];
		if ((element.borderType == null && payload == TableBorder.all) ||
				element.borderType == payload) {
			return;
		}
		element.borderType = payload;
		final RangeManager? rangeManager = _range;
		final int endIndex = rangeManager?.getRange().endIndex ?? 0;
		_draw.render(IDrawOption(curIndex: endIndex));
	}

	void tableBorderColor(String payload) {
		final dynamic positionContext = _position?.getPositionContext();
		if (positionContext == null || positionContext.isTable != true) {
			return;
		}

		final int? index = positionContext.index as int?;
		if (index == null) {
			return;
		}

		final List<IElement> elementList = _draw.getOriginalElementList();
		if (index < 0 || index >= elementList.length) {
			return;
		}
		final IElement element = elementList[index];
		final String defaultColor =
				_options.table?.defaultBorderColor ?? payload;
		if ((element.borderColor == null && payload == defaultColor) ||
				element.borderColor == payload) {
			return;
		}
		element.borderColor = payload;
		final RangeManager? rangeManager = _range;
		final int endIndex = rangeManager?.getRange().endIndex ?? 0;
		_draw.render(
			IDrawOption(curIndex: endIndex, isCompute: false),
		);
	}

	void tableTdBorderType(TdBorder payload) {
		final TableParticle? tableParticle = _tableParticle;
		if (tableParticle == null) {
			return;
		}
		final List<List<ITd>>? rowCol = tableParticle.getRangeRowCol();
		if (rowCol == null) {
			return;
		}
		final List<ITd> tdList = rowCol.expand((List<ITd> row) => row).toList();
		final bool isSetBorderType = tdList.any(
			(ITd td) => td.borderTypes?.contains(payload) != true,
		);
		for (final ITd td in tdList) {
			td.borderTypes ??= <TdBorder>[];
			final List<TdBorder> borderTypes = td.borderTypes!;
			final int index = borderTypes.indexOf(payload);
			if (isSetBorderType) {
				if (index == -1) {
					borderTypes.add(payload);
				}
			} else {
				if (index != -1) {
					borderTypes.removeAt(index);
				}
			}
			if (borderTypes.isEmpty) {
				td.borderTypes = null;
			}
		}
		final RangeManager? rangeManager = _range;
		final int endIndex = rangeManager?.getRange().endIndex ?? 0;
		_draw.render(IDrawOption(curIndex: endIndex));
	}

	void tableTdSlashType(TdSlash payload) {
		final TableParticle? tableParticle = _tableParticle;
		if (tableParticle == null) {
			return;
		}
		final List<List<ITd>>? rowCol = tableParticle.getRangeRowCol();
		if (rowCol == null) {
			return;
		}
		final List<ITd> tdList = rowCol.expand((List<ITd> row) => row).toList();
		final bool isSetSlashType = tdList.any(
			(ITd td) => td.slashTypes?.contains(payload) != true,
		);
		for (final ITd td in tdList) {
			td.slashTypes ??= <TdSlash>[];
			final List<TdSlash> slashTypes = td.slashTypes!;
			final int index = slashTypes.indexOf(payload);
			if (isSetSlashType) {
				if (index == -1) {
					slashTypes.add(payload);
				}
			} else {
				if (index != -1) {
					slashTypes.removeAt(index);
				}
			}
			if (slashTypes.isEmpty) {
				td.slashTypes = null;
			}
		}
		final RangeManager? rangeManager = _range;
		final int endIndex = rangeManager?.getRange().endIndex ?? 0;
		_draw.render(IDrawOption(curIndex: endIndex));
	}

	void tableTdBackgroundColor(String payload) {
		final TableParticle? tableParticle = _tableParticle;
		if (tableParticle == null) {
			return;
		}
		final List<List<ITd>>? rowCol = tableParticle.getRangeRowCol();
		if (rowCol == null) {
			return;
		}
		for (final List<ITd> row in rowCol) {
			for (final ITd td in row) {
				td.backgroundColor = payload;
			}
		}
		final RangeManager? rangeManager = _range;
		final int endIndex = rangeManager?.getRange().endIndex ?? 0;
		rangeManager?.setRange(endIndex, endIndex);
		_draw.render(IDrawOption(isCompute: false));
	}

	void tableSelectAll() {
		final dynamic positionContext = _position?.getPositionContext();
		if (positionContext == null || positionContext.isTable != true) {
			return;
		}

		final int? index = positionContext.index as int?;
		final String? tableId = positionContext.tableId as String?;
		if (index == null || tableId == null) {
			return;
		}

		final RangeManager? rangeManager = _range;
		if (rangeManager == null) {
			return;
		}
		final IRange range = rangeManager.getRange();
		final List<IElement> elementList = _draw.getOriginalElementList();
		if (index < 0 || index >= elementList.length) {
			return;
		}
		final List<ITr>? trList = elementList[index].trList;
		if (trList == null || trList.isEmpty) {
			return;
		}
		final int endTrIndex = trList.length - 1;
		final int endTdIndex = trList[endTrIndex].tdList.length - 1;
		rangeManager.replaceRange(
			IRange(
				startIndex: range.startIndex,
				endIndex: range.endIndex,
				tableId: tableId,
				startTdIndex: 0,
				endTdIndex: endTdIndex,
				startTrIndex: 0,
				endTrIndex: endTrIndex,
			),
		);
		_draw.render(
			IDrawOption(isCompute: false, isSubmitHistory: false),
		);
	}

	double _getContextInnerWidth() {
		try {
			final dynamic result = (_draw as dynamic).getContextInnerWidth();
			if (result is num) {
				return result.toDouble();
			}
		} catch (_) {}
		return _draw.getInnerWidth();
	}

	List<dynamic>? _getRowList() {
		try {
			final dynamic rowList = (_draw as dynamic).getRowList();
			if (rowList is List) {
				return rowList;
			}
		} catch (_) {}
		return null;
	}

	void _copyTableContext(IElement source, IElement target) {
		target
			..tableId = source.tableId
			..trId = source.trId
			..tdId = source.tdId;
	}
}