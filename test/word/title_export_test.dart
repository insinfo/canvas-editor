import 'package:canvas_text_editor/ce_docx.dart';
import 'package:canvas_text_editor/src/editor/dataset/enum/element.dart';
import 'package:canvas_text_editor/src/editor/dataset/enum/title.dart';
import 'package:canvas_text_editor/src/editor/interface/element.dart';
import 'package:canvas_text_editor/src/word/docx_to_element.dart';
import 'package:canvas_text_editor/src/word/element_to_docx.dart';
import 'package:test/test.dart';

void main() {
  test('exporta título como Heading do Word e preserva no round-trip', () {
    final DocxFile file = DocxReader.createEmpty();
    final DocxConversionResult original = DocxToElementConverter.convert(file);
    final List<IElement> current = <IElement>[
      IElement(
        value: '',
        type: ElementType.title,
        level: TitleLevel.first,
        valueList: <IElement>[
          IElement(
            value: 'Título exportado',
            level: TitleLevel.first,
            size: 21,
          ),
        ],
      ),
    ];

    EditorToDocx.apply(file, current, original.main);
    final bytes = DocxWriter.write(file);
    final DocxFile reopened = DocxReader.read(bytes);
    final String documentXml =
        reopened.package.partString('word/document.xml')!;
    final String stylesXml = reopened.package.partString('word/styles.xml')!;

    expect(documentXml, contains('<w:pStyle w:val="Heading1"/>'));
    expect(documentXml, contains('<w:outlineLvl w:val="0"/>'));
    expect(stylesXml, contains('w:styleId="Heading1"'));

    final converted = DocxToElementConverter.convert(reopened);
    expect(converted.main, isNotEmpty);
    expect(
      converted.main.any((IElement element) =>
          element.type == ElementType.title &&
          element.level == TitleLevel.first),
      isTrue,
    );
  });

  test('exporta espaçamento de linha e parágrafo para w:spacing', () {
    final DocxFile file = DocxReader.createEmpty();
    final original = DocxToElementConverter.convert(file);
    EditorToDocx.apply(
        file,
        <IElement>[
          IElement(
            value: 'Parágrafo espaçado',
            rowMargin: 0,
            lineSpacingRule: 'auto',
            lineSpacingValue: 1.5,
            paraSpacingBefore: 4,
            paraSpacingAfter: 8,
            paraIndentLeft: 24,
            paraIndentFirstLine: 12,
            paraIndentRight: 36,
          ),
        ],
        original.main);
    final reopened = DocxReader.read(DocxWriter.write(file));
    final xml = reopened.package.partString('word/document.xml')!;
    expect(xml, contains('w:before="60"'));
    expect(xml, contains('w:after="120"'));
    expect(xml, contains('w:line="360"'));
    expect(xml, contains('w:lineRule="auto"'));
    expect(xml, contains('w:left="360"'));
    expect(xml, contains('w:firstLine="180"'));
    expect(xml, contains('w:right="540"'));

    // Reimportação: o recuo direito volta para o modelo (px = twips/15).
    final reconverted = DocxToElementConverter.convert(reopened);
    final withRight = reconverted.main
        .where((IElement e) => e.paraIndentRight != null)
        .toList(growable: false);
    expect(withRight, isNotEmpty);
    expect(withRight.first.paraIndentRight, closeTo(36, 0.1));
  });
}
