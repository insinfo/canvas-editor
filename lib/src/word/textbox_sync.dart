// Sync do carimbo (caixa de texto do header) editado → DOCX (F3 follow-up).
//
// O carimbo vive num `mc:AlternateContent` (DrawingML em mc:Choice + VML em
// mc:Fallback) dentro do header. A estratégia é cirúrgica e textual: regenera
// o `<w:txbxContent>` a partir dos IElement editados e ajusta a geometria
// (wp:extent/a:ext em EMU, wp:posOffset) por regex sobre o XML do PART —
// preservando todo o resto byte a byte. Puro (sem dart:html) → testável em VM.

import '../editor/interface/element.dart';

/// Aplica texto+geometria editados do carimbo ao XML de um header part.
/// Retorna o XML novo (ou o original, se nada casou).
String patchHeaderTextBoxXml(
  String headerXml, {
  required List<IElement> elements,
  required double widthPx,
  required double heightPx,
  double? offsetXPx,
  required double offsetYPx,
}) {
  final String content = _buildTxbxContent(elements);
  String out = headerXml.replaceAll(
    RegExp(r'<w:txbxContent>[\s\S]*?</w:txbxContent>'),
    content,
  );
  final int cx = (widthPx * 9525).round();
  final int cy = (heightPx * 9525).round();
  out = out.replaceAll(
    RegExp(r'<wp:extent cx="\d+" cy="\d+"'),
    '<wp:extent cx="$cx" cy="$cy"',
  );
  out = out.replaceAll(
    RegExp(r'<a:ext cx="\d+" cy="\d+"'),
    '<a:ext cx="$cx" cy="$cy"',
  );
  out = _replacePosOffset(out, 'wp:positionV', (offsetYPx * 9525).round());
  if (offsetXPx != null) {
    final int offX = (offsetXPx * 9525).round();
    // O corpus usa <wp:align>right</wp:align>; um arrasto explícito vira
    // posOffset a partir da margem (relativeFrom preservado).
    out = out.replaceAllMapped(
      RegExp(r'(<wp:positionH[^>]*>)\s*<wp:align>[^<]*</wp:align>'),
      (Match m) => '${m[1]}<wp:posOffset>$offX</wp:posOffset>',
    );
    out = _replacePosOffset(out, 'wp:positionH', offX);
  }
  return out;
}

String _replacePosOffset(String xml, String tag, int valueEmu) {
  return xml.replaceAllMapped(
    RegExp('(<$tag[^>]*>)\\s*<wp:posOffset>-?\\d+</wp:posOffset>'),
    (Match m) => '${m[1]}<wp:posOffset>$valueEmu</wp:posOffset>',
  );
}

String _buildTxbxContent(List<IElement> elements) {
  final StringBuffer out = StringBuffer('<w:txbxContent>');
  StringBuffer runs = StringBuffer();
  void flushParagraph() {
    out.write('<w:p>$runs</w:p>');
    runs = StringBuffer();
  }

  for (final IElement el in elements) {
    if (el.value == '\n') {
      flushParagraph();
      continue;
    }
    if (el.value.isEmpty) continue;
    final StringBuffer rPr = StringBuffer();
    final String? font = el.font;
    if (font != null) {
      rPr.write('<w:rFonts w:ascii="${_escapeAttr(font)}" '
          'w:hAnsi="${_escapeAttr(font)}"/>');
    }
    if (el.bold == true) rPr.write('<w:b/>');
    if (el.italic == true) rPr.write('<w:i/>');
    if (el.color != null) {
      rPr.write('<w:color w:val="${el.color!.replaceFirst('#', '')}"/>');
    }
    if (el.size != null) {
      rPr.write('<w:sz w:val="${(el.size! * 3 / 2).round()}"/>');
    }
    if (el.underline == true) rPr.write('<w:u w:val="single"/>');
    runs.write('<w:r>'
        '${rPr.isEmpty ? '' : '<w:rPr>$rPr</w:rPr>'}'
        '<w:t xml:space="preserve">${_escapeText(el.value)}</w:t>'
        '</w:r>');
  }
  flushParagraph();
  out.write('</w:txbxContent>');
  return out.toString();
}

String _escapeText(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

String _escapeAttr(String value) =>
    _escapeText(value).replaceAll('"', '&quot;');
