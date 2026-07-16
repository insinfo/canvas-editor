import 'package:canvas_text_editor/src/editor/core/document/document_mutation.dart';
import 'package:canvas_text_editor/src/editor/core/document/document_replay_delta.dart';
import 'package:canvas_text_editor/src/editor/core/document/document_transaction.dart';
import 'package:canvas_text_editor/src/editor/core/layout/layout_invalidation.dart';
import 'package:canvas_text_editor/src/editor/interface/element.dart';
import 'package:test/test.dart';

void main() {
  List<IElement> cloneElements(Iterable<IElement> source) => source
      .map(
        (IElement element) => IElement(
          value: element.value,
          bold: element.bold,
          color: element.color,
        ),
      )
      .toList();

  void splice(
    List<IElement> target,
    int start,
    int deleteCount,
    List<IElement> replacement,
  ) {
    target.replaceRange(start, start + deleteCount, replacement);
  }

  test('splice mutation replays only the changed payload', () {
    final List<IElement> elements =
        'abcd'.split('').map((String value) => IElement(value: value)).toList();
    final ElementSpliceMutation mutation = ElementSpliceMutation(
      start: 2,
      removed: <IElement>[elements[2]],
      inserted: <IElement>[IElement(value: 'X'), IElement(value: 'Y')],
      cloneElements: cloneElements,
      splice: (int start, int count, List<IElement> replacement) =>
          splice(elements, start, count, replacement),
    );

    mutation.apply();
    expect(elements.map((IElement e) => e.value).join(), 'abXYd');

    mutation.revert();
    expect(elements.map((IElement e) => e.value).join(), 'abcd');

    mutation.apply();
    expect(elements.map((IElement e) => e.value).join(), 'abXYd');
  });

  test('transaction reverts mutations in reverse order', () {
    final List<IElement> elements = <IElement>[
      IElement(value: 'a'),
      IElement(value: 'b'),
    ];
    final DocumentTransaction transaction = DocumentTransaction(
      mergeKey: 'typing',
    );
    void callback(int start, int count, List<IElement> replacement) =>
        splice(elements, start, count, replacement);
    final ElementSpliceMutation first = ElementSpliceMutation(
      start: 1,
      removed: const <IElement>[],
      inserted: <IElement>[IElement(value: '1')],
      cloneElements: cloneElements,
      splice: callback,
    );
    first.apply();
    transaction.add(first);
    final ElementSpliceMutation second = ElementSpliceMutation(
      start: 2,
      removed: const <IElement>[],
      inserted: <IElement>[IElement(value: '2')],
      cloneElements: cloneElements,
      splice: callback,
    );
    second.apply();
    transaction.add(second);

    expect(elements.map((IElement e) => e.value).join(), 'a12b');
    transaction.revert();
    expect(elements.map((IElement e) => e.value).join(), 'ab');
    transaction.apply();
    expect(elements.map((IElement e) => e.value).join(), 'a12b');
  });

  test('style snapshot produces repaint-only invalidation', () {
    final List<IElement> elements = <IElement>[
      IElement(value: 'a'),
      IElement(value: 'b'),
      IElement(value: 'c'),
    ];
    final ElementSnapshotMutation mutation = ElementSnapshotMutation.capture(
      elements: elements,
      indexes: <int>[1, 2],
      impact: DocumentMutationImpact.repaintOnly,
      cloneElements: cloneElements,
    );
    elements[1].color = '#ff0000';
    elements[2].color = '#ff0000';
    mutation.captureAfter();
    final DocumentTransaction transaction = DocumentTransaction()
      ..add(mutation);
    final LayoutInvalidation invalidation =
        LayoutInvalidation.fromTransaction(transaction);

    expect(invalidation.kind, LayoutInvalidationKind.repaintOnly);
    expect(invalidation.range?.start, 1);
    expect(invalidation.range?.end, 2);

    transaction.revert();
    expect(elements[1].color, isNull);
    transaction.apply();
    expect(elements[2].color, '#ff0000');
  });

  test('adjacent typing and backspace transactions are mergeable', () {
    DocumentTransaction insertion(int start, String value) {
      return DocumentTransaction(mergeKey: 'typing')
        ..add(
          ElementSpliceMutation(
            start: start,
            removed: const <IElement>[],
            inserted: <IElement>[IElement(value: value)],
            cloneElements: cloneElements,
            splice: (int _, int __, List<IElement> ___) {},
          ),
        );
    }

    final DocumentTransaction first = insertion(4, 'a');
    final DocumentTransaction second = insertion(5, 'b');
    expect(first.canMergeWith(second), isTrue);

    final DocumentTransaction backspaceA = DocumentTransaction(
      mergeKey: 'backspace',
    )..add(
        ElementSpliceMutation(
          start: 5,
          removed: <IElement>[IElement(value: 'b')],
          inserted: const <IElement>[],
          cloneElements: cloneElements,
          splice: (int _, int __, List<IElement> ___) {},
        ),
      );
    final DocumentTransaction backspaceB = DocumentTransaction(
      mergeKey: 'backspace',
    )..add(
        ElementSpliceMutation(
          start: 4,
          removed: <IElement>[IElement(value: 'a')],
          inserted: const <IElement>[],
          cloneElements: cloneElements,
          splice: (int _, int __, List<IElement> ___) {},
        ),
      );
    expect(backspaceA.canMergeWith(backspaceB), isTrue);
  });

  test('typing burst is retained and replayed as one splice mutation', () {
    final List<IElement> elements =
        'ab'.split('').map((String value) => IElement(value: value)).toList();
    void callback(int start, int count, List<IElement> replacement) =>
        splice(elements, start, count, replacement);

    DocumentTransaction? burst;
    for (int i = 0; i < 1000; i++) {
      final ElementSpliceMutation mutation = ElementSpliceMutation(
        start: 1 + i,
        removed: const <IElement>[],
        inserted: <IElement>[IElement(value: 'x')],
        cloneElements: cloneElements,
        splice: callback,
      );
      mutation.apply();
      final DocumentTransaction candidate =
          DocumentTransaction(mergeKey: 'typing')..add(mutation);
      if (burst == null) {
        burst = candidate;
      } else {
        burst.merge(candidate);
      }
    }

    expect(burst!.mutationCount, 1);
    expect(elements.length, 1002);
    burst.revert();
    expect(elements.map((IElement e) => e.value).join(), 'ab');
    burst.apply();
    expect(elements.length, 1002);
    expect(elements.first.value, 'a');
    expect(elements.last.value, 'b');
  });

  test('delete burst appends removed payload in original order', () {
    final List<IElement> elements = 'abcde'
        .split('')
        .map((String value) => IElement(value: value))
        .toList();
    void callback(int start, int count, List<IElement> replacement) =>
        splice(elements, start, count, replacement);
    final DocumentTransaction burst = DocumentTransaction(mergeKey: 'delete');

    for (int i = 0; i < 3; i++) {
      final ElementSpliceMutation mutation = ElementSpliceMutation(
        start: 1,
        removed: <IElement>[elements[1]],
        inserted: const <IElement>[],
        cloneElements: cloneElements,
        splice: callback,
      );
      mutation.apply();
      final DocumentTransaction candidate =
          DocumentTransaction(mergeKey: 'delete')..add(mutation);
      if (burst.isEmpty) {
        burst.add(mutation);
      } else {
        burst.merge(candidate);
      }
    }

    expect(burst.mutationCount, 1);
    expect(elements.map((IElement e) => e.value).join(), 'ae');
    burst.revert();
    expect(elements.map((IElement e) => e.value).join(), 'abcde');
    burst.apply();
    expect(elements.map((IElement e) => e.value).join(), 'ae');
  });

  test('backspace burst prepends removed payload in original order', () {
    final List<IElement> elements = 'abcde'
        .split('')
        .map((String value) => IElement(value: value))
        .toList();
    void callback(int start, int count, List<IElement> replacement) =>
        splice(elements, start, count, replacement);
    DocumentTransaction? burst;

    for (final int start in <int>[3, 2, 1]) {
      final ElementSpliceMutation mutation = ElementSpliceMutation(
        start: start,
        removed: <IElement>[elements[start]],
        inserted: const <IElement>[],
        cloneElements: cloneElements,
        splice: callback,
      );
      mutation.apply();
      final DocumentTransaction candidate =
          DocumentTransaction(mergeKey: 'backspace')..add(mutation);
      if (burst == null) {
        burst = candidate;
      } else {
        burst.merge(candidate);
      }
    }

    expect(burst!.mutationCount, 1);
    expect(elements.map((IElement e) => e.value).join(), 'ae');
    burst.revert();
    expect(elements.map((IElement e) => e.value).join(), 'abcde');
    burst.apply();
    expect(elements.map((IElement e) => e.value).join(), 'ae');
  });

  test('typing after selection replacement stays one reversible splice', () {
    final List<IElement> elements = 'abcde'
        .split('')
        .map((String value) => IElement(value: value))
        .toList();
    void callback(int start, int count, List<IElement> replacement) =>
        splice(elements, start, count, replacement);

    final ElementSpliceMutation replacement = ElementSpliceMutation(
      start: 1,
      removed: elements.sublist(1, 4),
      inserted: <IElement>[IElement(value: 'X')],
      cloneElements: cloneElements,
      splice: callback,
    );
    replacement.apply();
    final DocumentTransaction burst = DocumentTransaction(mergeKey: 'typing')
      ..add(replacement);

    final ElementSpliceMutation insertion = ElementSpliceMutation(
      start: 2,
      removed: const <IElement>[],
      inserted: <IElement>[IElement(value: 'Y')],
      cloneElements: cloneElements,
      splice: callback,
    );
    insertion.apply();
    burst.merge(
      DocumentTransaction(mergeKey: 'typing')..add(insertion),
    );

    expect(burst.mutationCount, 1);
    expect(elements.map((IElement e) => e.value).join(), 'aXYe');
    burst.revert();
    expect(elements.map((IElement e) => e.value).join(), 'abcde');
    burst.apply();
    expect(elements.map((IElement e) => e.value).join(), 'aXYe');
  });

  test('forward checkpoint drops removed values but recreates replacement', () {
    final List<IElement> elements = 'abcde'
        .split('')
        .map((String value) => IElement(value: value))
        .toList();
    void callback(int start, int count, List<IElement> replacement) =>
        splice(elements, start, count, replacement);
    final ElementSpliceMutation mutation = ElementSpliceMutation(
      start: 1,
      removed: elements.sublist(1, 4),
      inserted: <IElement>[IElement(value: 'X'), IElement(value: 'Y')],
      cloneElements: cloneElements,
      splice: callback,
      replayDomain: elements,
    );
    mutation.apply();
    final DocumentReplayDelta checkpoint = mutation.copyForCheckpoint();

    expect(mutation.retainedPayloadUnits, 5);
    expect(checkpoint.retainedPayloadUnits, 2);
    elements
      ..clear()
      ..addAll('abcde'.split('').map((String value) => IElement(value: value)));
    checkpoint.replay();
    expect(elements.map((IElement e) => e.value).join(), 'aXYe');
  });

  test('forward checkpoint coalesces adjacent insertions into one replay', () {
    final List<IElement> elements =
        'ab'.split('').map((String value) => IElement(value: value)).toList();
    void callback(int start, int count, List<IElement> replacement) =>
        splice(elements, start, count, replacement);
    final ElementSpliceMutation first = ElementSpliceMutation(
      start: 1,
      removed: const <IElement>[],
      inserted: <IElement>[IElement(value: 'X')],
      cloneElements: cloneElements,
      splice: callback,
      replayDomain: elements,
    );
    first.apply();
    final DocumentReplayDelta checkpoint = first.copyForCheckpoint();
    final ElementSpliceMutation second = ElementSpliceMutation(
      start: 2,
      removed: const <IElement>[],
      inserted: <IElement>[IElement(value: 'Y')],
      cloneElements: cloneElements,
      splice: callback,
      replayDomain: elements,
    );
    second.apply();

    expect(checkpoint.tryMergeCheckpoint(second), isTrue);
    expect(checkpoint.replayOperationCount, 1);
    expect(checkpoint.retainedPayloadUnits, 2);
    elements
      ..clear()
      ..addAll(<IElement>[IElement(value: 'a'), IElement(value: 'b')]);
    checkpoint.replay();
    expect(elements.map((IElement e) => e.value).join(), 'aXYb');
  });

  test('forward delete checkpoint retains no removed element payload', () {
    final List<IElement> elements = 'abcde'
        .split('')
        .map((String value) => IElement(value: value))
        .toList();
    void callback(int start, int count, List<IElement> replacement) =>
        splice(elements, start, count, replacement);
    final ElementSpliceMutation first = ElementSpliceMutation(
      start: 1,
      removed: <IElement>[elements[1]],
      inserted: const <IElement>[],
      cloneElements: cloneElements,
      splice: callback,
      replayDomain: elements,
    );
    first.apply();
    final DocumentReplayDelta checkpoint = first.copyForCheckpoint();
    final ElementSpliceMutation second = ElementSpliceMutation(
      start: 1,
      removed: <IElement>[elements[1]],
      inserted: const <IElement>[],
      cloneElements: cloneElements,
      splice: callback,
      replayDomain: elements,
    );
    second.apply();

    expect(checkpoint.tryMergeCheckpoint(second), isTrue);
    expect(checkpoint.retainedPayloadUnits, 0);
    elements
      ..clear()
      ..addAll('abcde'.split('').map((String value) => IElement(value: value)));
    checkpoint.replay();
    expect(elements.map((IElement e) => e.value).join(), 'ade');
  });
}
