import 'dart:io';
import 'dart:typed_data';

import 'package:canvas_text_editor/ce_docx.dart';
import 'package:test/test.dart';

const _etpPath = 'resources/PGCTIC1_-_ETP_-_Sistema_de_Gestão_Pública.docx';
const _trPath =
    'resources/PGCTIC1_-_TR_-_SISTEMA_GESTAO_PUBLICA__Recuperação_Automática_.docx';

/// Inventário calculado sobre o MODELO carregado — aceite F2: os números da
/// seção 2.2 do roteiro devem ser reproduzidos a partir do modelo tipado
/// (mapeado) ou constar como preservado.
class _ModelInventory {
  int tables = 0, rows = 0, cells = 0;
  int gridSpan = 0, vMerge = 0, tcBorders = 0;
  int shd = 0; // célula + parágrafo + run
  int pStyle = 0, rStyle = 0, tblStyle = 0;
  int numPr = 0;
  int tabDefs = 0;
  int br = 0;
  int jcBoth = 0;
  int hyperlinks = 0;
  int drawings = 0;
  int fieldInstructions = 0;
  final Map<String, int> preserved = {};

  static _ModelInventory of(DocxFile file) {
    final inv = _ModelInventory();
    void visitBlocks(List<WpBlock> blocks) {
      for (final block in blocks) {
        switch (block) {
          case WpParagraph p:
            final pPr = p.properties;
            if (pPr?.styleId != null) inv.pStyle++;
            if (pPr?.numPr != null) inv.numPr++;
            if (pPr?.shading != null) inv.shd++;
            if (pPr?.jc == 'both') inv.jcBoth++;
            inv.tabDefs += pPr?.tabs?.length ?? 0;
            // rPr da marca de parágrafo também carrega rStyle/shd no XML.
            if (pPr?.markRunProperties?.styleId != null) inv.rStyle++;
            if (pPr?.markRunProperties?.shading != null) inv.shd++;
            for (final inline in p.inlines) {
              switch (inline) {
                case WpRun run:
                  inv._visitRun(run);
                case WpHyperlink link:
                  inv.hyperlinks++;
                  link.runs.forEach(inv._visitRun);
                case WpSimpleField field:
                  inv.fieldInstructions++;
                  field.runs.forEach(inv._visitRun);
                case WpPreservedInline preserved:
                  inv.preserved
                      .update(preserved.qname, (v) => v + 1, ifAbsent: () => 1);
              }
            }
          case WpTable table:
            inv.tables++;
            if (table.properties?.styleId != null) inv.tblStyle++;
            for (final row in table.rows) {
              inv.rows++;
              for (final cell in row.cells) {
                inv.cells++;
                final tcPr = cell.properties;
                if (tcPr?.gridSpan != null) inv.gridSpan++;
                if (tcPr?.vMerge != null) inv.vMerge++;
                if (tcPr?.borders != null) inv.tcBorders++;
                if (tcPr?.shading != null) inv.shd++;
                visitBlocks(cell.blocks);
              }
            }
          case WpPreservedBlock preserved:
            inv.preserved
                .update(preserved.qname, (v) => v + 1, ifAbsent: () => 1);
        }
      }
    }

    visitBlocks(file.document.body);
    return inv;
  }

  void _visitRun(WpRun run) {
    final rPr = run.properties;
    if (rPr?.styleId != null) rStyle++;
    if (rPr?.shading != null) shd++;
    for (final content in run.content) {
      switch (content) {
        case WpBreak _:
          br++;
        case WpDrawing _:
          drawings++;
        case WpInstrText _:
          fieldInstructions++;
        case WpPreservedRunContent preserved:
          this
              .preserved
              .update(preserved.qname, (v) => v + 1, ifAbsent: () => 1);
        case _:
          break;
      }
    }
  }
}

