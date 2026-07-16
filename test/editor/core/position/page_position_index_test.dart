import 'package:canvas_text_editor/src/editor/core/position/page_position_index.dart';
import 'package:canvas_text_editor/src/editor/interface/element.dart';
import 'package:test/test.dart';

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
  );
}

void main() {
  test('ancora filha herda somente deslocamento de pagina da tabela externa',
      () {
    final IElementPositionAnchor page = IElementPositionAnchor();
    final IElementPositionAnchor cell = IElementPositionAnchor(
      pageParent: page,
    );
    final IElementPosition position = IElementPosition(
      pageNo: 2,
      index: 3,
      value: 'x',
      rowIndex: 1,
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
      isFirstLetter: true,
      isLastLetter: true,
      anchor: cell,
    );

    page.shift(pageDelta: 4, indexDelta: 100, rowIndexDelta: 20);
    expect(position.pageNo, 6);
    expect(position.index, 3,
        reason: 'indice dentro da celula permanece local');
    expect(position.rowIndex, 1);
  });

  group('PagePositionIndex', () {
    test('indexa faixas contiguas sem copiar a lista canonica', () {
      final List<IElementPosition> positions = <IElementPosition>[
        _position(0, 0),
        _position(0, 1),
        _position(2, 2),
        _position(7, 3),
        _position(7, 4),
      ];
      final PagePositionIndex index = PagePositionIndex()..rebuild(positions);

      expect(index.isValid, isTrue);
      expect(index.pageCount, 3);
      expect(
        index.sliceFor(positions, 0),
        isA<PagePositionSlice>()
            .having((PagePositionSlice value) => value.startOffset, 'start', 0)
            .having((PagePositionSlice value) => value.endOffset, 'end', 2),
      );
      expect(
        index.sliceFor(positions, 2),
        isA<PagePositionSlice>()
            .having((PagePositionSlice value) => value.startOffset, 'start', 2)
            .having((PagePositionSlice value) => value.endOffset, 'end', 3),
      );
      expect(
        index.sliceFor(positions, 7),
        isA<PagePositionSlice>()
            .having((PagePositionSlice value) => value.startOffset, 'start', 3)
            .having((PagePositionSlice value) => value.endOffset, 'end', 5),
      );
      expect(index.sliceFor(positions, 1), isNull);
    });

    test('recusa lista diferente ou alterada depois do rebuild', () {
      final List<IElementPosition> positions = <IElementPosition>[
        _position(0, 0),
        _position(1, 1),
      ];
      final PagePositionIndex index = PagePositionIndex()..rebuild(positions);

      expect(index.sliceFor(List<IElementPosition>.from(positions), 1), isNull);

      positions.add(_position(1, 2));
      expect(index.sliceFor(positions, 1), isNull);

      index.rebuild(positions);
      expect(index.sliceFor(positions, 1)?.length, 2);
    });

    test('invalida paginas fora de ordem para habilitar o fallback', () {
      final List<IElementPosition> positions = <IElementPosition>[
        _position(0, 0),
        _position(2, 1),
        _position(1, 2),
      ];
      final PagePositionIndex index = PagePositionIndex()..rebuild(positions);

      expect(index.isValid, isFalse);
      expect(index.pageCount, 0);
      expect(index.sliceFor(positions, 0), isNull);
    });

    test('aceita lista vazia e pode ser limpo explicitamente', () {
      final List<IElementPosition> positions = <IElementPosition>[];
      final PagePositionIndex index = PagePositionIndex()..rebuild(positions);

      expect(index.isValid, isTrue);
      expect(index.pageCount, 0);

      index.clear();
      expect(index.isValid, isFalse);
      expect(index.sliceFor(positions, 0), isNull);
    });

    test('reconstroi limites conhecidos em O(paginas), sem scan de posicoes',
        () {
      final List<IElementPosition> positions = <IElementPosition>[
        _position(0, 0),
        _position(0, 1),
        _position(2, 2),
        _position(2, 3),
        _position(2, 4),
      ];
      final PagePositionIndex index = PagePositionIndex()
        ..rebuildFromPageLengths(positions, <int>[2, 0, 3]);

      expect(index.isValid, isTrue);
      expect(index.pageCount, 2);
      expect(index.sliceFor(positions, 0)?.length, 2);
      expect(index.sliceFor(positions, 1), isNull);
      expect(index.sliceFor(positions, 2)?.startOffset, 2);
      expect(index.sliceFor(positions, 2)?.endOffset, 5);

      index.rebuildFromPageLengths(positions, <int>[2, 2]);
      expect(index.isValid, isFalse,
          reason: 'a soma precisa cobrir exatamente a lista canonica');
    });
  });
}
