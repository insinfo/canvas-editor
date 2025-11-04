import 'dart:html';
import 'dart:math' as math;

import '../../dataset/constant/common.dart';
import '../../dataset/constant/editor.dart' as editor_constants;
import '../../dataset/enum/common.dart';
import '../../dataset/enum/editor.dart';
import '../../interface/draw.dart';
import '../../interface/editor.dart';
import '../../interface/footer.dart';
import '../../interface/header.dart';
import '../../utils/index.dart' as utils;
import '../draw/draw.dart';
import '../i18n/i18n.dart';
import 'zone_tip.dart';

class Zone {
	Zone(this._draw)
			: _options = _draw.getOptions(),
				_container = _draw.getContainer(),
				_i18n = _draw.getI18n(),
				_currentZone = EditorZone.main {
		if (_options.zone?.tipDisabled != true) {
			ZoneTip(_draw, this);
		}
	}

	static const double _indicatorPadding = 2;
	static const List<double> _indicatorTitleTranslate = <double>[20, 5];

	final Draw _draw;
	final IEditorOption _options;
	final DivElement _container;
	final I18n _i18n;

	EditorZone _currentZone;
	DivElement? _indicatorContainer;

	bool isHeaderActive() => _currentZone == EditorZone.header;

	bool isMainActive() => _currentZone == EditorZone.main;

	bool isFooterActive() => _currentZone == EditorZone.footer;

	EditorZone getZone() => _currentZone;

	void setZone(EditorZone zone) {
		final IHeader header = _resolveHeaderOption();
		final IFooter footer = _resolveFooterOption();
		if ((zone == EditorZone.header && (header.editable == false)) ||
				(zone == EditorZone.footer && (footer.editable == false))) {
			return;
		}
		if (_currentZone == zone) {
			return;
		}
		_currentZone = zone;

			final dynamic rangeManager = _draw.getRange();
			rangeManager?.clearRange?.call();
			_draw.render(
				IDrawOption(
					isSubmitHistory: false,
					isSetCursor: false,
					isCompute: false,
				),
			);
		drawZoneIndicator();

		utils.nextTick(() {
			final dynamic listener = _draw.getListener();
			listener?.zoneChange?.call(zone);
			final dynamic eventBus = _draw.getEventBus();
			if (eventBus?.isSubscribe?.call('zoneChange') == true) {
				eventBus.emit('zoneChange', zone);
			}
		});
	}

	EditorZone getZoneByY(double y) {
		final double headerBottom = _getHeaderTop() + _getHeaderHeight();
		if (y < headerBottom) {
			return EditorZone.header;
		}
		final double footerTop =
			_draw.getHeight() - (_getFooterBottom() + _getFooterHeight());
		if (y > footerTop) {
			return EditorZone.footer;
		}
		return EditorZone.main;
	}

