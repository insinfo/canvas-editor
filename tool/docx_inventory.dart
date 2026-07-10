// Ferramenta de inventário de features OOXML de um .docx
// (roteiro_editor_profissional, Fase 0.3 — "medidor de compatibilidade").
//
// Uso:
//   dart run tool/docx_inventory.dart <arquivo.docx> [outro.docx ...]
//   dart run tool/docx_inventory.dart --verify   (valida o corpus resources/
//                                                 contra a seção 2.2 do roteiro)
//
// Usa apenas ce_zip cru + regex, como previsto nos "primeiros passos" do
// roteiro — roda mesmo sem o reader OOXML da Fase 2.

import 'dart:io';

import 'package:canvas_text_editor/ce_zip.dart';

class DocxInventory {
  final String path;
  final Map<String, int> counts = {};
  final Map<String, String> info = {};

  DocxInventory(this.path);

  static DocxInventory scan(String path) {
    final inventory = DocxInventory(path);
    final archive = ZipArchive.decodeBytes(File(path).readAsBytesSync());

    final document = archive.readString('word/document.xml') ?? '';
    final styles = archive.readString('word/styles.xml') ?? '';
    final numbering = archive.readString('word/numbering.xml') ?? '';
    final settings = archive.readString('word/settings.xml') ?? '';

    final headerNames = archive.entryNames
        .where((n) => RegExp(r'^word/header\d+\.xml$').hasMatch(n))
        .toList();
    final footerNames = archive.entryNames
        .where((n) => RegExp(r'^word/footer\d+\.xml$').hasMatch(n))
        .toList();
    final headersFooters = [
      for (final name in [...headerNames, ...footerNames])
        archive.readString(name) ?? ''
    ].join();
    final mediaNames =
        archive.entryNames.where((n) => n.startsWith('word/media/')).toList();
    final relsXml = archive.entryNames
        .where((n) => n.endsWith('.rels'))
        .map((n) => archive.readString(n) ?? '')
        .join();

    int count(String source, String pattern) =>
        RegExp(pattern).allMatches(source).length;

    final c = inventory.counts;
    c['partes (ZIP)'] = archive.entries.length;
    c['tabelas (w:tbl)'] = count(document, '<w:tbl[ >/]');
    c['linhas (w:tr)'] = count(document, '<w:tr[ >/]');
    c['células (w:tc)'] = count(document, '<w:tc[ >/]');
    c['gridSpan'] = count(document, '<w:gridSpan[ /]');
    c['vMerge'] = count(document, '<w:vMerge[ >/]');
    c['vMerge restart'] = count(document, '<w:vMerge w:val="restart"');
    c['tcBorders'] = count(document, '<w:tcBorders[ >/]');
    c['w:shd'] = count(document, '<w:shd[ >/]');
    c['pStyle'] = count(document, '<w:pStyle[ >/]');
    c['rStyle'] = count(document, '<w:rStyle[ >/]');
    c['tblStyle'] = count(document, '<w:tblStyle[ >/]');
    c['estilos (styles.xml)'] = count(styles, '<w:style[ >/]');
    c['abstractNum'] = count(numbering, '<w:abstractNum[ >/]');
    c['numPr no corpo'] = count(document, '<w:numPr[ >/]');
    c['seções (sectPr)'] = count(document, '<w:sectPr[ >/]');
    c['headers (partes)'] = headerNames.length;
    c['footers (partes)'] = footerNames.length;
    c['campo PAGE'] =
        count('$document$headersFooters', r'PAGE(?![A-Z])[^<]*</w:instrText>');
    c['campo NUMPAGES'] =
        count('$document$headersFooters', r'NUMPAGES[^<]*</w:instrText>');
    c['mc:AlternateContent'] =
        count('$document$headersFooters', '<mc:AlternateContent[ >/]');
    c['imagens (media)'] = mediaNames.length;
    c['hyperlinks externos'] = count(
        relsXml, 'TargetMode="External"[^>]*|Target[^>]*TargetMode="External"');
    c['bookmarks'] = count(document, '<w:bookmarkStart[ >/]');
    c['w:ins'] = count(document, '<w:ins[ >/]');
    c['tab stops (w:tab defs)'] = count(document, '<w:tab w:val=');
    c['w:br'] = count(document, '<w:br[ >/]');
    c['jc both'] = count(document, '<w:jc w:val="both"');
    c['autoHyphenation'] = count(settings, '<w:autoHyphenation[ >/]');

    final pgSz = RegExp('<w:pgSz ([^>/]*)').firstMatch(document);
    inventory.info['pgSz'] = pgSz?.group(1)?.trim() ?? '(ausente)';
    final pgMar = RegExp('<w:pgMar ([^>/]*)').firstMatch(document);
    inventory.info['pgMar'] = pgMar?.group(1)?.trim() ?? '(ausente)';
    final normalFont = RegExp(
            '<w:docDefaults>.*?<w:rFonts [^>]*w:ascii="([^"]*)"',
            dotAll: true)
        .firstMatch(styles);
    inventory.info['fonte docDefaults'] = normalFont?.group(1) ?? '(ausente)';

    return inventory;
  }

