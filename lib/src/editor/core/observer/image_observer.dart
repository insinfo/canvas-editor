import 'dart:async';

class AllSettledResult {
  final bool isFulfilled;
  final Object? value;
  final Object? error;

  AllSettledResult({
    required this.isFulfilled,
    this.value,
    this.error,
  });
}

class ImageObserver {
  final List<Future<dynamic>> _futureList = [];
  int _pendingCount = 0;

  int get pendingCount => _pendingCount;
  bool get hasPending => _pendingCount > 0;

  void add(Future<dynamic> payload) {
    _futureList.add(payload);
    _pendingCount += 1;
    payload.then<void>(
      (_) => _settleOne(),
      onError: (Object _, StackTrace __) => _settleOne(),
    );
  }

  void _settleOne() {
    if (_pendingCount > 0) {
      _pendingCount -= 1;
    }
  }

  void clearAll() {
    _futureList.clear();
  }

  Future<List<AllSettledResult>> allSettled() {
    final wrapped = _futureList.map((future) async {
      try {
        final value = await future;
        return AllSettledResult(isFulfilled: true, value: value);
      } catch (error) {
        return AllSettledResult(isFulfilled: false, error: error);
      }
    }).toList();
    return Future.wait(wrapped);
  }
}
