import 'dart:io';
import 'dart:typed_data';

import 'package:canvas_text_editor/ce_pdf.dart';

/// Utilitário de diagnóstico para empacotar JPEGs de página em um PDF.
///
/// Uso: dart run tool/build_raster_pdf.dart saida.pdf pagina1.jpg pagina2.jpg
void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln(
        'Uso: dart run tool/build_raster_pdf.dart saida.pdf pagina1.jpg [...]');
    exitCode = 64;
    return;
  }
  final List<Uint8List> pages = <Uint8List>[
    for (final String path in args.skip(1)) File(path).readAsBytesSync(),
  ];
  final Uint8List pdf = RasterPdfEncoder.encode(
    pages,
    title: 'Raster PDF smoke test',
  );
  final File output = File(args.first)..createSync(recursive: true);
  output.writeAsBytesSync(pdf, flush: true);
  stdout
      .writeln('${output.path}: ${pdf.length} bytes, ${pages.length} páginas');
}
