@TestOn('browser')
library;

import 'package:canvas_text_editor/src/editor/core/position/position.dart';
import 'package:canvas_text_editor/src/editor/dataset/enum/common.dart';
import 'package:canvas_text_editor/src/editor/dataset/enum/editor.dart';
import 'package:canvas_text_editor/src/editor/dataset/enum/element.dart';
import 'package:canvas_text_editor/src/editor/interface/editor.dart';
import 'package:canvas_text_editor/src/editor/interface/element.dart';
import 'package:canvas_text_editor/src/editor/interface/position.dart';
import 'package:canvas_text_editor/src/editor/interface/row.dart';
import 'package:test/test.dart';

class _FakeZone {
  bool isMainActive() => true;
  bool isHeaderActive() => false;
  bool isFooterActive() => false;
  EditorZone getZone() => EditorZone.main;
}

class _FakeDraw {
  _FakeDraw(this.pageNo);

  final int pageNo;
  final _FakeZone zone = _FakeZone();

  Object getEventBus() => Object();
  IEditorOption getOptions() => IEditorOption(scale: 1);
  _FakeZone getZone() => zone;
  int getPageNo() => pageNo;
  List<double> getMargins() => <double>[0, 0, 0, 0];
  List<IElement> getOriginalElementList() => <IElement>[];
}

class _FakeHeader {
  double getExtraHeight() => 0;
}

class _LayoutFakeDraw extends _FakeDraw {
  _LayoutFakeDraw(this.pages) : super(0);

  final List<List<IRow>> pages;
  final _FakeHeader header = _FakeHeader();

  double getInnerWidth() => 500;
  List<List<IRow>> getPageRowList() => pages;
  _FakeHeader getHeader() => header;
}

IElementPosition _position(int pageNo, int index) {
  return IElementPosition(
    pageNo: pageNo,
    index: index,
    value: 'x',
    rowIndex: index,
    rowNo: 0,
    ascent: 0,
    lineHeight: 10,
    left: 0,
    metrics: IElementMetrics(
      width: 10,
      height: 10,
      boundingBoxAscent: 8,
      boundingBoxDescent: 2,
    ),
    isFirstLetter: index == 0,
    isLastLetter: true,
    coordX: (index % 2) * 10,
    coordY: 0,
  );
}

