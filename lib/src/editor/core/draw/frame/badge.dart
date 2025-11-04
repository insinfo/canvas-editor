import 'dart:html';

import '../../../interface/badge.dart';
import '../../../interface/editor.dart';
import '../draw.dart';

class Badge {
	Badge(this._draw)
			: _options = _draw.getOptions(),
				_imageCache = <String, ImageElement>{},
				_areaBadgeMap = <String, IBadge>{};

	final Draw _draw;
	final IEditorOption _options;
	final Map<String, ImageElement> _imageCache;
	final Map<String, IBadge> _areaBadgeMap;

	IBadge? _mainBadge;

	dynamic _getHeader() {
		try {
			return (_draw as dynamic).getHeader();
		} catch (_) {
			return null;
		}
	}

	dynamic _getArea() {
		try {
			return (_draw as dynamic).getArea();
		} catch (_) {
			return null;
		}
	}

	void setMainBadge(IBadge? payload) {
		_mainBadge = payload;
	}

	void setAreaBadgeMap(List<IAreaBadge> payload) {
		_areaBadgeMap
			..clear()
			..addEntries(payload.map(
				(IAreaBadge areaBadge) => MapEntry<String, IBadge>(
					areaBadge.areaId,
					areaBadge.badge,
				),
			));
	}

	void _drawImage(
		CanvasRenderingContext2D ctx,
		double x,
		double y,
		double width,
		double height,
		String value,
	) {
		final ImageElement? cached = _imageCache[value];
		if (cached != null) {
			if (cached.complete == true) {
				ctx.drawImageScaled(cached, x, y, width, height);
			}
			return;
		}

		final ImageElement img = ImageElement()
			..crossOrigin = 'Anonymous'
			..src = value;
		img.onLoad.first.then((_) {
			_imageCache[value] = img;
			ctx.drawImageScaled(img, x, y, width, height);
		});
	}

	double _resolveHeaderExtraHeight() {
		final dynamic header = _getHeader();
		if (header == null) {
			return 0;
		}
		try {
			final dynamic extraHeight = header.getExtraHeight();
			if (extraHeight is num) {
				return extraHeight.toDouble();
			}
		} catch (_) {
			return 0;
		}
		return 0;
	}

	double _resolvePositionTop(dynamic position) {
		try {
			final dynamic coordinate = position.coordinate;
			final dynamic leftTop = coordinate.leftTop;
			if (leftTop is List && leftTop.length > 1) {
				final dynamic y = leftTop[1];
				if (y is num) {
					return y.toDouble();
				}
			}
		} catch (_) {
			return 0;
		}
		return 0;
	}

	void render(CanvasRenderingContext2D ctx, int pageNo) {
		final double scale = (_options.scale ?? 1).toDouble();
		final IBadgeOption badgeOption = _options.badge ?? IBadgeOption();

		if (pageNo == 0 && _mainBadge != null) {
			final IBadge badge = _mainBadge!;
			final List<double> margins = _draw.getMargins();
			final double headerTop = margins[0] + _resolveHeaderExtraHeight();
			final double left = (badge.left ?? badgeOption.left ?? 0) * scale;
			final double top =
					(badge.top ?? badgeOption.top ?? 0) * scale + headerTop;
			_drawImage(
				ctx,
				left,
				top,
				badge.width * scale,
				badge.height * scale,
				badge.value,
			);
		}

		if (_areaBadgeMap.isEmpty) {
			return;
		}
		final dynamic areaManager = _getArea();
		final Map<dynamic, dynamic>? rawAreaInfo =
				areaManager?.getAreaInfo?.call() as Map<dynamic, dynamic>?;
		if (rawAreaInfo == null || rawAreaInfo.isEmpty) {
			return;
		}

		for (final MapEntry<dynamic, dynamic> entry in rawAreaInfo.entries) {
			final String? areaId = entry.key as String?;
			if (areaId == null) {
				continue;
			}
			final IBadge? badgeItem = _areaBadgeMap[areaId];
			if (badgeItem == null) {
				continue;
			}
			final dynamic info = entry.value;
			final List<dynamic>? positionList = info?.positionList as List<dynamic>?;
			if (positionList == null || positionList.isEmpty) {
				continue;
			}
			final dynamic firstPosition = positionList.first;
			final int? positionPageNo = firstPosition?.pageNo as int?;
			if (positionPageNo != pageNo) {
				continue;
			}
			final double baseTop = _resolvePositionTop(firstPosition);
			final double left =
					(badgeItem.left ?? badgeOption.left ?? 0) * scale;
			final double top =
					(badgeItem.top ?? badgeOption.top ?? 0) * scale + baseTop;
			_drawImage(
				ctx,
				left,
				top,
				badgeItem.width * scale,
				badgeItem.height * scale,
				badgeItem.value,
			);
		}
	}
}