	void drawZoneIndicator() {
		_clearZoneIndicator();
		if (!isHeaderActive() && !isFooterActive()) {
			return;
		}

		final double scale = (_options.scale ?? 1).toDouble();
		final bool isHeaderZone = isHeaderActive();
		final List<Element> pageList = _draw.getPageList();
		if (pageList.isEmpty) {
			return;
		}

		final List<double> margins = _draw.getMargins();
		final double innerWidth = _draw.getInnerWidth();
		final double pageHeight = _draw.getHeight();
		final double pageGap = _draw.getPageGap();
		final double offsetX = _indicatorTitleTranslate[0] * scale;
		final double offsetY = _indicatorTitleTranslate[1] * scale;

		final double indicatorHeight =
				isHeaderZone ? _getHeaderHeight() : _getFooterHeight();
		if (indicatorHeight <= 0) {
			return;
		}
		final double indicatorTop = isHeaderZone
				? _getHeaderTop()
				: pageHeight - _getFooterBottom() - indicatorHeight;

		_indicatorContainer = DivElement()
			..classes.add('${editor_constants.editorPrefix}-zone-indicator');

		for (int p = 0; p < pageList.length; p++) {
			final double startY = (pageHeight + pageGap) * p + indicatorTop;
			final double indicatorLeftX = margins[3] - _indicatorPadding;
			final double indicatorRightX =
					margins[3] + innerWidth + _indicatorPadding;
			final double indicatorTopY = isHeaderZone
					? startY - _indicatorPadding
					: startY + indicatorHeight + _indicatorPadding;
			final double indicatorBottomY = isHeaderZone
					? startY + indicatorHeight + _indicatorPadding
					: startY - _indicatorPadding;

			final DivElement indicatorTitle = DivElement()
				..text = _i18n.t('frame.${isHeaderZone ? 'header' : 'footer'}')
				..style.top = '${indicatorBottomY}px'
				..style.transform =
						'translate(${offsetX}px, ${offsetY}px) scale($scale)';
			_indicatorContainer!.append(indicatorTitle);

			final SpanElement lineTop = SpanElement()
				..classes.add(
						'${editor_constants.editorPrefix}-zone-indicator-border__top')
				..style.top = '${indicatorTopY}px'
				..style.width = '${innerWidth}px'
				..style.marginLeft = '${margins[3]}px';
			_indicatorContainer!.append(lineTop);

			final SpanElement lineLeft = SpanElement()
				..classes.add(
						'${editor_constants.editorPrefix}-zone-indicator-border__left')
				..style.top = '${startY}px'
				..style.height = '${indicatorHeight}px'
				..style.left = '${indicatorLeftX}px';
			_indicatorContainer!.append(lineLeft);

			final SpanElement lineBottom = SpanElement()
				..classes.add(
						'${editor_constants.editorPrefix}-zone-indicator-border__bottom')
				..style.top = '${indicatorBottomY}px';
			_indicatorContainer!.append(lineBottom);

			final SpanElement lineRight = SpanElement()
				..classes.add(
						'${editor_constants.editorPrefix}-zone-indicator-border__right')
				..style.top = '${startY}px'
				..style.height = '${indicatorHeight}px'
				..style.left = '${indicatorRightX}px';
			_indicatorContainer!.append(lineRight);
		}

		_container.append(_indicatorContainer!);
	}

	void _clearZoneIndicator() {
		_indicatorContainer?.remove();
		_indicatorContainer = null;
	}

		IHeader _resolveHeaderOption() {
			final IHeader header = _options.header ??= IHeader();
			header.maxHeightRadio ??= MaxHeightRatio.quarter;
			header.disabled ??= false;
			header.editable ??= true;
			header.top ??= 0;
			header.inactiveAlpha ??= 0.6;
			return header;
		}

		IFooter _resolveFooterOption() {
			final IFooter footer = _options.footer ??= IFooter();
			footer.maxHeightRadio ??= MaxHeightRatio.quarter;
			footer.disabled ??= false;
			footer.editable ??= true;
			footer.bottom ??= 0;
			footer.inactiveAlpha ??= 0.6;
			return footer;
		}

	double _getHeaderTop() {
		final IHeader header = _resolveHeaderOption();
		if (header.disabled == true) {
			return 0;
		}
		final double top = (header.top ?? 0).toDouble();
		final double scale = (_options.scale ?? 1).toDouble();
		return (top * scale).floorToDouble();
	}

	double _getHeaderHeight() {
		final IHeader header = _resolveHeaderOption();
		if (header.disabled == true) {
			return 0;
		}
		final double maxHeight = _resolveMaxHeight(header.maxHeightRadio);
		return maxHeight;
	}

	double _getFooterHeight() {
		final IFooter footer = _resolveFooterOption();
		if (footer.disabled == true) {
			return 0;
		}
		final double maxHeight = _resolveMaxHeight(footer.maxHeightRadio);
		return maxHeight;
	}

	double _getFooterBottom() {
		final IFooter footer = _resolveFooterOption();
		final double bottom = (footer.bottom ?? 0).toDouble();
		final double scale = (_options.scale ?? 1).toDouble();
		return (bottom * scale).floorToDouble();
	}

	double _resolveMaxHeight(MaxHeightRatio? ratio) {
		final double fraction =
				maxHeightRadioMapping[ratio ?? MaxHeightRatio.quarter] ?? 0;
		final double height = _draw.getHeight();
		return math.max(0, height * fraction).floorToDouble();
	}
}