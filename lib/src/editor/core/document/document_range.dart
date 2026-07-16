/// Intervalo inclusivo de elementos afetados por uma mutacao do documento.
///
/// O tipo e deliberadamente pequeno e independente de UI/layout para poder ser
/// transportado pelo historico, scheduler e renderer sem flags ad-hoc.
class DocumentRange {
  const DocumentRange(this.start, this.end)
      : assert(start >= 0),
        assert(end >= start);

  factory DocumentRange.collapsed(int index) => DocumentRange(index, index);

  final int start;
  final int end;

  int get length => end - start + 1;

  bool contains(int index) => index >= start && index <= end;

  bool intersects(DocumentRange other) =>
      start <= other.end && other.start <= end;

  DocumentRange union(DocumentRange other) => DocumentRange(
        start < other.start ? start : other.start,
        end > other.end ? end : other.end,
      );

  @override
  bool operator ==(Object other) =>
      other is DocumentRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'DocumentRange($start, $end)';
}
