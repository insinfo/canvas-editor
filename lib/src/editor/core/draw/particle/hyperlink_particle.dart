import 'package:canvas_text_editor/src/dom/dom.dart';

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
  late final HTMLDivElement _container;
  late final HTMLDivElement _hyperlinkPopupContainer;
  late final HTMLAnchorElement _hyperlinkDom;

  _HyperlinkPopupDom _createHyperlinkPopupDom() {
    final HTMLDivElement popup = HTMLDivElement()
      ..classList.add('$editorPrefix-hyperlink-popup')
      ..style.display = 'none';
    final HTMLAnchorElement anchor = HTMLAnchorElement()
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
    // Link interno (#bookmark): navega dentro do documento, como no Word.
    if (url.startsWith('#')) {
      _draw.locationBookmark(url.substring(1));
      return;
    }
    final Window? newTab = window.open(url, '_blank');
    newTab?.setProperty('opener'.toJS, null);
  }

  void render(
    CanvasRenderingContext2D ctx,
    IRowElement element,
    double x,
    double y,
  ) {
    ctx.save();
    ctx.font = element.style;
    final String color =
        element.color ?? _options.defaultHyperlinkColor ?? '#000000';
    element.color = color;
    ctx.fillColor = color;
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

  final HTMLDivElement container;
  final HTMLAnchorElement anchor;
}
