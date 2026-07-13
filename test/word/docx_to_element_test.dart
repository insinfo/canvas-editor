import 'dart:io';
import 'dart:typed_data';

import 'package:canvas_text_editor/src/editor/dataset/enum/element.dart';
import 'package:canvas_text_editor/src/editor/dataset/enum/row.dart';
import 'package:canvas_text_editor/src/editor/dataset/enum/table/table.dart';
import 'package:canvas_text_editor/src/editor/interface/element.dart';
import 'package:canvas_text_editor/src/word/docx_to_element.dart';
import 'package:canvas_text_editor/ce_docx.dart';
import 'package:test/test.dart';

const _etpPath = 'resources/PGCTIC1_-_ETP_-_Sistema_de_Gestão_Pública.docx';
const _trPath =
    'resources/PGCTIC1_-_TR_-_SISTEMA_GESTAO_PUBLICA__Recuperação_Automática_.docx';

DocxConversionResult _convert(String path) => DocxToElementConverter.convert(
    DocxReader.read(Uint8List.fromList(File(path).readAsBytesSync())));

int _countType(List<IElement> elements, ElementType type) {
  var count = 0;
  for (final element in elements) {
    if (element.type == type) count++;
    final children = element.valueList;
    if (children != null) count += _countType(children, type);
    final trList = element.trList;
    if (trList != null) {
      for (final tr in trList) {
        for (final td in tr.tdList) {
          count += _countType(td.value, type);
        }
      }
    }
  }
  return count;
}

String _plainText(List<IElement> elements) {
  final buffer = StringBuffer();
  for (final element in elements) {
    if (element.type == null ||
        element.type == ElementType.superscript ||
        element.type == ElementType.subscript) {
      buffer.write(element.value);
    }
    final children = element.valueList;
    if (children != null) buffer.write(_plainText(children));
    final trList = element.trList;
    if (trList != null) {
      for (final tr in trList) {
        for (final td in tr.tdList) {
          buffer.write(_plainText(td.value));
        }
      }
    }
  }
  return buffer.toString();
}

