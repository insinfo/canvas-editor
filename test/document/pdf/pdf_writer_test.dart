import 'dart:convert';
import 'dart:typed_data';

import 'package:canvas_text_editor/ce_pdf.dart';
import 'package:canvas_text_editor/src/document/zip/codecs/zlib/inflate.dart';
import 'package:test/test.dart';

void main() {
  group('zlibEncode/adler32', () {
    test('produz stream zlib decodificável com Adler-32 correto', () {
      final List<int> raw = utf8.encode('canvas editor pdf ' * 50);
      final Uint8List zlib = zlibEncode(raw);
      expect(zlib[0], 0x78);
      final Uint8List inflated =
          Inflate(zlib.sublist(2, zlib.length - 4)).getBytes();
      expect(inflated, raw);
      final int checksum = adler32(raw);
      final int stored = (zlib[zlib.length - 4] << 24) |
          (zlib[zlib.length - 3] << 16) |
          (zlib[zlib.length - 2] << 8) |
          zlib[zlib.length - 1];
      expect(stored, checksum);
    });

    test('adler32 bate com valor conhecido ("Wikipedia")', () {
      expect(adler32(ascii.encode('Wikipedia')), 0x11E60398);
    });
  });

  group('encodeWinAnsi', () {
    test('preserva ASCII e Latin-1 (pt-BR completo)', () {
      const String texto = 'Ação já é possível: à, ê, õ, ü, ç — “aspas”…';
      final String encoded = encodeWinAnsi(texto);
      expect(encoded.codeUnits.every((int c) => c <= 0xff), isTrue);
      expect(encoded, contains('ç'));
      expect(encoded.codeUnits, contains(0x97)); // — em dash → 0x97
      expect(encoded.codeUnits, contains(0x93)); // “ → 0x93
      expect(encoded.codeUnits, contains(0x85)); // … → 0x85
    });

    test('remove zero-width e aproxima símbolos sem glifo', () {
      expect(encodeWinAnsi('a​b'), 'ab');
      expect(encodeWinAnsi('✓'), 'v');
      expect(encodeWinAnsi('日本'), '??');
    });
  });

  group('standardFontFor', () {
    test('mapeia famílias para standard-14 com estilo', () {
      expect(standardFontFor(family: 'Arial'), 'Helvetica');
      expect(standardFontFor(family: 'Arial', bold: true), 'Helvetica-Bold');
      expect(standardFontFor(family: 'Times New Roman', italic: true),
          'Times-Italic');
      expect(standardFontFor(family: 'Courier New', bold: true, italic: true),
          'Courier-BoldOblique');
      expect(standardFontFor(family: null), 'Helvetica');
    });
  });

  group('PdfWriter', () {
    test('gera documento com página, fonte, texto e xref consistente', () {
      final PdfWriter writer = PdfWriter();
      final PdfContentBuilder content =
          PdfContentBuilder(pageHeightPt: 842, k: 0.75);
      content.text(
        fontResource: writer.fontResourceName('Helvetica'),
        sizePx: 16,
        winAnsiText: encodeWinAnsi('Olá, PDF vetorial!'),
        x: 100,
        baselineY: 120,
        color: '#1a2b3c',
      );
      content.fillRect(50, 50, 200, 20, '#ffff00');
      content.strokeLine(0, 0, 100, 0, color: '#d9d9d9', widthPx: 1);
      writer.addPage(
        widthPt: 595,
        heightPt: 842,
        content: content.build(),
      );
      final Uint8List pdf = writer.build(title: 'Vetor (α)');
      final String text = latin1.decode(pdf, allowInvalid: true);

      expect(pdf.sublist(0, 8), ascii.encode('%PDF-1.4'));
      expect(text, contains('/Type /Catalog'));
      expect(text, contains('/Type /Pages /Count 1'));
      expect(text, contains('/BaseFont /Helvetica'));
      expect(text, contains('/Encoding /WinAnsiEncoding'));
      expect(text, contains('/MediaBox [0 0 595 842]'));
      expect(text, contains('/Filter /FlateDecode'));
      expect(text, endsWith('%%EOF\n'));

      // Content stream comprimido deve conter o texto ao inflar.
      final RegExp streamReg = RegExp('stream\n');
      final Iterable<Match> streams = streamReg.allMatches(text);
      expect(streams, isNotEmpty);
      final int start = streams.first.end;
      final int end = text.indexOf('\nendstream', start);
      final Uint8List zlib =
          Uint8List.fromList(latin1.encode(text.substring(start, end)));
      final String ops =
          latin1.decode(Inflate(zlib.sublist(2, zlib.length - 4)).getBytes());
      expect(ops, contains('BT'));
      expect(ops, contains('/F1 12 Tf'));
      expect(ops, contains('Tj'));
      expect(ops, contains('re f'));
    });

    test('anotação de link entra na página', () {
      final PdfWriter writer = PdfWriter();
      final int annot = writer.addLinkAnnotation(
          <double>[10, 10, 100, 30], 'https://example.com');
      writer.addPage(
        widthPt: 595,
        heightPt: 842,
        content: 'q Q'.codeUnits,
        annotationIds: <int>[annot],
      );
      final String text =
          latin1.decode(writer.build(), allowInvalid: true);
      expect(text, contains('/Subtype /Link'));
      expect(text, contains('/URI (https://example.com)'));
      expect(text, contains('/Annots ['));
    });
  });

  group('decodeImageBytes', () {
    test('JPEG 1x1: DCTDecode passthrough', () {
      final Uint8List jpeg = base64Decode(
        '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////2wBDAf//////////////////////////////////////////////////////////////////////////////////////wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAX/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIQAxAAAAF//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABBQJ//8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAgBAwEBPwF//8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAgBAgEBPwF//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQAGPwJ//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPyF//9oADAMBAAIAAwAAABD/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oACAEDAQE/EH//xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oACAECAQE/EH//xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oACAEBAAE/EH//2Q==',
      );
      final PdfImageData? image = decodeImageBytes(jpeg);
      expect(image, isNotNull);
      expect(image!.width, 1);
      expect(image.height, 1);
      expect(image.filter, '/DCTDecode');
      expect(image.colorSpace, '/DeviceRGB');
    });

    test('PNG RGB: passthrough Flate com Predictor 15', () {
      final Uint8List png = _buildPng(
        width: 2,
        height: 2,
        colorType: 2,
        pixelBytes: <int>[
          // duas scanlines com filtro 0
          0, 255, 0, 0, 0, 255, 0, //
          0, 0, 0, 255, 255, 255, 255,
        ],
      );
      final PdfImageData? image = decodeImageBytes(png);
      expect(image, isNotNull);
      expect(image!.filter, '/FlateDecode');
      expect(image.colorSpace, '/DeviceRGB');
      expect(image.decodeParms, contains('/Predictor 15'));
      expect(image.smask, isNull);
    });

    test('PNG RGBA: separa cor e SMask', () {
      final Uint8List png = _buildPng(
        width: 1,
        height: 1,
        colorType: 6,
        pixelBytes: <int>[0, 10, 20, 30, 128],
      );
      final PdfImageData? image = decodeImageBytes(png);
      expect(image, isNotNull);
      expect(image!.smask, isNotNull);
      // Inflar cor e alfa e conferir os bytes.
      Uint8List inflate(Uint8List zlib) =>
          Inflate(zlib.sublist(2, zlib.length - 4)).getBytes();
      expect(inflate(image.data), <int>[10, 20, 30]);
      expect(inflate(image.smask!.data), <int>[128]);
    });

    test('formato desconhecido retorna null', () {
      expect(decodeImageBytes(Uint8List.fromList(<int>[1, 2, 3, 4])), isNull);
    });
  });
}

/// Monta um PNG mínimo (sem CRCs válidos não — CRC é ignorado pelo decoder,
/// mas escreve mesmo assim zeros) com uma única IDAT zlib.
Uint8List _buildPng({
  required int width,
  required int height,
  required int colorType,
  required List<int> pixelBytes,
}) {
  final BytesBuilder out = BytesBuilder()
    ..add(<int>[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  void chunk(String type, List<int> data) {
    out.add(<int>[
      (data.length >> 24) & 0xff,
      (data.length >> 16) & 0xff,
      (data.length >> 8) & 0xff,
      data.length & 0xff,
    ]);
    out.add(ascii.encode(type));
    out.add(data);
    out.add(const <int>[0, 0, 0, 0]); // CRC não verificado
  }

  chunk('IHDR', <int>[
    (width >> 24) & 0xff, (width >> 16) & 0xff, (width >> 8) & 0xff,
    width & 0xff, //
    (height >> 24) & 0xff, (height >> 16) & 0xff, (height >> 8) & 0xff,
    height & 0xff,
    8, colorType, 0, 0, 0,
  ]);
  chunk('IDAT', zlibEncode(pixelBytes));
  chunk('IEND', const <int>[]);
  return out.takeBytes();
}
