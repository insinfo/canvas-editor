import 'package:canvas_text_editor/src/editor/core/document/document_mutation.dart';
import 'package:canvas_text_editor/src/editor/core/document/document_replay_delta.dart';
import 'package:canvas_text_editor/src/editor/core/history/history_restorer.dart';
import 'package:canvas_text_editor/src/editor/core/history/history_timeline.dart';
import 'package:canvas_text_editor/src/editor/interface/element.dart';
import 'package:test/test.dart';

void main() {
  group('HistoryRestorer', () {
    test('replays a long linear delta chain iteratively in insertion order',
        () {
      const int deltaCount = 50000;
      var value = -1;
      final HistoryRestorer baseline = HistoryRestorer.absolute(() {
        value = 0;
      });
      HistoryRestorer current = baseline;

      for (int i = 0; i < deltaCount; i++) {
        current = current.appendDelta(() {
          value++;
        });
      }

      expect(current.deltaCount, deltaCount);
      expect(current.retainedDeltaCallbackCount, deltaCount);
      expect(current.sharesDeltaStorageWith(baseline), isTrue);

      // A recursively composed restorer of this depth overflows the JS/VM
      // stack. Flat replay has constant call-stack depth.
      current.restore();
      expect(value, deltaCount);
    });

    test('shared linear storage keeps every earlier endpoint immutable', () {
      final List<String> document = <String>[];
      final HistoryRestorer baseline = HistoryRestorer.absolute(document.clear);
      final HistoryRestorer first = baseline.appendDelta(
        () => document.add('A'),
      );
      final HistoryRestorer second = first.appendDelta(
        () => document.add('B'),
      );

      baseline.restore();
      expect(document, isEmpty);
      first.restore();
      expect(document, <String>['A']);
      second.restore();
      expect(document, <String>['A', 'B']);

      expect(first.sharesDeltaStorageWith(second), isTrue);
      expect(first.deltaCount, 1);
      expect(first.retainedDeltaCallbackCount, 2);
    });

    test('append after undo forks only the visible prefix', () {
      final List<String> document = <String>[];
      final HistoryRestorer baseline = HistoryRestorer.absolute(document.clear);
      final HistoryRestorer first = baseline.appendDelta(
        () => document.add('A'),
      );
      final HistoryRestorer abandoned = first.appendDelta(
        () => document.add('old-redo'),
      );
      final HistoryRestorer branch = first.appendDelta(
        () => document.add('new-branch'),
      );

      expect(branch.sharesDeltaStorageWith(first), isFalse);
      expect(branch.retainedDeltaCallbackCount, 2);

      branch.restore();
      expect(document, <String>['A', 'new-branch']);
      abandoned.restore();
      expect(document, <String>['A', 'old-redo']);
    });

    test('a new absolute endpoint starts a compact independent delta log', () {
      var value = '';
      final HistoryRestorer old = HistoryRestorer.absolute(() => value = 'S0')
          .appendDelta(() => value += '+D1')
          .appendDelta(() => value += '+D2');
      final HistoryRestorer snapshot =
          HistoryRestorer.absolute(() => value = 'S3');
      final HistoryRestorer afterSnapshot =
          snapshot.appendDelta(() => value += '+D4');

      expect(old.deltaCount, 2);
      expect(afterSnapshot.deltaCount, 1);
      expect(old.sharesDeltaStorageWith(afterSnapshot), isFalse);

      old.restore();
      expect(value, 'S0+D1+D2');
      afterSnapshot.restore();
      expect(value, 'S3+D4');
    });

    test('direct undo/redo actions allocate no delta storage', () {
      var calls = 0;
      final HistoryRestorer action = HistoryRestorer.action(() => calls++);

      expect(action.deltaCount, 0);
      expect(action.retainedDeltaCallbackCount, 0);
      action.restore();
      expect(calls, 1);
      expect(
        () => action.appendDelta(() {}),
        throwsStateError,
      );
    });

    test('timeline mixes flat deltas, direct undo redo and snapshots', () {
      final List<int> document = <int>[];
      final HistoryTimeline<HistoryRestorer> timeline =
          HistoryTimeline<HistoryRestorer>();

      final HistoryRestorer baseline = HistoryRestorer.absolute(document.clear);
      timeline.execute(baseline);

      void applyOne() => document.add(1);
      void revertOne() => document.removeLast();
      applyOne();
      final HistoryRestorer afterOne = baseline.appendDelta(applyOne);
      timeline.execute(
        afterOne,
        undoAction: HistoryRestorer.action(revertOne),
        redoAction: HistoryRestorer.action(applyOne),
      );

      void applyTwo() => document.add(2);
      void revertTwo() => document.removeLast();
      applyTwo();
      final HistoryRestorer afterTwo = afterOne.appendDelta(applyTwo);
      timeline.execute(
        afterTwo,
        undoAction: HistoryRestorer.action(revertTwo),
        redoAction: HistoryRestorer.action(applyTwo),
      );

      document
        ..clear()
        ..add(9);
      timeline.execute(
        HistoryRestorer.absolute(() {
          document
            ..clear()
            ..add(9);
        }),
      );

      timeline.undo()!.restore();
      expect(document, <int>[1, 2]);
      timeline.undo()!.restore();
      expect(document, <int>[1]);
      timeline.redo()!.restore();
      expect(document, <int>[1, 2]);
      timeline.redo()!.restore();
      expect(document, <int>[9]);
    });

    test('transition eviction keeps the prefix required by a later snapshot',
        () {
      var value = 0;
      final HistoryTimeline<HistoryRestorer> timeline =
          HistoryTimeline<HistoryRestorer>();
      HistoryRestorer current = HistoryRestorer.absolute(() => value = 0);
      timeline.execute(current);

      for (int i = 0; i < 20; i++) {
        void apply() => value++;
        void revert() => value--;
        apply();
        current = current.appendDelta(apply);
        timeline.execute(
          current,
          undoAction: HistoryRestorer.action(revert),
          redoAction: HistoryRestorer.action(apply),
          maxTransitions: 2,
        );
      }

      expect(timeline.transitionCount, 2);
      expect(current.deltaCount, 20);
      expect(current.retainedDeltaCallbackCount, 20);

      // Even though old undo units were evicted, the absolute pre-snapshot
      // endpoint still needs their flat prefix to reconstruct value 20.
      value = 99;
      timeline.execute(
        HistoryRestorer.absolute(() => value = 99),
        maxTransitions: 2,
      );
      timeline.undo()!.restore();
      expect(value, 20);
    });

    test('10k compact deltas replay one checkpoint plus the retained window',
        () {
      const int deltaCount = 10000;
      const int maxTransitions = 3;
      final _CounterModel model = _CounterModel();
      final HistoryTimeline<HistoryRestorer> timeline =
          HistoryTimeline<HistoryRestorer>();
      HistoryRestorer current = HistoryRestorer.absolute(() {
        model.value = 0;
      });
      timeline.execute(current);

      for (int i = 0; i < deltaCount; i++) {
        void apply() {
          model.value += 1;
          model.fullCallbackCalls += 1;
        }

        void revert() => model.value -= 1;
        apply();
        current = current.appendDelta(
          apply,
          checkpointDelta: _CounterDelta(model, 1),
        );
        timeline.execute(
          current,
          undoAction: HistoryRestorer.action(revert),
          redoAction: HistoryRestorer.action(apply),
          maxTransitions: maxTransitions,
        );
        _compactTimeline(timeline);
      }

      expect(timeline.transitionCount, maxTransitions);
      expect(current.deltaCount, deltaCount);
      expect(current.retainedDeltaCallbackCount, maxTransitions + 1);
      expect(current.checkpointReplayOperationCount, 1);
      expect(current.checkpointPayloadUnits, 1);
      expect(current.retainedWindowPayloadUnits, maxTransitions + 1);
      expect(current.checkpointBarrierCount, 0);

      model
        ..value = -1
        ..fullCallbackCalls = 0
        ..checkpointReplayCalls = 0;
      current.restore();
      expect(model.value, deltaCount);
      expect(model.checkpointReplayCalls, 1);
      expect(model.fullCallbackCalls, maxTransitions + 1);
    });

    test('10k alternating Enter/text splices compact to one model replay', () {
      const int deltaCount = 10000;
      const int maxTransitions = 3;
      final List<IElement> elements = <IElement>[];
      List<IElement> cloneElements(Iterable<IElement> source) => source
          .map((IElement element) => IElement(value: element.value))
          .toList(growable: true);
      void splice(
        int start,
        int deleteCount,
        List<IElement> replacement,
      ) {
        elements.replaceRange(start, start + deleteCount, replacement);
      }

      final HistoryTimeline<HistoryRestorer> timeline =
          HistoryTimeline<HistoryRestorer>();
      HistoryRestorer current = HistoryRestorer.absolute(elements.clear);
      timeline.execute(current);

      for (int i = 0; i < deltaCount; i++) {
        final ElementSpliceMutation mutation = ElementSpliceMutation(
          start: i,
          removed: const <IElement>[],
          inserted: <IElement>[IElement(value: i.isEven ? '\u200B' : 'a')],
          splice: splice,
          cloneElements: cloneElements,
          replayDomain: elements,
        );
        mutation.apply();
        current = current.appendDelta(
          mutation.apply,
          checkpointDelta: mutation,
        );
        timeline.execute(
          current,
          undoAction: HistoryRestorer.action(() => elements.removeLast()),
          redoAction: HistoryRestorer.action(mutation.apply),
          maxTransitions: maxTransitions,
        );
        _compactTimeline(timeline);
      }

      expect(current.retainedDeltaCallbackCount, maxTransitions + 1);
      expect(current.checkpointReplayOperationCount, 1);
      expect(current.checkpointPayloadUnits, deltaCount - maxTransitions - 1);
      expect(current.retainedWindowPayloadUnits, maxTransitions + 1);

      elements.clear();
      current.restore();
      expect(elements, hasLength(deltaCount));
      expect(elements.first.value, '\u200B');
      expect(elements.last.value, 'a');
    });

    test('compacted endpoint survives snapshot undo redo and branch', () {
      const int maxTransitions = 3;
      final _CounterModel model = _CounterModel();
      final HistoryTimeline<HistoryRestorer> timeline =
          HistoryTimeline<HistoryRestorer>();
      HistoryRestorer current = HistoryRestorer.absolute(() => model.value = 0);
      timeline.execute(current);

      for (int i = 0; i < 20; i++) {
        void apply() => model.value += 1;
        void revert() => model.value -= 1;
        apply();
        current = current.appendDelta(
          apply,
          checkpointDelta: _CounterDelta(model, 1),
        );
        timeline.execute(
          current,
          undoAction: HistoryRestorer.action(revert),
          redoAction: HistoryRestorer.action(apply),
          maxTransitions: maxTransitions,
        );
        _compactTimeline(timeline);
      }

      model.value = 99;
      timeline.execute(
        HistoryRestorer.absolute(() => model.value = 99),
        maxTransitions: maxTransitions,
      );
      timeline.undo()!.restore();
      expect(model.value, 20);
      timeline.undo()!.restore();
      expect(model.value, 19);

      final HistoryRestorer branchBefore = timeline.current!;
      void applyBranch() => model.value += 100;
      void revertBranch() => model.value -= 100;
      applyBranch();
      final HistoryRestorer branch = branchBefore.appendDelta(
        applyBranch,
        checkpointDelta: _CounterDelta(model, 100),
      );
      timeline.execute(
        branch,
        undoAction: HistoryRestorer.action(revertBranch),
        redoAction: HistoryRestorer.action(applyBranch),
        maxTransitions: maxTransitions,
      );
      _compactTimeline(timeline);

      expect(timeline.canRedo, isFalse);
      expect(model.value, 119);
      branch.restore();
      expect(model.value, 119);
      timeline.undo()!.restore();
      expect(model.value, 19);
      timeline.redo()!.restore();
      expect(model.value, 119);
    });

    test('opaque delta is an explicit checkpoint barrier', () {
      var value = 0;
      final HistoryTimeline<HistoryRestorer> timeline =
          HistoryTimeline<HistoryRestorer>();
      HistoryRestorer current = HistoryRestorer.absolute(() => value = 0);
      timeline.execute(current);

      for (int i = 0; i < 10; i++) {
        void apply() => value++;
        apply();
        current = current.appendDelta(apply);
        timeline.execute(current, maxTransitions: 2);
        _compactTimeline(timeline);
      }

      expect(current.checkpointReplayOperationCount, 0);
      expect(current.retainedDeltaCallbackCount, 10);
      expect(current.checkpointBarrierCount, 10);
      current.restore();
      expect(value, 10);
    });
  });
}

