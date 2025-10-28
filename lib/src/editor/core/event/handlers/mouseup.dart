import '../../../dataset/constant/element.dart' as element_constants;
import '../../../dataset/enum/common.dart';
import '../../../dataset/enum/control.dart';
import '../../../dataset/enum/element.dart';
import '../../../interface/draw.dart';
import '../../../interface/editor.dart';
import '../../../interface/element.dart';
import '../../../interface/position.dart';
import '../../../interface/range.dart';
import '../../../interface/table/td.dart';
import '../../../utils/element.dart' as element_utils;
import '../../../utils/index.dart';

final Expando<String> _dragIdExpando = Expando<String>('dragId');

void mouseup(dynamic evt, dynamic host) {
	if (host.isAllowDrop == true) {
		_finalizeDrag(evt, host);
	} else if (host.isAllowDrag == true) {
		final IRange? cacheRange = host.cacheRange as IRange?;
		if (cacheRange != null && cacheRange.startIndex != cacheRange.endIndex) {
			host.mousedown(evt);
		}
	}
}

void _finalizeDrag(dynamic evt, dynamic host) {
	final dynamic draw = host.getDraw();
	if (draw.isReadonly() == true || draw.isDisabled() == true) {
		host.mousedown(evt);
		return;
	}

	final dynamic position = draw.getPosition();
	final List<IElementPosition> positionList =
			(position.getPositionList() as List?)?.cast<IElementPosition>() ??
					<IElementPosition>[];
	final IPositionContext positionContext =
			(position.getPositionContext() as IPositionContext?) ??
					IPositionContext(isTable: false);
	final dynamic rangeManager = draw.getRange();
	final IRange? cacheRange = host.cacheRange as IRange?;
	final List<IElement> cacheElementList =
			(host.cacheElementList as List?)?.cast<IElement>() ?? <IElement>[];
	final List<IElementPosition> cachePositionList =
			(host.cachePositionList as List?)?.cast<IElementPosition>() ??
					<IElementPosition>[];
	final IPositionContext? cachePositionContext =
			host.cachePositionContext as IPositionContext?;
	if (cacheRange == null || cacheElementList.isEmpty) {
		host.mousedown(evt);
		return;
	}

	final IRange range = rangeManager.getRange() as IRange;
	final bool isCacheRangeCollapsed =
			cacheRange.startIndex == cacheRange.endIndex;
	final int cacheStartIndex = isCacheRangeCollapsed
			? cacheRange.startIndex - 1
			: cacheRange.startIndex;
	final int cacheEndIndex = cacheRange.endIndex;

	if (range.startIndex >= cacheStartIndex &&
			range.endIndex <= cacheEndIndex &&
			cachePositionContext?.tdId == positionContext.tdId) {
		_drawWithinCachedRange(evt, host, draw, cacheRange, cacheElementList,
				cachePositionList, cacheEndIndex, isCacheRangeCollapsed);
		return;
	}

	final List<IElement> dragElementList = _sliceElements(
		cacheElementList,
		cacheStartIndex + 1,
		cacheEndIndex + 1,
	);
	final bool isContainControl =
			dragElementList.any((IElement element) => element.controlId != null);
	final dynamic control = draw.getControl();
	final List<IElement> elementList =
			(draw.getElementList() as List?)?.cast<IElement>() ?? <IElement>[];
	final IEditorOption editorOptions =
			draw.getOptions() as IEditorOption;
	final bool isOmitControlAttr =
			!isContainControl ||
				range.startIndex < elementList.length &&
						elementList[range.startIndex].controlId != null ||
				control?.getIsElementListContainFullControl(dragElementList) != true;

	final List<IElement> replaceElementList = _buildReplacementElements(
		dragElementList,
		editorOptions,
		isOmitControlAttr,
	);
	if (replaceElementList.isEmpty) {
		draw.render(IDrawOption(isSetCursor: false));
		return;
	}
	final element_utils.FormatElementContextOption contextOption =
			element_utils.FormatElementContextOption(editorOptions: editorOptions);
	element_utils.formatElementContext(
		elementList,
		replaceElementList,
		range.startIndex,
		options: contextOption,
	);

	final IElement? cacheStartElement =
			cacheStartIndex >= 0 && cacheStartIndex < cacheElementList.length
					? cacheElementList[cacheStartIndex]
					: null;
	final IElementPosition? cacheStartPosition = cacheStartIndex >= 0 &&
			cacheStartIndex < cachePositionList.length
					? cachePositionList[cacheStartIndex]
					: null;
	final String? cacheRangeStartId = cacheStartElement == null
			? null
			: _createDragId(cacheStartElement);
	final String cacheRangeEndId =
			_createDragId(cacheElementList[cacheEndIndex]);

	final int replaceLength = replaceElementList.length;
	int rangeStartIndex = range.startIndex;
	int rangeEndIndex = rangeStartIndex + replaceLength;
	final dynamic activeControl = control?.getActiveControl();
	if (activeControl != null &&
			rangeStartIndex < cacheElementList.length &&
			cacheElementList[rangeStartIndex].controlComponent !=
					ControlComponent.postfix) {
		final dynamic setValueResult =
				activeControl.setValue(replaceElementList);
		rangeEndIndex = (setValueResult as num?)?.toInt() ?? -1;
		rangeStartIndex = rangeEndIndex - replaceLength;
	} else {
		draw.spliceElementList(
			elementList,
			rangeStartIndex + 1,
			0,
			replaceElementList,
		);
	}

	if (rangeEndIndex < 0) {
		draw.render(IDrawOption(isSetCursor: false));
		return;
	}

	final String rangeStartId =
			_createDragId(elementList[rangeStartIndex]);
	final String rangeEndId =
			_createDragId(elementList[rangeEndIndex]);

	final int cacheRangeStartIndex = cacheRangeStartId == null
			? -1
			: _getElementIndexByDragId(cacheRangeStartId, cacheElementList);
	final int cacheRangeEndIndex = _getElementIndexByDragId(
		cacheRangeEndId,
		cacheElementList,
	);
	if (cacheRangeEndIndex == -1) {
		draw.render(IDrawOption(isSetCursor: false));
		return;
	}
	final IElement cacheEndElement = cacheElementList[cacheRangeEndIndex];
	if (cacheEndElement.controlId != null &&
			cacheEndElement.controlComponent != ControlComponent.postfix) {
		rangeManager.replaceRange(_cloneRange(cacheRange)
			..startIndex = cacheRangeStartIndex
			..endIndex = cacheRangeEndIndex);
		control?.getActiveControl()?.cut();
	} else {
		var isTdElementDeletable = true;
		final IPositionContext? cacheCtx = cachePositionContext;
		if (cacheCtx != null && cacheCtx.isTable == true) {
			final String? tableId = cacheCtx.tableId;
			final int? trIndex = cacheCtx.trIndex;
			final int? tdIndex = cacheCtx.tdIndex;
			if (tableId != null && trIndex != null && tdIndex != null) {
				final List<IElement> originElementList =
						(draw.getOriginalElementList() as List?)?.cast<IElement>() ??
							<IElement>[];
				isTdElementDeletable = !originElementList.any((IElement el) {
					if (el.id != tableId) {
						return false;
					}
					final List<ITr>? trList = el.trList;
					if (trList == null || trIndex >= trList.length) {
						return false;
					}
					final ITr tr = trList[trIndex];
					final List<ITd> tdList = tr.tdList;
					if (tdIndex >= tdList.length) {
						return false;
					}
					return tdList[tdIndex].deletable == false;
				});
			}
		}
		if (isTdElementDeletable) {
			draw.spliceElementList(
				cacheElementList,
				cacheRangeStartIndex + 1,
				cacheRangeEndIndex - cacheRangeStartIndex,
			);
		}
	}

	final IElement startElement =
			range.startIndex < elementList.length
					? elementList[range.startIndex]
					: elementList.last;
	final IElementPosition startPosition =
			range.startIndex < positionList.length
					? positionList[range.startIndex]
					: positionList.isNotEmpty
							? positionList.last
							: IElementPosition(
									pageNo: 0,
									index: 0,
									value: '',
									rowIndex: 0,
									rowNo: 0,
									ascent: 0,
									lineHeight: 0,
									left: 0,
									metrics: IElementMetrics(
										width: 0,
										height: 0,
										boundingBoxAscent: 0,
										boundingBoxDescent: 0,
									),
									isFirstLetter: false,
									isLastLetter: false,
									coordinate: <String, List<double>>{},
								);
	int? positionContextIndex = positionContext.index;
	if (positionContextIndex != null && positionContextIndex != 0) {
		final bool isMovingIntoTable =
				startElement.tableId != null && cacheStartElement?.tableId == null;
		final bool isMovingOutFromTable =
				startElement.tableId == null && cacheStartElement?.tableId != null;
		if (isMovingIntoTable && cacheStartPosition != null) {
			if (cacheStartPosition.index < positionContextIndex) {
				positionContextIndex -= replaceLength;
			}
		} else if (isMovingOutFromTable) {
			if (startPosition.index < positionContextIndex) {
				positionContextIndex += replaceLength;
			}
		}
		final IPositionContext newPositionContext =
				_clonePositionContext(positionContext)
					..index = positionContextIndex;
		position.setPositionContext(newPositionContext);
	}

	final int rangeStartIdIndex =
			_getElementIndexByDragId(rangeStartId, elementList);
	final int rangeEndIdIndex =
			_getElementIndexByDragId(rangeEndId, elementList);
	rangeManager.setRange(
		isCacheRangeCollapsed ? rangeEndIdIndex : rangeStartIdIndex,
		rangeEndIdIndex,
		range.tableId,
		range.startTdIndex,
		range.endTdIndex,
		range.startTrIndex,
		range.endTrIndex,
	);
	draw.clearSideEffect();

	IElement? imgElement;
	if (isCacheRangeCollapsed) {
		final List<IElement> currentElementList =
				(draw.getElementList() as List?)?.cast<IElement>() ?? <IElement>[];
		if (rangeEndIdIndex >= 0 && rangeEndIdIndex < currentElementList.length) {
			final IElement dragElement = currentElementList[rangeEndIdIndex];
			if (dragElement.type == ElementType.image ||
					dragElement.type == ElementType.latex) {
				_moveImgPosition(dragElement, evt, host);
				imgElement = dragElement;
			}
		}
	}

	draw.render(IDrawOption(isSetCursor: false));

	if (activeControl != null) {
		control?.emitControlContentChange();
	} else if (cacheStartElement?.controlId != null) {
		control?.emitControlContentChange(<String, dynamic>{
			'context': <String, dynamic>{
				'range': cacheRange,
				'elementList': cacheElementList,
			},
			'controlElement': cacheStartElement,
		});
	}

	if (imgElement != null) {
		final dynamic previewer = draw.getPreviewer();
		if (imgElement.imgDisplay == ImageDisplay.surround ||
				imgElement.imgDisplay == ImageDisplay.floatTop ||
				imgElement.imgDisplay == ImageDisplay.floatBottom) {
			previewer?.drawResizer(imgElement);
		} else {
			final List<IElementPosition> dragPositionList =
					(position.getPositionList() as List?)?.cast<IElementPosition>() ??
						<IElementPosition>[];
			if (rangeEndIdIndex >= 0 &&
						rangeEndIdIndex < dragPositionList.length) {
				previewer?.drawResizer(
					imgElement,
					dragPositionList[rangeEndIdIndex],
				);
			}
		}
	}
}

