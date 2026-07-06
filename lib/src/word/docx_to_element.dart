// Conversor WordprocessingML → IElement[] do editor
// (roteiro_editor_profissional, F2.3).
//
// Mantém-se puro (sem dart:html): importa apenas as interfaces/enums do
// modelo do editor, para poder rodar em testes VM.

import 'dart:convert';

import 'package:ce_docx/ce_docx.dart';

import '../editor/dataset/enum/element.dart';
import '../editor/dataset/enum/row.dart';
import '../editor/dataset/enum/table/table.dart';
import '../editor/dataset/enum/title.dart';
import '../editor/dataset/enum/vertical_align.dart';
import '../editor/interface/element.dart';
import '../editor/interface/table/td.dart';

/// Resultado da conversão de um DOCX para o modelo do editor.
class DocxConversionResult {
  final List<IElement> header;
  final List<IElement> main;
  final List<IElement> footer;
  final double pageWidthPx;
  final double pageHeightPx;

  /// Margens em px na ordem do editor: [top, right, bottom, left].
  final List<double> marginsPx;

  /// Notas de fidelidade (o que foi substituído/só preservado).
  final List<String> notes;

  DocxConversionResult({
    required this.header,
    required this.main,
    required this.footer,
    required this.pageWidthPx,
    required this.pageHeightPx,
    required this.marginsPx,
    required this.notes,
  });
}

/// Cores de `w:highlight` → hex CSS.
const Map<String, String> _highlightColors = {
  'yellow': '#FFFF00',
  'green': '#00FF00',
  'cyan': '#00FFFF',
  'magenta': '#FF00FF',
  'blue': '#0000FF',
  'red': '#FF0000',
  'darkBlue': '#00008B',
  'darkCyan': '#008B8B',
  'darkGreen': '#006400',
  'darkMagenta': '#8B008B',
  'darkRed': '#8B0000',
  'darkYellow': '#808000',
  'darkGray': '#A9A9A9',
  'lightGray': '#D3D3D3',
  'black': '#000000',
  'white': '#FFFFFF',
};

class DocxToElementConverter {
  final DocxFile file;
  final FormatResolver _resolver;
  final NumberingCounters _counters;
  final List<String> _notes = [];

  DocxToElementConverter._(this.file)
      : _resolver = FormatResolver(file.styles),
        _counters = NumberingCounters(file.numbering);

  static DocxConversionResult convert(DocxFile file) =>
      DocxToElementConverter._(file)._convert();

  DocxConversionResult _convert() {
    final mainPart = file.package.mainDocumentPartName;
    final main = _convertBlocks(file.document.body,
        fromPart: mainPart, stampBlocks: true);

    final headerBlocks = file.headersByType['default'];
    final footerBlocks = file.footersByType['default'];
    final header = headerBlocks == null
        ? <IElement>[]
        : _convertBlocks(headerBlocks.blocks, fromPart: headerBlocks.partName);
    final footer = footerBlocks == null
        ? <IElement>[]
        : _convertBlocks(footerBlocks.blocks, fromPart: footerBlocks.partName);
    if (file.headersByType.length > 1) {
      _notes.add('headers first/even convertidos apenas como default '
          '(seleção por tipo na Fase 4.6)');
    }

    final section = file.document.section;
    return DocxConversionResult(
      header: header,
      main: main,
      footer: footer,
      pageWidthPx: Units.twipToPx(section?.pageWidthTwips ?? 11906),
      pageHeightPx: Units.twipToPx(section?.pageHeightTwips ?? 16838),
      marginsPx: [
        Units.twipToPx(section?.marginTopTwips ?? 1440),
        Units.twipToPx(section?.marginRightTwips ?? 1800),
        Units.twipToPx(section?.marginBottomTwips ?? 1440),
        Units.twipToPx(section?.marginLeftTwips ?? 1800),
      ],
      notes: _notes,
    );
  }

