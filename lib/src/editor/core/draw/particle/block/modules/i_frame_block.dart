import 'package:canvas_text_editor/src/dom/dom.dart';

import '../../../../../interface/block.dart';
import '../../../../../interface/row.dart';

class IFrameBlock {
	IFrameBlock(this._element);

	static const List<String> sandbox = <String>['allow-scripts', 'allow-same-origin'];

	final IRowElement _element;

	void _defineIframeProperties(Window? iframeWindow) {
		if (iframeWindow == null) {
			return;
		}
		final JSObject? objectConstructor =
				globalContext.getProperty('Object'.toJS) as JSObject?;
		if (objectConstructor == null) {
			return;
		}
		final JSObject descriptor = JSObject()
			..setProperty(
				'parent'.toJS,
				JSObject()..setProperty('get'.toJS, (() => null).toJS),
			)
			..setProperty(
				'__POWERED_BY_CANVAS_EDITOR__'.toJS,
				JSObject()..setProperty('get'.toJS, (() => true.toJS).toJS),
			);
		objectConstructor.callMethod(
			'defineProperties'.toJS,
			iframeWindow,
			descriptor,
		);
	}

	void render(HTMLDivElement blockItemContainer) {
		final IBlock? block = _element.block;
		if (block == null) {
			return;
		}
		final HTMLIFrameElement iframe = HTMLIFrameElement()
			..style.border = 'none'
			..style.width = '100%'
			..style.height = '100%';
		if (_element.id != null) {
			iframe.dataset['id'] = _element.id!;
		}
		iframe.setAttribute('sandbox', sandbox.join(' '));
		final String? src = block.iframeBlock?.src;
		final String? srcdoc = block.iframeBlock?.srcdoc;
		if (src != null && src.isNotEmpty) {
			iframe.src = src;
		} else if (srcdoc != null && srcdoc.isNotEmpty) {
			iframe.srcdoc = srcdoc.toJS;
		}
		blockItemContainer.append(iframe);
		_defineIframeProperties(iframe.contentWindow);
	}
}