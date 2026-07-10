import 'dart:async';
import 'dart:html';

/// Base de todos os componentes de UI do `CanvasEditorWidget`.
///
/// Contrato do ciclo de vida:
/// 1. o componente constrói seu [root] uma única vez (no construtor);
/// 2. listeners de streams externas são registrados via [listen], que os
///    cancela automaticamente no descarte;
/// 3. [dispose] finaliza o componente — cancela inscrições, remove o [root]
///    do DOM e é idempotente.
abstract class UiComponent {
  Element get root;

  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];
  bool _isDisposed = false;

  bool get isDisposed => _isDisposed;

  /// Registra um listener cuja inscrição é cancelada no [dispose].
  void listen<T>(Stream<T> stream, void Function(T event) onData) {
    _subscriptions.add(stream.listen(onData));
  }

  void mountTo(Element parent) => parent.append(root);

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    for (final StreamSubscription<dynamic> subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    onDispose();
    root.remove();
  }

  /// Ponto de extensão para limpeza específica do componente, executado
  /// antes da remoção do [root].
  void onDispose() {}
}

/// Coalesce invalidações de UI em um único flush por frame de animação.
///
/// Eventos do editor (por exemplo `rangeStyleChange` a cada clique ou tecla)
/// chegam em rajadas; agendar a atualização via `requestAnimationFrame` com
/// deduplicação por identidade garante no máximo UMA escrita de DOM por
/// frame por tarefa, mantendo o ciclo de digitação/edição leve.
class UiScheduler {
  final Set<void Function()> _pending = <void Function()>{};
  int? _frameId;

  void schedule(void Function() task) {
    _pending.add(task);
    _frameId ??= window.requestAnimationFrame(_flush);
  }

  void _flush(num _) {
    _frameId = null;
    if (_pending.isEmpty) return;
    final List<void Function()> tasks = List<void Function()>.from(_pending);
    _pending.clear();
    for (final void Function() task in tasks) {
      task();
    }
  }

  void dispose() {
    final int? frameId = _frameId;
    if (frameId != null) {
      window.cancelAnimationFrame(frameId);
    }
    _frameId = null;
    _pending.clear();
  }
}
