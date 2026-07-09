import 'dart:async';
import 'dart:html';
import 'dart:math' as math;

import '../../../utils/index.dart';
import '../../interface/editor.dart';
import '../draw/draw.dart';

class IElementVisibleInfo {
	final double intersectionHeight;

	IElementVisibleInfo({required this.intersectionHeight});
}

class IPageVisibleInfo {
	final int intersectionPageNo;
	final List<int> visiblePageNoList;

	IPageVisibleInfo({
		required this.intersectionPageNo,
		required this.visiblePageNoList,
	});
}

class ScrollObserver {
	final Draw draw;
	late final IEditorOption _options;
	late final EventTarget _scrollContainer;
	late final Callback _observer;
	late final EventListener _scrollListener;

	ScrollObserver(this.draw) {
		_options = draw.getOptions();
		_scrollContainer = _resolveScrollContainer();
			_observer = debounce(_handleScroll, const Duration(milliseconds: 150));
		_scrollListener = (Event _) => _observer();
		Timer(Duration.zero, () {
				if (window.scrollY == 0) {
				_observer();
			}
		});
		_addEvent();
	}

	EventTarget getScrollContainer() => _scrollContainer;

	EventTarget _resolveScrollContainer() {
		final selector = _options.scrollContainerSelector;
		if (selector != null && selector.isNotEmpty) {
			final target = document.querySelector(selector);
			if (target != null) {
				return target;
			}
		}
		return document;
	}

	void _addEvent() {
				if (_scrollContainer is Document) {
					_scrollContainer.addEventListener('scroll', _scrollListener);
				} else if (_scrollContainer is Element) {
					_scrollContainer.addEventListener('scroll', _scrollListener);
		}
	}

	void removeEvent() {
				if (_scrollContainer is Document) {
					_scrollContainer.removeEventListener('scroll', _scrollListener);
				} else if (_scrollContainer is Element) {
					_scrollContainer.removeEventListener('scroll', _scrollListener);
		}
	}

	IElementVisibleInfo getElementVisibleInfo(Element element) {
		final rect = element.getBoundingClientRect();
		final bool isDocument = identical(_scrollContainer, document);
		final double viewHeight;
			if (isDocument) {
				final docElement = document.documentElement;
				final docClientHeight = (docElement?.clientHeight ?? 0).toDouble();
				final windowHeight = (window.innerHeight ?? 0).toDouble();
				viewHeight = math.max(docClientHeight, windowHeight);
		} else {
				final container = _scrollContainer as Element;
				viewHeight = container.clientHeight.toDouble();
		}
			final visibleHeight = math.min(rect.bottom.toDouble(), viewHeight) -
					math.max(rect.top.toDouble(), 0);
		return IElementVisibleInfo(
				intersectionHeight: visibleHeight > 0 ? visibleHeight : 0.0,
		);
	}

	IPageVisibleInfo getPageVisibleInfo() {
		final IPageVisibleInfo? fastInfo = _getPagingVisibleInfo();
		if (fastInfo != null) {
			return fastInfo;
		}
		final pageList = draw.getPageList();
		final visiblePageNoList = <int>[];
		var intersectionPageNo = 0;
		var intersectionMaxHeight = 0.0;
		for (var i = 0; i < pageList.length; i++) {
			final curPage = pageList[i];
			final info = getElementVisibleInfo(curPage);
			final intersectionHeight = info.intersectionHeight;
			if (intersectionMaxHeight > 0 && intersectionHeight == 0) {
				break;
			}
			if (intersectionHeight > 0) {
				visiblePageNoList.add(i);
			}
			if (intersectionHeight > intersectionMaxHeight) {
				intersectionMaxHeight = intersectionHeight;
				intersectionPageNo = i;
			}
		}
		return IPageVisibleInfo(
			intersectionPageNo: intersectionPageNo,
			visiblePageNoList: visiblePageNoList,
		);
	}

	IPageVisibleInfo? _getPagingVisibleInfo() {
		if (draw.getIsPagingMode() != true) {
			return null;
		}
		final int pageCount = draw.getPageCount();
		if (pageCount <= 0) {
			return IPageVisibleInfo(
				intersectionPageNo: 0,
				visiblePageNoList: const <int>[],
			);
		}
		final double pageHeight = (draw.getHeight() as num).toDouble();
		final double pageGap = (draw.getPageGap() as num).toDouble();
		final double pageStride = pageHeight + pageGap;
		if (pageHeight <= 0 || pageStride <= 0) {
			return null;
		}

		final Rectangle<num> pageContainerRect =
				draw.getPageContainer().getBoundingClientRect();
		final double viewportTop;
		final double viewportBottom;
		if (identical(_scrollContainer, document)) {
			final docElement = document.documentElement;
			final docClientHeight = (docElement?.clientHeight ?? 0).toDouble();
			final windowHeight = (window.innerHeight ?? 0).toDouble();
			viewportTop = -pageContainerRect.top.toDouble();
			viewportBottom = viewportTop + math.max(docClientHeight, windowHeight);
		} else if (_scrollContainer is Element) {
			final Rectangle<num> containerRect =
					_scrollContainer.getBoundingClientRect();
			viewportTop = containerRect.top.toDouble() -
					pageContainerRect.top.toDouble();
			viewportBottom = containerRect.bottom.toDouble() -
					pageContainerRect.top.toDouble();
		} else {
			return null;
		}

		if (viewportBottom <= 0 || viewportTop >= pageCount * pageStride) {
			return IPageVisibleInfo(
				intersectionPageNo: viewportTop < 0 ? 0 : pageCount - 1,
				visiblePageNoList: const <int>[],
			);
		}

		int first = (viewportTop / pageStride).floor();
		int last = (viewportBottom / pageStride).floor();
		first = first.clamp(0, pageCount - 1);
		last = last.clamp(0, pageCount - 1);
		final visiblePageNoList = <int>[];
		var intersectionPageNo = first;
		var intersectionMaxHeight = 0.0;
		for (var i = first; i <= last; i++) {
			final double pageTop = i * pageStride;
			final double pageBottom = pageTop + pageHeight;
			final double intersectionHeight =
					math.min(pageBottom, viewportBottom) -
							math.max(pageTop, viewportTop);
			if (intersectionHeight <= 0) {
				continue;
			}
			visiblePageNoList.add(i);
			if (intersectionHeight > intersectionMaxHeight) {
				intersectionMaxHeight = intersectionHeight;
				intersectionPageNo = i;
			}
		}
		return IPageVisibleInfo(
			intersectionPageNo: intersectionPageNo,
			visiblePageNoList: visiblePageNoList,
		);
	}

	void _handleScroll() {
		final info = getPageVisibleInfo();
		draw.setIntersectionPageNo(info.intersectionPageNo);
		draw.setVisiblePageNoList(info.visiblePageNoList);
	}
}