void _drawWithinCachedRange(
	dynamic evt,
	dynamic host,
	dynamic draw,
	IRange cacheRange,
	List<IElement> cacheElementList,
	List<IElementPosition> cachePositionList,
	int cacheEndIndex,
	bool isCacheRangeCollapsed,
) {
	draw.clearSideEffect();
	bool isSubmitHistory = false;
	bool isCompute = false;
	if (isCacheRangeCollapsed) {
		final IElement dragElement = cacheElementList[cacheEndIndex];
		if (dragElement.type == ElementType.image ||
				dragElement.type == ElementType.latex) {
			_moveImgPosition(dragElement, evt, host);
			final dynamic previewer = draw.getPreviewer();
			if (dragElement.imgDisplay == ImageDisplay.surround ||
					dragElement.imgDisplay == ImageDisplay.floatTop ||
					dragElement.imgDisplay == ImageDisplay.floatBottom) {
				previewer?.drawResizer(dragElement);
				isSubmitHistory = true;
			} else {
				if (cacheEndIndex < cachePositionList.length) {
					previewer?.drawResizer(
						dragElement,
						cachePositionList[cacheEndIndex],
					);
				}
			}
			isCompute = dragElement.imgDisplay == ImageDisplay.surround;
		}
	}
	final dynamic rangeManager = draw.getRange();
	rangeManager.replaceRange(_cloneRange(cacheRange));
	draw.render(
		IDrawOption(
			isCompute: isCompute,
			isSubmitHistory: isSubmitHistory,
			isSetCursor: false,
		),
	);
}

