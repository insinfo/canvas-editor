import 'dart:io';
import 'dart:typed_data';

import 'package:canvas_text_editor/ce_xml.dart';
import 'package:canvas_text_editor/ce_zip.dart';
import 'package:test/test.dart';

/// TR: document.xml de 4,45 MB — corpus real da seção 2.2 do roteiro.
const _trPath =
    'resources/PGCTIC1_-_TR_-_SISTEMA_GESTAO_PUBLICA__Recuperação_Automática_.docx';

class _EventCollector extends XmlSaxHandler {
  final List<String> events = [];

  @override
  void xmlDeclaration(String? version, String? encoding, String? standalone) =>
      events.add('decl:$version/$encoding/$standalone');

  @override
  void startElement(
          String qname, List<XmlSaxAttribute> attributes, bool selfClosing) =>
      events.add('start:$qname'
          '${attributes.isEmpty ? '' : attributes.join(',')}'
          '${selfClosing ? '/' : ''}');

  @override
  void endElement(String qname) => events.add('end:$qname');

  @override
  void characters(String text) => events.add('text:$text');

  @override
  void cdata(String text) => events.add('cdata:$text');

  @override
  void comment(String text) => events.add('comment:$text');

  @override
  void processingInstruction(String target, String? data) =>
      events.add('pi:$target:$data');
}

class _CountingHandler extends XmlSaxHandler {
  int elements = 0;
  int attributes = 0;
  int textLength = 0;

  @override
  void startElement(
      String qname, List<XmlSaxAttribute> attributes, bool selfClosing) {
    elements++;
    this.attributes += attributes.length;
  }

  @override
  void characters(String text) {
    textLength += text.length;
  }
}

