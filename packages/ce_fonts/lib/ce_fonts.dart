/// Parser TTF + métricas (hmtx/cmap) para layout determinístico (D4/F4.10) e,
/// futuramente, subsetting para embedding no PDF (F7.2).
///
/// Uso no layout:
/// ```dart
/// final m = FontRegistry.instance.lookup('Arial');
/// final w = m?.measureWidth('texto', 16); // px, ou null → fallback canvas
/// ```
library;

export 'src/font_metrics.dart';
export 'src/font_registry.dart';
