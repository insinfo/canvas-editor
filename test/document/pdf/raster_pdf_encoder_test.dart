import 'dart:convert';
import 'dart:typed_data';

import 'package:canvas_text_editor/ce_pdf.dart';
import 'package:test/test.dart';

void main() {
  // JPEG baseline 1 x 1 usado apenas para validar a estrutura do container.
  final Uint8List jpeg = base64Decode(
    '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////2wBDAf//////////////////////////////////////////////////////////////////////////////////////wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAX/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIQAxAAAAF//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABBQJ//8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAgBAwEBPwF//8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAgBAgEBPwF//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQAGPwJ//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPyF//9oADAMBAAIAAwAAABD/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oACAEDAQE/EH//xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oACAECAQE/EH//xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oACAEBAAE/EH//2Q==',
  );

  test('gera PDF multipágina válido com JPEGs sem reamostragem', () {
    final Uint8List pdf = RasterPdfEncoder.encode(
      <Uint8List>[jpeg, jpeg],
      title: r'Documento (teste) \ PDF',
    );
    final String text = latin1.decode(pdf, allowInvalid: true);

    expect(pdf.sublist(0, 8), ascii.encode('%PDF-1.4'));
    expect(text, contains('/Type /Catalog'));
    expect(text, contains('/Type /Pages /Count 2'));
    expect(RegExp(r'/Subtype /Image').allMatches(text), hasLength(2));
    expect(RegExp(r'/Type /Page\b').allMatches(text), hasLength(2));
    expect(text, contains(r'/Title (Documento \(teste\) \\ PDF)'));
    expect(text, endsWith('%%EOF\n'));
  });

  test('rejeita lista vazia e dados que não são JPEG', () {
    expect(() => RasterPdfEncoder.encode(const <Uint8List>[]),
        throwsArgumentError);
    expect(
      () => RasterPdfEncoder.encode(<Uint8List>[
        Uint8List.fromList(<int>[1])
      ]),
      throwsFormatException,
    );
  });
}