void main() {
  late DocxConversionResult etp;
  late DocxConversionResult tr;

  setUpAll(() {
    etp = _convert(_etpPath);
    tr = _convert(_trPath);
  });

  group('aceite F2.3: conversão sem exceções e estrutura fiel', () {
    test('geometria da página vem do arquivo (não do default do editor)', () {
      for (final result in [etp, tr]) {
        expect(result.pageWidthPx, closeTo(793.7, 0.1));
        expect(result.pageHeightPx, closeTo(1122.5, 0.1));
        expect(result.marginsPx[0], closeTo(94.5, 0.1)); // top 1418 twips
        expect(result.marginsPx[3], closeTo(75.6, 0.1)); // left 1134 twips
      }
    });

    test('ETP: 3 tabelas, sem hyperlinks, conteúdo textual presente', () {
      expect(_countType(etp.main, ElementType.table), 3);
      expect(_countType(etp.main, ElementType.hyperlink), 0);
      final text = _plainText(etp.main);
      expect(text.length, greaterThan(10000));
      expect(text, contains('ESTUDO TÉCNICO PRELIMINAR'));
    });

    test('TR: 22 tabelas top-level convertidas e 3 hyperlinks', () {
      expect(_countType(tr.main, ElementType.table), lessThanOrEqualTo(22));
      expect(_countType(tr.main, ElementType.table), greaterThanOrEqualTo(20));
      expect(_countType(tr.main, ElementType.hyperlink), 3);
      final text = _plainText(tr.main);
      expect(text, contains('TERMO DE REFERÊNCIA'));
    });

    test('F4.6: variantes first/even de header/footer expostas na conversão',
        () {
      // ETP: default+first; TR: default+first+even. Nos dois, titlePg e
      // evenAndOddHeaders estão DESLIGADOS — a renderização continua só com
      // o default, mas as variantes ficam convertidas e disponíveis.
      expect(etp.headerFirst, isNotNull);
      expect(etp.titlePage, isFalse);
      expect(tr.headerFirst, isNotNull);
      expect(tr.headerEven, isNotNull);
      expect(tr.footerEven, isNotNull);
      expect(tr.titlePage, isFalse);
      expect(tr.evenAndOddHeaders, isFalse);
      expect(
        tr.notes.any((n) => n.contains('variante inativa')),
        isTrue,
      );
    });

    test('TR: tabela grande tem merges resolvidos (colspan/rowspan)', () {
      final tables = <IElement>[
        for (final e in tr.main)
          if (e.type == ElementType.table) e
      ];
      var colspanCells = 0;
      var rowspanCells = 0;
      var totalCells = 0;
      for (final table in tables) {
        for (final row in table.trList!) {
          for (final td in row.tdList) {
            totalCells++;
            if (td.colspan > 1) colspanCells++;
            if (td.rowspan > 1) rowspanCells++;
          }
        }
      }
      // 3650 células no XML; as vMerge "continue" são absorvidas.
      expect(totalCells, greaterThan(3000));
      expect(colspanCells, greaterThan(1000)); // 1670 gridSpan no XML
      expect(rowspanCells, greaterThanOrEqualTo(2)); // 4 restarts no TR
    });

    test('células com sombreamento e alinhamento vertical', () {
      var shaded = 0;
      var vAligned = 0;
      for (final element in tr.main) {
        if (element.type != ElementType.table) continue;
        for (final row in element.trList!) {
          for (final td in row.tdList) {
            if (td.backgroundColor != null) shaded++;
            if (td.verticalAlign != null) vAligned++;
          }
        }
      }
      expect(shaded, greaterThan(50));
      expect(vAligned, greaterThan(1000));
    });

    test('numeração multinível materializada como marcador (1., 1.1., a) …)',
        () {
      final text = _plainText(etp.main);
      expect(text, contains('1. '));
      expect(text, contains('2. '));
      // O ETP tem 208 numPr aplicados; os marcadores devem aparecer.
      final markers = RegExp(r'(^|\n)\d+\.\s').allMatches(text);
      expect(markers.length, greaterThanOrEqualTo(3));
    });

    test('títulos (outlineLvl) viram TITLE com nível', () {
      expect(_countType(etp.main, ElementType.title), greaterThan(0));
    });

    test('imagens: headers com brasão como data URL base64', () {
      final headerImages = _countType(etp.header, ElementType.image) +
          _countType(etp.main, ElementType.image);
      expect(headerImages, greaterThanOrEqualTo(1));
      IElement? image;
      void find(List<IElement> list) {
        for (final e in list) {
          if (image != null) return;
          if (e.type == ElementType.image) {
            image = e;
            return;
          }
          if (e.valueList != null) find(e.valueList!);
        }
      }

      find(etp.header);
      if (image == null) find(etp.main);
      expect(image, isNotNull);
      expect(image!.value, startsWith('data:image/'));
      expect(image!.value, contains(';base64,'));
      expect(image!.width, greaterThan(1));
      expect(image!.height, greaterThan(1));
    });

    test('footer: campos PAGE/NUMPAGES viram formato dinâmico (F4.7)', () {
      for (final result in [etp, tr]) {
        expect(result.pageNumberFormat, 'Página {pageNo} | {pageCount}');
        expect(result.pageNumberSize, isNotNull);
        // O parágrafo do campo sai do rodapé estático (sem duplicação).
        expect(_plainText(result.footer), isNot(contains('Página')));
      }
      // O parágrafo do campo começa com 2 <w:tab/> (tab stops center+right
      // do estilo Rodapé do Word) → número à DIREITA, como o Word renderiza
      // (screenshot de referência); a suposição anterior (jc left) era só o
      // jc do parágrafo, ignorando os tabs.
      expect(etp.pageNumberRowFlex, RowFlex.right);
      expect(tr.pageNumberRowFlex, anyOf(RowFlex.center, RowFlex.right));
    });

    test('distâncias de header/footer vêm do pgMar (F4.6)', () {
      expect(etp.headerDistancePx, closeTo(28.4, 0.1)); // 426 twips
      expect(etp.footerDistancePx, closeTo(30.3, 0.1)); // 454 twips
      expect(tr.headerDistancePx, closeTo(37.8, 0.1)); // 567 twips
      expect(tr.footerDistancePx, closeTo(15.3, 0.1)); // 230 twips
    });

    test('bordas efetivas: estilo de tabela e tcBorders (F4.5)', () {
      final etpTables = [
        for (final e in etp.main)
          if (e.type == ElementType.table) e
      ];
      // ETP: bordas vêm do estilo "TabeladeGradeClara" (Grid Table Light).
      for (final table in etpTables) {
        expect(table.borderType, TableBorder.all);
      }
      expect(etpTables.map((t) => t.borderColor), contains('#BFBFBF'));

      final trTables = [
        for (final e in tr.main)
          if (e.type == ElementType.table) e
      ];
      // TR: toda tabela tem bordas de tabela OU células com borderTypes.
      for (final table in trTables) {
        if (table.borderType == TableBorder.all) continue;
        var bordered = 0;
        var total = 0;
        for (final row in table.trList!) {
          for (final td in row.tdList) {
            total++;
            if (td.borderTypes?.isNotEmpty == true) bordered++;
          }
        }
        expect(bordered / total, greaterThan(0.8),
            reason: 'tabela sem bordas de tabela deve ter células com '
                'bordas próprias');
      }
    });

    test('justificação both → RowFlex.alignment presente no TR', () {
      var justified = 0;
      void scan(List<IElement> list) {
        for (final e in list) {
          if (e.rowFlex == RowFlex.alignment) justified++;
          if (e.valueList != null) scan(e.valueList!);
          if (e.trList != null) {
            for (final tr in e.trList!) {
              for (final td in tr.tdList) {
                scan(td.value);
              }
            }
          }
        }
      }

      scan(tr.main);
      expect(justified, greaterThan(1000));
    });

    test('carimbo do header registrado nas notas de fidelidade', () {
      expect(etp.notes.any((note) => note.contains('carimbo')), isTrue);
    });
  });
}