void _moveImgPosition(IElement element, dynamic evt, dynamic host) {
	final dynamic draw = host.getDraw();
	if (element.imgDisplay == ImageDisplay.surround ||
			element.imgDisplay == ImageDisplay.floatTop ||
			element.imgDisplay == ImageDisplay.floatBottom) {
		final ICurrentPosition? start =
				host.mouseDownStartPosition as ICurrentPosition?;
		if (start != null && element.imgFloatPosition != null) {
			final double offsetX = (evt?.offsetX as num?)?.toDouble() ?? 0;
			final double offsetY = (evt?.offsetY as num?)?.toDouble() ?? 0;
			final double startX = start.x ?? 0;
			final double startY = start.y ?? 0;
			final Map<String, num> floatPosition =
					Map<String, num>.from(element.imgFloatPosition!);
			final double moveX = offsetX - startX;
			final double moveY = offsetY - startY;
			floatPosition['x'] = (floatPosition['x'] ?? 0) + moveX;
			floatPosition['y'] = (floatPosition['y'] ?? 0) + moveY;
			final int pageNo = (draw.getPageNo() as num?)?.toInt() ?? 0;
			floatPosition['pageNo'] = pageNo;
			element.imgFloatPosition = floatPosition;
		}
	}
	draw.getImageParticle()?.destroyFloatImage();
}

