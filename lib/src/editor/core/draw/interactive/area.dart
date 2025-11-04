import 'dart:html';

import '../../../dataset/constant/placeholder.dart';
import '../../../dataset/enum/area.dart';
import '../../../dataset/enum/common.dart';
import '../../../dataset/enum/editor.dart';
import '../../../dataset/enum/element.dart';
import '../../../interface/area.dart';
import '../../../interface/draw.dart';
import '../../../interface/editor.dart';
import '../../../interface/element.dart';
import '../../../interface/placeholder.dart';
import '../../../interface/position.dart';
import '../../../interface/range.dart';
import '../../../utils/element.dart' as element_utils;
import '../../../utils/index.dart' as utils;
import '../../position/position.dart';
import '../../range/range_manager.dart';
import '../../zone/zone.dart';
import '../draw.dart';
import '../frame/placeholder.dart';

class Area {
	Area(Draw draw)
			: _draw = draw,
				_options = draw.getOptions(),
				_zone = draw.getZone(),
				_range = draw.getRange() as RangeManager,
				_position = draw.getPosition() as Position;

	final Draw _draw;
	final IEditorOption _options;
	final Zone _zone;
	final RangeManager _range;
	final Position _position;
	final Map<String, IAreaInfo<IElement, IElementPosition>> _areaInfoMap =
			<String, IAreaInfo<IElement, IElementPosition>>{};

	dynamic _drawDynamic<T>(T Function(dynamic target) callback) {
		try {
			return callback(_draw as dynamic);
		} catch (_) {
			return null;
		}
	}

	Map<String, IAreaInfo<IElement, IElementPosition>> getAreaInfo() =>
			_areaInfoMap;

	String? getActiveAreaId() {
		if (_areaInfoMap.isEmpty) {
			return null;
		}
		final IRange range = _range.getRange();
		final List<IElement> elementList = _draw.getElementList();
		if (range.startIndex < 0 || range.startIndex >= elementList.length) {
			return null;
		}
		return elementList[range.startIndex].areaId;
	}

	IAreaInfo<IElement, IElementPosition>? getActiveAreaInfo() {
		final String? areaId = getActiveAreaId();
		if (areaId == null) {
			return null;
		}
		return _areaInfoMap[areaId];
	}

	bool isReadonly() {
		final IAreaInfo<IElement, IElementPosition>? activeInfo =
				getActiveAreaInfo();
		final IArea? area = activeInfo?.area;
		if (area == null) {
			return false;
		}
		switch (area.mode) {
			case AreaMode.edit:
				return false;
			case AreaMode.readonly:
				return true;
			case AreaMode.form:
				final dynamic control = _draw.getControl();
				final dynamic getter = control?.getIsRangeWithinControl;
				if (getter is Function) {
					return getter() != true;
				}
				return true;
			default:
				return false;
		}
	}

	String? insertArea(IInsertAreaOption<IElement> payload) {
		final String? id = payload.id;
		final List<IElement> value = payload.value;
		final IArea area = _cloneArea(payload.area);
		final LocationPosition? position = payload.position;
		final IAreaRange? range = payload.range;

		if (_zone.getZone() != EditorZone.main) {
			_zone.setZone(EditorZone.main);
		}

		_position.setPositionContext(IPositionContext(isTable: false));

		if (range != null && getActiveAreaId() == null) {
			final List<IElement> elementList =
					_draw.getOriginalMainElementList();
			if (range.startIndex < 0 ||
					range.startIndex >= elementList.length ||
					range.endIndex < 0 ||
					range.endIndex >= elementList.length) {
				return null;
			}
			_range.setRange(range.startIndex, range.endIndex);
		} else {
			if (position == LocationPosition.before) {
				_range.setRange(0, 0);
			} else {
				final List<IElement> elementList =
						_draw.getOriginalMainElementList();
				final int lastIndex = elementList.isEmpty ? 0 : elementList.length - 1;
				_range.setRange(lastIndex, lastIndex);
			}
		}

		final String areaId = id ?? utils.getUUID();
		_drawDynamic((dynamic target) {
			target.insertElementList(<IElement>[
				IElement(
					type: ElementType.area,
					value: '',
					areaId: areaId,
					valueList: value,
					area: area,
				),
			]);
			return null;
		});
		return areaId;
	}

