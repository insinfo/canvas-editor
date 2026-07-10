// Gerador das métricas de fonte embarcadas (D4/F4.10).
//
// Lê os TTF do sistema (ou de um caminho fornecido), extrai as métricas
// compactas (unitsPerEm + hhea/OS2 + avanços por codepoint no intervalo
// necessário) e emite `lib/src/document/fonts/metrics_data.dart`.
//
// Uso: dart run tool/gen_font_metrics.dart
//
// Só precisa ser reexecutado ao trocar o conjunto de fontes/codepoints; a
// saída é commitada para o runtime não depender de arquivos de fonte.

import 'dart:io';
import 'dart:typed_data';

import 'package:canvas_text_editor/ce_fonts.dart';

/// Fontes a embarcar: família (nome CSS) → caminhos candidatos do TTF.
const Map<String, List<String>> _fonts = <String, List<String>>{
  'arial': <String>[
    r'C:\Windows\Fonts\arial.ttf',
    '/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf',
  ],
  'times new roman': <String>[
    r'C:\Windows\Fonts\times.ttf',
    '/usr/share/fonts/truetype/liberation/LiberationSerif-Regular.ttf',
  ],
  'courier new': <String>[
    r'C:\Windows\Fonts\cour.ttf',
    '/usr/share/fonts/truetype/liberation/LiberationMono-Regular.ttf',
  ],
};

// Símbolos/pontuação fora de 0x20–0x24F que os DOCX de resources/ usam.
const List<int> _extraCodepoints = <int>[
  0x2013, 0x2014, // en/em dash
  0x2018, 0x2019, // aspas simples curvas
  0x201C, 0x201D, // aspas duplas curvas
  0x2022, // bullet
  0x2026, // reticências
  0x2039, 0x203A, // ‹ ›
  0x20AC, // €
  0x2122, // ™
  0x2212, // minus
  0x202F, // narrow nbsp
];

void main() {
  final StringBuffer out = StringBuffer();
  out.writeln('// GERADO por tool/gen_font_metrics.dart — não editar à mão.');
  out.writeln('// Métricas TTF compactas para layout determinístico '
      '(D4/F4.10).');
  out.writeln("import 'font_metrics.dart';");
  out.writeln("import 'font_registry.dart';");
  out.writeln();
  out.writeln('void registerEmbeddedFonts(FontRegistry registry) {');

  var embedded = 0;
  for (final MapEntry<String, List<String>> entry in _fonts.entries) {
    final String? path = entry.value.cast<String?>().firstWhere(
        (String? p) => p != null && File(p).existsSync(),
        orElse: () => null);
    if (path == null) {
      stderr.writeln('[gen] pulando ${entry.key}: TTF não encontrado');
      continue;
    }
    final Uint8List bytes = File(path).readAsBytesSync();
    final FontMetrics m =
        parseTtfMetrics(bytes, extraCodepoints: _extraCodepoints);
    final List<int> packed = <int>[];
    final List<int> cps = m.advanceWidths.keys.toList()..sort();
    for (final int cp in cps) {
      packed
        ..add(cp)
        ..add(m.advanceWidths[cp]!);
    }
    stdout.writeln('[gen] ${entry.key}: unitsPerEm=${m.unitsPerEm} '
        'ascent=${m.ascent} descent=${m.descent} lineGap=${m.lineGap} '
        'single=${m.singleLineEm.toStringAsFixed(4)}em '
        'glyphs=${cps.length} (de $path)');
    out.writeln("  registry.register('${entry.key}',");
    out.writeln('      FontMetrics.fromPacked(');
    out.writeln('        unitsPerEm: ${m.unitsPerEm},');
    out.writeln('        ascent: ${m.ascent},');
    out.writeln('        descent: ${m.descent},');
    out.writeln('        lineGap: ${m.lineGap},');
    out.writeln('        defaultAdvance: ${m.defaultAdvance},');
    out.writeln('        packedAdvances: <int>[');
    // Empacota em linhas de ~16 pares para o arquivo não ficar gigante.
    for (int i = 0; i < packed.length; i += 32) {
      final int end = (i + 32 < packed.length) ? i + 32 : packed.length;
      out.writeln('          ${packed.sublist(i, end).join(', ')},');
    }
    out.writeln('        ],');
    out.writeln('      ));');
    embedded++;
  }

  out.writeln('}');

  final File target = File('lib/src/document/fonts/metrics_data.dart');
  target.writeAsStringSync(out.toString());
  stdout.writeln('[gen] $embedded fonte(s) → ${target.path} '
      '(${target.lengthSync()} bytes)');
}
