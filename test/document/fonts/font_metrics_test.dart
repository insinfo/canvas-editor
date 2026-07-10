import 'dart:typed_data';

import 'package:canvas_text_editor/ce_fonts.dart';
import 'package:test/test.dart';

void main() {
  group('FontRegistry (métricas embarcadas)', () {
    test('Arial resolve com métricas plausíveis', () {
      final FontMetrics? m = FontRegistry.instance.lookup('Arial');
      expect(m, isNotNull);
      expect(m!.unitsPerEm, 2048);
      // single line ~1.15em (ascent+descent+lineGap)/unitsPerEm.
      expect(m.singleLineEm, closeTo(1.15, 0.01));
    });

    test('substituição Ecofont → Arial', () {
      final FontMetrics? eco =
          FontRegistry.instance.lookup('Ecofont_Spranq_eco_Sans');
      final FontMetrics? arial = FontRegistry.instance.lookup('Arial');
      expect(eco, isNotNull);
      expect(identical(eco, arial), isTrue);
    });

    test('família desconhecida → null (fallback canvas)', () {
      expect(FontRegistry.instance.lookup('Wingdings XYZ'), isNull);
    });

    test('pilha CSS e aspas são normalizadas', () {
      expect(FontRegistry.instance.lookup('"Arial", sans-serif'), isNotNull);
    });
  });

  group('measureWidth (Arial)', () {
    final FontMetrics m = FontRegistry.instance.lookup('Arial')!;

    test('largura de avanço proporcional ao tamanho', () {
      final double w16 = m.measureWidth('Hello', 16);
      final double w32 = m.measureWidth('Hello', 32);
      expect(w32, closeTo(w16 * 2, 0.001));
    });

    test('espaço mede a largura de avanço do glifo espaço', () {
      // Arial: espaço = 569 unidades; a 2048 upem em 20px → ~5.56px.
      final double w = m.measureWidth(' ', 20);
      expect(w, closeTo(569 * 20 / 2048, 0.01));
    });

    test('string vazia mede zero', () {
      expect(m.measureWidth('', 16), 0);
    });

    test('acentos pt-BR têm métrica (não caem no default)', () {
      // "ção" deve medir perto de c+~+a+o com cedilha/til reais.
      final double comAcento = m.measureWidth('ção', 16);
      final double semAcento = m.measureWidth('cao', 16);
      expect(comAcento, greaterThan(0));
      // largura semelhante (acentos não mudam o avanço horizontal no Arial).
      expect(comAcento, closeTo(semAcento, 0.5));
    });
  });

  group('parseTtfMetrics (robustez)', () {
    test('bytes inválidos lançam FontParseException', () {
      // sfnt version + numTables=0 → head ausente.
      final Uint8List fake =
          Uint8List.fromList(<int>[0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
      expect(
        () => parseTtfMetrics(fake),
        throwsA(isA<FontParseException>()),
      );
    });
  });
}