	void render(CanvasRenderingContext2D ctx, int pageNo) {
		if (_areaInfoMap.isEmpty) {
			return;
		}
		ctx.save();
		final List<double> margins = _draw.getMargins();
		final double width = _draw.getInnerWidth();
		_areaInfoMap.forEach((String _, IAreaInfo<IElement, IElementPosition> info) {
			final IArea area = info.area;
			final bool hasVisual =
					area.backgroundColor != null || area.borderColor != null;
			final bool hasPlaceholder = area.placeholder != null;
			if (area.hide == true || (!hasVisual && !hasPlaceholder)) {
				return;
			}
			final List<IElementPosition> pagePositions = info.positionList
					.where((IElementPosition position) => position.pageNo == pageNo)
					.toList();
			if (pagePositions.isEmpty) {
				return;
			}
			bool translated = false;
			ctx.translate(0.5, 0.5);
			translated = true;
			final IElementPosition firstPosition = pagePositions.first;
			final IElementPosition lastPosition = pagePositions.last;
			final List<double>? firstLeftTop =
					firstPosition.coordinate['leftTop'];
			final List<double>? lastRightBottom =
					lastPosition.coordinate['rightBottom'];
			if (firstLeftTop == null ||
					firstLeftTop.length < 2 ||
					lastRightBottom == null ||
					lastRightBottom.length < 2) {
				if (translated) {
					ctx.translate(-0.5, -0.5);
				}
				return;
			}
			final double x = margins[3];
			final double y = firstLeftTop[1].ceilToDouble();
			final double rawHeight = (lastRightBottom[1] - y).ceilToDouble();
			final double height = rawHeight < 0 ? 0 : rawHeight;

			if (area.backgroundColor != null) {
				ctx.fillStyle = area.backgroundColor!;
				ctx.fillRect(x, y, width, height);
			}

			if (area.borderColor != null) {
				ctx.strokeStyle = area.borderColor!;
				ctx.strokeRect(x, y, width, height);
			}

			if (hasPlaceholder && info.positionList.length <= 1) {
				final Placeholder placeholderPainter = Placeholder(_draw);
				final IPlaceholder placeholderOption =
						_resolvePlaceholderOption(area);
				placeholderPainter.render(
					ctx,
					PlaceholderRenderOption(
						placeholder: placeholderOption,
						startY: firstLeftTop[1],
					),
				);
			}

			if (translated) {
				ctx.translate(-0.5, -0.5);
			}
		});
		ctx.restore();
	}

	void compute() {
		_areaInfoMap.clear();
		final List<IElement> elementList =
				_draw.getOriginalMainElementList();
		final List<IElementPosition> positionList =
				_position.getOriginalMainPositionList();
		for (int index = 0; index < elementList.length; index++) {
			if (index >= positionList.length) {
				break;
			}
			final IElement element = elementList[index];
			final String? areaId = element.areaId;
			final IArea? area = element.area;
			if (areaId == null || area == null) {
				continue;
			}
			final IAreaInfo<IElement, IElementPosition>? existing =
					_areaInfoMap[areaId];
			if (existing == null) {
				_areaInfoMap[areaId] = IAreaInfo<IElement, IElementPosition>(
					id: areaId,
					area: _cloneArea(area),
					elementList: <IElement>[element],
					positionList: <IElementPosition>[positionList[index]],
				);
			} else {
				existing.elementList.add(element);
				existing.positionList.add(positionList[index]);
			}
		}
	}

	IGetAreaValueResult<IElement>? getAreaValue(
			[IGetAreaValueOption? options]) {
		final String? areaId = options?.id ?? getActiveAreaId();
		if (areaId == null) {
			return null;
		}
		final IAreaInfo<IElement, IElementPosition>? info = _areaInfoMap[areaId];
		if (info == null || info.positionList.isEmpty) {
			return null;
		}
		final List<IElement> zipped = element_utils.zipElementList(info.elementList);
		return IGetAreaValueResult<IElement>(
			id: info.id,
			area: info.area,
			startPageNo: info.positionList.first.pageNo,
			endPageNo: info.positionList.last.pageNo,
			value: zipped,
		);
	}

