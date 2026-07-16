import '../../interface/element.dart';
import 'document_index.dart';
import 'document_mutation.dart' show ElementCloneList;

/// Independently mutable document regions owned by [DocumentModel].
enum DocumentSection { main, header, footer }

/// UI-independent owner of the editor's main/header/footer element lists.
///
/// The lists passed to the constructor remain the canonical list references,
/// which lets the model be introduced around the current editor without
/// breaking existing consumers. Mutations should go through this API so the
/// monotonic [revision] and indexes stay coherent.
class DocumentModel {
  DocumentModel({
    required this.main,
    List<IElement>? header,
    List<IElement>? footer,
    ElementCloneList? cloneElements,
  })  : header = header ?? <IElement>[],
        footer = footer ?? <IElement>[],
        _cloneElements = cloneElements ?? _shallowCloneList {
    mainIndex = DocumentIndex(main);
    headerIndex = DocumentIndex(this.header);
    footerIndex = DocumentIndex(this.footer);
  }

  final List<IElement> main;
  final List<IElement> header;
  final List<IElement> footer;
  final ElementCloneList _cloneElements;

  late final DocumentIndex mainIndex;
  late final DocumentIndex headerIndex;
  late final DocumentIndex footerIndex;

  /// Convenience alias for the main-document index.
  DocumentIndex get index => mainIndex;

  int _revision = 0;

  int get revision => _revision;

  List<IElement> elementsFor(DocumentSection section) => switch (section) {
        DocumentSection.main => main,
        DocumentSection.header => header,
        DocumentSection.footer => footer,
      };

  DocumentIndex indexFor(DocumentSection section) => switch (section) {
        DocumentSection.main => mainIndex,
        DocumentSection.header => headerIndex,
        DocumentSection.footer => footerIndex,
      };

  /// Applies a splice and returns a cloned snapshot of the removed elements.
  List<IElement> onSplice({
    DocumentSection section = DocumentSection.main,
    required int start,
    required int deleteCount,
    Iterable<IElement> inserted = const <IElement>[],
  }) {
    final List<IElement> elements = elementsFor(section);
    if (start < 0 || start > elements.length) {
      throw RangeError.range(start, 0, elements.length, 'start');
    }
    if (deleteCount < 0 || start + deleteCount > elements.length) {
      throw RangeError.range(
        deleteCount,
        0,
        elements.length - start,
        'deleteCount',
      );
    }
    final List<IElement> replacement = _cloneElements(inserted);
    final List<IElement> removed =
        _cloneElements(elements.getRange(start, start + deleteCount));
    if (deleteCount == 0 && replacement.isEmpty) {
      return removed;
    }

    elements.replaceRange(start, start + deleteCount, replacement);
    indexFor(section).onSplice(
      start: start,
      deleteCount: deleteCount,
      insertCount: replacement.length,
    );
    _revision++;
    return removed;
  }

  /// Updates revision and indexes after a canonical list was spliced by a
  /// compatibility layer that still owns the actual mutation.
  ///
  /// This is the bridge used while legacy editor helpers are migrated to
  /// transactions. The backing list must already contain the post-splice
  /// value and the change must be representable as one contiguous splice.
  void didSplice({
    DocumentSection section = DocumentSection.main,
    required int start,
    required int deleteCount,
    required int insertCount,
  }) {
    if (deleteCount == 0 && insertCount == 0) {
      return;
    }
    indexFor(section).onSplice(
      start: start,
      deleteCount: deleteCount,
      insertCount: insertCount,
    );
    _revision++;
  }

  /// Records a structural change that cannot be described by one splice.
  ///
  /// Protected form content can delete a sparse subset of a requested range.
  /// Resetting the lazy index is O(1) and guarantees the next lookup rebuilds
  /// from the canonical list instead of retaining incorrect boundaries.
  void didComplexStructureChange({
    DocumentSection section = DocumentSection.main,
  }) {
    indexFor(section).reset();
    _revision++;
  }

  /// Records a structural mutation whose owning region can no longer be
  /// identified (for example, a nested cell list detached by the mutation).
  /// Resetting all three lazy indexes is constant-time and bumps the document
  /// revision once, preserving a single logical change.
  void didComplexStructureChangeAll() {
    mainIndex.reset();
    headerIndex.reset();
    footerIndex.reset();
    _revision++;
  }

  /// Records an in-place style mutation without invalidating structural maps.
  ///
  /// Style setters do not change `id`, `tableId`, `pagingId`, or paragraph
  /// boundaries, so the existing indexes remain valid.
  void onStyleChange({
    DocumentSection section = DocumentSection.main,
  }) {
    // Resolve the section now so future section-specific revision tracking can
    // be added without changing this API.
    indexFor(section);
    _revision++;
  }

  /// Replaces one or more regions while preserving their canonical references.
  void replace({
    Iterable<IElement>? main,
    Iterable<IElement>? header,
    Iterable<IElement>? footer,
  }) {
    if (main == null && header == null && footer == null) {
      return;
    }
    if (main != null) {
      _replaceRegion(this.main, main, mainIndex);
    }
    if (header != null) {
      _replaceRegion(this.header, header, headerIndex);
    }
    if (footer != null) {
      _replaceRegion(this.footer, footer, footerIndex);
    }
    _revision++;
  }

  void _replaceRegion(
    List<IElement> target,
    Iterable<IElement> replacement,
    DocumentIndex targetIndex,
  ) {
    final List<IElement> cloned = _cloneElements(replacement);
    target
      ..clear()
      ..addAll(cloned);
    targetIndex.reset();
  }

  static List<IElement> _shallowCloneList(Iterable<IElement> source) =>
      List<IElement>.of(source);
}
