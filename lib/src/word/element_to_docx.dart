// Bridge editor → DOCX (roteiro_editor_profissional, F3.3).
//
// Sincroniza o conteúdo atual do editor (IElement[]) de volta ao modelo
// WordprocessingML aberto, mantendo o passthrough D1: blocos cujo conteúdo
// não mudou desde a abertura re-usam o bloco original (XML byte a byte);
// blocos editados/novos são regenerados a partir dos elementos.

import 'dart:convert';

import 'package:canvas_text_editor/ce_docx.dart';
import 'package:canvas_text_editor/ce_opc.dart';

import '../editor/dataset/enum/element.dart';
import '../editor/dataset/enum/row.dart';
import '../editor/dataset/enum/table/table.dart';
import '../editor/dataset/enum/title.dart';
import '../editor/interface/element.dart';
import '../editor/interface/table/td.dart';

const String _zwsp = '​';

class EditorToDocx {
  final DocxFile file;
  final List<String> notes = [];
  int _docPrId = 1000;

  EditorToDocx._(this.file);

  /// Aplica [current] (conteúdo atual do editor) ao modelo de [file].
  /// [original] é a lista convertida na abertura — referência de "intocado".
  /// Retorna notas de fidelidade.
  static List<String> apply(
      DocxFile file, List<IElement> current, List<IElement> original) {
    final sync = EditorToDocx._(file);
    sync._apply(current, original);
    return sync.notes;
  }

  void _apply(List<IElement> current, List<IElement> original) {
    final currentSpecs = _split(current);
    final originalSpecs = <int, _BlockSpec>{};
    for (final spec in _split(original)) {
      final stamp = spec.stamp;
      if (stamp != null) originalSpecs[stamp] = spec;
    }

    final body = file.document.body;
    final preservedIndices = <int>[
      for (var i = 0; i < body.length; i++)
        if (body[i] is WpPreservedBlock) i
    ];
    var preservedCursor = 0;

    // Região do Sumário (extension['toc'] sem 'tocTitle'): os parágrafos das
    // entradas são envolvidos num complex field `TOC \o "1-9" \h` para o
    // Word reconhecer/atualizar via F9 (o resultado em cache é o que já
    // renderizamos). O título "Sumário" fica fora do campo.
    WpParagraph? tocFirstParagraph;
    WpParagraph? tocLastParagraph;
    bool specIsTocEntry(_BlockSpec spec) =>
        spec.table == null &&
        spec.elements.any((IElement e) {
          final dynamic ext = e.extension;
          return ext is Map && ext['toc'] != null && ext['tocTitle'] != true;
        });

    final newBody = <WpBlock>[];
    for (final spec in currentSpecs) {
      final stamp = spec.stamp;
      // Reinsere blocos preservados (bookmarks etc.) que vinham antes
      // deste bloco no body original.
      if (stamp != null) {
        while (preservedCursor < preservedIndices.length &&
            preservedIndices[preservedCursor] < stamp) {
          newBody.add(body[preservedIndices[preservedCursor]]);
          preservedCursor++;
        }
      }

      final originalBlock =
          stamp != null && stamp < body.length ? body[stamp] : null;
      final originalSpec = stamp != null ? originalSpecs[stamp] : null;

      if (originalBlock != null &&
          originalSpec != null &&
          _specsEqual(spec, originalSpec)) {
        newBody.add(originalBlock); // passthrough D1
        continue;
      }

      // Primeiro parágrafo vazio do documento: não tem separador antes,
      // logo não tem stamp — casa por posição quando intocado.
      if (stamp == null &&
          spec.table == null &&
          _meaningful(spec.elements).isEmpty &&
          newBody.length < body.length) {
        final positional = body[newBody.length];
        if (positional is WpParagraph && positional.text.isEmpty) {
          newBody.add(positional);
          continue;
        }
      }

      if (spec.table != null) {
        newBody.add(_tableFromElement(
            spec.table!,
            originalBlock is WpTable ? originalBlock : null,
            originalSpec?.table));
      } else {
        final WpParagraph paragraph = _paragraphFromElements(spec.elements,
            originalBlock is WpParagraph ? originalBlock.properties : null);
        if (specIsTocEntry(spec)) {
          tocFirstParagraph ??= paragraph;
          tocLastParagraph = paragraph;
        }
        newBody.add(paragraph);
      }
    }
    while (preservedCursor < preservedIndices.length) {
      newBody.add(body[preservedIndices[preservedCursor]]);
      preservedCursor++;
    }

    // Envelopa as entradas do Sumário no campo TOC (begin+instr+separate no
    // 1º parágrafo, end no último) — resultado em cache = o texto já gerado.
    if (tocFirstParagraph != null && tocLastParagraph != null) {
      tocFirstParagraph.inlines.insert(
        0,
        WpPreservedInline(
          'w:fldTocBegin',
          '<w:r><w:fldChar w:fldCharType="begin"/></w:r>'
              '<w:r><w:instrText xml:space="preserve"> TOC \\o "1-9" \\h \\z '
              '\\u </w:instrText></w:r>'
              '<w:r><w:fldChar w:fldCharType="separate"/></w:r>',
        ),
      );
      tocLastParagraph.inlines.add(WpPreservedInline(
        'w:fldTocEnd',
        '<w:r><w:fldChar w:fldCharType="end"/></w:r>',
      ));
      notes.add('sumário exportado como campo TOC (atualizável via F9)');
    }

    body
      ..clear()
      ..addAll(newBody);
  }

