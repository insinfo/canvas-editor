/// Parser/serializer XML 1.0 namespace-aware em Dart puro
/// (roteiro_editor_profissional, Fase 1.2 / decisão D6).
///
/// - SAX streaming ([XmlSaxParser]) para partes grandes (document.xml);
/// - DOM leve ([XmlDocument]) para partes pequenas;
/// - serializer com controle exato de escape ([XmlEscape]).
library;

export 'src/dom.dart';
export 'src/sax.dart'
    show
        XmlNameUtil,
        XmlParseException,
        XmlSaxAttribute,
        XmlSaxHandler,
        XmlSaxParser;
export 'src/serializer.dart' show XmlEscape;
