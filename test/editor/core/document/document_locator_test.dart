import 'package:canvas_text_editor/src/editor/core/document/document_locator.dart';
import 'package:canvas_text_editor/src/editor/dataset/enum/element.dart';
import 'package:canvas_text_editor/src/editor/interface/element.dart';
import 'package:canvas_text_editor/src/editor/interface/table/td.dart';
import 'package:test/test.dart';

void main() {
  group('DocumentLocatorIndex', () {
    test('resolve tabela aninhada depois de substituir a raiz', () {
      final _NestedFixture before = _nestedFixture(
        outerPartId: 'outer-part-before',
        leafValue: 'before',
      );
      final List<IElement> headerEven = <IElement>[
        IElement(id: 'header-even-item', value: 'even'),
      ];
      final DocumentLocatorIndex index = DocumentLocatorIndex(
        <DocumentRegion, List<IElement>>{
          DocumentRegion.main: before.root,
          DocumentRegion.headerEven: headerEven,
        },
      );

      final DocumentListLocator? nested = index.captureList(
        before.innerCell.value,
        regionHint: DocumentRegion.main,
      );
      final DocumentListLocator? even = index.captureList(
        headerEven,
        regionHint: DocumentRegion.headerEven,
      );
      final DocumentElementLocator? leaf = index.captureElement(
        before.innerCell.value,
        0,
        regionHint: DocumentRegion.main,
      );

      expect(nested, isNotNull);
      expect(nested!.path, hasLength(2));
      expect(nested.path.first.pagingId, 'outer-paging');
      expect(nested.path.last.tableId, 'inner-table');
      expect(even?.region, DocumentRegion.headerEven);
      expect(index.rebuildCount, 1,
          reason: 'raiz de header resolve por identidade sem varredura');

      final _NestedFixture after = _nestedFixture(
        outerPartId: 'outer-part-after',
        leafValue: 'after',
      );
      final List<IElement> newHeaderEven = <IElement>[
        IElement(id: 'header-even-item', value: 'even-after'),
      ];
      index.rebindRoots(<DocumentRegion, List<IElement>>{
        DocumentRegion.main: after.root,
        DocumentRegion.headerEven: newHeaderEven,
      });

      final List<IElement>? resolvedNested = index.resolveList(nested);
      final List<IElement>? resolvedEven = index.resolveList(even!);
      final ResolvedDocumentElement? resolvedLeaf = index.resolveElement(leaf!);

      expect(identical(resolvedNested, after.innerCell.value), isTrue);
      expect(resolvedNested?.single.value, 'after');
      expect(identical(resolvedEven, newHeaderEven), isTrue);
      expect(resolvedLeaf?.element.value, 'after');
      expect(index.rebuildCount, 2,
          reason: 'somente a regiao aninhada requer reconstrucao');
    });

    test('variantes default/first/even permanecem enderecos distintos', () {
      final Map<DocumentRegion, List<IElement>> roots =
          <DocumentRegion, List<IElement>>{
        for (final DocumentRegion region in DocumentRegion.values)
          region: <IElement>[IElement(value: region.name)],
      };
      final DocumentLocatorIndex index = DocumentLocatorIndex(roots);

      for (final DocumentRegion region in DocumentRegion.values) {
        final DocumentListLocator? locator =
            index.captureList(roots[region]!, regionHint: region);
        expect(locator?.region, region);
        expect(identical(index.resolveList(locator!), roots[region]), isTrue);
      }
      expect(index.rebuildCount, 0,
          reason: 'captura/resolucao de raiz e O(1) por identidade');
    });

    test('elemento com id continua resolvendo depois de mudar de offset', () {
      final List<IElement> before = <IElement>[
        IElement(value: 'a'),
        IElement(id: 'stable', value: 'target'),
      ];
      final DocumentLocatorIndex index = DocumentLocatorIndex(
        <DocumentRegion, List<IElement>>{DocumentRegion.main: before},
      );
      final DocumentElementLocator locator = index.captureElement(
        before,
        1,
        regionHint: DocumentRegion.main,
      )!;

      final List<IElement> after = <IElement>[
        IElement(value: 'inserted'),
        IElement(value: 'a'),
        IElement(id: 'stable', value: 'target-after'),
      ];
      index.rebindRoots(
        <DocumentRegion, List<IElement>>{DocumentRegion.main: after},
      );

      final ResolvedDocumentElement? resolved = index.resolveElement(locator);
      expect(resolved?.index, 2);
      expect(resolved?.element.value, 'target-after');
    });

    test('id exato distingue parts com header repetido; fallback ambiguo falha',
        () {
      final ITd firstCell = _singleCell('repeated');
      final ITd secondCell = _singleCell('repeated');
      final List<IElement> before = <IElement>[
        _tablePart('part-1', firstCell),
        _tablePart('part-2', secondCell),
      ];
      final DocumentLocatorIndex index = DocumentLocatorIndex(
        <DocumentRegion, List<IElement>>{DocumentRegion.main: before},
      );
      final DocumentListLocator locator = index.captureList(
        secondCell.value,
        regionHint: DocumentRegion.main,
      )!;

      final ITd clonedFirst = _singleCell('first-after');
      final ITd clonedSecond = _singleCell('second-after');
      index.rebindRoots(<DocumentRegion, List<IElement>>{
        DocumentRegion.main: <IElement>[
          _tablePart('part-1', clonedFirst),
          _tablePart('part-2', clonedSecond),
        ],
      });
      expect(identical(index.resolveList(locator), clonedSecond.value), isTrue,
          reason: 'snapshot preserva o id exato da part');

      final ITd changedFirst = _singleCell('first-changed');
      final ITd changedSecond = _singleCell('second-changed');
      index.rebindRoots(<DocumentRegion, List<IElement>>{
        DocumentRegion.main: <IElement>[
          _tablePart('new-part-1', changedFirst),
          _tablePart('new-part-2', changedSecond),
        ],
      });
      expect(index.resolveList(locator), isNull,
          reason: 'pagingId+rowId+cellId repetidos sao ambiguos');
    });

    test('replace in-place exige e respeita invalidacao explicita da regiao',
        () {
      final _NestedFixture before =
          _nestedFixture(outerPartId: 'part', leafValue: 'before');
      final List<IElement> canonicalRoot = before.root;
      final DocumentLocatorIndex index = DocumentLocatorIndex(
        <DocumentRegion, List<IElement>>{DocumentRegion.main: canonicalRoot},
      );
      final DocumentListLocator locator = index.captureList(
        before.innerCell.value,
        regionHint: DocumentRegion.main,
      )!;
      final _NestedFixture after =
          _nestedFixture(outerPartId: 'part', leafValue: 'after');
      canonicalRoot
        ..clear()
        ..addAll(after.root);
      index.rebindRoots(
        <DocumentRegion, List<IElement>>{DocumentRegion.main: canonicalRoot},
      );

      expect(
          identical(index.resolveList(locator), before.innerCell.value), isTrue,
          reason: 'identidade da raiz sozinha nao detecta clear/addAll');
      index.invalidateRegion(DocumentRegion.main);
      expect(
          identical(index.resolveList(locator), after.innerCell.value), isTrue);
    });
  });
}

