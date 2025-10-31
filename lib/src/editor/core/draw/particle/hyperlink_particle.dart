// TODO: Translate from C:\\MyTsProjects\\canvas-editor\\src\\editor\\core\\draw\\particle\\HyperlinkParticle.ts
import 'dart:html';

import '../../../dataset/constant/editor.dart';
import '../../../interface/editor.dart';
import '../../../interface/element.dart';
import '../../../interface/row.dart';
import '../draw.dart';

class HyperlinkParticle {
	HyperlinkParticle(this._draw) : _options = _draw.getOptions() {
		_container = _draw.getContainer();
		final _HyperlinkPopupDom popupDom = _createHyperlinkPopupDom();
		_hyperlinkPopupContainer = popupDom.container;
		_hyperlinkDom = popupDom.anchor;
	}

	final Draw _draw;
	final IEditorOption _options;
	late final DivElement _container;
	late final DivElement _hyperlinkPopupContainer;
	late final AnchorElement _hyperlinkDom;

	_HyperlinkPopupDom _createHyperlinkPopupDom() {
		final DivElement popup = DivElement()
			..classes.add('$editorPrefix-hyperlink-popup')
			..style.display = 'none';
		final AnchorElement anchor = AnchorElement()
			..target = '_blank'
			..rel = 'noopener';
		popup.append(anchor);
		_container.append(popup);
		return _HyperlinkPopupDom(container: popup, anchor: anchor);
	}

	void drawHyperlinkPopup(IElement element, IElementPosition position) {
		final List<double>? leftTop = position.coordinate['leftTop'];
		if (leftTop == null || leftTop.length < 2) {
			return;
		}
		final double left = leftTop[0];
		final double top = leftTop[1];
		final double height = _draw.getHeight();
		final double pageGap = _draw.getPageGap();
		final double preY = _draw.getPageNo() * (height + pageGap);
		_hyperlinkPopupContainer.style
			..display = 'block'
			..left = '${left}px'
			..top = '${top + preY + position.lineHeight}px';
		final String url = element.url?.isNotEmpty == true ? element.url! : '#';
		_hyperlinkDom
			..href = url
			..title = url
			..text = url;
	}

	void clearHyperlinkPopup() {
		_hyperlinkPopupContainer.style.display = 'none';
	}

	void openHyperlink(IElement element) {
		final String? url = element.url;
		if (url == null || url.isEmpty) {
			return;
		}
		window.open(url, '_blank');
	}

	void render(
		CanvasRenderingContext2D ctx,
		IRowElement element,
		double x,
		double y,
	) {
		ctx.save();
		ctx.font = element.style;
		final String color = element.color ?? _options.defaultHyperlinkColor ?? '#000000';
		element.color = color;
		ctx.fillStyle = color;
		element.underline ??= true;
		ctx.fillText(element.value, x, y);
		ctx.restore();
	}
}

class _HyperlinkPopupDom {
	const _HyperlinkPopupDom({
		required this.container,
		required this.anchor,
	});

	final DivElement container;
	final AnchorElement anchor;
}