  // ---------------------------------------------------------------------
  // Split: lista plana do editor → especificações de bloco
  // ---------------------------------------------------------------------

  List<_BlockSpec> _split(List<IElement> elements) {
    final specs = <_BlockSpec>[];
    var currentElements = <IElement>[];
    var emittedSinceSeparator = false;
    var sawSeparator = false;

    // O separador '\n' que abre o bloco i carrega o stamp wp:i — é a única
    // fonte de identidade para parágrafos VAZIOS (que não têm elementos).
    int? previousSeparatorStamp;

    void flushParagraph() {
      specs.add(_BlockSpec.paragraph(currentElements,
          fallbackStamp: previousSeparatorStamp));
      currentElements = [];
      emittedSinceSeparator = true;
    }

    for (final element in _expandNewlines(elements)) {
      final isSeparator = element.type == null &&
          element.value == '\n' &&
          !_hasFlag(element, 'wpBr');
      if (isSeparator) {
        if (currentElements.isNotEmpty) {
          flushParagraph();
        } else if (!emittedSinceSeparator) {
          specs.add(_BlockSpec.paragraph(const [],
              fallbackStamp: previousSeparatorStamp));
        }
        emittedSinceSeparator = false;
        sawSeparator = true;
        previousSeparatorStamp = _stampOf(element);
        continue;
      }
      if (element.type == ElementType.table) {
        if (currentElements.isNotEmpty) flushParagraph();
        specs.add(_BlockSpec.table(element));
        emittedSinceSeparator = true;
        continue;
      }
      if (element.type == ElementType.list) {
        if (currentElements.isNotEmpty) flushParagraph();
        notes.add('lista criada no editor exportada como parágrafos');
        var item = <IElement>[];
        for (final child in element.valueList ?? const <IElement>[]) {
          if (child.type == null && child.value == '\n') {
            specs.add(_BlockSpec.paragraph(item));
            item = [];
          } else {
            item.add(child);
          }
        }
        specs.add(_BlockSpec.paragraph(item));
        emittedSinceSeparator = true;
        continue;
      }
      currentElements.add(element);
    }
    if (currentElements.isNotEmpty) {
      flushParagraph();
    } else if (sawSeparator && !emittedSinceSeparator) {
      specs.add(_BlockSpec.paragraph(const [],
          fallbackStamp: previousSeparatorStamp));
    }
    return specs;
  }

  /// O zip do editor pode fundir '\n' dentro de values multi-caractere
  /// (ZERO→'\n', Enter digitado). Expande esses values em elementos
  /// separados para o split enxergar os separadores de bloco.
  static List<IElement> _expandNewlines(List<IElement> elements) {
    List<IElement>? expanded;
    for (var i = 0; i < elements.length; i++) {
      final element = elements[i];
      final isPlainText =
          element.type == null || element.type == ElementType.text;
      if (!isPlainText ||
          _hasFlag(element, 'wpBr') ||
          element.value == '\n' ||
          !element.value.contains('\n')) {
        expanded?.add(element);
        continue;
      }
      expanded ??= [...elements.sublist(0, i)];
      final parts = element.value.split('\n');
      for (var p = 0; p < parts.length; p++) {
        if (p > 0) {
          expanded.add(IElement(value: '\n')..externalId = element.externalId);
        }
        if (parts[p].isNotEmpty) {
          expanded.add(_cloneWithValue(element, parts[p]));
        }
      }
    }
    return expanded ?? elements;
  }

  static IElement _cloneWithValue(IElement source, String value) => IElement(
        value: value,
        type: source.type,
        font: source.font,
        size: source.size,
        bold: source.bold,
        italic: source.italic,
        underline: source.underline,
        strikeout: source.strikeout,
        color: source.color,
        highlight: source.highlight,
        rowFlex: source.rowFlex,
        rowMargin: source.rowMargin,
        externalId: source.externalId,
        extension: source.extension,
      );

  // ---------------------------------------------------------------------
  // Comparação intocado vs. editado
  // ---------------------------------------------------------------------