	Map<String, dynamic>? getContextByAreaId(
		String areaId, {
		ILocationAreaOption? options,
	}) {
		final List<IElement> elementList =
				_draw.getOriginalMainElementList();
		final List<IElementPosition> positionList =
				_position.getOriginalMainPositionList();
		for (int index = 0; index < elementList.length; index++) {
			final IElement element = elementList[index];
			bool match = false;
			final LocationPosition? position = options?.position;
			if (position == LocationPosition.outerBefore) {
				if (index + 1 < elementList.length &&
						elementList[index + 1].areaId == areaId) {
					match = true;
				}
			} else if (position == LocationPosition.after) {
				if (element.areaId == areaId &&
						(index + 1 >= elementList.length ||
								elementList[index + 1].areaId != areaId)) {
					match = true;
				}
			} else if (position == LocationPosition.outerAfter) {
				if (element.areaId != areaId &&
						index > 0 &&
						elementList[index - 1].areaId == areaId) {
					match = true;
				}
			} else {
				if (element.areaId == areaId) {
					match = true;
				}
			}
			if (!match || index >= positionList.length) {
				continue;
			}
			return <String, dynamic>{
				'range': IRange(startIndex: index, endIndex: index),
				'elementPosition': positionList[index],
			};
		}
		return null;
	}

	void setAreaProperties(ISetAreaPropertiesOption payload) {
		final String? areaId = payload.id ?? getActiveAreaId();
		if (areaId == null) {
			return;
		}
		final IAreaInfo<IElement, IElementPosition>? info = _areaInfoMap[areaId];
		if (info == null) {
			return;
		}

		final IArea target = info.area;
		final IArea properties = payload.properties;
		bool isCompute = false;

		if (!utils.isNonValue(properties.extension)) {
			target.extension = utils.deepClone(properties.extension);
		}
		if (!utils.isNonValue(properties.placeholder)) {
			target.placeholder = properties.placeholder == null
					? null
					: _clonePlaceholder(properties.placeholder!);
		}
		if (!utils.isNonValue(properties.top)) {
			target.top = properties.top;
			isCompute = true;
		}
		if (!utils.isNonValue(properties.borderColor)) {
			target.borderColor = properties.borderColor;
		}
		if (!utils.isNonValue(properties.backgroundColor)) {
			target.backgroundColor = properties.backgroundColor;
		}
		if (!utils.isNonValue(properties.mode)) {
			target.mode = properties.mode;
		}
		if (!utils.isNonValue(properties.hide)) {
			target.hide = properties.hide;
			isCompute = true;
		}
		if (!utils.isNonValue(properties.deletable)) {
			target.deletable = properties.deletable;
		}

		_draw.render(
			IDrawOption(
				isCompute: isCompute,
				isSetCursor: false,
			),
		);
	}

	void setAreaValue(ISetAreaValueOption<IElement> payload) {
		final String? areaId = payload.id ?? getActiveAreaId();
		if (areaId == null) {
			return;
		}
		final IAreaInfo<IElement, IElementPosition>? info = _areaInfoMap[areaId];
		if (info == null) {
			return;
		}
		final List<IElementPosition> areaPositions = info.positionList;
		if (areaPositions.isEmpty) {
			return;
		}
		final List<IElement> elementList =
				_draw.getOriginalMainElementList();
		final List<IElement> valueList = payload.value;

		element_utils.formatElementList(
			<IElement>[
				IElement(
					type: ElementType.area,
					value: '',
					valueList: valueList,
					areaId: info.id,
					area: info.area,
				),
			],
			element_utils.FormatElementListOption(
				editorOptions: _options,
			),
		);

		_drawDynamic((dynamic target) {
			target.spliceElementList(
				elementList,
				areaPositions.first.index,
				areaPositions.length,
				valueList,
				ISpliceElementListOption(isIgnoreDeletedRule: true),
			);
			return null;
		});

		_draw.render(
			IDrawOption(
				isSetCursor: false,
			),
		);
	}

	IArea _cloneArea(IArea area) => IArea(
				extension: utils.deepClone(area.extension),
				placeholder:
						area.placeholder != null ? _clonePlaceholder(area.placeholder!) : null,
				top: area.top,
				borderColor: area.borderColor,
				backgroundColor: area.backgroundColor,
				mode: area.mode,
				hide: area.hide,
				deletable: area.deletable,
			);

	IPlaceholder _clonePlaceholder(IPlaceholder placeholder) => IPlaceholder(
				data: placeholder.data,
				color: placeholder.color,
				opacity: placeholder.opacity,
				size: placeholder.size,
				font: placeholder.font,
			);

	IPlaceholder _resolvePlaceholderOption(IArea area) {
		final IPlaceholder base = _clonePlaceholder(defaultPlaceholderOption);
		final IPlaceholder? custom = area.placeholder;
		if (custom == null) {
			return base;
		}
		return IPlaceholder(
			data: custom.data.isNotEmpty ? custom.data : base.data,
			color: custom.color ?? base.color,
			opacity: custom.opacity ?? base.opacity,
			size: custom.size ?? base.size,
			font: custom.font ?? base.font,
		);
	}
}
