import '../../interface/listener.dart';

/// Lightweight registry that mirrors the original TypeScript Listener class.
///
/// Each field is an optional callback; external modules assign handlers to the
/// relevant properties when they need to react to editor events. Leaving them
/// nullable keeps the invocation sites simple—callers can check for `null`
/// before executing.
class Listener {
	Listener()
			: rangeStyleChange = null,
				visiblePageNoListChange = null,
				intersectionPageNoChange = null,
				pageSizeChange = null,
				pageScaleChange = null,
				saved = null,
				contentChange = null,
				controlChange = null,
				controlContentChange = null,
				pageModeChange = null,
				zoneChange = null;

	IRangeStyleChange? rangeStyleChange;
	IVisiblePageNoListChange? visiblePageNoListChange;
	IIntersectionPageNoChange? intersectionPageNoChange;
	IPageSizeChange? pageSizeChange;
	IPageScaleChange? pageScaleChange;
	ISaved? saved;
	IContentChange? contentChange;
	IControlChange? controlChange;
	IControlContentChange? controlContentChange;
	IPageModeChange? pageModeChange;
	IZoneChange? zoneChange;
}