  bool _specsEqual(_BlockSpec a, _BlockSpec b) {
    if ((a.table == null) != (b.table == null)) return false;
    if (a.table != null) return _sameTable(a.table!, b.table!);
    final left = _meaningful(a.elements);
    final right = _meaningful(b.elements);
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (!_sameElement(left[i], right[i])) return false;
    }
    return true;
  }

  static List<IElement> _meaningful(List<IElement> elements) => [
        for (final element in elements)
          if (!(element.type == null &&
              element.value.replaceAll(_zwsp, '').isEmpty &&
              element.value.isNotEmpty))
            element
      ];

  bool _sameElement(IElement a, IElement b) {
    // Bookmarks criados em sessão (ex.: âncoras do Sumário) precisam forçar
    // a regeneração do parágrafo para serem emitidos no DOCX.
    if (!_sameStringList(
        _extensionStrings(a, 'bookmarks'), _extensionStrings(b, 'bookmarks'))) {
      return false;
    }
    if (a.type != b.type ||
        _clean(a.value) != _clean(b.value) ||
        a.font != b.font ||
        a.size != b.size ||
        (a.bold ?? false) != (b.bold ?? false) ||
        (a.italic ?? false) != (b.italic ?? false) ||
        (a.underline ?? false) != (b.underline ?? false) ||
        (a.strikeout ?? false) != (b.strikeout ?? false) ||
        a.color != b.color ||
        a.highlight != b.highlight ||
        a.rowFlex != b.rowFlex ||
        a.level != b.level ||
        a.url != b.url) {
      return false;
    }
    // Imagem: mudança de modo de exibição (wrap) ou arrasto de float
    // precisam regenerar o parágrafo (wp:anchor novo).
    if (a.imgDisplay != b.imgDisplay ||
        _hasFlag(a, 'imgFloatMoved') != _hasFlag(b, 'imgFloatMoved')) {
      return false;
    }
    // Propriedades de parágrafo editáveis pela régua/ribbon: sem comparar
    // aqui, a edição cairia no passthrough D1 e se perderia no save.
    if (a.paraIndentLeft != b.paraIndentLeft ||
        a.paraIndentFirstLine != b.paraIndentFirstLine ||
        a.paraIndentRight != b.paraIndentRight ||
        a.paraSpacingBefore != b.paraSpacingBefore ||
        a.paraSpacingAfter != b.paraSpacingAfter ||
        a.lineSpacingRule != b.lineSpacingRule ||
        a.lineSpacingValue != b.lineSpacingValue ||
        !_sameTabStops(a.paraTabStops, b.paraTabStops)) {
      return false;
    }
    final aChildren = a.valueList ?? const <IElement>[];
    final bChildren = b.valueList ?? const <IElement>[];
    if (aChildren.length != bChildren.length) return false;
    for (var i = 0; i < aChildren.length; i++) {
      if (!_sameElement(aChildren[i], bChildren[i])) return false;
    }
    return true;
  }

  static bool _sameEnumNames(List<Enum>? a, List<Enum>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) {
      return (a == null || a.isEmpty) && (b == null || b.isEmpty);
    }
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].name != b[i].name) return false;
    }
    return true;
  }

  static bool _sameTabStops(List<ITabStop>? a, List<ITabStop>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) {
      return (a == null || a.isEmpty) && (b == null || b.isEmpty);
    }
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].type != b[i].type ||
          a[i].position != b[i].position ||
          a[i].leader != b[i].leader) {
        return false;
      }
    }
    return true;
  }

  bool _sameTable(IElement a, IElement b) {
    // Bordas da tabela (toolbar contextual): mudou → regenerar tblBorders.
    if (a.borderType != b.borderType ||
        a.borderColor != b.borderColor ||
        a.borderWidth != b.borderWidth) {
      return false;
    }
    final aTr = a.trList ?? const [];
    final bTr = b.trList ?? const [];
    if (aTr.length != bTr.length) return false;
    for (var r = 0; r < aTr.length; r++) {
      if (aTr[r].tdList.length != bTr[r].tdList.length) return false;
      for (var c = 0; c < aTr[r].tdList.length; c++) {
        final aTd = aTr[r].tdList[c];
        final bTd = bTr[r].tdList[c];
        if (aTd.colspan != bTd.colspan ||
            aTd.rowspan != bTd.rowspan ||
            aTd.backgroundColor != bTd.backgroundColor ||
            aTd.verticalAlign != bTd.verticalAlign ||
            !_sameEnumNames(aTd.borderTypes, bTd.borderTypes) ||
            !_sameEnumNames(aTd.slashTypes, bTd.slashTypes)) {
          return false;
        }
        final aValue = _meaningful(aTd.value);
        final bValue = _meaningful(bTd.value);
        if (aValue.length != bValue.length) return false;
        for (var i = 0; i < aValue.length; i++) {
          if (!_sameElement(aValue[i], bValue[i])) return false;
        }
      }
    }
    return true;
  }

  static String _clean(String value) => value.replaceAll(_zwsp, '');

  static bool _hasFlag(IElement element, String flag) {
    final extension = element.extension;
    return extension is Map && extension[flag] == true;
  }

  static bool _sameStringList(List<String>? a, List<String>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static List<String>? _extensionStrings(IElement element, String key) {
    final extension = element.extension;
    if (extension is! Map) return null;
    final value = extension[key];
    if (value is! List || value.isEmpty) return null;
    return value.cast<String>();
  }

  static int? _stampOf(IElement element) {
    final id = element.externalId;
    if (id == null || !id.startsWith('wp:')) return null;
    return int.tryParse(id.substring(3));
  }

  // ---------------------------------------------------------------------
  // Regeneração de parágrafo
  // ---------------------------------------------------------------------

  WpParagraph _paragraphFromElements(
      List<IElement> elements, WpParagraphProperties? base) {
    TitleLevel? headingLevel;
    final flattened = <IElement>[];
    void flatten(IElement element) {
      headingLevel ??= element.level;
      if (element.type == ElementType.title) {
        for (final child in element.valueList ?? const <IElement>[]) {
          flatten(child);
        }
        return;
      }
      flattened.add(element);
    }

    for (final element in elements) {
      flatten(element);
    }

    final inlines = <WpInline>[];
    final pendingRun = <WpRunContent>[];
    WpRunProperties? pendingProps;

    void flushRun() {
      if (pendingRun.isEmpty) return;
      inlines
          .add(WpRun(properties: pendingProps, content: List.of(pendingRun)));
      pendingRun.clear();
      pendingProps = null;
    }

    void addContent(WpRunProperties? props, WpRunContent content) {
      if (pendingRun.isNotEmpty && !_samePropsKey(pendingProps, props)) {
        flushRun();
      }
      pendingProps = props ?? pendingProps;
      pendingRun.add(content);
    }

    final deferredBookmarkEnds = <String>[];
    for (final element in flattened) {
      // Bookmarks capturados na abertura (extension['wpBookmark*Xml']) são
      // re-emitidos para não sumirem quando o parágrafo é regenerado — os
      // ends vão para o fim do parágrafo (âncora de título/TOC típica).
      final bookmarkStarts = _extensionStrings(element, 'wpBookmarkStartXml');
      if (bookmarkStarts != null) {
        flushRun();
        for (final xml in bookmarkStarts) {
          inlines.add(WpPreservedInline('w:bookmarkStart', xml));
        }
      }
      final bookmarkEnds = _extensionStrings(element, 'wpBookmarkEndXml');
      if (bookmarkEnds != null) deferredBookmarkEnds.addAll(bookmarkEnds);
      if (_hasFlag(element, 'wpMarker')) continue; // numeração vem do numPr
      if (_hasFlag(element, 'wpBr')) {
        // Quebra(s) de linha w:br — value contém apenas '\n's.
        for (var i = 0; i < element.value.length; i++) {
          if (element.value.codeUnitAt(i) == 0x0a) {
            addContent(null, WpBreak());
          }
        }
        continue;
      }
      switch (element.type) {
        case null || ElementType.superscript || ElementType.subscript:
          final text = _clean(element.value);
          if (text.isEmpty) break;
          addContent(_runPropsFrom(element), WpText(text));
        case ElementType.tab:
          addContent(null, WpTabChar());
        case ElementType.pageBreak:
          addContent(null, WpBreak('page'));
        case ElementType.image:
          final drawing = _drawingFor(element);
          if (drawing != null) addContent(null, drawing);
        case ElementType.hyperlink:
          flushRun();
          inlines.add(_hyperlinkFrom(element));
        case ElementType.separator:
          notes.add('separador exportado como parágrafo vazio');
        case _:
          final text = _clean(element.value);
          if (text.isNotEmpty) {
            addContent(_runPropsFrom(element), WpText(text));
          }
          notes.add('elemento ${element.type} exportado como texto');
      }
    }
    flushRun();
    for (final xml in deferredBookmarkEnds) {
      inlines.add(WpPreservedInline('w:bookmarkEnd', xml));
    }

    final rowFlex = flattened.isEmpty ? null : flattened.first.rowFlex;
    final jc = switch (rowFlex) {
      RowFlex.center => 'center',
      RowFlex.right => 'right',
      RowFlex.alignment => 'both',
      RowFlex.justify => 'distribute',
      _ => base?.styleId != null ? 'left' : null,
    };
    final int? outlineLevel = headingLevel == null
        ? null
        : <TitleLevel, int>{
            TitleLevel.first: 0,
            TitleLevel.second: 1,
            TitleLevel.third: 2,
            TitleLevel.fourth: 3,
            TitleLevel.fifth: 4,
            TitleLevel.sixth: 5,
          }[headingLevel];
    final String? headingStyleId =
        headingLevel == null ? null : _resolveHeadingStyleId(outlineLevel!);
    final IElement? paragraphAnchor =
        flattened.isEmpty ? null : flattened.first;
    final String? lineRule = paragraphAnchor?.lineSpacingRule;
    final double? lineValue = paragraphAnchor?.lineSpacingValue;
    final double? beforePx = paragraphAnchor?.paraSpacingBefore;
    final double? afterPx = paragraphAnchor?.paraSpacingAfter;
    final double? indentLeftPx = paragraphAnchor?.paraIndentLeft;
    final double? firstLinePx = paragraphAnchor?.paraIndentFirstLine;
    final double? indentRightPx = paragraphAnchor?.paraIndentRight;
    // F4.4: tab stops editados na régua vencem os do estilo base.
    final List<WpTabStop>? tabStops = paragraphAnchor?.paraTabStops == null
        ? null
        : <WpTabStop>[
            for (final stop in paragraphAnchor!.paraTabStops!)
              WpTabStop(
                val: stop.type,
                posTwips: (stop.position * 15).round(),
                leader: stop.leader,
              ),
          ];
    final WpSpacing? spacing =
        lineRule == null && beforePx == null && afterPx == null
            ? base?.spacing
            : WpSpacing(
                beforeTwips: beforePx == null
                    ? base?.spacing?.beforeTwips
                    : (beforePx * 15).round(),
                afterTwips: afterPx == null
                    ? base?.spacing?.afterTwips
                    : (afterPx * 15).round(),
                line: lineRule == null || lineValue == null
                    ? base?.spacing?.line
                    : lineRule == 'auto'
                        ? (lineValue * 240).round()
                        : (lineValue * 15).round(),
                lineRule: lineRule ?? base?.spacing?.lineRule,
              );
    final WpIndent? indent =
        indentLeftPx == null && firstLinePx == null && indentRightPx == null
            ? base?.indent
            : WpIndent(
                leftTwips: indentLeftPx == null
                    ? base?.indent?.leftTwips
                    : (indentLeftPx * 15).round(),
                rightTwips: indentRightPx == null
                    ? base?.indent?.rightTwips
                    : (indentRightPx * 15).round(),
                firstLineTwips: firstLinePx != null && firstLinePx >= 0
                    ? (firstLinePx * 15).round()
                    : null,
                hangingTwips: firstLinePx != null && firstLinePx < 0
                    ? (-firstLinePx * 15).round()
                    : null,
              );

    return WpParagraph(
      properties: base == null &&
              jc == null &&
              headingLevel == null &&
              spacing == null &&
              indent == null &&
              tabStops == null
          ? null
          : WpParagraphProperties(
              styleId: headingStyleId ?? base?.styleId,
              numPr: base?.numPr,
              jc: jc ?? base?.jc,
              spacing: spacing,
              indent: indent,
              tabs: tabStops ?? base?.tabs,
              shading: base?.shading,
              borders: base?.borders,
              keepNext: headingLevel != null ? true : base?.keepNext,
              keepLines: headingLevel != null ? true : base?.keepLines,
              pageBreakBefore: base?.pageBreakBefore,
              widowControl: base?.widowControl,
              contextualSpacing: base?.contextualSpacing,
              outlineLvl: outlineLevel ?? base?.outlineLvl,
              markRunProperties: base?.markRunProperties,
            ),
      inlines: inlines,
    );
  }

  String _resolveHeadingStyleId(int outlineLevel) {
    final int number = outlineLevel + 1;
    final RegExp namePattern = RegExp(
      '^(heading|title|título|titulo)\\s*$number\$',
      caseSensitive: false,
    );
    final List<WpStyle> paragraphStyles = file.styles.byId.values
        .where((WpStyle style) => style.type == 'paragraph')
        .toList(growable: false);
    for (final WpStyle style in paragraphStyles) {
      if (namePattern.hasMatch(style.name?.trim() ?? '')) return style.id;
    }
    for (final WpStyle style in paragraphStyles) {
      int? effectiveOutline;
      for (final WpStyle chained in file.styles.chainOf(style.id)) {
        effectiveOutline =
            chained.paragraphProperties?.outlineLvl ?? effectiveOutline;
      }
      if (effectiveOutline == outlineLevel) return style.id;
    }
    return 'Heading$number';
  }

  WpRunProperties _runPropsFrom(IElement element) => WpRunProperties(
        fontAscii: element.font,
        fontHAnsi: element.font,
        bold: element.bold == true,
        italic: element.italic == true,
        strike: element.strikeout == true,
        sizeHalfPoints:
            element.size == null ? null : (element.size! * 3 / 2).round(),
        color: element.color?.replaceFirst('#', ''),
        highlight: null,
        shading: element.highlight != null
            ? WpShading(fill: element.highlight!.replaceFirst('#', ''))
            : null,
        underline: element.underline == true ? 'single' : null,
        vertAlign: switch (element.type) {
          ElementType.superscript => 'superscript',
          ElementType.subscript => 'subscript',
          _ => null,
        },
      );

  static bool _samePropsKey(WpRunProperties? a, WpRunProperties? b) {
    if (a == null || b == null) return a == b;
    return a.fontAscii == b.fontAscii &&
        a.bold == b.bold &&
        a.italic == b.italic &&
        a.strike == b.strike &&
        a.sizeHalfPoints == b.sizeHalfPoints &&
        a.color == b.color &&
        a.underline == b.underline &&
        a.vertAlign == b.vertAlign &&
        a.shading?.fill == b.shading?.fill;
  }

  WpHyperlink _hyperlinkFrom(IElement element) {
    final runs = <WpRun>[];
    for (final child in element.valueList ?? const <IElement>[]) {
      final text = _clean(child.value);
      if (text.isEmpty) continue;
      runs.add(WpRun(
        properties: _runPropsFrom(child),
        content: [WpText(text)],
      ));
    }
    final url = element.url ?? '';
    if (url.startsWith('#')) {
      return WpHyperlink(anchor: url.substring(1), runs: runs);
    }
    return WpHyperlink(relId: _relIdForUrl(url), runs: runs);
  }

  String _relIdForUrl(String url) {
    final rels = file.package.relationshipsFor(file.mainPartName);
    for (final rel in rels.items) {
      if (rel.isExternal && rel.target == url) return rel.id;
    }
    final id = rels.nextId();
    rels.add(Relationship(
        id: id, type: RelType.hyperlink, target: url, isExternal: true));
    file.package.setRelationshipsFor(file.mainPartName, rels);
    return id;
  }

  // ---------------------------------------------------------------------
  // Imagens
  // ---------------------------------------------------------------------

  WpDrawing? _drawingFor(IElement element) {
    final extension = element.extension;
    final String? raw = extension is Map && extension['wpDrawing'] is String
        ? extension['wpDrawing'] as String
        : null;
    final Map<dynamic, dynamic>? anchor =
        extension is Map && extension['wpAnchor'] is Map
            ? extension['wpAnchor'] as Map
            : null;
    final bool moved = _hasFlag(element, 'imgFloatMoved');
    final String displayName = element.imgDisplay?.name ??
        (anchor == null ? 'inline' : anchor['display'] as String? ?? 'inline');
    final String originalDisplay = anchor == null
        ? 'inline'
        : anchor['display'] as String? ?? 'inline';
    final bool displayChanged = element.imgDisplay != null &&
        element.imgDisplay!.name != originalDisplay &&
        !(anchor == null &&
            (element.imgDisplay!.name == 'inline' ||
                element.imgDisplay!.name == 'block'));

    // Passthrough D1: XML original intacto quando nada de âncora mudou.
    if (raw != null && !moved && !displayChanged) {
      return WpDrawing(isInline: anchor == null, rawXml: raw);
    }

    // Regeneração: reusa o <a:graphic> original (mantém rel/media) ou embute
    // a imagem nova; só o envelope wp:inline/wp:anchor é reconstruído.
    String? graphic = raw == null ? null : _extractGraphic(raw);
    if (graphic == null) {
      final WpDrawing? fresh = _embedNewImage(element);
      if (fresh == null) return null;
      graphic = _extractGraphic(fresh.rawXml);
      if (graphic == null) return fresh;
    }
    final cx = ((element.width ?? 100) * 9525).round();
    final cy = ((element.height ?? 100) * 9525).round();
    final id = _docPrId++;
    final bool isFloat = displayName == 'surround' ||
        displayName == 'floatTop' ||
        displayName == 'floatBottom' ||
        (displayName == 'block' && anchor != null);
    if (!isFloat) {
      final xml = '<w:drawing>'
          '<wp:inline distT="0" distB="0" distL="0" distR="0">'
          '<wp:extent cx="$cx" cy="$cy"/>'
          '<wp:docPr id="$id" name="Imagem $id"/>'
          '$graphic</wp:inline></w:drawing>';
      notes.add('imagem regenerada como inline (modo $displayName)');
      return WpDrawing(isInline: true, rawXml: xml);
    }

    // Posição: preferir a posição ao vivo (arrasto/troca de modo no editor,
    // px da página → relativeFrom="page"); senão, offsets originais da âncora.
    final Map<String, num>? live = element.imgFloatPosition;
    String positionXml;
    if (live != null) {
      final int px = (((live['x'] ?? 0)).toDouble() * 9525).round();
      final int py = (((live['y'] ?? 0)).toDouble() * 9525).round();
      positionXml =
          '<wp:positionH relativeFrom="page"><wp:posOffset>$px</wp:posOffset>'
          '</wp:positionH>'
          '<wp:positionV relativeFrom="page"><wp:posOffset>$py</wp:posOffset>'
          '</wp:positionV>';
    } else {
      final String hRel = anchor?['hRel'] as String? ?? 'column';
      final String vRel = anchor?['vRel'] as String? ?? 'paragraph';
      final String? hAlign = anchor?['hAlign'] as String?;
      final int ax = (((anchor?['x'] as num?) ?? 0).toDouble() * 9525).round();
      final int ay = (((anchor?['y'] as num?) ?? 0).toDouble() * 9525).round();
      positionXml = '<wp:positionH relativeFrom="$hRel">'
          '${hAlign != null ? '<wp:align>$hAlign</wp:align>' : '<wp:posOffset>$ax</wp:posOffset>'}'
          '</wp:positionH>'
          '<wp:positionV relativeFrom="$vRel">'
          '<wp:posOffset>$ay</wp:posOffset></wp:positionV>';
    }
    final String behindDoc = displayName == 'floatBottom' ? '1' : '0';
    final String wrapXml = switch (displayName) {
      'surround' => '<wp:wrapSquare wrapText="bothSides"/>',
      'block' => '<wp:wrapTopAndBottom/>',
      _ => '<wp:wrapNone/>',
    };
    final xml = '<w:drawing>'
        '<wp:anchor distT="0" distB="0" distL="114300" distR="114300" '
        'simplePos="0" relativeHeight="251658240" behindDoc="$behindDoc" '
        'locked="0" layoutInCell="1" allowOverlap="1">'
        '<wp:simplePos x="0" y="0"/>'
        '$positionXml'
        '<wp:extent cx="$cx" cy="$cy"/>'
        '<wp:effectExtent l="0" t="0" r="0" b="0"/>'
        '$wrapXml'
        '<wp:docPr id="$id" name="Imagem $id"/>'
        '$graphic</wp:anchor></w:drawing>';
    notes.add('imagem flutuante regenerada como wp:anchor (modo $displayName'
        '${moved ? ', reposicionada' : ''})');
    return WpDrawing(isInline: false, rawXml: xml);
  }

  /// Extrai o subtree `<a:graphic>…</a:graphic>` de um drawing preservado —
  /// regenerar só o envelope mantém o blip/rel/media originais.
  static String? _extractGraphic(String drawingXml) {
    final int start = drawingXml.indexOf('<a:graphic');
    if (start < 0) return null;
    const String closeTag = '</a:graphic>';
    final int end = drawingXml.lastIndexOf(closeTag);
    if (end < start) return null;
    return drawingXml.substring(start, end + closeTag.length);
  }

  WpDrawing? _embedNewImage(IElement element) {
    final match = RegExp(r'^data:(image/[a-z+]+);base64,(.+)$', dotAll: true)
        .firstMatch(element.value);
    if (match == null) {
      notes.add('imagem sem data URL válida ignorada no save');
      return null;
    }
    final contentType = match.group(1)!;
    final bytes = base64Decode(match.group(2)!);
    final extensionName = switch (contentType) {
      'image/png' => 'png',
      'image/jpeg' => 'jpeg',
      'image/gif' => 'gif',
      _ => 'png',
    };

    // Content type default para a extensão (regenera [Content_Types].xml
    // apenas se necessário).
    if (file.package.contentTypes.defaults[extensionName] == null) {
      file.package.contentTypes.setDefault(extensionName, contentType);
      file.package.setPartString(
          '[Content_Types].xml', file.package.contentTypes.toXmlString());
    }

    var index = 1;
    while (file.package.hasPart('word/media/image900$index.$extensionName')) {
      index++;
    }
    final partName = 'word/media/image900$index.$extensionName';
    file.package.setPart(partName, bytes);

    final rels = file.package.relationshipsFor(file.mainPartName);
    final relId = rels.nextId();
    rels.add(Relationship(
        id: relId,
        type: RelType.image,
        target: 'media/image900$index.$extensionName'));
    file.package.setRelationshipsFor(file.mainPartName, rels);

    final cx = ((element.width ?? 100) * 9525).round();
    final cy = ((element.height ?? 100) * 9525).round();
    final id = _docPrId++;
    final xml = '<w:drawing>'
        '<wp:inline distT="0" distB="0" distL="0" distR="0">'
        '<wp:extent cx="$cx" cy="$cy"/>'
        '<wp:docPr id="$id" name="Imagem $id"/>'
        '<a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">'
        '<a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<pic:nvPicPr><pic:cNvPr id="$id" name="Imagem $id"/><pic:cNvPicPr/></pic:nvPicPr>'
        '<pic:blipFill><a:blip r:embed="$relId"/>'
        '<a:stretch><a:fillRect/></a:stretch></pic:blipFill>'
        '<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$cx" cy="$cy"/></a:xfrm>'
        '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>'
        '</pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing>';
    notes.add('imagem nova embutida como $partName');
    return WpDrawing(isInline: true, rawXml: xml, embedRelId: relId);
  }

  // ---------------------------------------------------------------------
  // Regeneração de tabela
  // ---------------------------------------------------------------------

  WpTable _tableFromElement(IElement element, WpTable? base,
      [IElement? original]) {
    final colgroup = element.colgroup ?? const <IColgroup>[];
    // Bordas editadas na toolbar contextual: só sobrescrevem o tblPr original
    // quando o usuário mexeu (senão o passthrough do tblPr preserva estilos
    // por-lado que o modelo do editor não representa).
    final bool tableBordersChanged = original != null &&
        (original.borderType != element.borderType ||
            original.borderColor != element.borderColor ||
            original.borderWidth != element.borderWidth);
    final bool cellVisualsChanged =
        original != null && !_sameCellVisuals(element, original);
    final grid = base != null && base.gridColumnsTwips.length == colgroup.length
        ? base.gridColumnsTwips
        : [for (final col in colgroup) (col.width * 15).round()];

    final rows = <WpTableRow>[];
    // vMerge: células com rowspan > 1 exigem células de continuação nas
    // linhas seguintes (removidas na conversão de abertura).
    final pending = <int, _PendingMerge>{};
    for (final tr in element.trList ?? const <ITr>[]) {
      final cells = <WpTableCell>[];
      var col = 0;
      var tdIndex = 0;
      while (true) {
        final merge = pending[col];
        if (merge != null) {
          cells.add(WpTableCell(
            properties: WpTableCellProperties(
              width: _cellWidth(grid, col, merge.span),
              gridSpan: merge.span > 1 ? merge.span : null,
              vMerge: 'continue',
            ),
            blocks: [WpParagraph(inlines: const [])],
          ));
          merge.remaining--;
          if (merge.remaining == 0) pending.remove(col);
          col += merge.span;
          continue;
        }
        if (tdIndex >= (tr.tdList.length)) break;
        final td = tr.tdList[tdIndex++];
        final span = td.colspan;
        cells.add(WpTableCell(
          properties: WpTableCellProperties(
            width: _cellWidth(grid, col, span),
            gridSpan: span > 1 ? span : null,
            vMerge: td.rowspan > 1 ? 'restart' : null,
            borders: cellVisualsChanged &&
                    (td.borderTypes != null || td.slashTypes != null)
                ? _tcBordersFor(
                    td.borderTypes ?? const <TdBorder>[],
                    td.slashTypes ?? const <TdSlash>[],
                    element.borderColor)
                : null,
            shading: td.backgroundColor != null
                ? WpShading(
                    val: 'clear',
                    color: 'auto',
                    fill: td.backgroundColor!.replaceFirst('#', ''))
                : null,
            vAlign: switch (td.verticalAlign?.value) {
              'middle' => 'center',
              'bottom' => 'bottom',
              _ => null,
            },
          ),
          blocks: _cellBlocks(td),
        ));
        if (td.rowspan > 1) {
          pending[col] = _PendingMerge(td.rowspan - 1, span);
        }
        col += span;
      }
      rows.add(WpTableRow(
        properties: tr.pagingRepeat == true
            ? const WpTableRowProperties(tblHeader: true)
            : null,
        cells: cells,
      ));
    }

    final WpTableProperties? baseProps = base?.properties;
    final WpTableProperties props;
    if (tableBordersChanged) {
      props = WpTableProperties(
        styleId: baseProps?.styleId,
        width: baseProps?.width ?? const WpTableWidth(value: 5000, type: 'pct'),
        jc: baseProps?.jc,
        borders: _tblBordersFor(element),
        indentTwips: baseProps?.indentTwips,
        layout: baseProps?.layout,
      );
      notes.add('bordas da tabela regeneradas '
          '(${element.borderType?.value ?? 'all'})');
    } else {
      props = baseProps ??
          const WpTableProperties(
            width: WpTableWidth(value: 5000, type: 'pct'),
            borders: WpBorders(
              top: WpBorder(val: 'single', sizeEighths: 4, color: '000000'),
              left: WpBorder(val: 'single', sizeEighths: 4, color: '000000'),
              bottom: WpBorder(val: 'single', sizeEighths: 4, color: '000000'),
              right: WpBorder(val: 'single', sizeEighths: 4, color: '000000'),
              insideH: WpBorder(val: 'single', sizeEighths: 4, color: '000000'),
              insideV: WpBorder(val: 'single', sizeEighths: 4, color: '000000'),
            ),
          );
    }
    return WpTable(
      properties: props,
      gridColumnsTwips: grid,
      rows: rows,
    );
  }

  /// Assinatura visual das células (bordas/diagonais) — decide se o tcBorders
  /// deve ser regenerado a partir do estado do editor.
  static bool _sameCellVisuals(IElement a, IElement b) {
    final aTr = a.trList ?? const <ITr>[];
    final bTr = b.trList ?? const <ITr>[];
    if (aTr.length != bTr.length) return false;
    for (var r = 0; r < aTr.length; r++) {
      if (aTr[r].tdList.length != bTr[r].tdList.length) return false;
      for (var c = 0; c < aTr[r].tdList.length; c++) {
        if (!_sameEnumNames(
                aTr[r].tdList[c].borderTypes, bTr[r].tdList[c].borderTypes) ||
            !_sameEnumNames(
                aTr[r].tdList[c].slashTypes, bTr[r].tdList[c].slashTypes)) {
          return false;
        }
      }
    }
    return true;
  }

  /// `w:tblBorders` a partir do estado do editor (TableBorder + cor/largura).
  WpBorders _tblBordersFor(IElement element) {
    final String color =
        (element.borderColor ?? '#000000').replaceFirst('#', '');
    // px → oitavos de ponto (1px = 0,75pt = 6/8): mínimo 2 (0,25pt).
    final int size =
        (((element.borderWidth ?? 0.66) * 6).round()).clamp(2, 96);
    final String val =
        element.borderType == TableBorder.dash ? 'dashed' : 'single';
    const WpBorder none = WpBorder(val: 'none', sizeEighths: 0, color: 'auto');
    final WpBorder line = WpBorder(val: val, sizeEighths: size, color: color);
    return switch (element.borderType) {
      TableBorder.empty => const WpBorders(
          top: none,
          left: none,
          bottom: none,
          right: none,
          insideH: none,
          insideV: none),
      TableBorder.external => WpBorders(
          top: line,
          left: line,
          bottom: line,
          right: line,
          insideH: none,
          insideV: none),
      TableBorder.internal => WpBorders(
          top: none,
          left: none,
          bottom: none,
          right: none,
          insideH: line,
          insideV: line),
      _ => WpBorders(
          top: line,
          left: line,
          bottom: line,
          right: line,
          insideH: line,
          insideV: line),
    };
  }

  /// `w:tcBorders` a partir dos lados visíveis e das diagonais do editor
  /// (TdSlash.forward = ↗ = w:tr2bl; TdSlash.back = ↘ = w:tl2br).
  static WpBorders _tcBordersFor(
      List<TdBorder> sides, List<TdSlash> slashes, String? color) {
    final String resolved = (color ?? '#000000').replaceFirst('#', '');
    WpBorder line() =>
        WpBorder(val: 'single', sizeEighths: 4, color: resolved);
    const WpBorder none = WpBorder(val: 'nil', sizeEighths: 0, color: 'auto');
    WpBorder pick(TdBorder side) =>
        sides.any((TdBorder s) => s.name == side.name) ? line() : none;
    final bool hasForward =
        slashes.any((TdSlash s) => s.name == TdSlash.forward.name);
    final bool hasBack =
        slashes.any((TdSlash s) => s.name == TdSlash.back.name);
    return WpBorders(
      top: pick(TdBorder.top),
      left: pick(TdBorder.left),
      bottom: pick(TdBorder.bottom),
      right: pick(TdBorder.right),
      tl2br: hasBack ? line() : null,
      tr2bl: hasForward ? line() : null,
    );
  }

  static WpTableWidth _cellWidth(List<int> grid, int col, int span) {
    var width = 0;
    for (var i = col; i < col + span && i < grid.length; i++) {
      width += grid[i];
    }
    return WpTableWidth(value: width, type: 'dxa');
  }

  List<WpBlock> _cellBlocks(ITd td) {
    final blocks = <WpBlock>[];
    var current = <IElement>[];
    void flush() {
      blocks.add(_paragraphFromElements(current, null));
      current = [];
    }

    for (final element in td.value) {
      if (element.type == null &&
          element.value == '\n' &&
          !_hasFlag(element, 'wpBr')) {
        flush();
        continue;
      }
      if (element.type == ElementType.table) {
        notes.add('tabela aninhada não exportada (achatada na abertura)');
        continue;
      }
      current.add(element);
    }
    flush();
    return blocks;
  }
}

class _PendingMerge {
  int remaining;
  final int span;
  _PendingMerge(this.remaining, this.span);
}

class _BlockSpec {
  final List<IElement> elements;
  final IElement? table;

  /// Stamp do separador que abriu o bloco (identidade de parágrafo vazio).
  final int? fallbackStamp;

  _BlockSpec.paragraph(this.elements, {this.fallbackStamp}) : table = null;

  _BlockSpec.table(IElement this.table)
      : elements = const [],
        fallbackStamp = null;

  /// Índice do bloco original (stamp `wp:<i>`), quando consistente.
  int? get stamp {
    int? result;
    final candidates = table != null ? [table!] : elements;
    for (final element in candidates) {
      final stamp = EditorToDocx._stampOf(element);
      if (stamp == null) continue;
      if (result == null) {
        result = stamp;
      } else if (result != stamp) {
        return null; // parágrafos mesclados: regenerar
      }
    }
    return result ?? fallbackStamp;
  }
}
