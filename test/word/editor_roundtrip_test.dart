import 'dart:io';
import 'dart:typed_data';

import 'package:canvas_text_editor/src/editor/dataset/enum/element.dart';
import 'package:canvas_text_editor/src/editor/interface/element.dart';
import 'package:canvas_text_editor/src/word/docx_to_element.dart';
import 'package:canvas_text_editor/src/word/element_to_docx.dart';
import 'package:ce_docx/ce_docx.dart';
import 'package:test/test.dart';

const _etpPath = 'resources/PGCTIC1_-_ETP_-_Sistema_de_Gestão_Pública.docx';
const _trPath =
    'resources/PGCTIC1_-_TR_-_SISTEMA_GESTAO_PUBLICA__Recuperação_Automática_.docx';

Uint8List _read(String path) =>
    Uint8List.fromList(File(path).readAsBytesSync());

/// Pipeline completo: abrir → converter p/ editor → sincronizar de volta →
/// salvar (roteiro_editor_profissional, aceite F3/G2 via editor).
({DocxFile file, DocxConversionResult original, DocxConversionResult current})
    _openTwice(Uint8List bytes) {
  final fileA = DocxReader.read(bytes);
  final original = DocxToElementConverter.convert(fileA);
  final fileB = DocxReader.read(bytes);
  final current = DocxToElementConverter.convert(fileB);
  return (file: fileB, original: original, current: current);
}

IElement? _findTextElement(List<IElement> elements, bool Function(IElement) test) {
  for (final element in elements) {
    if (element.type == null && test(element)) return element;
    final children = element.valueList;
    if (children != null) {
      final found = _findTextElement(children, test);
      if (found != null) return found;
    }
  }
  return null;
}