  // ---- Blocos ----

  List<IElement> _convertBlocks(List<WpBlock> blocks,
      {required String fromPart, bool stampBlocks = false}) {
    final elements = <IElement>[];
    var first = true;
    for (var index = 0; index < blocks.length; index++) {
      final block = blocks[index];
      final startLength = elements.length;
      switch (block) {
        case WpParagraph paragraph:
          final pPr = _resolver.resolveParagraph(paragraph);
          if (!first) {
            elements.add(_paragraphBreak(pPr));
          }
          elements.addAll(_convertParagraph(paragraph, pPr, fromPart));
          first = false;
        case WpTable table:
          if (!first) elements.add(IElement(value: '\n'));
          final converted = _convertTable(table, fromPart);
          if (converted != null) elements.add(converted);
          first = false;
        case WpPreservedBlock preserved:
          _notes.add('bloco preservado não renderizado: ${preserved.qname}');
      }
      if (stampBlocks) {
        for (var i = startLength; i < elements.length; i++) {
          _stampBlockIndex(elements[i], index);
        }
      }
    }
    return elements;
  }

  /// Marca o elemento (e descendentes) com o índice do bloco de origem no
  /// body — usado pelo bridge editor→docx para o passthrough D1 no save.
  static void _stampBlockIndex(IElement element, int index) {
    element.externalId ??= 'wp:$index';
    final children = element.valueList;
    if (children != null) {
      for (final child in children) {
        _stampBlockIndex(child, index);
      }
    }
    final trList = element.trList;
    if (trList != null) {
      for (final tr in trList) {
        for (final td in tr.tdList) {
          for (final child in td.value) {
            _stampBlockIndex(child, index);
          }
        }
      }
    }
  }

  /// Elemento '\n' que inicia a linha do parágrafo, carregando o alinhamento.
  IElement _paragraphBreak(WpParagraphProperties pPr) => IElement(
        value: '\n',
        rowFlex: _rowFlex(pPr.jc),
        rowMargin: _rowMargin(pPr.spacing),
      );

  // ---- Parágrafo ----

  List<IElement> _convertParagraph(
      WpParagraph paragraph, WpParagraphProperties pPr, String fromPart) {
    final rowFlex = _rowFlex(pPr.jc);
    final rowMargin = _rowMargin(pPr.spacing);
    final elements = <IElement>[];

    // Numeração multinível → marcador textual inline (motor real na F4.2).
    final numPr = pPr.numPr;
    if (numPr != null && numPr.numId != null && numPr.numId != 0) {
      final marker = _counters.next(numPr.numId!, numPr.ilvl);
      if (marker != null && marker.isNotEmpty) {
        final markerStyle = _resolver.resolveRun(paragraph, null);
        elements.add(_styledText('$marker ', markerStyle, rowFlex, rowMargin)
          ..extension = const {'wpMarker': true});
      }
    }

    var fieldState = _FieldState.none;
    for (final inline in paragraph.inlines) {
      switch (inline) {
        case WpRun run:
          fieldState = _convertRun(
              paragraph, run, elements, fieldState, rowFlex, rowMargin,
              fromPart: fromPart);
        case WpHyperlink link:
          final valueList = <IElement>[];
          var linkFieldState = _FieldState.none;
          for (final run in link.runs) {
            linkFieldState = _convertRun(
                paragraph, run, valueList, linkFieldState, null, null,
                fromPart: fromPart);
          }
          if (valueList.isEmpty) break;
          final url = link.relId != null
              ? file.hyperlinkUrl(link.relId!, fromPart: fromPart)
              : (link.anchor != null ? '#${link.anchor}' : null);
          elements.add(IElement(
            type: ElementType.hyperlink,
            value: '',
            url: url ?? '',
            valueList: valueList,
            rowFlex: rowFlex,
            rowMargin: rowMargin,
          ));
        case WpSimpleField field:
          // Campo simples: usa o resultado em cache (motor real na F4.7).
          _notes.add('fldSimple com resultado em cache: '
              '${field.instruction.trim()}');
          var innerState = _FieldState.none;
          for (final run in field.runs) {
            innerState = _convertRun(
                paragraph, run, elements, innerState, rowFlex, rowMargin,
                fromPart: fromPart);
          }
        case WpPreservedInline preserved:
          if (preserved.qname == 'mc:AlternateContent') {
            _notes.add('text box (carimbo) preservado, sem render '
                '(placeholder na Fase 4.8)');
          }
      }
    }

    // Título: outlineLvl efetivo vira TITLE (catálogo/navegação).
    final outline = pPr.outlineLvl;
    if (outline != null && outline >= 0 && elements.isNotEmpty) {
      return [
        IElement(
          type: ElementType.title,
          value: '',
          level: _titleLevel(outline),
          valueList: elements,
          rowFlex: rowFlex,
          rowMargin: rowMargin,
        )
      ];
    }
    return elements;
  }

