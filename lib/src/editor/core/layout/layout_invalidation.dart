import '../document/document_mutation.dart';
import '../document/document_range.dart';
import '../document/document_transaction.dart';

enum LayoutInvalidationKind {
  repaintOnly,
  paragraph,
  table,
  full,
}

/// Decisao unica consumida pelo layout e pelo renderer.
class LayoutInvalidation {
  const LayoutInvalidation({required this.kind, this.range});

  factory LayoutInvalidation.fromTransaction(DocumentTransaction transaction) {
    return LayoutInvalidation(
      kind: _kindForImpact(transaction.impact),
      range: transaction.affectedRange,
    );
  }

  final LayoutInvalidationKind kind;
  final DocumentRange? range;

  bool get needsLayout => kind != LayoutInvalidationKind.repaintOnly;

  bool get isRepaintOnly => kind == LayoutInvalidationKind.repaintOnly;

  LayoutInvalidation combine(LayoutInvalidation other) {
    final LayoutInvalidationKind combinedKind =
        kind.index >= other.kind.index ? kind : other.kind;
    final DocumentRange? combinedRange;
    if (range == null) {
      combinedRange = other.range;
    } else if (other.range == null) {
      combinedRange = range;
    } else {
      combinedRange = range!.union(other.range!);
    }
    return LayoutInvalidation(kind: combinedKind, range: combinedRange);
  }

  static LayoutInvalidationKind _kindForImpact(
    DocumentMutationImpact impact,
  ) {
    switch (impact) {
      case DocumentMutationImpact.repaintOnly:
        return LayoutInvalidationKind.repaintOnly;
      case DocumentMutationImpact.paragraphLayout:
        return LayoutInvalidationKind.paragraph;
      case DocumentMutationImpact.tableLayout:
        return LayoutInvalidationKind.table;
      case DocumentMutationImpact.fullLayout:
        return LayoutInvalidationKind.full;
    }
  }
}
