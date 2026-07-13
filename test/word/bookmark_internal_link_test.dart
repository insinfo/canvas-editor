// M1 (plano_expansao_word_gdocs §4.1/§4.2): títulos customizados via
// outlineLvl herdado (cadeia basedOn) + bookmarks/links internos.
import 'package:canvas_text_editor/ce_docx.dart';
import 'package:canvas_text_editor/src/document/opc/opc_package.dart';
import 'package:canvas_text_editor/src/editor/dataset/enum/element.dart';
import 'package:canvas_text_editor/src/editor/dataset/enum/title.dart';
import 'package:canvas_text_editor/src/editor/interface/element.dart';
import 'package:canvas_text_editor/src/word/docx_to_element.dart';
import 'package:canvas_text_editor/src/word/element_to_docx.dart';
import 'package:test/test.dart';

const String _documentXml = '<?xml version="1.0" encoding="UTF-8" '
    'standalone="yes"?>\n'
    '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
    '<w:body>'
    '<w:p><w:pPr><w:pStyle w:val="NivelCustom"/></w:pPr><w:bookmarkStart w:id="7" w:name="alvo1"/><w:r><w:t>Título customizado</w:t></w:r><w:bookmarkEnd w:id="7"/></w:p>'
    '<w:p><w:r><w:t>corpo do documento</w:t></w:r></w:p>'
    '<w:p><w:hyperlink w:anchor="alvo1"><w:r><w:t>ir para o título</w:t></w:r></w:hyperlink></w:p>'
    '</w:body>'
    '</w:document>';

const String _stylesXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial"/><w:sz w:val="22"/></w:rPr></w:rPrDefault></w:docDefaults>
<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/></w:style>
<w:style w:type="paragraph" w:styleId="NivelBase"><w:name w:val="Nivel Base"/><w:basedOn w:val="Normal"/><w:pPr><w:outlineLvl w:val="1"/></w:pPr></w:style>
<w:style w:type="paragraph" w:styleId="NivelCustom"><w:name w:val="Nivel Custom"/><w:basedOn w:val="NivelBase"/><w:rPr><w:b/></w:rPr></w:style>
</w:styles>
''';

DocxFile _syntheticDocx() {
  final DocxFile base = DocxReader.createEmpty();
  final bytes = DocxWriter.write(base);
  final OpcPackage pkg = OpcPackage.decode(bytes);
  pkg.setPartString('word/document.xml', _documentXml.trim());
  pkg.setPartString('word/styles.xml', _stylesXml.trim());
  return DocxReader.read(pkg.save());
}

IElement? _findLeafWithBookmark(List<IElement> elements, String name) {
  for (final element in elements) {
    final ext = element.extension;
    if (ext is Map) {
      final bookmarks = ext['bookmarks'];
      if (bookmarks is List && bookmarks.contains(name)) return element;
    }
    final children = element.valueList;
    if (children != null) {
      final found = _findLeafWithBookmark(children, name);
      if (found != null) return found;
    }
  }
  return null;
}

void main() {
  test('estilo customizado com outlineLvl herdado vira título nível 2', () {
    final converted = DocxToElementConverter.convert(_syntheticDocx());
    final titles = converted.main
        .where((e) => e.type == ElementType.title)
        .toList(growable: false);
    expect(titles, hasLength(1));
    expect(titles.single.level, TitleLevel.second);
  });

  test('bookmark inline vira alvo de navegação no primeiro leaf do título',
      () {
    final converted = DocxToElementConverter.convert(_syntheticDocx());
    final target = _findLeafWithBookmark(converted.main, 'alvo1');
    expect(target, isNotNull);
    final ext = target!.extension as Map;
    expect(ext['wpBookmarkStartXml'], isNotEmpty);
    expect(ext['wpBookmarkEndXml'], isNotEmpty);
  });

  test('hyperlink com w:anchor vira url interna #alvo1', () {
    final converted = DocxToElementConverter.convert(_syntheticDocx());
    final links = <IElement>[];
    void collect(List<IElement> list) {
      for (final e in list) {
        if (e.type == ElementType.hyperlink) links.add(e);
        if (e.valueList != null) collect(e.valueList!);
      }
    }

    collect(converted.main);
    expect(links, hasLength(1));
    expect(links.single.url, '#alvo1');
  });

  test('regenerar o parágrafo do título mantém bookmark e link no DOCX', () {
    final file = _syntheticDocx();
    // Duas conversões independentes: `original` é a referência de abertura e
    // `current` a lista editada (no app o original é um snapshot clonado).
    final converted = DocxToElementConverter.convert(file);
    final current = DocxToElementConverter.convert(file).main;
    final titleLeaf = _findLeafWithBookmark(current, 'alvo1')!;
    titleLeaf.value = 'Título customizado EDITADO';

    EditorToDocx.apply(file, current, converted.main);
    final reopened = DocxReader.read(DocxWriter.write(file));
    final xml = reopened.package.partString('word/document.xml')!;

    expect(xml, contains('w:name="alvo1"'));
    expect(xml, contains('<w:bookmarkEnd'));
    expect(xml, contains('w:anchor="alvo1"'));
    expect(xml, contains('EDITADO'));
  });

  test('round-trip sem edição continua byte-idêntico com bookmarks', () {
    final file = _syntheticDocx();
    final converted = DocxToElementConverter.convert(file);
    final before = file.package.partString('word/document.xml')!;
    EditorToDocx.apply(file, converted.main, converted.main);
    final after = DocxReader.read(DocxWriter.write(file))
        .package
        .partString('word/document.xml')!;
    expect(after, before);
  });
}
