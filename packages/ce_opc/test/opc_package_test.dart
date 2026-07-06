import 'dart:io';
import 'dart:typed_data';

import 'package:ce_opc/ce_opc.dart';
import 'package:test/test.dart';

const _etpPath =
    '../../resources/PGCTIC1_-_ETP_-_Sistema_de_Gestão_Pública.docx';
const _trPath =
    '../../resources/PGCTIC1_-_TR_-_SISTEMA_GESTAO_PUBLICA__Recuperação_Automática_.docx';

void main() {
  group('unidade', () {
    test('ContentTypes: defaults, overrides e serialização', () {
      final ct = ContentTypes.parse(
          '<?xml version="1.0"?><Types xmlns="$contentTypesNamespace">'
          '<Default Extension="xml" ContentType="application/xml"/>'
          '<Default Extension="PNG" ContentType="image/png"/>'
          '<Override PartName="/word/document.xml" '
          'ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
          '</Types>');
      expect(ct.typeOf('word/document.xml'), contains('document.main+xml'));
      expect(ct.typeOf('/word/media/image1.png'), 'image/png');
      expect(ct.typeOf('word/styles.xml'), 'application/xml');
      expect(ct.typeOf('sem_extensao'), isNull);

      final reparsed = ContentTypes.parse(ct.toXmlString());
      expect(reparsed.defaults, ct.defaults);
      expect(reparsed.overrides, ct.overrides);
    });

    test('Relationships: parse, byId, external, nextId e serialização', () {
      final rels = Relationships.parse(
          '<?xml version="1.0"?><Relationships xmlns="$relationshipsNamespace">'
          '<Relationship Id="rId1" Type="${RelType.styles}" Target="styles.xml"/>'
          '<Relationship Id="rId7" Type="${RelType.hyperlink}" '
          'Target="https://example.com" TargetMode="External"/>'
          '</Relationships>');
      expect(rels.items, hasLength(2));
      expect(rels.byId('rId1')!.target, 'styles.xml');
      expect(rels.byId('rId7')!.isExternal, isTrue);
      expect(rels.firstOfType(RelType.styles)!.id, 'rId1');
      expect(rels.nextId(), 'rId8');

      final reparsed = Relationships.parse(rels.toXmlString());
      expect(reparsed.items.map((r) => r.toString()),
          rels.items.map((r) => r.toString()));
    });
  });

  for (final (label, path) in [('ETP', _etpPath), ('TR', _trPath)]) {
    group('corpus $label', () {
      late Uint8List original;
      late OpcPackage package;

      setUpAll(() {
        original = File(path).readAsBytesSync();
        package = OpcPackage.decode(original);
      });

      test('parte principal resolvida via rels da raiz', () {
        expect(package.mainDocumentPartName, 'word/document.xml');
        expect(package.contentTypeOf('word/document.xml'),
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml');
      });

      test('todas as partes têm content type resolvível', () {
        for (final name in package.partNames) {
          if (name == '[Content_Types].xml') continue;
          expect(package.contentTypeOf(name), isNotNull, reason: name);
        }
      });

      test('rels do document.xml: styles, numbering, headers e imagens', () {
        final rels = package.relationshipsFor('word/document.xml');
        expect(rels.firstOfType(RelType.styles), isNotNull);
        expect(rels.firstOfType(RelType.numbering), isNotNull);
        expect(rels.ofType(RelType.header), isNotEmpty);
        expect(rels.ofType(RelType.footer), isNotEmpty);

        // Headers referenciam as imagens do template (brasão etc.).
        var headerImages = 0;
        for (final headerRel in rels.ofType(RelType.header)) {
          final headerPart =
              package.resolveTarget('word/document.xml', headerRel.target);
          expect(package.hasPart(headerPart), isTrue, reason: headerPart);
          for (final imageRel
              in package.relationshipsFor(headerPart).ofType(RelType.image)) {
            final imagePart = package.resolveTarget(headerPart, imageRel.target);
            expect(package.hasPart(imagePart), isTrue, reason: imagePart);
            headerImages++;
          }
        }
        expect(headerImages, greaterThanOrEqualTo(1));
      });

      test('todos os targets internos de todos os .rels resolvem', () {
        final relsParts = package.partNames
            .where((name) => name.endsWith('.rels'))
            .toList();
        expect(relsParts, isNotEmpty);
        for (final relsPart in relsParts) {
          // Parte dona do .rels: remove o segmento `_rels/` e o sufixo.
          final owner = relsPart == '_rels/.rels'
              ? null
              : relsPart
                  .replaceFirst('_rels/', '')
                  .replaceFirst(RegExp(r'\.rels$'), '');
          final rels = package.relationshipsFor(owner);
          for (final rel in rels.items) {
            if (rel.isExternal) continue;
            final target = package.resolveTarget(owner, rel.target);
            expect(package.hasPart(target), isTrue,
                reason: '$relsPart → ${rel.target}');
          }
        }
      });

      if (label == 'TR') {
        test('TR tem os 3 hyperlinks externos (seção 2.2)', () {
          final rels = package.relationshipsFor('word/document.xml');
          final externals =
              rels.ofType(RelType.hyperlink).where((r) => r.isExternal);
          expect(externals, hasLength(3));
          for (final rel in externals) {
            expect(rel.target, startsWith('http'));
          }
        });
      }

      test('aceite F1: abrir → não tocar → salvar = byte-fiel', () {
        final saved = OpcPackage.decode(original).save();
        expect(saved.length, original.length);
        for (var i = 0; i < saved.length; i++) {
          if (saved[i] != original[i]) {
            fail('bytes divergem no offset $i');
          }
        }
      });

      test('editar uma parte mantém as demais e o pacote reabre', () {
        final edited = OpcPackage.decode(original);
        final xml = edited.partString('word/document.xml')!;
        edited.setPartString('word/document.xml', xml);
        final reopened = OpcPackage.decode(edited.save());
        expect(reopened.partNames, package.partNames);
        expect(reopened.partString('word/document.xml'), xml);
        for (final name in package.partNames) {
          expect(reopened.partBytes(name)!.length,
              package.partBytes(name)!.length,
              reason: name);
        }
      });
    });
  }
}