void main() {
  group('SAX', () {
    test('emite a sequência de eventos esperada', () {
      final collector = _EventCollector();
      XmlSaxParser.parseString(
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<!-- oi --><a x="1"><b/>t1<c y="2" z="3">t2</c>'
          '<![CDATA[<raw>&]]><?pi dados?></a>',
          collector);
      expect(collector.events, [
        'decl:1.0/UTF-8/yes',
        'comment: oi ',
        'start:ax="1"',
        'start:b/',
        'end:b',
        'text:t1',
        'start:cy="2",z="3"',
        'text:t2',
        'end:c',
        'cdata:<raw>&',
        'pi:pi:dados',
        'end:a',
      ]);
    });

    test('decodifica entidades predefinidas e numéricas', () {
      final collector = _EventCollector();
      XmlSaxParser.parseString(
          '<a>&amp;&lt;&gt;&quot;&apos;&#65;&#x42;&#x1F600;</a>', collector);
      expect(collector.events[1], 'text:&<>"\'AB😀');
    });

    test('normaliza CRLF em texto e whitespace em atributos', () {
      final collector = _EventCollector();
      XmlSaxParser.parseString('<a b="x\ty\r\nz">l1\r\nl2\rl3</a>', collector);
      expect(collector.events[0], 'start:ab="x y z"');
      expect(collector.events[1], 'text:l1\nl2\nl3');
    });

    test('referências de caractere preservam whitespace em atributos', () {
      final collector = _EventCollector();
      XmlSaxParser.parseString('<a b="x&#x9;y&#xA;z&#xD;w"/>', collector);
      expect(collector.events[0], 'start:ab="x\ty\nz\rw"/');
    });

    test('rejeita XML malformado com posição', () {
      expect(() => XmlSaxParser.parseString('<a><b></a>', _EventCollector()),
          throwsA(isA<XmlParseException>()));
      expect(
          () => XmlSaxParser.parseString('<a>&bogus;</a>', _EventCollector()),
          throwsA(isA<XmlParseException>()));
      expect(() => XmlSaxParser.parseString('<a', _EventCollector()),
          throwsA(isA<XmlParseException>()));
      expect(() => XmlSaxParser.parseString('<a/><b/>', _EventCollector()),
          throwsA(isA<XmlParseException>()));
    });

    test('pula DOCTYPE sem resolução externa', () {
      final collector = _EventCollector();
      XmlSaxParser.parseString(
          '<!DOCTYPE root [<!ENTITY x "y">]><root/>', collector);
      expect(collector.events, ['start:root/', 'end:root']);
    });
  });

  group('DOM', () {
    test('navegação: filhos, descendentes, texto, atributos', () {
      final doc = XmlDocument.parse('<w:document xmlns:w="urn:w"><w:body>'
          '<w:p><w:r><w:t>Olá</w:t></w:r><w:r><w:t> Word</w:t></w:r></w:p>'
          '<w:p/></w:body></w:document>');
      final root = doc.rootElement;
      expect(root.qname, 'w:document');
      expect(root.localName, 'document');
      expect(root.prefix, 'w');
      final body = root.firstChild('w:body')!;
      expect(body.childrenNamed('w:p'), hasLength(2));
      expect(root.descendantsNamed('w:t'), hasLength(2));
      expect(body.childrenNamed('w:p').first.text, 'Olá Word');
      expect(root.getAttribute('xmlns:w'), 'urn:w');
    });

    test('resolução de namespaces sobe pela árvore', () {
      final doc = XmlDocument.parse('<a xmlns="urn:default" xmlns:x="urn:x">'
          '<x:b><c xmlns:y="urn:y"><y:d/></c></x:b></a>');
      final root = doc.rootElement;
      final b = root.childElements.first;
      final c = b.childElements.first;
      final d = c.childElements.first;
      expect(root.namespaceUri, 'urn:default');
      expect(b.namespaceUri, 'urn:x');
      expect(c.namespaceUri, 'urn:default');
      expect(d.namespaceUri, 'urn:y');
      expect(d.resolvePrefix('x'), 'urn:x');
      expect(d.resolvePrefix('nope'), isNull);
    });

    test('mutação: setAttribute/add/insert/remove', () {
      final doc = XmlDocument.parse('<a b="1"><c/></a>');
      final root = doc.rootElement;
      root.setAttribute('b', '2');
      root.setAttribute('d', '3');
      final novo = XmlElement('e');
      root.insert(0, novo);
      expect(root.toXmlString(), '<a b="2" d="3"><e/><c/></a>');
      expect(root.remove(novo), isTrue);
      root.removeAttribute('d');
      expect(root.toXmlString(), '<a b="2"><c/></a>');
    });
  });

  group('serializer', () {
    test('escape exato em texto e atributos', () {
      expect(XmlEscape.text('a&b<c>d\re'), 'a&amp;b&lt;c&gt;d&#xD;e');
      expect(XmlEscape.attribute('a"b\tc\nd\re&<>'),
          'a&quot;b&#x9;c&#xA;d&#xD;e&amp;&lt;&gt;');
      expect(XmlEscape.text('sem escape'), 'sem escape');
    });

    test('round-trip estável (parse → serialize → parse → serialize)', () {
      const source = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '\r\n<w:doc xmlns:w="urn:w" a="x&amp;y">'
          '<w:t xml:space="preserve"> a &lt; b </w:t>'
          '<!--c--><w:sp/><?pi d?></w:doc>';
      final doc = XmlDocument.parse(source);
      final once = doc.toXmlString();
      final twice = XmlDocument.parse(once).toXmlString();
      expect(once, source, reason: 'output idêntico ao input canônico');
      expect(twice, once);
    });

    test('whitespace de atributo sobrevive ao round-trip', () {
      final doc = XmlDocument.parse('<a/>');
      doc.rootElement.setAttribute('v', 'x\ty\nz\rw');
      final reparsed = XmlDocument.parse(doc.toXmlString());
      expect(reparsed.rootElement.getAttribute('v'), 'x\ty\nz\rw');
    });

    test('CR em texto sobrevive ao round-trip', () {
      final doc = XmlDocument.parse('<a/>');
      doc.rootElement.add(XmlText('linha1\rlinha2'));
      final reparsed = XmlDocument.parse(doc.toXmlString());
      expect(reparsed.rootElement.text, 'linha1\rlinha2');
    });
  });

  group('corpus TR (document.xml 4,45 MB)', () {
    late Uint8List documentXml;

    setUpAll(() {
      final archive = ZipArchive.decodeBytes(File(_trPath).readAsBytesSync());
      documentXml = archive.readBytes('word/document.xml')!;
      expect(documentXml.length, greaterThan(4000000));
    });

    test('SAX parse < 500 ms (aceite F1.2)', () {
      // Aquecimento (JIT) fora da medição.
      XmlSaxParser.parseBytes(documentXml, _CountingHandler());

      final handler = _CountingHandler();
      final stopwatch = Stopwatch()..start();
      XmlSaxParser.parseBytes(documentXml, handler);
      stopwatch.stop();

      // ignore: avoid_print
      print('SAX TR: ${stopwatch.elapsedMilliseconds} ms, '
          '${handler.elements} elementos, ${handler.attributes} atributos');
      expect(handler.elements, greaterThan(100000));
      expect(stopwatch.elapsedMilliseconds, lessThan(500),
          reason: 'orçamento do roteiro F1.2');
    });

    test('namespaces w:, wp:, mc:, v:, r: resolvem para as URIs OOXML', () {
      final doc = XmlDocument.parseBytes(documentXml);
      final root = doc.rootElement;
      expect(root.qname, 'w:document');
      expect(root.resolvePrefix('w'),
          'http://schemas.openxmlformats.org/wordprocessingml/2006/main');
      expect(root.resolvePrefix('r'),
          'http://schemas.openxmlformats.org/officeDocument/2006/relationships');
      expect(root.resolvePrefix('wp'),
          'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing');
      expect(root.resolvePrefix('mc'),
          'http://schemas.openxmlformats.org/markup-compatibility/2006');
      expect(root.resolvePrefix('v'), 'urn:schemas-microsoft-com:vml');
    });

    test('DOM round-trip well-formed e estável no document.xml real', () {
      final doc = XmlDocument.parseBytes(documentXml);
      final once = doc.toXmlString();
      final reparsed = XmlDocument.parse(once);
      expect(reparsed.rootElement.qname, 'w:document');
      expect(reparsed.toXmlString(), once,
          reason: 'serialização deve ser um ponto fixo');
      expect(reparsed.rootElement.descendantsNamed('w:t').length,
          doc.rootElement.descendantsNamed('w:t').length);
    });
  });
}