ITd _singleCell(String value) => ITd(
      id: 'repeated-cell',
      colspan: 1,
      rowspan: 1,
      value: <IElement>[IElement(value: value)],
    );

IElement _tablePart(String id, ITd cell) => IElement(
      id: id,
      pagingId: 'same-paging',
      type: ElementType.table,
      value: '',
      trList: <ITr>[
        ITr(id: 'repeated-row', height: 20, tdList: <ITd>[cell]),
      ],
    );

class _NestedFixture {
  const _NestedFixture({
    required this.root,
    required this.innerCell,
  });

  final List<IElement> root;
  final ITd innerCell;
}

_NestedFixture _nestedFixture({
  required String outerPartId,
  required String leafValue,
}) {
  final ITd innerCell = ITd(
    id: 'inner-cell',
    colspan: 1,
    rowspan: 1,
    value: <IElement>[
      IElement(id: 'leaf', value: leafValue),
    ],
  );
  final IElement innerTable = IElement(
    id: 'inner-table',
    type: ElementType.table,
    value: '',
    trList: <ITr>[
      ITr(
        id: 'inner-row',
        height: 20,
        tdList: <ITd>[innerCell],
      ),
    ],
  );
  final ITd outerCell = ITd(
    id: 'outer-cell',
    colspan: 1,
    rowspan: 1,
    value: <IElement>[innerTable],
  );
  final IElement outerTable = IElement(
    id: outerPartId,
    pagingId: 'outer-paging',
    type: ElementType.table,
    value: '',
    trList: <ITr>[
      ITr(
        id: 'outer-row',
        height: 20,
        tdList: <ITd>[outerCell],
      ),
    ],
  );
  return _NestedFixture(root: <IElement>[outerTable], innerCell: innerCell);
}
