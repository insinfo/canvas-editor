import 'dart:html';

typedef PageCanvasMetricResolver = double Function();

/// Owns the DOM canvases used by the editor pages and their 2D contexts.
///
/// Layout and painting remain outside this class. It only manages canvas count,
/// CSS/backing-store metrics, live/dormant state and the DPR transform.
class PageCanvasManager {
  PageCanvasManager({
    required HtmlElement pageContainer,
    required PageCanvasMetricResolver width,
    required PageCanvasMetricResolver height,
    required PageCanvasMetricResolver pageGap,
    PageCanvasMetricResolver? devicePixelRatio,
  })  : _pageContainer = pageContainer,
        _width = width,
        _height = height,
        _pageGap = pageGap,
        _devicePixelRatio = devicePixelRatio ?? _resolveWindowDevicePixelRatio;

  final HtmlElement _pageContainer;
  final PageCanvasMetricResolver _width;
  final PageCanvasMetricResolver _height;
  final PageCanvasMetricResolver _pageGap;
  final PageCanvasMetricResolver _devicePixelRatio;

  final List<CanvasElement> pageList = <CanvasElement>[];
  final List<CanvasRenderingContext2D> contextList =
      <CanvasRenderingContext2D>[];

  double? _pixelRatioOverride;

  static double _resolveWindowDevicePixelRatio() =>
      window.devicePixelRatio.toDouble();

  double get pagePixelRatio =>
      _pixelRatioOverride ?? _devicePixelRatio().toDouble();

  /// Updates the explicit DPR and reports whether it actually changed.
  bool setPagePixelRatio(double? value) {
    if (value == null) {
      if (_pixelRatioOverride == null) {
        return false;
      }
      _pixelRatioOverride = null;
      return true;
    }
    if (_pixelRatioOverride != null &&
        (_pixelRatioOverride! - value).abs() < 1e-6) {
      return false;
    }
    _pixelRatioOverride = value;
    return true;
  }

  CanvasElement createPage(int index) {
    final CanvasElement canvas = CanvasElement()
      // New pages start dormant. CSS keeps their document footprint while the
      // 1x1 backing store avoids allocating a full bitmap offscreen.
      ..width = 1
      ..height = 1
      ..style.width = '${_width()}px'
      ..style.height = '${_height()}px'
      ..style.marginBottom = '${_pageGap()}px'
      ..style.display = 'block'
      ..style.backgroundColor = '#ffffff'
      ..style.cursor = 'text'
      ..dataset['index'] = '$index';
    final CanvasRenderingContext2D context = canvas.context2D;

    _pageContainer.append(canvas);
    pageList.add(canvas);
    contextList.add(context);
    return canvas;
  }

  /// Synchronizes the DOM canvas count and returns a clamped current page.
  int syncPageCount(int desiredPageCount, int currentPageNo) {
    while (pageList.length < desiredPageCount) {
      createPage(pageList.length);
    }
    while (pageList.length > desiredPageCount) {
      final CanvasElement removedCanvas = pageList.removeLast();
      removedCanvas.remove();
      if (contextList.isNotEmpty) {
        contextList.removeLast();
      }
    }

    var nextPageNo = currentPageNo;
    if (nextPageNo >= desiredPageCount) {
      nextPageNo = desiredPageCount - 1;
    }
    if (nextPageNo < 0 && desiredPageCount > 0) {
      nextPageNo = 0;
    }
    applyPageMetrics();
    return nextPageNo;
  }

  void initializeContext(CanvasRenderingContext2D context) {
    final double dpr = pagePixelRatio;
    context
      ..setTransform(1, 0, 0, 1, 0, 0)
      ..scale(dpr, dpr);
  }

  /// Applies backing-store and CSS metrics without waking dormant pages.
  void applyPageMetrics({bool updateStyles = true}) {
    if (pageList.isEmpty) {
      return;
    }
    final double width = _width();
    final double height = _height();
    final double gap = _pageGap();
    final double ratio = pagePixelRatio;
    final int pixelWidth = (width * ratio).round();
    final int pixelHeight = (height * ratio).round();

    for (var i = 0; i < pageList.length; i++) {
      final CanvasElement page = pageList[i];
      final bool isDormant = (page.width ?? 0) <= 1 && (page.height ?? 0) <= 1;
      final bool metricsChanged =
          page.width != pixelWidth || page.height != pixelHeight;
      if (!isDormant && metricsChanged) {
        page
          ..width = pixelWidth
          ..height = pixelHeight;
        initializeContext(contextList[i]);
      }
      if (updateStyles) {
        page
          ..style.width = '${width}px'
          ..style.height = '${height}px'
          ..style.marginBottom = '${gap}px';
      }
    }
  }

  /// Wakes or releases a page backing store while preserving its CSS size.
  void setPageLive(int index, bool live) {
    if (index < 0 || index >= pageList.length) {
      return;
    }
    final CanvasElement canvas = pageList[index];
    if (live) {
      final double dpr = pagePixelRatio;
      final int fullWidth = (_width() * dpr).round();
      final int fullHeight = (_height() * dpr).round();
      if (canvas.width != fullWidth || canvas.height != fullHeight) {
        canvas
          ..width = fullWidth
          ..height = fullHeight;
        if (index < contextList.length) {
          initializeContext(contextList[index]);
        }
      }
    } else if (canvas.width != 1) {
      canvas
        ..width = 1
        ..height = 1;
    }
  }

  /// Applies a content-driven height to one page and resets its DPR context.
  void setPageHeight(
    int index,
    double height, {
    bool truncateBackingStore = false,
  }) {
    if (index < 0 || index >= pageList.length) {
      return;
    }
    final double pixelHeight = height * pagePixelRatio;
    pageList[index]
      ..style.height = '${height}px'
      ..height =
          truncateBackingStore ? pixelHeight.toInt() : pixelHeight.round();
    if (index < contextList.length) {
      initializeContext(contextList[index]);
    }
  }

  double getCanvasWidth(int pageNo, {required double fallback}) {
    if (pageList.isEmpty) {
      return fallback;
    }
    final CanvasElement page = pageList[_clampPageIndex(pageNo)];
    final double ratio = pagePixelRatio;
    final int rawWidth = page.width ?? 0;
    return ratio <= 0 ? rawWidth.toDouble() : rawWidth.toDouble() / ratio;
  }

  double getCanvasHeight(int pageNo, {required double fallback}) {
    if (pageList.isEmpty) {
      return fallback;
    }
    final CanvasElement page = pageList[_clampPageIndex(pageNo)];
    final double ratio = pagePixelRatio;
    final int rawHeight = page.height ?? 0;
    return ratio <= 0 ? rawHeight.toDouble() : rawHeight.toDouble() / ratio;
  }

  int _clampPageIndex(int pageNo) {
    if (pageNo < 0) {
      return 0;
    }
    if (pageNo >= pageList.length) {
      return pageList.length - 1;
    }
    return pageNo;
  }

  void dispose() {
    _pageContainer.children.clear();
    pageList.clear();
    contextList.clear();
  }
}
