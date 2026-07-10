import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:canvas_text_editor/ce_zip.dart';
import 'package:test/test.dart';

/// Caminhos do corpus real (roteiro_editor_profissional, seção 2.2).
final _resourcesDir = Directory('resources');

List<File> _docxFixtures() => _resourcesDir
    .listSync()
    .whereType<File>()
    .where((f) => f.path.toLowerCase().endsWith('.docx'))
    .toList()
  ..sort((a, b) => a.path.compareTo(b.path));

void main() {
  group('corpus resources/', () {
    test('existem os 2 DOCX do corpus', () {
      expect(_docxFixtures(), hasLength(2),
          reason: 'esperados ETP e TR em resources/');
    });

    for (final fixture in _docxFixtures()) {
      final label = fixture.uri.pathSegments.last;

      group(label, () {
        late Uint8List original;
        late ZipArchive archive;

        setUpAll(() {
          original = fixture.readAsBytesSync();
          archive = ZipArchive.decodeBytes(original);
        });

        test('abre e lista as partes esperadas de um DOCX', () {
          final names = archive.entryNames;
          expect(names, contains('[Content_Types].xml'));
          expect(names, contains('_rels/.rels'));
          expect(names, contains('word/document.xml'));
          expect(names, contains('word/styles.xml'));
          expect(names, contains('word/numbering.xml'));
          expect(names.length, greaterThanOrEqualTo(25));
        });

        test('extrai todas as partes sem exceção e sem conteúdo vazio', () {
          for (final entry in archive.entries) {
            final content = entry.content;
            if (!entry.name.endsWith('/')) {
              expect(content, isNotEmpty, reason: entry.name);
            }
          }
        });

        test('re-zip sem modificação é byte-fiel ao arquivo original', () {
          final reencoded = ZipArchive.decodeBytes(original).encode();
          expect(reencoded.length, original.length);
          expect(_sha256(reencoded), _sha256(original),
              reason: 'zip inteiro deve ser idêntico quando nada foi tocado');
        });

        test('re-zip preserva cada parte por hash após reabrir', () {
          final reopened = ZipArchive.decodeBytes(archive.encode());
          expect(reopened.entryNames, archive.entryNames);
          for (final entry in archive.entries) {
            final other = reopened.findEntry(entry.name)!;
            expect(_sha256(other.content), _sha256(entry.content),
                reason: entry.name);
            expect(other.crc32, entry.crc32, reason: entry.name);
          }
        });

        test('modificar 1 parte preserva as outras byte a byte (payload raw)',
            () {
          final edited = ZipArchive.decodeBytes(original);
          edited.setFile('word/document.xml',
              utf8.encode(edited.readString('word/document.xml')!));
          final reopened = ZipArchive.decodeBytes(edited.encode());

          for (final entry in archive.entries) {
            final other = reopened.findEntry(entry.name)!;
            if (entry.name == 'word/document.xml') continue;
            expect(other.rawCompressed, isNotNull, reason: entry.name);
            expect(_sha256(other.rawCompressed!), _sha256(entry.rawCompressed!),
                reason: 'payload comprimido intocado deve ser idêntico: '
                    '${entry.name}');
          }
          expect(
              _sha256(reopened.readBytes('word/document.xml')!),
              _sha256(Uint8List.fromList(
                  utf8.encode(archive.readString('word/document.xml')!))));
        });
      });
    }
  });

  group('operações básicas', () {
    test('cria zip novo, adiciona/substitui/remove e reabre', () {
      final archive = ZipArchive();
      archive.setFile('a.txt', utf8.encode('hello'));
      archive.setFile('dir/b.bin', List<int>.generate(70000, (i) => i % 251));
      archive.setFile('a.txt', utf8.encode('world'));

      final reopened = ZipArchive.decodeBytes(archive.encode());
      expect(reopened.entryNames, ['a.txt', 'dir/b.bin']);
      expect(reopened.readString('a.txt'), 'world');
      expect(reopened.readBytes('dir/b.bin'),
          List<int>.generate(70000, (i) => i % 251));

      expect(reopened.removeFile('a.txt'), isTrue);
      expect(reopened.removeFile('a.txt'), isFalse);
      final reopened2 = ZipArchive.decodeBytes(reopened.encode());
      expect(reopened2.entryNames, ['dir/b.bin']);
    });

    test('nome com acentos round-trip via flag UTF-8', () {
      final archive = ZipArchive();
      archive.setFile('pasta/ação_ç.xml', utf8.encode('<a/>'));
      final reopened = ZipArchive.decodeBytes(archive.encode());
      expect(reopened.readString('pasta/ação_ç.xml'), '<a/>');
    });

    test('deflate/inflate round-trip com dados repetitivos e aleatórios', () {
      final repetitive = Uint8List.fromList(List<int>.filled(200000, 0x41));
      final pseudoRandom = Uint8List.fromList(
          List<int>.generate(100000, (i) => (i * 2654435761) & 0xff));
      for (final data in [repetitive, pseudoRandom]) {
        final archive = ZipArchive();
        archive.setFile('data.bin', data);
        final reopened = ZipArchive.decodeBytes(archive.encode());
        expect(_sha256(reopened.readBytes('data.bin')!), _sha256(data));
      }
    });
  });
}

String _sha256(List<int> bytes) {
  // Hash simples e determinístico (FNV-1a 64 dobrado) — suficiente para
  // comparação de igualdade nos testes sem dependência externa.
  var h1 = 0xcbf29ce484222325;
  var h2 = 0x100000001b3;
  for (final b in bytes) {
    h1 = ((h1 ^ b) * 0x100000001b3) & 0xffffffffffffffff;
    h2 = ((h2 ^ b) * 0x1000193) & 0xffffffffffffffff;
  }
  return '${h1.toRadixString(16)}:${h2.toRadixString(16)}:${bytes.length}';
}