  _FieldState _convertRun(
    WpParagraph paragraph,
    WpRun run,
    List<IElement> into,
    _FieldState fieldState,
    RowFlex? rowFlex,
    double? rowMargin, {
    required String fromPart,
  }) {
    final rPr = _resolver.resolveRun(paragraph, run.properties);
    var state = fieldState;
    for (final content in run.content) {
      switch (content) {
        case WpFieldChar fieldChar:
          state = switch (fieldChar.fldCharType) {
            'begin' => _FieldState.instruction,
            'separate' => _FieldState.result,
            _ => _FieldState.none, // end
          };
        case WpInstrText instr:
          if (state == _FieldState.instruction) {
            _notes.add('campo com resultado em cache: ${instr.text.trim()} '
                '(motor de campos na Fase 4.7)');
          }
        case WpText text:
          // Dentro da instrução do campo o texto não é visível.
          if (state != _FieldState.instruction && text.text.isNotEmpty) {
            into.add(_styledText(text.text, rPr, rowFlex, rowMargin));
          }
        case WpTabChar _:
          into.add(IElement(
              type: ElementType.tab,
              value: '',
              rowFlex: rowFlex,
              rowMargin: rowMargin));
        case WpBreak brk:
          if (brk.breakType == 'page') {
            into.add(IElement(type: ElementType.pageBreak, value: ''));
          } else {
            // Quebra de linha (w:br) ≠ fim de parágrafo: marcada para o
            // bridge editor→docx não dividir o parágrafo no save.
            into.add(IElement(value: '\n')
              ..extension = const {'wpBr': true});
          }
        case WpNoBreakHyphen _:
          into.add(_styledText('‑', rPr, rowFlex, rowMargin));
        case WpSymbol symbol:
          into.add(_styledText(_symbolChar(symbol), rPr, rowFlex, rowMargin));
        case WpDrawing drawing:
          final image = _convertDrawing(drawing, fromPart);
          if (image != null) into.add(image);
        case WpPreservedRunContent preserved:
          if (preserved.qname == 'mc:AlternateContent' ||
              preserved.qname == 'w:pict') {
            _notes.add('text box (carimbo) preservado, sem render '
                '(placeholder na Fase 4.8): ${preserved.qname}');
          }
      }
    }
    return state;
  }

  IElement _styledText(String text, WpRunProperties rPr, RowFlex? rowFlex,
      double? rowMargin) {
    final sizeHalf = rPr.sizeHalfPoints;
    final underline = rPr.underline;
    final highlight = rPr.highlight != null
        ? _highlightColors[rPr.highlight!]
        : _shadingFill(rPr.shading);
    final element = IElement(
      value: rPr.caps == true ? text.toUpperCase() : text,
      font: rPr.fontAscii ?? rPr.fontHAnsi,
      size: sizeHalf == null ? null : Units.halfPointToPx(sizeHalf).round(),
      bold: rPr.bold,
      italic: rPr.italic,
      underline: underline != null && underline != 'none' ? true : null,
      strikeout: rPr.strike,
      color: _hexColor(rPr.color),
      highlight: highlight,
      rowFlex: rowFlex,
      rowMargin: rowMargin,
    );
    if (rPr.vertAlign == 'superscript') {
      element.type = ElementType.superscript;
    } else if (rPr.vertAlign == 'subscript') {
      element.type = ElementType.subscript;
    }
    return element;
  }