void _compactTimeline(HistoryTimeline<HistoryRestorer> timeline) {
  final HistoryRestorer? current = timeline.current;
  if (current == null) return;
  HistoryRestorer oldest = current;
  timeline.visitRetainedEndpoints((HistoryRestorer endpoint) {
    if (current.sharesDeltaStorageWith(endpoint) &&
        endpoint.deltaCount < oldest.deltaCount) {
      oldest = endpoint;
    }
  });
  current.compactBefore(oldest);
}

class _CounterModel {
  int value = 0;
  int fullCallbackCalls = 0;
  int checkpointReplayCalls = 0;
}

class _CounterDelta implements DocumentReplayDelta {
  _CounterDelta(this.model, this.amount);

  final _CounterModel model;
  int amount;

  @override
  DocumentReplayDelta copyForCheckpoint() => _CounterDelta(model, amount);

  @override
  void replay() {
    model
      ..value += amount
      ..checkpointReplayCalls += 1;
  }

  @override
  int get replayOperationCount => 1;

  @override
  int get retainedPayloadUnits => 1;

  @override
  bool tryMergeCheckpoint(DocumentReplayDelta next) {
    if (next is! _CounterDelta || !identical(model, next.model)) {
      return false;
    }
    amount += next.amount;
    return true;
  }
}
