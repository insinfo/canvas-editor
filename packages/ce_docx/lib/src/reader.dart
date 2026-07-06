import 'dart:typed_data';

import 'package:ce_opc/ce_opc.dart';
import 'package:ce_xml/ce_xml.dart';

import 'model.dart';
import 'numbering.dart';
import 'styles.dart';

/// Resultado da leitura de um .docx (roteiro_editor_profissional, F2.1).
class DocxFile {
  final OpcPackage package;
  final WpDocumentModel document;
  final WpStyleSheet styles;
  final WpNumbering numbering;
  final WpSettings settings;

  /// Headers/footers da seção única do corpus, por tipo (default/first/even).
  final Map<String, WpHeaderFooter> headersByType;
  final Map<String, WpHeaderFooter> footersByType;

  /// Notas de fidelidade: qnames preservados-sem-mapeamento e avisos.
  final List<String> fidelityNotes;

  DocxFile({
    required this.package,
    required this.document,
    required this.styles,
    required this.numbering,
    required this.settings,
    required this.headersByType,
    required this.footersByType,
    required this.fidelityNotes,
  });

  /// Bytes de uma imagem referenciada por `r:embed` a partir de uma parte.
  Uint8List? imageBytes(String relId, {String fromPart = 'word/document.xml'}) {
    final rel = package.relationshipsFor(fromPart).byId(relId);
    if (rel == null || rel.isExternal) return null;
    return package.partBytes(package.resolveTarget(fromPart, rel.target));
  }

  /// Content type de uma imagem referenciada por `r:embed`.
  String? imageContentType(String relId,
      {String fromPart = 'word/document.xml'}) {
    final rel = package.relationshipsFor(fromPart).byId(relId);
    if (rel == null || rel.isExternal) return null;
    return package.contentTypeOf(package.resolveTarget(fromPart, rel.target));
  }

  /// URL de um hyperlink externo (`r:id`) de uma parte.
  String? hyperlinkUrl(String relId, {String fromPart = 'word/document.xml'}) {
    final rel = package.relationshipsFor(fromPart).byId(relId);
    return rel != null && rel.isExternal ? rel.target : null;
  }
}

/// Reader DOCX → modelo tipado.
class DocxReader {
  final List<String> _notes = [];

  DocxReader._();

  static DocxFile read(Uint8List bytes) => DocxReader._()._read(bytes);

  DocxFile _read(Uint8List bytes) {
    final package = OpcPackage.decode(bytes);
    final mainPart = package.mainDocumentPartName;

    final documentXml = package.partString(mainPart);
    if (documentXml == null) {
      throw FormatException('Parte principal ausente: $mainPart');
    }
    final documentRoot = XmlDocument.parse(documentXml).rootElement;
    final bodyEl = documentRoot.firstChild('w:body');
    if (bodyEl == null) {
      throw const FormatException('document.xml sem <w:body>.');
    }

    final section =
        WpSectionProperties.fromXml(bodyEl.firstChild('w:sectPr'));
    final body = _parseBlocks(bodyEl, skip: const {'w:sectPr'});

    final styles = _parsePart(
        package, 'word/styles.xml', WpStyleSheet.parse,
        orElse: WpStyleSheet.new);
    final numbering = _parsePart(
        package, 'word/numbering.xml', WpNumbering.parse,
        orElse: WpNumbering.new);
    final settingsXml = package.partString('word/settings.xml');
    final settings = WpSettings.fromXml(settingsXml == null
        ? null
        : XmlDocument.parse(settingsXml).rootElement);

    final headers = <String, WpHeaderFooter>{};
    final footers = <String, WpHeaderFooter>{};
    if (section != null) {
      final rels = package.relationshipsFor(mainPart);
      for (final (refs, into, rootName) in [
        (section.headerReferences, headers, 'w:hdr'),
        (section.footerReferences, footers, 'w:ftr'),
      ]) {
        for (final ref in refs) {
          final rel = rels.byId(ref.relId);
          if (rel == null) {
            _notes.add('referência de header/footer sem rel: ${ref.relId}');
            continue;
          }
          final partName = package.resolveTarget(mainPart, rel.target);
          final xml = package.partString(partName);
          if (xml == null) {
            _notes.add('parte de header/footer ausente: $partName');
            continue;
          }
          final root = XmlDocument.parse(xml).rootElement;
          if (root.qname != rootName) {
            _notes.add('raiz inesperada em $partName: ${root.qname}');
          }
          into[ref.type] = WpHeaderFooter(
              partName: partName, blocks: _parseBlocks(root));
        }
      }
    }

    return DocxFile(
      package: package,
      document: WpDocumentModel(body: body, section: section),
      styles: styles,
      numbering: numbering,
      settings: settings,
      headersByType: headers,
      footersByType: footers,
      fidelityNotes: _notes,
    );
  }

  static T _parsePart<T>(
      OpcPackage package, String partName, T Function(String) parse,
      {required T Function() orElse}) {
    final xml = package.partString(partName);
    return xml == null ? orElse() : parse(xml);
  }

  // ---- Blocos ----

