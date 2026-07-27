import 'dart:io';
import 'dart:typed_data';

import 'package:canvas_text_editor/src/editor/dataset/enum/element.dart';
import 'package:canvas_text_editor/src/editor/dataset/enum/table/table.dart';
import 'package:canvas_text_editor/src/editor/dataset/enum/vertical_align.dart';
import 'package:canvas_text_editor/src/editor/interface/element.dart';
import 'package:canvas_text_editor/src/word/docx_to_element.dart';
import 'package:canvas_text_editor/src/word/element_to_docx.dart';
import 'package:canvas_text_editor/ce_docx.dart';
import 'package:test/test.dart';

const _etpPath = 'resources/PGCTIC1_-_ETP_-_Sistema_de_Gestão_Pública.docx';

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

IElement _firstTable(List<IElement> elements) =>
    elements.firstWhere((e) => e.type == ElementType.table);

void main() {
  group('visuais de tabela (bordas/fundo/vAlign) → DOCX', () {
    late Uint8List original;

    setUpAll(() => original = _read(_etpPath));

    test('mudar bordas p/ externas vermelhas regenera tblBorders', () {
      final env = _openTwice(original);
      final table = _firstTable(env.current.main)
        ..borderType = TableBorder.external
        ..borderColor = '#FF0000';

      // Fundo + alinhamento vertical numa célula (como a mini-toolbar faz).
      final td = table.trList!.first.tdList.first
        ..backgroundColor = '#FFEE00'
        ..verticalAlign = VerticalAlign.middle;
      expect(td.backgroundColor, '#FFEE00');

      EditorToDocx.apply(env.file, env.current.main, env.original.main);
      final saved = DocxWriter.write(env.file);
      expect(DocxValidator.validate(saved), isEmpty);

      final xml = String.fromCharCodes(
          DocxReader.read(saved).package.partBytes('word/document.xml')!);
      expect(xml, contains('w:color="FF0000"'));
      expect(xml, contains('<w:insideH w:val="none"'),
          reason: 'externas: sem bordas internas');
      expect(xml, contains('w:fill="FFEE00"'));
      expect(xml, contains('<w:vAlign w:val="center"/>'));

      // Reabre: fundo e vAlign sobrevivem; bordas externas visíveis mantêm
      // a tabela com bordas (modelo do editor colapsa p/ all/empty).
      final reopened = DocxToElementConverter.convert(DocxReader.read(saved));
      final reTable = _firstTable(reopened.main);
      final reTd = reTable.trList!.first.tdList.first;
      expect(reTd.backgroundColor?.toUpperCase(), '#FFEE00');
      expect(reTd.verticalAlign, VerticalAlign.middle);
      expect(reTable.borderColor?.toUpperCase(), '#FF0000');
    });

    test('sem edição → save byte-idêntico continua valendo', () {
      final env = _openTwice(original);
      EditorToDocx.apply(env.file, env.current.main, env.original.main);
      final saved = DocxWriter.write(env.file);
      expect(saved.length, original.length);
    });
  });
}