void main() {
  for (final (label, path) in [('ETP', _etpPath), ('TR', _trPath)]) {
    group('round-trip via editor $label', () {
      late Uint8List original;

      setUpAll(() => original = _read(path));

      test('abrir → converter → sincronizar sem edição → salvar '
          '= byte-idêntico', () {
        final env = _openTwice(original);
        final notes = EditorToDocx.apply(
            env.file, env.current.main, env.original.main);
        final saved = DocxWriter.write(env.file);
        expect(saved.length, original.length,
            reason: 'notas: ${notes.join('; ')}');
        for (var i = 0; i < saved.length; i++) {
          if (saved[i] != original[i]) fail('bytes divergem no offset $i');
        }
      });

      test('editar texto de 1 parágrafo → mudança localizada e reabrível',
          () {
        final env = _openTwice(original);
        final target = _findTextElement(
            env.current.main,
            (e) =>
                e.value.trim().length > 30 &&
                e.externalId != null &&
                !(e.extension is Map &&
                    (e.extension as Map)['wpMarker'] == true));
        expect(target, isNotNull);
        target!.value = '${target.value} [EDITADO-F3]';

        EditorToDocx.apply(env.file, env.current.main, env.original.main);
        final saved = DocxWriter.write(env.file);

        expect(DocxValidator.validate(saved), isEmpty);

        // Apenas 1 bloco difere no document.xml.
        final fresh = DocxReader.read(original);
        final before = [
          for (final block in fresh.document.body)
            DocxWriter.serializeBlock(block)
        ];
        final after = [
          for (final block in env.file.document.body)
            DocxWriter.serializeBlock(block)
        ];
        expect(after.length, before.length);
        var diffs = 0;
        for (var i = 0; i < before.length; i++) {
          if (before[i] != after[i]) diffs++;
        }
        expect(diffs, 1, reason: 'só o parágrafo editado deve mudar');

        // Reabre com o texto editado e demais partes intactas.
        final reopened = DocxReader.read(saved);
        expect(
            reopened.document.allParagraphs
                .any((p) => p.text.contains('[EDITADO-F3]')),
            isTrue);
        for (final name in reopened.package.partNames) {
          if (name == env.file.mainPartName) continue;
          expect(reopened.package.partBytes(name),
              fresh.package.partBytes(name),
              reason: name);
        }
      });
    });
  }

  group('edições estruturais (ETP)', () {
    late Uint8List original;

    setUpAll(() => original = _read(_etpPath));

    test('editar célula de tabela regenera com vMerge/gridSpan válidos', () {
      final env = _openTwice(original);
      // Tabela com merge vertical (rowspan > 1) do ETP.
      final table = env.current.main.firstWhere((e) =>
          e.type == ElementType.table &&
          e.trList!.any((tr) => tr.tdList.any((td) => td.rowspan > 1)));
      final td = table.trList!.first.tdList.first;
      final text = _findTextElement(td.value, (e) => e.value.isNotEmpty);
      expect(text, isNotNull);
      text!.value = 'Célula editada F3';

      EditorToDocx.apply(env.file, env.current.main, env.original.main);
      final saved = DocxWriter.write(env.file);
      expect(DocxValidator.validate(saved), isEmpty);

      // A tabela regenerada mantém a mesma malha de células por linha
      // (células de continuação de vMerge recriadas).
      final fresh = DocxReader.read(original);
      final stamp = int.parse(table.externalId!.substring(3));
      final originalTable = fresh.document.body[stamp] as WpTable;
      final reopened = DocxReader.read(saved);
      final newTable = reopened.document.body[stamp] as WpTable;
      expect(newTable.rows.length, originalTable.rows.length);
      for (var r = 0; r < newTable.rows.length; r++) {
        expect(newTable.rows[r].cells.length,
            originalTable.rows[r].cells.length,
            reason: 'linha $r');
      }
      expect(
          reopened.document.allParagraphs
              .any((p) => p.text.contains('Célula editada F3')),
          isTrue);
    });

    test('inserir parágrafo novo no meio preserva os vizinhos', () {
      final env = _openTwice(original);
      // Insere num separador de bloco no meio do documento.
      final separators = <int>[
        for (var i = 0; i < env.current.main.length; i++)
          if (env.current.main[i].value == '\n' &&
              env.current.main[i].type == null)
            i
      ];
      expect(separators.length, greaterThan(10));
      final index = separators[separators.length ~/ 2];
      env.current.main.insertAll(index, [
        IElement(value: '\n'),
        IElement(value: 'Parágrafo novo inserido pelo editor.'),
      ]);

      EditorToDocx.apply(env.file, env.current.main, env.original.main);
      final saved = DocxWriter.write(env.file);
      expect(DocxValidator.validate(saved), isEmpty);

      final fresh = DocxReader.read(original);
      final reopened = DocxReader.read(saved);
      expect(reopened.document.body.length,
          fresh.document.body.length + 1);
      expect(
          reopened.document.allParagraphs
              .any((p) => p.text.contains('Parágrafo novo inserido')),
          isTrue);

      // Blocos originais continuam byte a byte (passthrough).
      var passthrough = 0;
      final originalXml = {
        for (final block in fresh.document.body)
          if (block is WpParagraph && block.sourceXml != null)
            block.sourceXml!: true
      };
      for (final block in reopened.document.body) {
        if (block is WpParagraph &&
            originalXml.containsKey(block.sourceXml)) {
          passthrough++;
        }
      }
      expect(passthrough, greaterThan(fresh.document.body.length ~/ 2));
    });

    test('hyperlink editado reusa/gera rel externa (TR)', () {
      final trBytes = _read(_trPath);
      final env = _openTwice(trBytes);
      IElement? link;
      for (final element in env.current.main) {
        if (element.type == ElementType.hyperlink) {
          link = element;
          break;
        }
        if (element.valueList != null) {
          link = element.valueList!
              .where((e) => e.type == ElementType.hyperlink)
              .firstOrNull;
          if (link != null) break;
        }
      }
      expect(link, isNotNull, reason: 'TR tem 3 hyperlinks externos');
      final textChild =
          link!.valueList!.firstWhere((e) => e.value.isNotEmpty);
      textChild.value = '${textChild.value}X';

      EditorToDocx.apply(env.file, env.current.main, env.original.main);
      final saved = DocxWriter.write(env.file);
      expect(DocxValidator.validate(saved), isEmpty);

      final reopened = DocxReader.read(saved);
      final urls = <String>{};
      for (final paragraph in reopened.document.allParagraphs) {
        for (final inline in paragraph.inlines) {
          if (inline is WpHyperlink && inline.relId != null) {
            final url = reopened.hyperlinkUrl(inline.relId!);
            if (url != null) urls.add(url);
          }
        }
      }
      expect(urls, isNotEmpty);
    });
  });
}
