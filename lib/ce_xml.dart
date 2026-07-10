/// XML namespace-aware usado pelo suporte a DOCX.
library;

export 'src/document/xml/dom.dart';
export 'src/document/xml/sax.dart'
    show
        XmlNameUtil,
        XmlParseException,
        XmlSaxAttribute,
        XmlSaxHandler,
        XmlSaxParser;
export 'src/document/xml/serializer.dart' show XmlEscape;