  void printReport() {
    final name = path.split(RegExp(r'[/\\]')).last;
    stdout.writeln('=== Inventário: $name ===');
    for (final entry in counts.entries) {
      stdout.writeln('${entry.key.padRight(26)} ${entry.value}');
    }
    for (final entry in info.entries) {
      stdout.writeln('${entry.key.padRight(26)} ${entry.value}');
    }
    stdout.writeln();
  }
}

/// Valores esperados do corpus (roteiro_editor_profissional, seção 2.2).
const _expectedEtp = {
  'tabelas (w:tbl)': 3,
  'linhas (w:tr)': 18,
  'células (w:tc)': 82,
  'gridSpan': 1,
  'tcBorders': 0,
  'w:shd': 123,
  'pStyle': 458,
  'rStyle': 0,
  'estilos (styles.xml)': 158,
  'abstractNum': 40,
  'numPr no corpo': 208,
  'seções (sectPr)': 1,
  'bookmarks': 0,
  // Medição real: o corpus não tem nenhum w:ins (a seção 2.2 original
  // estimava 2/14; corrigido após verificação com este tool).
  'w:ins': 0,
  'tab stops (w:tab defs)': 33,
  'w:br': 0,
  'jc both': 1,
  'autoHyphenation': 1,
};

const _expectedTr = {
  'tabelas (w:tbl)': 22,
  'linhas (w:tr)': 1642,
  'células (w:tc)': 3650,
  'gridSpan': 1670,
  'tcBorders': 3158,
  'w:shd': 1496,
  'pStyle': 1524,
  'rStyle': 26,
  'estilos (styles.xml)': 181,
  'abstractNum': 13,
  'numPr no corpo': 29,
  'seções (sectPr)': 1,
  'bookmarks': 12,
  'w:ins': 0,
  'tab stops (w:tab defs)': 713,
  'w:br': 108,
  'jc both': 1428,
  'autoHyphenation': 1,
};

int _verifyCorpus() {
  const etpPath = 'resources/PGCTIC1_-_ETP_-_Sistema_de_Gestão_Pública.docx';
  const trPath =
      'resources/PGCTIC1_-_TR_-_SISTEMA_GESTAO_PUBLICA__Recuperação_Automática_.docx';
  var failures = 0;
  for (final (label, path, expected) in [
    ('ETP', etpPath, _expectedEtp),
    ('TR', trPath, _expectedTr),
  ]) {
    final inventory = DocxInventory.scan(path);
    for (final entry in expected.entries) {
      final actual = inventory.counts[entry.key];
      if (actual != entry.value) {
        stderr.writeln(
            'DIVERGÊNCIA [$label] ${entry.key}: esperado ${entry.value}, '
            'obtido $actual');
        failures++;
      }
    }
    stdout.writeln('[$label] verificado contra a seção 2.2 do roteiro.');
  }
  if (failures == 0) {
    stdout.writeln('OK: inventário bate com a seção 2.2 do roteiro.');
  }
  return failures;
}

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Uso: dart run tool/docx_inventory.dart <arquivo.docx>... '
        '| --verify');
    exitCode = 64;
    return;
  }
  if (args.first == '--verify') {
    exitCode = _verifyCorpus() == 0 ? 0 : 1;
    return;
  }
  for (final path in args) {
    DocxInventory.scan(path).printReport();
  }
}
