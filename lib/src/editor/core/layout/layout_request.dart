import 'layout_invalidation.dart';

/// Pedido de atualizacao produzido por um comando, sem chamada direta ao
/// pipeline global de Draw.
class LayoutRequest {
  const LayoutRequest({
    required this.invalidation,
    this.curIndex,
    this.setCursor = true,
    this.submitHistory = false,
    this.sourceHistory = false,
    this.notifyContentChange = false,
  });

  final LayoutInvalidation invalidation;
  final int? curIndex;
  final bool setCursor;
  final bool submitHistory;
  final bool sourceHistory;
  final bool notifyContentChange;
}