String _createDragId(IElement element) {
	final String dragId = getUUID();
	_dragIdExpando[element] = dragId;
	return dragId;
}

int _getElementIndexByDragId(String dragId, List<IElement> elementList) {
	for (var i = 0; i < elementList.length; i++) {
		if (_dragIdExpando[elementList[i]] == dragId) {
			return i;
		}
	}
	return -1;
}

List<IElement> _buildReplacementElements(
	List<IElement> dragElementList,
	IEditorOption editorOptions,
	bool isOmitControlAttr,
) {
	final List<IElement> result = <IElement>[];
	for (final IElement element in dragElementList) {
		if (element.type == null || element.type == ElementType.text) {
			final IElement newElement = IElement(value: element.value);
			_copyAttributes(
				source: element,
				target: newElement,
				attributes: element_constants.editorElementStyleAttr,
			);
			if (!isOmitControlAttr) {
				_copyAttributes(
					source: element,
					target: newElement,
					attributes: element_constants.controlContextAttr,
				);
			}
			result.add(newElement);
		} else {
			final List<IElement> cloneList =
					element_utils.cloneElementList(<IElement>[element]);
			IElement clone = cloneList.first;
			if (isOmitControlAttr) {
				clone
					..control = null
					..controlId = null
					..controlComponent = null;
			}
			final List<IElement> formatted = <IElement>[clone];
			element_utils.formatElementList(
				formatted,
				element_utils.FormatElementListOption(
					isHandleFirstElement: false,
					isForceCompensation: false,
					editorOptions: editorOptions,
				),
			);
			if (formatted.isNotEmpty) {
				result.add(formatted.first);
			}
		}
	}
	return result;
}

void _copyAttributes({
	required IElement source,
	required IElement target,
	required Iterable<String> attributes,
}) {
	for (final String attr in attributes) {
		switch (attr) {
			case 'bold':
				target.bold = source.bold;
				break;
			case 'color':
				target.color = source.color;
				break;
			case 'highlight':
				target.highlight = source.highlight;
				break;
			case 'font':
				target.font = source.font;
				break;
			case 'size':
				target.size = source.size;
				break;
			case 'italic':
				target.italic = source.italic;
				break;
			case 'underline':
				target.underline = source.underline;
				break;
			case 'strikeout':
				target.strikeout = source.strikeout;
				break;
			case 'textDecoration':
				target.textDecoration = source.textDecoration;
				break;
			case 'control':
				target.control = source.control;
				break;
			case 'controlId':
				target.controlId = source.controlId;
				break;
			case 'controlComponent':
				target.controlComponent = source.controlComponent;
				break;
		}
	}
}

	IPositionContext _clonePositionContext(IPositionContext source) {
		return IPositionContext(
			isTable: source.isTable,
			isCheckbox: source.isCheckbox,
			isRadio: source.isRadio,
			isControl: source.isControl,
			isImage: source.isImage,
			isDirectHit: source.isDirectHit,
			index: source.index,
			trIndex: source.trIndex,
			tdIndex: source.tdIndex,
			tdId: source.tdId,
			trId: source.trId,
			tableId: source.tableId,
		);
	}

IRange _cloneRange(IRange source) {
	return IRange(
		startIndex: source.startIndex,
		endIndex: source.endIndex,
		isCrossRowCol: source.isCrossRowCol,
		tableId: source.tableId,
		startTdIndex: source.startTdIndex,
		endTdIndex: source.endTdIndex,
		startTrIndex: source.startTrIndex,
		endTrIndex: source.endTrIndex,
		zone: source.zone,
	);
}

List<IElement> _sliceElements(
	List<IElement> elements,
	int start,
	int end,
) {
	final int safeStart = start.clamp(0, elements.length);
	final int safeEnd = end.clamp(safeStart, elements.length);
	return elements.sublist(safeStart, safeEnd);
}