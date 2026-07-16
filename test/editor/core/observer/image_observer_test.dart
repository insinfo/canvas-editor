import 'dart:async';

import 'package:canvas_text_editor/src/editor/core/observer/image_observer.dart';
import 'package:test/test.dart';

void main() {
  test('pending image loads survive a render-list reset until settlement',
      () async {
    final ImageObserver observer = ImageObserver();
    final Completer<void> imageLoad = Completer<void>();

    observer.add(imageLoad.future);
    expect(observer.pendingCount, 1);
    expect(observer.hasPending, isTrue);

    // A full repaint replaces the futures awaited by the next export, but the
    // old asynchronous load is still alive and must keep partial repaint off.
    observer.clearAll();
    expect(observer.pendingCount, 1);
    expect(await observer.allSettled(), isEmpty);

    imageLoad.complete();
    await imageLoad.future;
    await Future<void>.delayed(Duration.zero);
    expect(observer.pendingCount, 0);
    expect(observer.hasPending, isFalse);
  });

  test('failed image loads also release the pending guard', () async {
    final ImageObserver observer = ImageObserver();
    final Completer<void> imageLoad = Completer<void>();
    observer.add(imageLoad.future);

    imageLoad.completeError(StateError('broken image'));
    await expectLater(imageLoad.future, throwsStateError);
    await Future<void>.delayed(Duration.zero);

    expect(observer.pendingCount, 0);
    expect(observer.hasPending, isFalse);
  });
}
