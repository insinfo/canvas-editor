import 'model.dart';
import 'styles.dart';

/// Resolvedor de formatação efetiva — a cascata do Word
/// (roteiro_editor_profissional, F2.2):
/// docDefaults → cadeia basedOn do estilo de parágrafo → estilo de
/// caractere → formatação direta.
class FormatResolver {
  final WpStyleSheet styles;

  FormatResolver(this.styles);

  String? _paragraphStyleId(WpParagraph paragraph) =>
      paragraph.properties?.styleId ?? styles.defaultOf('paragraph')?.id;

  /// Propriedades efetivas do parágrafo (twips/half-points OOXML).
  WpParagraphProperties resolveParagraph(WpParagraph paragraph) {
    var result = styles.docDefaultsParagraph ?? const WpParagraphProperties();
    for (final style in styles.chainOf(_paragraphStyleId(paragraph))) {
      final pPr = style.paragraphProperties;
      if (pPr != null) result = result.mergedWith(pPr);
    }
    final direct = paragraph.properties;
    if (direct != null) result = result.mergedWith(direct);
    return result;
  }

  /// Propriedades efetivas de um run dentro de um parágrafo.
  /// [direct] são as propriedades diretas do run (podem ser nulas).
  WpRunProperties resolveRun(WpParagraph paragraph, WpRunProperties? direct) {
    var result = styles.docDefaultsRun ?? const WpRunProperties();
    for (final style in styles.chainOf(_paragraphStyleId(paragraph))) {
      final rPr = style.runProperties;
      if (rPr != null) result = result.mergedWith(rPr);
    }
    if (direct?.styleId != null) {
      for (final style in styles.chainOf(direct!.styleId)) {
        final rPr = style.runProperties;
        if (rPr != null) result = result.mergedWith(rPr);
      }
    }
    if (direct != null) result = result.mergedWith(direct);
    return result;
  }
}
