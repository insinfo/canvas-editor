/// WordprocessingML tipado: reader + preservação + cascata de estilos
/// (roteiro_editor_profissional, Fase 2; writer na Fase 3).
library;

export 'src/effective.dart' show FormatResolver;
export 'src/model.dart';
export 'src/numbering.dart'
    show
        NumberingCounters,
        WpAbstractNum,
        WpNum,
        WpNumbering,
        WpNumberingLevel,
        formatNumber;
export 'src/reader.dart' show DocxFile, DocxReader;
export 'src/styles.dart' show WpStyle, WpStyleSheet;
export 'src/units.dart' show Units;
