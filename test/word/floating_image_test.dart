import 'dart:io';
import 'dart:typed_data';

import 'package:canvas_text_editor/src/editor/dataset/enum/common.dart';
import 'package:canvas_text_editor/src/editor/dataset/enum/element.dart';
import 'package:canvas_text_editor/src/editor/interface/element.dart';
import 'package:canvas_text_editor/src/word/docx_to_element.dart';
import 'package:canvas_text_editor/src/word/element_to_docx.dart';
import 'package:canvas_text_editor/ce_docx.dart';
import 'package:test/test.dart';

const _etpPath = 'resources/PGCTIC1_-_ETP_-_Sistema_de_Gestão_Pública.docx';

// PNG 1×1 transparente.
const _pngDataUrl = 'data:image/png;base64,'
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8'
    'z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

Uint8List _read(String path) =>
    Uint8List.fromList(File(path).readAsBytesSync());

({DocxFile file, DocxConversionResult original, DocxConversionResult current})
    _openTwice(Uint8List bytes) {
  final fileA = DocxReader.read(bytes);
  final original = DocxToElementConverter.convert(fileA);
  final fileB = DocxReader.read(bytes);
  final current = DocxToElementConverter.convert(fileB);
  return (file: fileB, original: original, current: current);
}

int _findParagraphTextIndex(List<IElement> elements) {
  for (var i = 0; i < elements.length; i++) {
    final e = elements[i];
    if (e.type == null &&
        e.value != '\n' &&
        e.value.trim().length > 20 &&
        e.externalId != null) {
      return i;
    }
  }
  fail('nenhum elemento de texto de parágrafo encontrado');
}

IElement? _findImage(List<IElement> elements, bool Function(IElement) test) {
  for (final e in elements) {
    if (e.type == ElementType.image && test(e)) return e;
  }
  return null;
}

void main() {
  group('imagem flutuante (wp:anchor) round-trip', () {
    late Uint8List original;

    setUpAll(() => original = _read(_etpPath));

    test(
        'inserir imagem floatTop no editor → salvar grava wp:anchor '
        'wrapNone e reabre como floatTop', () {
      final env = _openTwice(original);
      final index = _findParagraphTextIndex(env.current.main);
      final image = IElement(
        type: ElementType.image,
        value: _pngDataUrl,
        width: 120,
        height: 80,
      )
        ..imgDisplay = ImageDisplay.floatTop
        ..imgFloatPosition = <String, num>{'x': 200, 'y': 300, 'pageNo': 0};
      env.current.main.insert(index, image);

      EditorToDocx.apply(env.file, env.current.main, env.original.main);
      final saved = DocxWriter.write(env.file);
      expect(DocxValidator.validate(saved), isEmpty);

      final xml = String.fromCharCodes(
          DocxReader.read(saved).package.partBytes('word/document.xml')!);
      expect(xml, contains('<wp:anchor'));
      expect(xml, contains('<wp:wrapNone/>'));
      expect(xml, contains('behindDoc="0"'));
      // 200 px → 1905000 EMU; 300 px → 2857500 EMU.
      expect(xml, contains('<wp:posOffset>1905000</wp:posOffset>'));
      expect(xml, contains('<wp:posOffset>2857500</wp:posOffset>'));

      final reopened = DocxToElementConverter.convert(DocxReader.read(saved));
      final reImage = _findImage(
          reopened.main, (e) => e.imgDisplay == ImageDisplay.floatTop);
      expect(reImage, isNotNull, reason: 'floatTop deve sobreviver ao reopen');
      final anchor = (reImage!.extension as Map)['wpAnchor'] as Map;
      expect(anchor['hRel'], 'page');
      expect((anchor['x'] as num).toDouble(), closeTo(200, 0.5));
      expect((anchor['y'] as num).toDouble(), closeTo(300, 0.5));
    });

    test('trocar wrap p/ surround e behindDoc no 2º save', () {
      final env = _openTwice(original);
      final index = _findParagraphTextIndex(env.current.main);
      final image = IElement(
        type: ElementType.image,
        value: _pngDataUrl,
        width: 120,
        height: 80,
      )
        ..imgDisplay = ImageDisplay.floatBottom
        ..imgFloatPosition = <String, num>{'x': 50, 'y': 60, 'pageNo': 0};
      env.current.main.insert(index, image);
      EditorToDocx.apply(env.file, env.current.main, env.original.main);
      final saved = DocxWriter.write(env.file);
      final xml = String.fromCharCodes(
          DocxReader.read(saved).package.partBytes('word/document.xml')!);
      expect(xml, contains('behindDoc="1"'));

      // Reabre e troca o modo para surround (como a toolbar contextual faz).
      final env2 = _openTwice(saved);
      final img = _findImage(
          env2.current.main, (e) => e.imgDisplay == ImageDisplay.floatBottom);
      expect(img, isNotNull);
      img!
        ..imgDisplay = ImageDisplay.surround
        ..imgFloatPosition = <String, num>{'x': 90, 'y': 110, 'pageNo': 0};
      EditorToDocx.apply(env2.file, env2.current.main, env2.original.main);
      final saved2 = DocxWriter.write(env2.file);
      expect(DocxValidator.validate(saved2), isEmpty);
      final xml2 = String.fromCharCodes(
          DocxReader.read(saved2).package.partBytes('word/document.xml')!);
      expect(xml2, contains('<wp:wrapSquare wrapText="bothSides"/>'));
      expect(xml2, contains('behindDoc="0"'));

      final reopened = DocxToElementConverter.convert(DocxReader.read(saved2));
      final reImage = _findImage(
          reopened.main, (e) => e.imgDisplay == ImageDisplay.surround);
      expect(reImage, isNotNull,
          reason: 'surround (wrapSquare) deve sobreviver ao reopen');
    });

    test('sem edição → save byte-idêntico continua valendo', () {
      final env = _openTwice(original);
      EditorToDocx.apply(env.file, env.current.main, env.original.main);
      final saved = DocxWriter.write(env.file);
      expect(saved.length, original.length);
    });
  });
}