  List<WpBlock> _parseBlocks(XmlElement parent, {Set<String> skip = const {}}) {
    final blocks = <WpBlock>[];
    for (final child in parent.childElements) {
      if (skip.contains(child.qname)) continue;
      switch (child.qname) {
        case 'w:p':
          blocks.add(_parseParagraph(child));
        case 'w:tbl':
          blocks.add(_parseTable(child));
        case _:
          _notes.add('bloco preservado: ${child.qname}');
          blocks.add(WpPreservedBlock(child.qname, child.toXmlString()));
      }
    }
    return blocks;
  }

  WpParagraph _parseParagraph(XmlElement el) {
    WpParagraphProperties? properties;
    final inlines = <WpInline>[];
    for (final child in el.childElements) {
      switch (child.qname) {
        case 'w:pPr':
          properties = WpParagraphProperties.fromXml(child);
        case 'w:r':
          inlines.add(_parseRun(child));
        case 'w:hyperlink':
          inlines.add(WpHyperlink(
            relId: child.getAttribute('r:id'),
            anchor: child.getAttribute('w:anchor'),
            runs: [
              for (final run in child.childrenNamed('w:r')) _parseRun(run)
            ],
          ));
        case 'w:fldSimple':
          inlines.add(WpSimpleField(
            instruction: child.getAttribute('w:instr') ?? '',
            runs: [
              for (final run in child.childrenNamed('w:r')) _parseRun(run)
            ],
          ));
        case _:
          inlines.add(WpPreservedInline(child.qname, child.toXmlString()));
      }
    }
    return WpParagraph(properties: properties, inlines: inlines);
  }

  WpRun _parseRun(XmlElement el) {
    WpRunProperties? properties;
    final content = <WpRunContent>[];
    for (final child in el.childElements) {
      switch (child.qname) {
        case 'w:rPr':
          properties = WpRunProperties.fromXml(child);
        case 'w:t':
          content.add(WpText(child.text));
        case 'w:tab':
          content.add(WpTabChar());
        case 'w:br':
          content.add(WpBreak(child.getAttribute('w:type')));
        case 'w:cr':
          content.add(WpBreak());
        case 'w:noBreakHyphen':
          content.add(WpNoBreakHyphen());
        case 'w:softHyphen':
          break; // hífen opcional: invisível fora da quebra
        case 'w:sym':
          content.add(WpSymbol(
            font: child.getAttribute('w:font'),
            charHex: child.getAttribute('w:char'),
          ));
        case 'w:drawing':
          content.add(_parseDrawing(child));
        case 'w:fldChar':
          content.add(
              WpFieldChar(child.getAttribute('w:fldCharType') ?? 'begin'));
        case 'w:instrText':
          content.add(WpInstrText(child.text));
        case 'w:lastRenderedPageBreak':
          break; // marcador transiente do Word — recalculado pelo layout
        case _:
          content
              .add(WpPreservedRunContent(child.qname, child.toXmlString()));
      }
    }
    return WpRun(properties: properties, content: content);
  }

  WpDrawing _parseDrawing(XmlElement el) {
    final inline = el.firstChild('wp:inline');
    final anchor = el.firstChild('wp:anchor');
    final container = inline ?? anchor;
    final extent = container?.firstChild('wp:extent');
    String? embed;
    for (final blip in el.descendantsNamed('a:blip')) {
      embed = blip.getAttribute('r:embed') ?? blip.getAttribute('r:link');
      if (embed != null) break;
    }
    if (anchor != null) {
      _notes.add('drawing flutuante (anchor) tratado como inline');
    }
    return WpDrawing(
      embedRelId: embed,
      widthEmu: double.tryParse(extent?.getAttribute('cx') ?? ''),
      heightEmu: double.tryParse(extent?.getAttribute('cy') ?? ''),
      isInline: inline != null,
      rawXml: el.toXmlString(),
    );
  }

  // ---- Tabela ----

  WpTable _parseTable(XmlElement el) {
    WpTableProperties? properties;
    final grid = <int>[];
    final rows = <WpTableRow>[];
    for (final child in el.childElements) {
      switch (child.qname) {
        case 'w:tblPr':
          properties = WpTableProperties.fromXml(child);
        case 'w:tblGrid':
          for (final col in child.childrenNamed('w:gridCol')) {
            grid.add(int.tryParse(col.getAttribute('w:w') ?? '') ?? 0);
          }
        case 'w:tr':
          rows.add(_parseRow(child));
        case _:
          _notes.add('filho de tabela ignorado: ${child.qname}');
      }
    }
    return WpTable(properties: properties, gridColumnsTwips: grid, rows: rows);
  }

  WpTableRow _parseRow(XmlElement el) {
    WpTableRowProperties? properties;
    final cells = <WpTableCell>[];
    for (final child in el.childElements) {
      switch (child.qname) {
        case 'w:trPr':
          properties = WpTableRowProperties.fromXml(child);
        case 'w:tc':
          WpTableCellProperties? tcPr;
          final tcPrEl = child.firstChild('w:tcPr');
          if (tcPrEl != null) {
            tcPr = WpTableCellProperties.fromXml(tcPrEl);
          }
          cells.add(WpTableCell(
            properties: tcPr,
            blocks: _parseBlocks(child, skip: const {'w:tcPr'}),
          ));
        case 'w:tblPrEx':
          _notes.add('tblPrEx ignorado em linha de tabela');
        case _:
          _notes.add('filho de linha ignorado: ${child.qname}');
      }
    }
    return WpTableRow(properties: properties, cells: cells);
  }
}
