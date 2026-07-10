/// Leitura, escrita e validação de WordprocessingML/DOCX.
library;

export 'src/document/docx/effective.dart' show FormatResolver;
export 'src/document/docx/model.dart';
export 'src/document/docx/numbering.dart'
    show
        NumberingCounters,
        WpAbstractNum,
        WpNum,
        WpNumbering,
        WpNumberingLevel,
        formatNumber;
export 'src/document/docx/reader.dart' show DocxFile, DocxReader;
export 'src/document/docx/styles.dart' show WpStyle, WpStyleSheet;
export 'src/document/docx/units.dart' show Units;
export 'src/document/docx/validator.dart' show DocxValidator;
export 'src/document/docx/writer.dart' show DocxWriter;
