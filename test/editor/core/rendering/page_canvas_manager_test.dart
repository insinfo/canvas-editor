@TestOn('browser')
library;

import 'dart:html';
import 'dart:js_util' as js_util;

import 'package:canvas_text_editor/src/editor/core/rendering/page_canvas_manager.dart';
import 'package:test/test.dart';

void main() {
  group('PageCanvasManager', () {
    late DivElement host;
    late PageCanvasManager manager;
    var width = 120.0;
    var height = 80.0;
    var gap = 12.0;

    setUp(() {
      host = DivElement();
      document.body!.append(host);
      manager = PageCanvasManager(
        pageContainer: host,
        width: () => width,
        height: () => height,
        pageGap: () => gap,
        devicePixelRatio: () => 1,
      );
    });

    tearDown(() {
      manager.dispose();
      host.remove();
    });

    test('sincroniza canvas, contexto, DOM e pagina atual', () {
      var currentPage = manager.syncPageCount(3, 0);

      expect(currentPage, 0);
      expect(manager.pageList, hasLength(3));
      expect(manager.contextList, hasLength(3));
      expect(host.children, hasLength(3));
      expect(
        manager.pageList.map((CanvasElement page) => page.dataset['index']),
        <String?>['0', '1', '2'],
      );

      final CanvasElement retainedFirstPage = manager.pageList.first;
      currentPage = manager.syncPageCount(1, 2);

      expect(currentPage, 0);
      expect(manager.pageList, hasLength(1));
      expect(manager.contextList, hasLength(1));
      expect(host.children, hasLength(1));
      expect(manager.pageList.single, same(retainedFirstPage));
    });

    test('paginas novas nascem dormentes com footprint CSS completo', () {
      manager.syncPageCount(2, 0);

      for (final CanvasElement page in manager.pageList) {
        expect(page.width, 1);
        expect(page.height, 1);
        expect(page.style.width, '120px');
        expect(page.style.height, '80px');
        expect(page.style.marginBottom, '12px');
        expect(page.style.display, 'block');
      }
    });

    test('pagina viva usa backing store e transformacao DPR', () {
      manager
        ..syncPageCount(1, 0)
        ..setPagePixelRatio(2)
        ..setPageLive(0, true);

      final CanvasElement page = manager.pageList.single;
      expect(page.width, 240);
      expect(page.height, 160);
      expect(page.style.width, '120px');
      expect(page.style.height, '80px');

      final Object transform = js_util.callMethod<Object>(
        manager.contextList.single,
        'getTransform',
        const <Object>[],
      );
      expect(js_util.getProperty<num>(transform, 'a'), 2);
      expect(js_util.getProperty<num>(transform, 'd'), 2);
    });

    test('dormancy libera bitmap sem alterar CSS', () {
      manager
        ..syncPageCount(1, 0)
        ..setPagePixelRatio(2)
        ..setPageLive(0, true);
      final CanvasElement page = manager.pageList.single;
      final String cssWidth = page.style.width;
      final String cssHeight = page.style.height;
      final String cssGap = page.style.marginBottom;

      manager.setPageLive(0, false);

      expect(page.width, 1);
      expect(page.height, 1);
      expect(page.style.width, cssWidth);
      expect(page.style.height, cssHeight);
      expect(page.style.marginBottom, cssGap);

      width = 140;
      height = 90;
      gap = 16;
      manager.applyPageMetrics();

      expect(page.width, 1);
      expect(page.height, 1);
      expect(page.style.width, '140px');
      expect(page.style.height, '90px');
      expect(page.style.marginBottom, '16px');
    });
  });
}
