import './listener.dart';

class EventBusMap {
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
  IMouseEventChange? mousemove;
  IMouseEventChange? mouseleave;
  IMouseEventChange? mouseenter;
  IMouseEventChange? mousedown;
  IMouseEventChange? mouseup;
  IMouseEventChange? click;
  IInputEventChange? input;
  IPositionContextChange? positionContextChange;
  IImageSizeChange? imageSizeChange;
  IImageMousedown? imageMousedown;

  EventBusMap({
    this.rangeStyleChange,
    this.visiblePageNoListChange,
    this.intersectionPageNoChange,
    this.pageSizeChange,
    this.pageScaleChange,
    this.saved,
    this.contentChange,
    this.controlChange,
    this.controlContentChange,
    this.pageModeChange,
    this.zoneChange,
    this.mousemove,
    this.mouseleave,
    this.mouseenter,
    this.mousedown,
    this.mouseup,
    this.click,
    this.input,
    this.positionContextChange,
    this.imageSizeChange,
    this.imageMousedown,
  });
}