  IElement? _convertDrawing(WpDrawing drawing, String fromPart) {
    final relId = drawing.embedRelId;
    if (relId == null) {
      _notes.add('drawing sem blip embed ignorado');
      return null;
    }
    final bytes = file.imageBytes(relId, fromPart: fromPart);
    if (bytes == null) {
      _notes.add('imagem não encontrada para rel $relId de $fromPart');
      return null;
    }
    final contentType =
        file.imageContentType(relId, fromPart: fromPart) ?? 'image/png';
    if (!drawing.isInline) {
      _notes.add('imagem flutuante renderizada como inline (Fase 4)');
    }
    return IElement(
      type: ElementType.image,
      value: 'data:$contentType;base64,${base64Encode(bytes)}',
      width: drawing.widthEmu == null
          ? 100
          : Units.emuToPx(drawing.widthEmu!),
      height: drawing.heightEmu == null
          ? 100
          : Units.emuToPx(drawing.heightEmu!),
    )..extension = {'wpDrawing': drawing.rawXml};
  }

  // ---- Tabela ----

  IElement? _convertTable(WpTable table, String fromPart) {
    if (table.rows.isEmpty) return null;

    // Grid: larguras das colunas em px.
    final colgroup = [
      for (final twips in table.gridColumnsTwips)
        IColgroup(width: Units.twipToPx(twips))
    ];

    // Mapeia células a colunas do grid para resolver vMerge → rowspan.
    // startCols[r][i] = coluna inicial da célula i da linha r.
    final startCols = <List<int>>[];
    for (final row in table.rows) {
      final cols = <int>[];
      var col = 0;
      for (final cell in row.cells) {
        cols.add(col);
        col += cell.properties?.gridSpan ?? 1;
      }
      startCols.add(cols);
    }

    int rowspanOf(int rowIndex, int cellIndex) {
      final col = startCols[rowIndex][cellIndex];
      var span = 1;
      for (var r = rowIndex + 1; r < table.rows.length; r++) {
        final cells = table.rows[r].cells;
        var found = false;
        for (var i = 0; i < cells.length; i++) {
          if (startCols[r][i] != col) continue;
          if (cells[i].properties?.vMerge == 'continue') {
            span++;
            found = true;
          }
          break;
        }
        if (!found) break;
      }
      return span;
    }

    final trList = <ITr>[];
    for (var r = 0; r < table.rows.length; r++) {
      final row = table.rows[r];
      final trPr = row.properties;
      final heightPx = trPr?.heightTwips != null
          ? Units.twipToPx(trPr!.heightTwips!)
          : 40.0;
      final tdList = <ITd>[];
      for (var i = 0; i < row.cells.length; i++) {
        final cell = row.cells[i];
        final tcPr = cell.properties;
        if (tcPr?.vMerge == 'continue') continue; // absorvida pelo restart
        final value = _convertCellBlocks(cell.blocks, fromPart);
        tdList.add(ITd(
          colspan: tcPr?.gridSpan ?? 1,
          rowspan: tcPr?.vMerge == 'restart' ? rowspanOf(r, i) : 1,
          value: value,
          backgroundColor: _shadingFill(tcPr?.shading),
          verticalAlign: switch (tcPr?.vAlign) {
            'center' => VerticalAlign.middle,
            'bottom' => VerticalAlign.bottom,
            'top' => VerticalAlign.top,
            _ => null,
          },
          borderTypes: _borderTypes(tcPr?.borders),
        ));
      }
      if (tdList.isEmpty) continue;
      trList.add(ITr(
        height: heightPx.clamp(20.0, double.infinity),
        tdList: tdList,
        minHeight: trPr?.heightRule == 'atLeast' ? heightPx : null,
        pagingRepeat: trPr?.tblHeader == true ? true : null,
      ));
    }
    if (trList.isEmpty) return null;

    return IElement(
      type: ElementType.table,
      value: '',
      colgroup: colgroup,
      trList: trList,
      borderType: TableBorder.all,
    );
  }

