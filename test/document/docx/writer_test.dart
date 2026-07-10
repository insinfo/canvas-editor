import 'dart:io';
import 'dart:typed_data';

import 'package:canvas_text_editor/ce_docx.dart';
import 'package:test/test.dart';

const _etpPath = 'resources/PGCTIC1_-_ETP_-_Sistema_de_Gestão_Pública.docx';
const _trPath =
    'resources/PGCTIC1_-_TR_-_SISTEMA_GESTAO_PUBLICA__Recuperação_Automática_.docx';

Uint8List _read(String path) =>
    Uint8List.fromList(File(path).readAsBytesSync());

void main() {
  for (final (label, path) in [('ETP', _etpPath), ('TR', _trPath)]) {
    group('round-trip $label (aceite F3/G2)', () {
      late Uint8List original;

      setUpAll(() {
        original = _read(path);
      });

      test('document.xml regenerado sem edição é byte-idêntico', () {
        final file = DocxReader.read(original);
        final rebuilt = DocxWriter.buildDocumentXml(file);
        expect(rebuilt, file.package.partString(file.mainPartName),
            reason: 'passthrough D1 deve reproduzir o body inteiro');
      });

      test('abrir → salvar sem edição = arquivo byte-idêntico', () {
        final file = DocxReader.read(original);
        final saved = DocxWriter.write(file);
        expect(saved.length, original.length);
        for (var i = 0; i < saved.length; i++) {
          if (saved[i] != original[i]) fail('bytes divergem no offset $i');
        }
      });

      test('validador estrutural aprova o arquivo salvo', () {
        final saved = DocxWriter.write(DocxReader.read(original));
        expect(DocxValidator.validate(saved), isEmpty);
      });

      test('editar 1 parágrafo: mudança localizada + reabre com o novo texto',
          () {
        final file = DocxReader.read(original);
        final body = file.document.body;
        final index = body.indexWhere(
            (block) => block is WpParagraph && block.text.trim().length > 20);
        expect(index, greaterThanOrEqualTo(0));
        final paragraph = body[index] as WpParagraph;

        const newText = 'Parágrafo editado pelo round-trip F3.';
        body[index] = WpParagraph(
          properties: paragraph.properties,
          inlines: [
            WpRun(
              properties: paragraph.allRuns.firstOrNull?.properties,
              content: [WpText(newText)],
            )
          ],
        );

        // Só o bloco editado muda no document.xml.
        final fresh = DocxReader.read(original);
        final before = [
          for (final block in fresh.document.body)
            DocxWriter.serializeBlock(block)
        ];
        final after = [
          for (final block in body) DocxWriter.serializeBlock(block)
        ];
        expect(after.length, before.length);
        var diffs = 0;
        for (var i = 0; i < before.length; i++) {
          if (before[i] != after[i]) diffs++;
        }
        expect(diffs, 1, reason: 'apenas o parágrafo editado deve mudar');

        final saved = DocxWriter.write(file);
        expect(DocxValidator.validate(saved), isEmpty);

        final reopened = DocxReader.read(saved);
        expect(
            reopened.document.allParagraphs
                .any((p) => p.text.contains(newText)),
            isTrue);

        // Partes não editadas continuam byte a byte idênticas.
        for (final name in reopened.package.partNames) {
          if (name == file.mainPartName) continue;
          expect(
              reopened.package.partBytes(name), fresh.package.partBytes(name),
              reason: name);
        }
      });
    });
  }

  group('serializer do modelo', () {
    test('parágrafo com pPr/rPr completo re-parseia com a mesma estrutura', () {
      final paragraph = WpParagraph(
        properties: const WpParagraphProperties(
          styleId: 'Nivel01',
          numPr: WpNumPr(numId: 11, ilvl: 2),
          jc: 'both',
          spacing: WpSpacing(
              beforeTwips: 240, afterTwips: 120, line: 276, lineRule: 'auto'),
          indent: WpIndent(leftTwips: 709, firstLineTwips: 0),
          keepNext: true,
          tabs: [WpTabStop(val: 'left', posTwips: 708, leader: 'dot')],
        ),
        inlines: [
          WpRun(
            properties: const WpRunProperties(
              fontAscii: 'Arial',
              fontHAnsi: 'Arial',
              bold: true,
              italic: false,
              sizeHalfPoints: 20,
              color: 'FF0000',
              underline: 'single',
            ),
            content: [WpText(' texto com espaços ')],
          ),
          WpRun(content: [WpTabChar(), WpBreak('page')]),
        ],
      );
      final xml = DocxWriter.serializeParagraph(paragraph);
      expect(xml, contains('<w:pStyle w:val="Nivel01"/>'));
      expect(
          xml,
          contains('<w:numPr><w:ilvl w:val="2"/>'
              '<w:numId w:val="11"/></w:numPr>'));
      expect(xml, contains('<w:jc w:val="both"/>'));
      expect(xml, contains('<w:i w:val="0"/>'));
      expect(xml, contains('<w:t xml:space="preserve"> texto com espaços '));
      expect(xml, contains('<w:br w:type="page"/>'));

      // Reparse pelo próprio reader (via DOM) mantém a estrutura.
      final reparsed = DocxReader.read(_wrapInDocx(xml));
      final p = reparsed.document.allParagraphs.first;
      expect(p.properties?.styleId, 'Nivel01');
      expect(p.properties?.numPr?.numId, 11);
      expect(p.properties?.numPr?.ilvl, 2);
      expect(p.text, ' texto com espaços ');
      final run = p.allRuns.first;
      expect(run.properties?.bold, isTrue);
      expect(run.properties?.italic, isFalse);
      expect(run.properties?.sizeHalfPoints, 20);
    });

    test('tabela do modelo re-parseia com grid, merges e shading', () {
      final table = WpTable(
        properties: const WpTableProperties(
          width: WpTableWidth(value: 5000, type: 'pct'),
          borders: WpBorders(
            top: WpBorder(val: 'single', sizeEighths: 4, color: '000000'),
            insideH: WpBorder(val: 'single', sizeEighths: 4, color: '000000'),
          ),
        ),
        gridColumnsTwips: const [3000, 3000, 3000],
        rows: [
          WpTableRow(
            properties: const WpTableRowProperties(
                heightTwips: 400, heightRule: 'atLeast', tblHeader: true),
            cells: [
              WpTableCell(
                properties: const WpTableCellProperties(
                  gridSpan: 2,
                  shading: WpShading(fill: 'D9D9D9'),
                  vAlign: 'center',
                ),
                blocks: [
                  WpParagraph(inlines: [
                    WpRun(content: [WpText('Cabeçalho')])
                  ])
                ],
              ),
              WpTableCell(
                properties: const WpTableCellProperties(vMerge: 'restart'),
                blocks: [],
              ),
            ],
          ),
        ],
      );
      final xml = DocxWriter.serializeTable(table);
      final reparsed = DocxReader.read(_wrapInDocx(xml));
      final parsed = reparsed.document.allTables.first;
      expect(parsed.gridColumnsTwips, [3000, 3000, 3000]);
      final firstRow = parsed.rows.first;
      expect(firstRow.properties?.tblHeader, isTrue);
      expect(firstRow.cells.first.properties?.gridSpan, 2);
      expect(firstRow.cells.first.properties?.shading?.fill, 'D9D9D9');
      expect(firstRow.cells.last.properties?.vMerge, 'restart');
    });
  });

  group('validador estrutural (negativos)', () {
    test('detecta rel quebrado e estilo inexistente', () {
      final file = DocxReader.read(_read(_etpPath));
      // Quebra: remove styles.xml (pStyle passa a apontar para nada).
      file.package.removePart('word/styles.xml');
      final problems = DocxValidator.validate(file.package.save());
      expect(problems, isNotEmpty);
      expect(
          problems.any((p) =>
              p.contains('estilo inexistente') || p.contains('inexistente')),
          isTrue);
    });
  });
}

/// Envolve blocos num .docx mínimo para testes do serializer.
Uint8List _wrapInDocx(String bodyBlocks) {
  final etp = DocxReader.read(_read(_etpPath));
  final xml = etp.documentBodyPrefix + bodyBlocks + etp.documentBodySuffix;
  etp.package.setPartString(etp.mainPartName, xml);
  return etp.package.save();
}
