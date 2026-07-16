import 'package:canvas_text_editor/src/editor/core/history/history_timeline.dart';
import 'package:test/test.dart';

void main() {
  group('HistoryTimeline', () {
    test('first execute establishes a baseline', () {
      final HistoryTimeline<String> timeline = HistoryTimeline<String>();

      expect(timeline.isEmpty, isTrue);
      timeline.execute('S0');

      expect(timeline.isEmpty, isFalse);
      expect(timeline.canUndo, isFalse);
      expect(timeline.canRedo, isFalse);
      expect(timeline.undo(), isNull);
      expect(timeline.redo(), isNull);

      timeline.execute('S1');
      expect(timeline.undo(), 'S0');
      expect(timeline.redo(), 'S1');
    });

    test('undo and redo preserve multiple disjoint delta transitions', () {
      final Map<String, int> document = <String, int>{
        'left': 0,
        'right': 0,
      };
      final HistoryTimeline<void Function()> timeline =
          HistoryTimeline<void Function()>();

      timeline.execute(() {
        document
          ..['left'] = 0
          ..['right'] = 0;
      });

      timeline.replaceCurrent(() => document['left'] = 0);
      document['left'] = 1;
      timeline.execute(() => document['left'] = 1);

      timeline.replaceCurrent(() => document['right'] = 0);
      document['right'] = 2;
      timeline.execute(() => document['right'] = 2);

      timeline.undo()!.call();
      expect(document, <String, int>{'left': 1, 'right': 0});
      timeline.undo()!.call();
      expect(document, <String, int>{'left': 0, 'right': 0});

      timeline.redo()!.call();
      expect(document, <String, int>{'left': 1, 'right': 0});
      timeline.redo()!.call();
      expect(document, <String, int>{'left': 1, 'right': 2});
    });

    test('direct actions run while current keeps absolute endpoints', () {
      final HistoryTimeline<void Function()> timeline =
          HistoryTimeline<void Function()>();
      var document = 'baseline';

      void restoreBaseline() => document = 'baseline';
      void restoreAfter() => document = 'after';
      void revertDelta() => document = 'undo-direct';
      void applyDelta() => document = 'redo-direct';

      timeline.execute(restoreBaseline);
      timeline.execute(
        restoreAfter,
        undoAction: revertDelta,
        redoAction: applyDelta,
      );

      timeline.undo()!.call();
      expect(document, 'undo-direct');
      timeline.current!.call();
      expect(document, 'baseline');

      timeline.redo()!.call();
      expect(document, 'redo-direct');
      timeline.current!.call();
      expect(document, 'after');
    });

    test('recording after undo discards the old redo branch', () {
      final HistoryTimeline<String> timeline = HistoryTimeline<String>()
        ..execute('S0')
        ..execute('S1')
        ..execute('S2');

      expect(timeline.undo(), 'S1');
      expect(timeline.canRedo, isTrue);

      timeline.replaceCurrent('before S3');
      timeline.execute('S3');

      expect(timeline.canRedo, isFalse);
      expect(timeline.undo(), 'before S3');
      expect(timeline.redo(), 'S3');
    });

    test('limit evicts only the oldest transitions', () {
      final HistoryTimeline<String> timeline = HistoryTimeline<String>();
      timeline.execute('S0');
      for (int i = 1; i <= 5; i++) {
        timeline.execute('S$i', maxTransitions: 2);
      }

      expect(timeline.transitionCount, 2);
      expect(timeline.undo(), 'S4');
      expect(timeline.undo(), 'S3');
      expect(timeline.canUndo, isFalse);
      expect(timeline.redo(), 'S4');
      expect(timeline.redo(), 'S5');
    });

    test('popUndo lets the next execute squash the latest transition', () {
      final HistoryTimeline<String> timeline = HistoryTimeline<String>()
        ..execute('S0')
        ..execute('S1');

      expect(timeline.popUndo(), 'S1');
      expect(timeline.canUndo, isFalse);

      timeline.execute('S2');
      expect(timeline.transitionCount, 1);
      expect(timeline.undo(), 'S0');
      expect(timeline.redo(), 'S2');

      final HistoryTimeline<String> baselineOnly = HistoryTimeline<String>()
        ..execute('baseline');
      expect(baselineOnly.popUndo(), 'baseline');
      expect(baselineOnly.isEmpty, isTrue);
    });
  });
}
