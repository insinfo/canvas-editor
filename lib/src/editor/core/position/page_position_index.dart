import '../../interface/element.dart';

/// Faixa contigua de [IElementPosition] pertencente a uma pagina.
///
/// Os offsets apontam para a lista canonica de posicoes; o indice nao copia
/// nem passa a ser dono dos objetos de geometria.
class PagePositionSlice {
  const PagePositionSlice({
    required this.pageNo,
    required this.startOffset,
    required this.endOffset,
  });

  final int pageNo;
  final int startOffset;
  final int endOffset;

  int get length => endOffset - startOffset;
}

/// Indice derivado e descartavel sobre a lista canonica de posicoes.
///
/// O indice so e usado quando a lista consultada e exatamente a lista que o
/// originou, continua com o mesmo tamanho e esta ordenada em faixas contiguas
/// por pagina. Qualquer violacao faz o chamador voltar ao scan tradicional.
class PagePositionIndex {
  final Map<int, PagePositionSlice> _sliceByPage = <int, PagePositionSlice>{};

  List<IElementPosition>? _source;
  int _sourceLength = 0;
  bool _isValid = false;

  bool get isValid => _isValid;
  int get pageCount => _sliceByPage.length;

  void clear() {
    _sliceByPage.clear();
    _source = null;
    _sourceLength = 0;
    _isValid = false;
  }

  void rebuild(List<IElementPosition> source) {
    _sliceByPage.clear();
    _source = source;
    _sourceLength = source.length;
    _isValid = true;

    if (source.isEmpty) {
      return;
    }

    var currentPageNo = source.first.pageNo;
    var startOffset = 0;
    for (var offset = 1; offset < source.length; offset++) {
      final int pageNo = source[offset].pageNo;
      if (pageNo == currentPageNo) {
        continue;
      }

      // computePositionList produz paginas em ordem crescente. Se uma lista
      // externa violar essa invariante, nao arriscamos selecionar uma faixa
      // incompleta: o hit-test usara seu fallback linear.
      if (pageNo < currentPageNo) {
        _sliceByPage.clear();
        _isValid = false;
        return;
      }

      _sliceByPage[currentPageNo] = PagePositionSlice(
        pageNo: currentPageNo,
        startOffset: startOffset,
        endOffset: offset,
      );
      currentPageNo = pageNo;
      startOffset = offset;
    }

    _sliceByPage[currentPageNo] = PagePositionSlice(
      pageNo: currentPageNo,
      startOffset: startOffset,
      endOffset: source.length,
    );
  }

  /// Rebuilds page slices from already-known page lengths.
  ///
  /// [Position] owns one list per page while computing geometry, so scanning
  /// every position again merely to rediscover the same boundaries is wasted
  /// work. This path is O(pages) and deliberately validates the total length
  /// before publishing the index.
  void rebuildFromPageLengths(
    List<IElementPosition> source,
    Iterable<int> pageLengths,
  ) {
    _sliceByPage.clear();
    _source = source;
    _sourceLength = source.length;
    _isValid = false;

    int offset = 0;
    int pageNo = 0;
    for (final int length in pageLengths) {
      if (length < 0 || offset + length > source.length) {
        _sliceByPage.clear();
        return;
      }
      if (length > 0) {
        _sliceByPage[pageNo] = PagePositionSlice(
          pageNo: pageNo,
          startOffset: offset,
          endOffset: offset + length,
        );
      }
      offset += length;
      pageNo += 1;
    }
    if (offset != source.length) {
      _sliceByPage.clear();
      return;
    }
    _isValid = true;
  }

  PagePositionSlice? sliceFor(
    List<IElementPosition> source,
    int pageNo,
  ) {
    if (!_isValid ||
        !identical(source, _source) ||
        source.length != _sourceLength) {
      return null;
    }
    return _sliceByPage[pageNo];
  }
}
