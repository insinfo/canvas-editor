import 'document_mutation.dart';
import 'document_range.dart';

/// Agrupa todas as mutations produzidas por um comando ou rajada de input.
class DocumentTransaction {
  DocumentTransaction({this.mergeKey});

  final String? mergeKey;
  final List<DocumentMutation> _mutations = <DocumentMutation>[];

  List<DocumentMutation> get mutations =>
      List<DocumentMutation>.unmodifiable(_mutations);

  int get mutationCount => _mutations.length;

  bool get isEmpty => _mutations.isEmpty;

  DocumentRange? get affectedRange {
    if (_mutations.isEmpty) {
      return null;
    }
    DocumentRange result = _mutations.first.affectedRange;
    for (int i = 1; i < _mutations.length; i++) {
      result = result.union(_mutations[i].affectedRange);
    }
    return result;
  }

  DocumentMutationImpact get impact {
    DocumentMutationImpact result = DocumentMutationImpact.repaintOnly;
    for (final DocumentMutation mutation in _mutations) {
      if (mutation.impact.index > result.index) {
        result = mutation.impact;
      }
    }
    return result;
  }

  void add(DocumentMutation mutation) {
    _mutations.add(mutation);
  }

  void apply() {
    for (final DocumentMutation mutation in _mutations) {
      mutation.apply();
    }
  }

  void revert() {
    for (int i = _mutations.length - 1; i >= 0; i--) {
      _mutations[i].revert();
    }
  }

  bool canMergeWith(DocumentTransaction next) {
    if (mergeKey == null ||
        mergeKey != next.mergeKey ||
        isEmpty ||
        next.isEmpty) {
      return false;
    }
    return _mutations.last.canMergeWith(next._mutations.first);
  }

  void merge(DocumentTransaction next) {
    if (!canMergeWith(next)) {
      throw ArgumentError('transactions are not mergeable');
    }
    final DocumentMutation currentTail = _mutations.last;
    final DocumentMutation nextHead = next._mutations.first;
    if (currentTail is ElementSpliceMutation &&
        nextHead is ElementSpliceMutation &&
        currentTail.tryMergeWith(nextHead)) {
      _mutations.addAll(next._mutations.skip(1));
      return;
    }
    _mutations.addAll(next._mutations);
  }
}
