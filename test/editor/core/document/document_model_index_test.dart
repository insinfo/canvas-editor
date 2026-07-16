import 'dart:math';

import 'package:canvas_text_editor/src/editor/core/document/document_model.dart';
import 'package:canvas_text_editor/src/editor/core/document/document_range.dart';
import 'package:canvas_text_editor/src/editor/dataset/constant/common.dart';
import 'package:canvas_text_editor/src/editor/interface/element.dart';
import 'package:test/test.dart';

void main() {
  IElement element(
    String value, {
    String? id,
    String? tableId,
    String? pagingId,
  }) =>
      IElement(
        value: value,
        id: id,
        tableId: tableId,
        pagingId: pagingId,
      );

  List<IElement> cloneElements(Iterable<IElement> source) => source
      .map(
        (IElement item) => element(
          item.value,
          id: item.id,
          tableId: item.tableId,
          pagingId: item.pagingId,
        ),
      )
      .toList();

  group('DocumentModel', () {
    test('owns canonical region references and monotonic revision', () {
      final List<IElement> main = <IElement>[element(ZERO), element('a')];
      final List<IElement> header = <IElement>[element('h')];
      final List<IElement> footer = <IElement>[element('f')];
      final DocumentModel model = DocumentModel(
        main: main,
        header: header,
        footer: footer,
        cloneElements: cloneElements,
      );

      expect(identical(model.main, main), isTrue);
      expect(identical(model.header, header), isTrue);
      expect(identical(model.footer, footer), isTrue);
      expect(model.revision, 0);

      model.onStyleChange();
      expect(model.revision, 1);

      final IElement inserted = element('b');
      final List<IElement> removed = model.onSplice(
        start: 1,
        deleteCount: 1,
        inserted: <IElement>[inserted],
      );
      expect(model.revision, 2);
      expect(removed.single.value, 'a');
      expect(main.map((IElement item) => item.value), <String>[ZERO, 'b']);
      expect(identical(main[1], inserted), isFalse);

      model.replace(
        main: <IElement>[element('new')],
        header: <IElement>[element('new header')],
      );
      expect(model.revision, 3);
      expect(identical(model.main, main), isTrue);
      expect(main.single.value, 'new');
      expect(header.single.value, 'new header');
      expect(footer.single.value, 'f');
    });

    test('maintains separate indexes for main, header, and footer', () {
      final DocumentModel model = DocumentModel(
        main: <IElement>[element('m', id: 'main')],
        header: <IElement>[element('h', id: 'header')],
        footer: <IElement>[element('f', id: 'footer')],
      );

      expect(model.index.lookupById('main'), 0);
      expect(model.headerIndex.lookupById('header'), 0);
      expect(model.footerIndex.lookupById('footer'), 0);
      expect(model.index.lookupById('header'), isNull);
    });

    test('invalidates every region once when a nested owner is unknown', () {
      final List<IElement> main = <IElement>[element('m', id: 'main')];
      final List<IElement> header = <IElement>[element('h', id: 'header')];
      final List<IElement> footer = <IElement>[element('f', id: 'footer')];
      final DocumentModel model = DocumentModel(
        main: main,
        header: header,
        footer: footer,
      );

      expect(model.mainIndex.lookupById('main'), 0);
      expect(model.headerIndex.lookupById('header'), 0);
      expect(model.footerIndex.lookupById('footer'), 0);

      main.single.id = 'main-next';
      header.single.id = 'header-next';
      footer.single.id = 'footer-next';
      model.didComplexStructureChangeAll();

      expect(model.revision, 1);
      expect(model.mainIndex.lookupById('main-next'), 0);
      expect(model.headerIndex.lookupById('header-next'), 0);
      expect(model.footerIndex.lookupById('footer-next'), 0);
    });
  });

  group('DocumentIndex', () {
    test('builds structural maps lazily and invalidates them in O(1)', () {
      final DocumentModel model = DocumentModel(
        main: <IElement>[
          element(ZERO, id: 'p0'),
          element('a', tableId: 'table-a', pagingId: 'page-a'),
          element('b', tableId: 'table-a', pagingId: 'page-a'),
          element('c', id: 'tail', pagingId: 'page-b'),
        ],
      );

      expect(model.index.structuralRebuildCount, 0);
      expect(model.index.lookupById('tail'), 3);
      expect(model.index.lookupByTableId('table-a'), <int>[1, 2]);
      expect(model.index.lookupByPagingId('page-a'), <int>[1, 2]);
      expect(model.index.structuralRebuildCount, 1);

      model.onStyleChange();
      expect(model.index.lookupById('tail'), 3);
      expect(model.index.structuralRebuildCount, 1);

      model.onSplice(
        start: 1,
        deleteCount: 0,
        inserted: <IElement>[
          element('x', id: 'inserted', tableId: 'table-b'),
        ],
      );
      expect(model.index.structuralRebuildCount, 1);
      expect(model.index.lookupById('inserted'), 1);
      expect(model.index.lookupById('tail'), 4);
      expect(model.index.lookupByTableId('table-a'), <int>[2, 3]);
      expect(model.index.structuralRebuildCount, 2);
    });

    test('updates paragraph boundaries across insertions and deletions', () {
      final DocumentModel model = DocumentModel(
        main: <IElement>[
          element(ZERO),
          element('a'),
          element('b'),
          element(ZERO),
          element('c'),
          element(ZERO),
        ],
      );

      expect(model.index.paragraphRangeAt(2), const DocumentRange(0, 2));
      expect(model.index.paragraphRangeAt(3), const DocumentRange(3, 4));
      expect(model.index.paragraphRangeAt(5), const DocumentRange(5, 5));

      model.onSplice(
        start: 2,
        deleteCount: 0,
        inserted: <IElement>[element(ZERO), element('new')],
      );
      expect(model.index.paragraphRangeAt(1), const DocumentRange(0, 1));
      expect(model.index.paragraphRangeAt(2), const DocumentRange(2, 4));
      expect(model.index.paragraphRangeAt(6), const DocumentRange(5, 6));

      model.onSplice(start: 2, deleteCount: 1);
      expect(model.index.paragraphRangeAt(2), const DocumentRange(0, 3));
      expect(model.index.paragraphRangeAt(5), const DocumentRange(4, 5));
    });

    test('incremental paragraph tree matches a naive scan after many splices',
        () {
      final Random random = Random(731);
      final DocumentModel model = DocumentModel(
        main: <IElement>[element(ZERO), element('a'), element('b')],
      );
      // Force the paragraph tree to be built before incremental mutations.
      expect(model.index.paragraphRangeAt(1), const DocumentRange(0, 2));

      for (int operation = 0; operation < 200; operation++) {
        final int start = random.nextInt(model.main.length + 1);
        final int maxDelete = min(3, model.main.length - start);
        final int deleteCount = random.nextInt(maxDelete + 1);
        final int insertCount = random.nextInt(4);
        final List<IElement> inserted = List<IElement>.generate(
          insertCount,
          (int index) => element(random.nextInt(4) == 0 ? ZERO : 'x'),
        );

        model.onSplice(
          start: start,
          deleteCount: deleteCount,
          inserted: inserted,
        );

        for (int index = 0; index < model.main.length; index++) {
          expect(
            model.index.paragraphRangeAt(index),
            _naiveParagraphRange(model.main, index),
            reason: 'operation $operation, index $index; '
                'splice=($start, $deleteCount, '
                '${inserted.map((IElement item) => item.value).toList()}); '
                'values=${model.main.map((IElement item) => item.value).toList()}',
          );
        }
      }
    });
  });
}

DocumentRange _naiveParagraphRange(List<IElement> elements, int index) {
  int start = index;
  while (start > 0 && elements[start].value != ZERO) {
    start--;
  }
  int end = start + 1;
  while (end < elements.length && elements[end].value != ZERO) {
    end++;
  }
  return DocumentRange(start, end - 1);
}