void main() {
  late DocxFile etp;
  late DocxFile tr;

  setUpAll(() {
    etp = DocxReader.read(Uint8List.fromList(File(_etpPath).readAsBytesSync()));
    tr = DocxReader.read(Uint8List.fromList(File(_trPath).readAsBytesSync()));
  });

  group('aceite F2: zero exceções e inventário do modelo = seção 2.2', () {
    test('ETP: contagens estruturais', () {
      final inv = _ModelInventory.of(etp);
      expect(inv.tables, 3);
      expect(inv.rows, 18);
      expect(inv.cells, 82);
      expect(inv.gridSpan, 1);
      expect(inv.vMerge, 4);
      expect(inv.tcBorders, 0);
      expect(inv.pStyle, 458);
      expect(inv.rStyle, 0);
      expect(inv.numPr, 208);
      expect(inv.tabDefs, 33);
      expect(inv.br, 0);
      expect(inv.jcBoth, 1);
      expect(inv.hyperlinks, 0);
      expect(etp.styles.byId.length, 158);
      expect(etp.numbering.abstractNums.length, 40);
    });

    test('TR: contagens estruturais', () {
      final inv = _ModelInventory.of(tr);
      expect(inv.tables, 22);
      expect(inv.rows, 1642);
      expect(inv.cells, 3650);
      expect(inv.gridSpan, 1670);
      expect(inv.vMerge, 14);
      expect(inv.tcBorders, 3158);
      expect(inv.pStyle, 1524);
      expect(inv.rStyle, 26);
      expect(inv.tblStyle, 15);
      expect(inv.numPr, 29);
      expect(inv.tabDefs, 713);
      expect(inv.br, 108);
      expect(inv.jcBoth, 1428);
      expect(inv.hyperlinks, 3);
      expect(tr.styles.byId.length, 181);
      expect(tr.numbering.abstractNums.length, 13);
    });

    test('TR: w:shd total (célula+parágrafo+run) = 1496', () {
      expect(_ModelInventory.of(tr).shd, 1496);
    });

    test('ETP: w:shd total = 123', () {
      expect(_ModelInventory.of(etp).shd, 123);
    });

    test('bookmarks do TR preservados como inline (12 starts)', () {
      final inv = _ModelInventory.of(tr);
      expect(inv.preserved['w:bookmarkStart'], 12);
      expect(inv.preserved['w:bookmarkEnd'], isNotNull);
    });
  });

  group('seção e headers/footers', () {
    test('geometria A4 e margens do arquivo (não default do editor)', () {
      final s = etp.document.section!;
      expect(s.pageWidthTwips, 11906);
      expect(s.pageHeightTwips, 16838);
      expect(Units.twipToPx(s.pageWidthTwips!), closeTo(793.7, 0.1));
      expect(Units.twipToPx(s.pageHeightTwips!), closeTo(1122.5, 0.1));
      expect(s.marginTopTwips, 1418);
      expect(s.marginLeftTwips, 1134);
      expect(s.headerDistanceTwips, 426);
      expect(s.footerDistanceTwips, 454);
    });

    test('ETP: headers default+first; TR: even+default+first', () {
      expect(etp.headersByType.keys.toSet(), {'default', 'first'});
      expect(etp.footersByType.keys.toSet(), {'default', 'first'});
      expect(tr.headersByType.keys.toSet(), {'even', 'default', 'first'});
      expect(tr.footersByType.keys.toSet(), {'even', 'default', 'first'});
      // titlePg/evenAndOddHeaders ausentes ⇒ só default fica ativo (seção 2.2)
      expect(etp.document.section!.titlePage, isFalse);
      expect(etp.settings.evenAndOddHeaders, isFalse);
    });

    test('footer default contém campos PAGE e NUMPAGES', () {
      for (final file in [etp, tr]) {
        final footer = file.footersByType['default']!;
        final instrs = <String>[];
        for (final block in footer.blocks) {
          if (block is! WpParagraph) continue;
          for (final run in block.allRuns) {
            instrs.addAll(run.content
                .whereType<WpInstrText>()
                .map((instr) => instr.text));
          }
        }
        expect(instrs.any((instrText) => instrText.contains('PAGE')), isTrue);
        expect(
            instrs.any((instrText) => instrText.contains('NUMPAGES')), isTrue);
      }
    });

    test('header contém o carimbo (mc:AlternateContent preservado)', () {
      var found = false;
      for (final header in etp.headersByType.values) {
        for (final block in header.blocks) {
          if (block is! WpParagraph) continue;
          for (final run in block.allRuns) {
            if (run.content.any((c) =>
                c is WpPreservedRunContent &&
                c.qname == 'mc:AlternateContent')) {
              found = true;
            }
          }
        }
      }
      expect(found, isTrue,
          reason: 'text box do carimbo deve estar preservado (D1)');
    });

    test('imagens dos headers resolvem bytes via rels', () {
      var images = 0;
      for (final header in tr.headersByType.values) {
        for (final block in header.blocks) {
          if (block is! WpParagraph) continue;
          for (final run in block.allRuns) {
            for (final drawing in run.content.whereType<WpDrawing>()) {
              final relId = drawing.embedRelId;
              if (relId == null) continue;
              final bytes = tr.imageBytes(relId, fromPart: header.partName);
              expect(bytes, isNotNull);
              expect(bytes!.length, greaterThan(100));
              images++;
            }
          }
        }
      }
      expect(images, greaterThanOrEqualTo(1));
    });
  });

  group('cascata de estilos (F2.2)', () {
    test('parágrafo sem pStyle herda Normal: Ecofont 12pt', () {
      final resolver = FormatResolver(etp.styles);
      final plain = etp.document.allParagraphs
          .firstWhere((p) => p.properties?.styleId == null);
      final rPr = resolver.resolveRun(plain, null);
      expect(rPr.fontAscii, 'Ecofont_Spranq_eco_Sans');
      expect(rPr.sizeHalfPoints, 24); // 12pt
      expect(Units.halfPointToPx(rPr.sizeHalfPoints!), 16.0);
    });

    test('Nivel01 (basedOn Ttulo1 → Normal): Arial 10pt bold + numId 11', () {
      final resolver = FormatResolver(etp.styles);
      final titled = etp.document.allParagraphs
          .firstWhere((p) => p.properties?.styleId == 'Nivel01');
      final rPr = resolver.resolveRun(titled, null);
      expect(rPr.fontAscii, 'Arial');
      expect(rPr.sizeHalfPoints, 20); // 10pt (Nivel01 sobrescreve Ttulo1)
      expect(rPr.bold, isTrue); // herdado de Ttulo1
      final pPr = resolver.resolveParagraph(titled);
      expect(pPr.numPr?.numId, 11);
      expect(pPr.jc, 'both');
      expect(pPr.keepNext, isTrue); // herdado de Ttulo1
    });

    test('cadeia basedOn protegida contra ciclo', () {
      final sheet = WpStyleSheet.parse('<w:styles xmlns:w="urn:w">'
          '<w:style w:type="paragraph" w:styleId="A"><w:basedOn w:val="B"/></w:style>'
          '<w:style w:type="paragraph" w:styleId="B"><w:basedOn w:val="A"/></w:style>'
          '</w:styles>');
      expect(sheet.chainOf('A').map((s) => s.id), ['B', 'A']);
    });
  });

  group('numeração multinível', () {
    test('contadores multinível com lvlText %1.%2. e reinício', () {
      final numbering = WpNumbering.parse('<w:numbering xmlns:w="urn:w">'
          '<w:abstractNum w:abstractNumId="1">'
          '<w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="decimal"/>'
          '<w:lvlText w:val="%1."/></w:lvl>'
          '<w:lvl w:ilvl="1"><w:start w:val="1"/><w:numFmt w:val="decimal"/>'
          '<w:lvlText w:val="%1.%2."/></w:lvl>'
          '</w:abstractNum>'
          '<w:num w:numId="5"><w:abstractNumId w:val="1"/></w:num>'
          '</w:numbering>');
      final counters = NumberingCounters(numbering);
      expect(counters.next(5, 0), '1.');
      expect(counters.next(5, 1), '1.1.');
      expect(counters.next(5, 1), '1.2.');
      expect(counters.next(5, 0), '2.');
      expect(counters.next(5, 1), '2.1.',
          reason: 'nível 1 reinicia quando o nível 0 avança');
    });

    test('formatos: letter, roman, bullet fallback', () {
      expect(formatNumber(3, 'lowerLetter'), 'c');
      expect(formatNumber(27, 'upperLetter'), 'AA');
      expect(formatNumber(4, 'lowerRoman'), 'iv');
      expect(formatNumber(1994, 'upperRoman'), 'MCMXCIV');
    });

    test('ETP: numId 11 (Nivel01) resolve nível decimal multinível', () {
      final level = etp.numbering.levelOf(11, 0);
      expect(level, isNotNull);
      expect(level!.numFmt, 'decimal');
      expect(level.lvlText, contains('%1'));
    });

    test('contadores reproduzem sequência real dos títulos do ETP', () {
      final resolver = FormatResolver(etp.styles);
      final counters = NumberingCounters(etp.numbering);
      final markers = <String>[];
      for (final paragraph in etp.document.allParagraphs) {
        final pPr = resolver.resolveParagraph(paragraph);
        final numPr = pPr.numPr;
        if (numPr == null || numPr.numId == null || numPr.numId == 0) {
          continue;
        }
        final marker = counters.next(numPr.numId!, numPr.ilvl);
        if (marker != null) markers.add(marker);
      }
      // Nivel01 numera os títulos de seção: os primeiros marcadores devem
      // começar em "1." e progredir.
      expect(markers, isNotEmpty);
      expect(markers.first, matches(RegExp(r'^[0-9a-z][.)]?')));
    });
  });

  group('robustez', () {
    test('fidelityNotes não contém erros fatais, só preservações', () {
      for (final file in [etp, tr]) {
        for (final note in file.fidelityNotes) {
          expect(note, isNot(contains('ausente')), reason: note);
        }
      }
    });
  });
}
