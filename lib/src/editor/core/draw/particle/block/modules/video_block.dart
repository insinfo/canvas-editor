import 'dart:async';
import 'dart:html';

import '../../../../../interface/row.dart';

class VideoBlock {
	VideoBlock(this._element) : _videoCache = <String, VideoElement>{};

	final IRowElement _element;
	final Map<String, VideoElement> _videoCache;

	Future<IRowElement> snapshot(
		CanvasRenderingContext2D ctx,
		double x,
		double y,
	) {
		final String src = _element.block?.videoBlock?.src ?? '';
		if (_videoCache.containsKey(src)) {
			final VideoElement video = _videoCache[src]!;
			ctx.drawImageScaled(video, x, y, _element.metrics.width, _element.metrics.height);
			return Future<IRowElement>.value(_element);
		}
		final Completer<IRowElement> completer = Completer<IRowElement>();
		final VideoElement video = VideoElement()
			..src = src
			..muted = true
			..crossOrigin = 'anonymous';
		video.onLoadedData.first.then((_) {
			ctx.drawImageScaled(video, x, y, _element.metrics.width, _element.metrics.height);
			_videoCache[src] = video;
			if (!completer.isCompleted) {
				completer.complete(_element);
			}
		});
		video.onError.first.then((Event event) {
			if (!completer.isCompleted) {
				completer.completeError(event);
			}
		});
		video.play().then((_) => video.pause()).catchError((error) {
			if (!completer.isCompleted) {
				completer.completeError(error);
			}
		});
		return completer.future;
	}

	void render(DivElement blockItemContainer) {
		final VideoElement video = VideoElement()
			..style.width = '100%'
			..style.height = '100%'
			..style.objectFit = 'contain'
			..src = _element.block?.videoBlock?.src ?? ''
			..controls = true;
		blockItemContainer.append(video);
	}
}