void main() {
  test('hit-test canonico inspeciona somente a pagina solicitada', () {
    final List<IElementPosition> positions = <IElementPosition>[
      for (var i = 0; i < 100; i++) _position(0, i),
      for (var i = 100; i < 200; i++) _position(1, i),
      _position(2, 200),
      _position(2, 201),
    ];
    final List<IElement> elements = <IElement>[
      for (var i = 0; i < positions.length; i++) IElement(value: 'x'),
    ];
    final Position position = Position(_FakeDraw(2))
      ..setPositionList(positions);

    final ICurrentPosition indexedResult = position.getPositionByXY(
      IGetPositionByXYPayload(
        x: 5,
        y: 5,
        pageNo: 2,
        elementList: elements,
      ),
    );

    expect(indexedResult.index, 200);
    expect(position.lastHitTestUsedPageIndex, isTrue);
    expect(position.lastHitTestCandidateCount, 2);
    expect(position.lastHitTestInspectedPositionCount, 1);

    final ICurrentPosition fallbackResult = position.getPositionByXY(
      IGetPositionByXYPayload(
        x: 5,
        y: 5,
        pageNo: 2,
        elementList: elements,
        positionList: List<IElementPosition>.from(positions),
      ),
    );

    expect(fallbackResult.index, indexedResult.index);
    expect(position.lastHitTestUsedPageIndex, isFalse);
    expect(position.lastHitTestCandidateCount, positions.length);
    // O fallback ainda filtra pageNo antes de materializar `coordinate`.
    expect(position.lastHitTestInspectedPositionCount, 1);
  });

  test('hit-test de float usa somente os floats da pagina solicitada', () {
    final Position position = Position(_FakeDraw(2));
    final List<IFloatPosition> floats = <IFloatPosition>[
      for (var i = 0; i < 50; i++) _floatPosition(0, i),
      _floatPosition(2, 200),
    ];
    position.setFloatPositionList(floats);

    final ICurrentPosition? indexedResult = position.getFloatPositionByXY(
      IGetFloatPositionByXYPayload(
        imgDisplays: <ImageDisplay>[ImageDisplay.floatTop],
        x: 5,
        y: 5,
        pageNo: 2,
      ),
    );

    expect(indexedResult?.index, 200);
    expect(position.lastFloatHitTestUsedPageIndex, isTrue);
    expect(position.lastFloatHitTestCandidateCount, 1);

    // Uma mutacao externa detectavel invalida o indice e preserva o resultado
    // pelo caminho linear defensivo.
    floats.add(_floatPosition(2, 201));
    final ICurrentPosition? fallbackResult = position.getFloatPositionByXY(
      IGetFloatPositionByXYPayload(
        imgDisplays: <ImageDisplay>[ImageDisplay.floatTop],
        x: 5,
        y: 5,
        pageNo: 2,
      ),
    );

    expect(fallbackResult?.index, indexedResult?.index);
    expect(position.lastFloatHitTestUsedPageIndex, isFalse);
    expect(position.lastFloatHitTestCandidateCount, floats.length);
  });

  test('agregacao local preserva lista canonica e rebasa paginas em O(paginas)',
      () {
    const int pageCount = 5;
    const int rowsPerPage = 3;
    const int elementsPerRow = 2;
    final List<List<IRow>> pages = <List<IRow>>[];
    int startIndex = 0;
    int rowIndex = 0;
    for (int page = 0; page < pageCount; page++) {
      final List<IRow> rows = <IRow>[];
      for (int row = 0; row < rowsPerPage; row++) {
        rows.add(_row(startIndex, rowIndex, elementsPerRow));
        startIndex += elementsPerRow;
        rowIndex += 1;
      }
      pages.add(rows);
    }
    final Position position = Position(_LayoutFakeDraw(pages));

    position.computePositionList();
    final List<IElementPosition> canonical = position.positionList;
    final int initialPositionCount = canonical.length;
    expect(canonical, hasLength(pageCount * rowsPerPage * elementsPerRow));
    expect(position.lastRecomputedPageCount, pageCount);

    // O fast paragraph path troca somente as rows do paragrafo e desloca os
    // startIndex das rows posteriores. As paginas posteriores conservam os
    // mesmos objetos de row e, portanto, a mesma geometria.
    pages[0][0] = _row(0, 0, elementsPerRow + 1);
    for (int page = 0; page < pages.length; page++) {
      for (int row = 0; row < pages[page].length; row++) {
        if (page == 0 && row == 0) continue;
        pages[page][row].startIndex += 1;
      }
    }

    position.computePositionList();

    expect(identical(position.positionList, canonical), isTrue);
    expect(position.lastRecomputedPageCount, 1);
    expect(position.lastRebasedPageCount, pageCount - 1);
    expect(position.lastFlattenedPositionCount,
        elementsPerRow + 1 + (rowsPerPage - 1) * elementsPerRow);
    expect(position.positionList, hasLength(initialPositionCount + 1));
    for (int index = 0; index < position.positionList.length; index++) {
      expect(position.positionList[index].index, index,
          reason: 'indice lazy da posicao $index');
    }

    position.computePositionList();
    expect(position.lastRecomputedPageCount, 0);
    expect(position.lastRebasedPageCount, 0);
    expect(position.lastFlattenedPositionCount, 0);

    // Convergencia de paginacao: uma nova pagina antes do sufixo desloca o
    // pageNo, mas as paginas antigas continuam reutilizaveis pela identidade
    // da primeira row (nao pela posicao ordinal antiga).
    for (final List<IRow> page in pages) {
      for (final IRow row in page) {
        row
          ..startIndex += 1
          ..rowIndex += 1;
      }
    }
    pages.insert(0, <IRow>[_row(0, 0, 1)]);
    position.computePositionList();

    expect(position.lastRecomputedPageCount, 1);
    expect(position.lastRebasedPageCount, pageCount);
    expect(position.lastFlattenedPositionCount, 1);
    expect(position.positionList.first.pageNo, 0);
    expect(position.positionList[1].pageNo, 1);
    expect(position.positionList.last.pageNo, pageCount);
    for (int index = 0; index < position.positionList.length; index++) {
      expect(position.positionList[index].index, index);
    }
  });
}

IRow _row(int startIndex, int rowIndex, int elementCount) {
  return IRow(
    width: elementCount * 10,
    height: 10,
    ascent: 8,
    startIndex: startIndex,
    rowIndex: rowIndex,
    elementList: <IRowElement>[
      for (int index = 0; index < elementCount; index++)
        IRowElement(
          metrics: IElementMetrics(
            width: 10,
            height: 10,
            boundingBoxAscent: 8,
            boundingBoxDescent: 2,
          ),
          style: '10px Arial',
          value: 'x',
        ),
    ],
  );
}

IFloatPosition _floatPosition(int pageNo, int index) {
  final IElement element = IElement(
    value: '',
    type: ElementType.image,
    imgDisplay: ImageDisplay.floatTop,
    imgFloatPosition: <String, num>{'x': 0, 'y': 0},
    width: 10,
    height: 10,
  );
  return IFloatPosition(
    pageNo: pageNo,
    element: element,
    position: _position(pageNo, index),
  );
}
