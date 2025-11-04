import 'dart:html';
import 'dart:js_util' as js_util;

import '../../../../../interface/block.dart';
import '../../../../../interface/row.dart';

class IFrameBlock {
	IFrameBlock(this._element);

	static const List<String> sandbox = <String>['allow-scripts', 'allow-same-origin'];

	final IRowElement _element;

	void _defineIframeProperties(WindowBase? iframeWindow) {
		if (iframeWindow == null) {
			return;
		}
		final dynamic objectConstructor = js_util.getProperty(js_util.globalThis, 'Object');
		final Map<String, dynamic> descriptor = <String, dynamic>{
			'parent': <String, dynamic>{
				'get': js_util.allowInterop(() => null),
			},
			'__POWERED_BY_CANVAS_EDITOR__': <String, dynamic>{
				'get': js_util.allowInterop(() => true),
			},
		};
		js_util.callMethod(objectConstructor, 'defineProperties', <dynamic>[
			iframeWindow,
			js_util.jsify(descriptor),
		]);
	}

	void render(DivElement blockItemContainer) {
		final IBlock? block = _element.block;
		if (block == null) {
			return;
		}
		final IFrameElement iframe = IFrameElement()
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
			iframe.srcdoc = srcdoc;
		}
		blockItemContainer.append(iframe);
		_defineIframeProperties(iframe.contentWindow);
	}
}