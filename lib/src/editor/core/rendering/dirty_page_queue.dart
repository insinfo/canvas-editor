import 'dart:collection';
import 'dart:html';

typedef DirtyPagePaint = void Function(int pageIndex);
typedef DirtyPagePredicate = bool Function(int pageIndex);

/// Fila pequena para desenho de paginas sujas com orçamento por frame.
///
/// Espelha a ideia do OnlyOffice de separar "pagina recalculada" de "pagina
/// pintada": quem invalida apenas enfileira o indice, e o drain cede a main
/// thread entre frames para manter scroll e input responsivos.
class DirtyPageQueue {
  DirtyPageQueue({
    required DirtyPagePaint paint,
    DirtyPagePredicate? shouldPaint,
    double frameBudgetMs = 8,
  })  : _paint = paint,
        _shouldPaint = shouldPaint,
        _frameBudgetMs = frameBudgetMs;

  final DirtyPagePaint _paint;
  final DirtyPagePredicate? _shouldPaint;
  final double _frameBudgetMs;
  final Queue<int> _queue = Queue<int>();
  final Set<int> _queued = <int>{};
  bool _scheduled = false;
  int _version = 0;

  bool get isEmpty => _queue.isEmpty;

  void enqueue(int pageIndex) {
    if (_queued.add(pageIndex)) {
      _queue.add(pageIndex);
    }
    _schedule();
  }

  void remove(int pageIndex) {
    if (!_queued.remove(pageIndex)) {
      return;
    }
    _queue.remove(pageIndex);
  }

  void clear() {
    _queue.clear();
    _queued.clear();
    _scheduled = false;
    _version += 1;
  }

  void _schedule() {
    if (_scheduled || _queue.isEmpty) {
      return;
    }
    _scheduled = true;
    final int version = _version;
    window.requestAnimationFrame((_) => _drain(version));
  }

  void _drain(int version) {
    if (version != _version) {
      return;
    }
    _scheduled = false;
    if (_queue.isEmpty) {
      return;
    }

    final double start = window.performance.now();
    while (_queue.isNotEmpty) {
      final int pageIndex = _queue.removeFirst();
      _queued.remove(pageIndex);
      if (_shouldPaint?.call(pageIndex) ?? true) {
        _paint(pageIndex);
      }
      if (_queue.isNotEmpty &&
          window.performance.now() - start > _frameBudgetMs) {
        _schedule();
        return;
      }
    }
  }
}
