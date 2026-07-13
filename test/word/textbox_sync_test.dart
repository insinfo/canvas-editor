// F3 follow-up: patch cirúrgico do carimbo editado no header part.
import 'package:canvas_text_editor/src/editor/interface/element.dart';
import 'package:canvas_text_editor/src/word/textbox_sync.dart';
import 'package:test/test.dart';

const String _headerXml = '<w:hdr>'
    '<w:p><w:r><mc:AlternateContent><mc:Choice Requires="wps">'
    '<w:drawing><wp:anchor behindDoc="0">'
    '<wp:positionH relativeFrom="margin"><wp:align>right</wp:align></wp:positionH>'
    '<wp:positionV relativeFrom="paragraph"><wp:posOffset>9525</wp:posOffset></wp:positionV>'
    '<wp:extent cx="1714500" cy="847725"/>'
    '<a:xfrm><a:ext cx="1714500" cy="847725"/></a:xfrm>'
    '<wps:txbx><w:txbxContent>'
    '<w:p><w:r><w:rPr><w:b/></w:rPr><w:t>Continuação de Processo</w:t></w:r></w:p>'
    '<w:p><w:r><w:t>Processo nº 44505/2025</w:t></w:r></w:p>'
    '</w:txbxContent></wps:txbx>'
    '</wp:anchor></w:drawing></mc:Choice>'
    '<mc:Fallback><w:pict><v:rect><v:textbox><w:txbxContent>'
    '<w:p><w:r><w:t>Continuação de Processo</w:t></w:r></w:p>'
    '</w:txbxContent></v:textbox></v:rect></w:pict></mc:Fallback>'
    '</mc:AlternateContent></w:r></w:p></w:hdr>';

void main() {
  test('patch regenera txbxContent (Choice e Fallback) e geometria', () {
    final patched = patchHeaderTextBoxXml(
      _headerXml,
      elements: <IElement>[
        IElement(value: 'Novo título', bold: true, size: 15),
        IElement(value: '\n'),
        IElement(value: 'Folha 2', size: 15),
      ],
      widthPx: 200,
      heightPx: 100,
      offsetXPx: 40,
      offsetYPx: 8,
    );

    // Texto novo nos DOIS ramos (Choice + Fallback VML).
    expect(RegExp('Novo título').allMatches(patched).length, 2);
    expect(patched, isNot(contains('Continuação de Processo')));
    expect(patched, contains('<w:b/>'));
    expect(patched, contains('<w:sz w:val="23"/>'));
    // Geometria: 200px → 1905000 EMU; 100px → 952500 EMU.
    expect(patched, contains('<wp:extent cx="1905000" cy="952500"'));
    expect(patched, contains('<a:ext cx="1905000" cy="952500"'));
    // Arrasto horizontal: wp:align vira posOffset (40px → 381000 EMU).
    expect(patched, isNot(contains('<wp:align>')));
    expect(patched,
        contains('<wp:positionH relativeFrom="margin"><wp:posOffset>381000'));
    // Offset vertical trocado (8px → 76200 EMU).
    expect(patched, contains('<wp:posOffset>76200</wp:posOffset>'));
  });

  test('sem offsetX mantém o alinhamento original', () {
    final patched = patchHeaderTextBoxXml(
      _headerXml,
      elements: <IElement>[IElement(value: 'X')],
      widthPx: 180,
      heightPx: 89,
      offsetXPx: null,
      offsetYPx: 1,
    );
    expect(patched, contains('<wp:align>right</wp:align>'));
  });
}