  List<IElement> _convertCellBlocks(List<WpBlock> blocks, String fromPart) {
    // Tabela aninhada em célula não é suportada pelo modelo do editor:
    // achata o conteúdo textual e registra na nota de fidelidade.
    final flattened = <WpBlock>[];
    for (final block in blocks) {
      if (block is WpTable) {
        _notes.add('tabela aninhada achatada em célula (não suportada)');
        for (final row in block.rows) {
          for (final cell in row.cells) {
            flattened.addAll(cell.blocks);
          }
        }
      } else {
        flattened.add(block);
      }
    }
    final elements = _convertBlocks(flattened, fromPart: fromPart);
    if (elements.isEmpty) {
      elements.add(IElement(value: ''));
    }
    return elements;
  }

  List<TdBorder>? _borderTypes(WpBorders? borders) {
    if (borders == null) return null;
    bool visible(WpBorder? side) =>
        side != null && side.val != null && side.val != 'none' &&
        side.val != 'nil';
    final types = <TdBorder>[
      if (visible(borders.top)) TdBorder.top,
      if (visible(borders.right)) TdBorder.right,
      if (visible(borders.bottom)) TdBorder.bottom,
      if (visible(borders.left)) TdBorder.left,
    ];
    return types.isEmpty ? null : types;
  }

  // ---- Helpers de estilo ----

  static RowFlex? _rowFlex(String? jc) => switch (jc) {
        'center' => RowFlex.center,
        'right' || 'end' => RowFlex.right,
        'both' => RowFlex.alignment,
        'distribute' => RowFlex.justify,
        _ => null,
      };

  /// `w:spacing w:line` em modo auto é múltiplo de 240 (single).
  static double? _rowMargin(WpSpacing? spacing) {
    final line = spacing?.line;
    if (line == null) return null;
    final rule = spacing?.lineRule ?? 'auto';
    if (rule == 'auto') {
      final factor = line / 240.0;
      return factor == 1.0 ? null : factor;
    }
    return null; // atLeast/exact entram no layout na Fase 4.3
  }

  static String? _hexColor(String? color) {
    if (color == null || color == 'auto') return null;
    return '#$color';
  }

  static String? _shadingFill(WpShading? shading) {
    final fill = shading?.fill;
    if (fill == null || fill == 'auto') return null;
    return '#$fill';
  }

  static TitleLevel _titleLevel(int outlineLvl) => switch (outlineLvl) {
        0 => TitleLevel.first,
        1 => TitleLevel.second,
        2 => TitleLevel.third,
        3 => TitleLevel.fourth,
        4 => TitleLevel.fifth,
        _ => TitleLevel.sixth,
      };

  static String _symbolChar(WpSymbol symbol) {
    final hex = symbol.charHex;
    if (hex == null) return '•';
    final code = int.tryParse(hex, radix: 16);
    if (code == null) return '•';
    return switch (code) {
      0xF0B7 => '•',
      0xF0A7 => '■',
      0xF06F => '○',
      0xF0FC => '✓',
      0xF0D8 => '➢',
      _ => code >= 0xF000 && code <= 0xF0FF
          ? '•'
          : String.fromCharCode(code),
    };
  }
}

enum _FieldState { none, instruction, result }
