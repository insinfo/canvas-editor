import 'package:canvas_text_editor/src/editor/core/layout/layout_scheduler.dart';
import 'package:test/test.dart';

void main() {
  group('LayoutScheduler', () {
    test('continues in another callback when the deadline is exhausted', () {
      final _FakeRuntime runtime = _FakeRuntime();
      final List<int> commits = <int>[];
      final LayoutScheduler<int, Never> scheduler = LayoutScheduler<int, Never>(
        frameBudget: const Duration(milliseconds: 5),
        clock: runtime.clock,
        schedule: runtime.schedule,
      );

      scheduler.start(
        continuation: 0,
        step: (LayoutSlice<int, Never> slice) {
          runtime.elapse(const Duration(milliseconds: 2));
          final int next = (slice.continuation ?? 0) + 1;
          return LayoutStepResult<int>(
            continuation: next,
            isComplete: next == 5,
            commit: () => commits.add(next),
          );
        },
      );

      expect(runtime.pendingCount, 1);
      runtime.runNext();

      expect(commits, <int>[1, 2, 3]);
      expect(scheduler.continuation, 3);
      expect(scheduler.isActive, isTrue);
      expect(runtime.pendingCount, 1);

      runtime.runNext();

      expect(commits, <int>[1, 2, 3, 4, 5]);
      expect(scheduler.hasJob, isFalse);
      expect(runtime.pendingCount, 0);
    });

    test('uses elapsed time instead of a fixed item count', () {
      final _FakeRuntime runtime = _FakeRuntime();
      int steps = 0;
      final LayoutScheduler<int, Never> scheduler = LayoutScheduler<int, Never>(
        frameBudget: const Duration(seconds: 1),
        clock: runtime.clock,
        schedule: runtime.schedule,
      );

      scheduler.start(
        continuation: 0,
        step: (LayoutSlice<int, Never> slice) {
          steps += 1;
          final int next = (slice.continuation ?? 0) + 1;
          return LayoutStepResult<int>(
            continuation: next,
            isComplete: next == 200,
          );
        },
      );
      runtime.runNext();

      expect(steps, 200);
      expect(scheduler.hasJob, isFalse);
      expect(runtime.pendingCount, 0);
    });

    test('pauses at an optional target and resumes with a new target', () {
      final _FakeRuntime runtime = _FakeRuntime();
      final List<int> commits = <int>[];
      int targetNotifications = 0;
      int completions = 0;
      final LayoutScheduler<int, int> scheduler = LayoutScheduler<int, int>(
        frameBudget: const Duration(milliseconds: 100),
        clock: runtime.clock,
        schedule: runtime.schedule,
      );

      scheduler.start(
        continuation: 0,
        target: 2,
        onTargetReached: () => targetNotifications += 1,
        onComplete: () => completions += 1,
        step: (LayoutSlice<int, int> slice) {
          runtime.elapse(const Duration(milliseconds: 1));
          final int next = (slice.continuation ?? 0) + 1;
          final int? target = slice.target;
          return LayoutStepResult<int>(
            continuation: next,
            isComplete: target == null && next == 5,
            targetReached: target != null && next >= target,
            commit: () => commits.add(next),
          );
        },
      );

      runtime.runNext();
      expect(commits, <int>[1, 2]);
      expect(scheduler.isPaused, isTrue);
      expect(scheduler.continuation, 2);
      expect(targetNotifications, 1);

      expect(scheduler.requestTarget(4), isTrue);
      runtime.runNext();
      expect(commits, <int>[1, 2, 3, 4]);
      expect(scheduler.isPaused, isTrue);
      expect(targetNotifications, 2);

      expect(scheduler.requestTarget(null), isTrue);
      runtime.runNext();
      expect(commits, <int>[1, 2, 3, 4, 5]);
      expect(completions, 1);
      expect(scheduler.hasJob, isFalse);
    });

    test('resume preserves the current continuation and target', () {
      final _FakeRuntime runtime = _FakeRuntime();
      final List<int> commits = <int>[];
      final LayoutScheduler<int, String> scheduler =
          LayoutScheduler<int, String>(
        frameBudget: const Duration(milliseconds: 100),
        clock: runtime.clock,
        schedule: runtime.schedule,
      );

      scheduler.start(
        continuation: 0,
        target: 'viewport',
        step: (LayoutSlice<int, String> slice) {
          final int next = (slice.continuation ?? 0) + 1;
          return LayoutStepResult<int>(
            continuation: next,
            isComplete: next == 2,
            targetReached: next == 1,
            commit: () => commits.add(next),
          );
        },
      );

      runtime.runNext();
      expect(scheduler.isPaused, isTrue);
      expect(scheduler.continuation, 1);
      expect(scheduler.target, 'viewport');

      expect(scheduler.resume(), isTrue);
      expect(scheduler.resume(), isFalse);
      runtime.runNext();

      expect(commits, <int>[1, 2]);
      expect(scheduler.hasJob, isFalse);
    });

    test('a replaced queued callback never computes or commits', () {
      final _FakeRuntime runtime = _FakeRuntime();
      final List<String> events = <String>[];
      final LayoutScheduler<int, Never> scheduler = LayoutScheduler<int, Never>(
        clock: runtime.clock,
        schedule: runtime.schedule,
      );

      final int oldVersion = scheduler.start(
        step: (_) {
          events.add('old-step');
          return LayoutStepResult<int>.complete(
            commit: () => events.add('old-commit'),
          );
        },
      );
      final int newVersion = scheduler.start(
        step: (_) => LayoutStepResult<int>.complete(
          commit: () => events.add('new-commit'),
        ),
      );

      expect(newVersion, greaterThan(oldVersion));
      runtime.runNext(runCancelled: true);
      expect(events, isEmpty);

      runtime.runNext();
      expect(events, <String>['new-commit']);
    });

    test('a job replaced during its step cannot publish its result', () {
      final _FakeRuntime runtime = _FakeRuntime();
      final List<String> commits = <String>[];
      late final LayoutScheduler<int, Never> scheduler;
      scheduler = LayoutScheduler<int, Never>(
        clock: runtime.clock,
        schedule: runtime.schedule,
      );

      scheduler.start(
        step: (_) {
          scheduler.start(
            step: (_) => LayoutStepResult<int>.complete(
              commit: () => commits.add('new'),
            ),
          );
          return LayoutStepResult<int>.complete(
            commit: () => commits.add('stale'),
          );
        },
      );

      runtime.runNext();
      expect(commits, isEmpty);
      runtime.runNext();
      expect(commits, <String>['new']);
    });

    test('cancel invalidates callbacks even if cancellation loses the race',
        () {
      final _FakeRuntime runtime = _FakeRuntime();
      int commits = 0;
      final LayoutScheduler<int, Never> scheduler = LayoutScheduler<int, Never>(
        clock: runtime.clock,
        schedule: runtime.schedule,
      );

      scheduler.start(
        step: (_) => LayoutStepResult<int>.complete(
          commit: () => commits += 1,
        ),
      );
      expect(scheduler.cancel(), isTrue);

      runtime.runNext(runCancelled: true);
      expect(commits, 0);
      expect(scheduler.hasJob, isFalse);
      expect(scheduler.cancel(), isFalse);
    });

    test('a target changed during a step does not pause at the stale target',
        () {
      final _FakeRuntime runtime = _FakeRuntime();
      final List<int> commits = <int>[];
      late final LayoutScheduler<int, int> scheduler;
      scheduler = LayoutScheduler<int, int>(
        frameBudget: const Duration(milliseconds: 100),
        clock: runtime.clock,
        schedule: runtime.schedule,
      );

      scheduler.start(
        continuation: 0,
        target: 1,
        step: (LayoutSlice<int, int> slice) {
          final int next = (slice.continuation ?? 0) + 1;
          if (next == 1) {
            scheduler.requestTarget(3);
          }
          return LayoutStepResult<int>(
            continuation: next,
            targetReached: next >= (slice.target ?? 999),
            commit: () => commits.add(next),
          );
        },
      );

      runtime.runNext();
      expect(commits, <int>[1, 2, 3]);
      expect(scheduler.isPaused, isTrue);
      expect(scheduler.target, 3);
    });

    test('reports step failures and invalidates the failed job', () {
      final _FakeRuntime runtime = _FakeRuntime();
      Object? reportedError;
      final LayoutScheduler<int, Never> scheduler = LayoutScheduler<int, Never>(
        clock: runtime.clock,
        schedule: runtime.schedule,
      );

      scheduler.start(
        onError: (Object error, StackTrace _) => reportedError = error,
        step: (_) => throw StateError('layout failed'),
      );
      runtime.runNext();

      expect(reportedError, isA<StateError>());
      expect(scheduler.hasJob, isFalse);
      expect(runtime.pendingCount, 0);
    });

    test('rejects a non-positive frame budget', () {
      expect(
        () => LayoutScheduler<int, Never>(frameBudget: Duration.zero),
        throwsArgumentError,
      );
    });
  });
}

class _FakeRuntime {
  Duration _now = Duration.zero;
  final List<_ScheduledCallback> _callbacks = <_ScheduledCallback>[];

  Duration clock() => _now;

  int get pendingCount =>
      _callbacks.where((_ScheduledCallback item) => !item.cancelled).length;

  void elapse(Duration duration) {
    _now += duration;
  }

  LayoutCancel schedule(LayoutCallback callback) {
    final _ScheduledCallback item = _ScheduledCallback(callback);
    _callbacks.add(item);
    return () => item.cancelled = true;
  }

  void runNext({bool runCancelled = false}) {
    while (_callbacks.isNotEmpty) {
      final _ScheduledCallback item = _callbacks.removeAt(0);
      if (!item.cancelled || runCancelled) {
        item.callback();
        return;
      }
    }
    fail('No scheduled callback available.');
  }
}

class _ScheduledCallback {
  _ScheduledCallback(this.callback);

  final LayoutCallback callback;
  bool cancelled = false;
}
