import 'dart:html';

import '../../editor/core/command/command.dart';
import '../../editor/core/draw/draw.dart';
import '../../editor/dataset/enum/editor.dart';
import '../../editor/interface/element.dart';
import '../core/ui_component.dart';

enum _RulerDrag {
  none,
  marginLeft,
  marginRight,
  indentLeft, // caixa: move recuo esquerdo + primeira linha juntos (Word)
  firstLine, // ▽ superior: só o delta da primeira linha
  hanging, // △ inferior: recuo das linhas de continuação (mantém a 1ª fixa)
  indentRight, // △ direito
  tabStop, // parada de tabulação (clique adiciona, fora da régua remove)
  tableColumn, // fronteira de coluna da tabela sob o cursor (régua contextual)
}

const List<String> _tabTypeCycle = <String>[
  'left',
  'center',
  'right',
  'decimal',
];

String _tabTypeTitle(String type) => switch (type) {
      'center' => 'Tabulação centralizada',
      'right' => 'Tabulação direita',
      'decimal' => 'Tabulação decimal',
      _ => 'Tabulação esquerda',
    };

/// Régua de página estilo Word/OnlyOffice.
///
/// A escala nasce na margem esquerda, usa quartos de centímetro e separa
/// visualmente o papel (cinza) da área editável (branca). Margens e recuos
/// são arrastáveis com o controle de 3 peças do Word (primeira linha,
/// deslocamento e caixa do recuo esquerdo) + recuo direito, com linha-guia
/// vertical pontilhada sobre o documento durante o arrasto.
class WidgetRuler extends UiComponent {
  WidgetRuler(this._command, this._draw) {
    root = DivElement()..classes.add('ce-rulers');
    _corner = DivElement()
      ..classes.addAll(<String>['ce-ruler-corner', 'ce-ruler-corner--left'])
      ..title = '${_tabTypeTitle('left')} — clique para alternar';
    listen(_corner.onClick, (_) => _cycleTabType());
    _horizontal = DivElement()..classes.add('ce-ruler-horizontal');
    _vertical = DivElement()..classes.add('ce-ruler-vertical');
    root.children.addAll(<Element>[_corner, _horizontal, _vertical]);
    listen(_horizontal.onMouseDown, _startDrag);
    listen(document.onMouseMove, _handleDrag);
    listen(document.onMouseUp, _finishDrag);
    listen(window.onResize, (_) => refresh());
    window.requestAnimationFrame((_) => refresh());
  }

  final Command _command;
  final Draw _draw;

  @override
  late final DivElement root;
  late final DivElement _corner;
  late final DivElement _horizontal;
  late final DivElement _vertical;

  _RulerDrag _drag = _RulerDrag.none;
  double _pageWidth = 0;
  double _scale = 1;
  List<double> _margins = <double>[0, 0, 0, 0];
  double _indentLeft = 0;
  double _firstLine = 0;
  double _indentRight = 0;

  // Tab stops do parágrafo do cursor (posições em px NÃO escalado a partir
  // da margem esquerda, como no modelo).
  List<ITabStop> _tabStops = <ITabStop>[];
  String _tabType = 'left';
  int _dragTabIndex = -1;
  bool _tabRemovePending = false;
  final List<DivElement> _tabMarkers = <DivElement>[];

  // Régua CONTEXTUAL de tabela (Word): com o cursor dentro de uma tabela, a
  // régua mostra as fronteiras das colunas; arrastar redimensiona a coluna.
  final List<DivElement> _columnMarkers = <DivElement>[];
  List<double> _columnEdges = <double>[]; // x na página (px de tela)
  int _dragColumnIndex = -1;
  double _dragColumnStartX = 0;

  // Marcadores persistentes (reposicionados sem reconstruir a régua — o
  // sync com o cursor roda por tecla via rangeStyleChange coalescido).
  DivElement? _markerMarginLeft;
  DivElement? _markerMarginRight;
  DivElement? _markerFirstLine;
  DivElement? _markerHanging;
  DivElement? _markerLeftBox;
  DivElement? _markerRight;

  // Linha-guia vertical (Word/OnlyOffice) durante o arrasto.
  DivElement? _guide;

  // Régua vertical estilo Word: a escala representa a PÁGINA ATIVA (a do
  // cursor) e desliza com o scroll — rolar sem clicar não re-ancora.
  DivElement? _verticalInner;
  bool _scrollHooked = false;

  // Durante a seleção por arrasto a régua não atualiza (Word) — sincroniza
  // uma vez no mouseup.
  bool _pointerDown = false;

  void refresh() {
    _scale = (_draw.getOptions().scale ?? 1).toDouble();
    // getWidth/getHeight/getMargins já incluem scale.
    _pageWidth = _draw.getWidth();
    _margins = List<double>.from(_draw.getMargins());
    final double pxPerCm = 96 / 2.54 * _scale;
    final int viewportHeight = root.parent?.clientHeight ?? 520;
    final double verticalHeight =
        (viewportHeight - 21).clamp(180, 1 << 20).toDouble();

    _hookScrollOnce();
    _readParagraphIndents();
    _horizontal.style.width = '${_pageWidth}px';
    // Como no Word: a régua vertical fica encostada à ESQUERDA da área de
    // visualização (não colada na página); só a escala acompanha a página.
    _vertical.style
      ..height = '${verticalHeight}px'
      ..left = '0';
    _corner.style.left = '0';
    _buildHorizontal(pxPerCm);
    _buildVertical(pxPerCm);
  }

  void _hookScrollOnce() {
    final Element? scroller = root.parent;
    if (_scrollHooked || scroller == null) return;
    _scrollHooked = true;
    listen(scroller.onScroll, (_) {
      window.requestAnimationFrame((_) => _syncVerticalScroll());
    });
    // Seleção por arrasto: pausa o sync dos marcadores até o mouseup.
    listen(document.onMouseDown, (MouseEvent event) {
      if (event.button == 0) _pointerDown = true;
    });
    listen(document.onMouseUp, (_) {
      if (!_pointerDown) return;
      _pointerDown = false;
      syncSelection();
    });
  }

  /// Desliza a escala vertical para acompanhar a página ATIVA no viewport.
  void _syncVerticalScroll() {
    final DivElement? inner = _verticalInner;
    if (inner == null) return;
    try {
      final int pageNo = _draw.getPageNo();
      final dynamic page = _draw.getPage(pageNo);
      if (page is! Element) return;
      final Rectangle<num> pageRect = page.getBoundingClientRect();
      final Rectangle<num> rulerRect = _vertical.getBoundingClientRect();
      final double offset = (pageRect.top - rulerRect.top).toDouble();
      inner.style.transform = 'translateY(${offset}px)';
    } catch (_) {}
  }

  /// Sincronização leve com o cursor: re-lê os recuos do parágrafo da
  /// seleção e reposiciona só os marcadores (sem reconstruir os ticks).
  void syncSelection() {
    if (_drag != _RulerDrag.none) return;
    // Durante o arrasto de seleção de texto a régua fica parada (Word);
    // o mouseup dispara o sync final.
    if (_pointerDown) return;
    if (_markerFirstLine == null) return;
    final double beforeLeft = _indentLeft;
    final double beforeFirst = _firstLine;
    final double beforeRight = _indentRight;
    final String beforeTabs = _tabSignature();
    _readParagraphIndents();
    final bool tabsChanged = beforeTabs != _tabSignature();
    // A régua de tabela é contextual: entrar/sair de tabela ou mudar as
    // larguras precisa refletir nos marcadores de coluna (Word).
    final String beforeColumns = _columnSignature();
    final bool columnsChanged = beforeColumns != _liveColumnSignature();
    if (beforeLeft == _indentLeft &&
        beforeFirst == _firstLine &&
        beforeRight == _indentRight &&
        !tabsChanged &&
        !columnsChanged) {
      return;
    }
    _positionMarkers();
    if (tabsChanged) _renderTabMarkers();
    if (columnsChanged) _renderColumnMarkers();
  }

  String _columnSignature() =>
      _columnEdges.map((double x) => x.toStringAsFixed(1)).join('|');

  /// Assinatura das fronteiras de coluna da tabela sob o cursor AGORA (sem
  /// tocar no DOM) — comparada com a última renderizada.
  String _liveColumnSignature() {
    final IElement? table = _command.getCursorTableElement();
    final Map<String, double>? rect = _command.getCursorTableRect();
    final List<IColgroup>? colgroup = table?.colgroup;
    if (table == null || rect == null || colgroup == null) return '';
    final StringBuffer buffer = StringBuffer();
    double x = rect['x'] ?? 0;
    buffer.write(x.toStringAsFixed(1));
    for (final IColgroup col in colgroup) {
      x += col.width * _scale;
      buffer.write('|${x.toStringAsFixed(1)}');
    }
    return buffer.toString();
  }

  String _tabSignature() => _tabStops
      .map((ITabStop stop) =>
          '${stop.type}:${stop.position.toStringAsFixed(1)}')
      .join('|');

  void _cycleTabType() {
    final int next =
        (_tabTypeCycle.indexOf(_tabType) + 1) % _tabTypeCycle.length;
    _corner.classes.remove('ce-ruler-corner--$_tabType');
    _tabType = _tabTypeCycle[next];
    _corner
      ..classes.add('ce-ruler-corner--$_tabType')
      ..title = '${_tabTypeTitle(_tabType)} — clique para alternar';
  }

  void _readParagraphIndents() {
    _indentLeft = 0;
    _firstLine = 0;
    _indentRight = 0;
    _tabStops = <ITabStop>[];
    try {
      final dynamic raw = _draw.getRange().getRangeParagraphElementList();
      if (raw is List) {
        bool indentsFound = false;
        bool tabsFound = false;
        for (final dynamic item in raw) {
          if (item is! IElement) continue;
          if (!indentsFound &&
              (item.paraIndentLeft != null ||
                  item.paraIndentFirstLine != null ||
                  item.paraIndentRight != null)) {
            _indentLeft = (item.paraIndentLeft ?? 0) * _scale;
            _firstLine = (item.paraIndentFirstLine ?? 0) * _scale;
            _indentRight = (item.paraIndentRight ?? 0) * _scale;
            indentsFound = true;
          }
          if (!tabsFound && item.paraTabStops != null) {
            _tabStops = item.paraTabStops!
                .map((ITabStop stop) => stop.clone())
                .toList();
            tabsFound = true;
          }
          if (indentsFound && tabsFound) break;
        }
      }
    } catch (_) {
      // A seleção pode estar sendo recomposta durante um render.
    }
  }

  void _buildHorizontal(double pxPerCm) {
    _horizontal.children.clear();
    final double left = _margins[3];
    final double right = _margins[1];
    final double contentWidth =
        (_pageWidth - left - right).clamp(1, _pageWidth);
    _horizontal.children.addAll(<Element>[
      DivElement()
        ..classes.add('ce-ruler__paper')
        ..style.left = '${left}px'
        ..style.width = '${contentWidth}px',
      _marginShade(start: true, size: left),
      _marginShade(start: false, size: right),
    ]);
    _appendTicks(_horizontal,
        extent: _pageWidth,
        pxPerCm: pxPerCm,
        zero: left,
        horizontal: true,
        contentEnd: contentWidth);
    _markerMarginLeft = _marker(
        'ce-ruler__margin-handle ce-ruler__margin-handle--left',
        'Margem esquerda',
        _RulerDrag.marginLeft);
    _markerMarginRight = _marker(
        'ce-ruler__margin-handle ce-ruler__margin-handle--right',
        'Margem direita',
        _RulerDrag.marginRight);
    _markerFirstLine = _marker('ce-ruler__indent ce-ruler__indent--first',
        'Recuo da primeira linha', _RulerDrag.firstLine);
    _markerHanging = _marker('ce-ruler__indent ce-ruler__indent--hanging',
        'Recuo deslocado', _RulerDrag.hanging);
    _markerLeftBox = _marker('ce-ruler__indent ce-ruler__indent--leftbox',
        'Recuo à esquerda', _RulerDrag.indentLeft);
    _markerRight = _marker('ce-ruler__indent ce-ruler__indent--right',
        'Recuo à direita', _RulerDrag.indentRight);
    _horizontal.children.addAll(<Element>[
      _markerMarginLeft!,
      _markerMarginRight!,
      _markerFirstLine!,
      _markerHanging!,
      _markerLeftBox!,
      _markerRight!,
    ]);
    _positionMarkers();
    _renderTabMarkers();
    _renderColumnMarkers();
  }

  /// (Re)cria os marcadores de tab stop na régua horizontal.
  void _renderTabMarkers() {
    for (final DivElement marker in _tabMarkers) {
      marker.remove();
    }
    _tabMarkers.clear();
    for (int index = 0; index < _tabStops.length; index++) {
      final ITabStop stop = _tabStops[index];
      final DivElement marker = DivElement()
        ..classes
            .addAll(<String>['ce-ruler__tab', 'ce-ruler__tab--${stop.type}'])
        ..title = '${_tabTypeTitle(stop.type)} — arraste para fora para '
            'remover'
        ..dataset['drag'] = _RulerDrag.tabStop.name
        ..dataset['tabIndex'] = '$index';
      _horizontal.append(marker);
      _tabMarkers.add(marker);
    }
    _positionTabMarkers();
  }

  /// Régua contextual de tabela (Word): marcadores nas fronteiras das colunas
  /// da tabela sob o cursor. Fora de tabela, remove os marcadores.
  void _renderColumnMarkers() {
    for (final DivElement marker in _columnMarkers) {
      marker.remove();
    }
    _columnMarkers.clear();
    _columnEdges = <double>[];
    if (_drag == _RulerDrag.tableColumn) return;
    final IElement? table = _command.getCursorTableElement();
    final Map<String, double>? rect = _command.getCursorTableRect();
    final List<IColgroup>? colgroup = table?.colgroup;
    if (table == null ||
        rect == null ||
        colgroup == null ||
        colgroup.isEmpty) {
      return;
    }
    double x = rect['x'] ?? 0;
    // Fronteira ESQUERDA da tabela + fim de cada coluna (a última fronteira é
    // a borda direita da tabela — arrastável como no Word).
    _columnEdges.add(x);
    for (final IColgroup col in colgroup) {
      x += col.width * _scale;
      _columnEdges.add(x);
    }
    for (int index = 0; index < _columnEdges.length; index++) {
      final DivElement marker = DivElement()
        ..classes.add('ce-ruler__column')
        ..title = 'Mover coluna da tabela'
        ..dataset['drag'] = _RulerDrag.tableColumn.name
        ..dataset['colIndex'] = '$index'
        ..style.left = '${_columnEdges[index].clamp(0, _pageWidth)}px';
      _horizontal.append(marker);
      _columnMarkers.add(marker);
    }
  }

  void _positionTabMarkers() {
    final int count = _tabMarkers.length < _tabStops.length
        ? _tabMarkers.length
        : _tabStops.length;
    for (int index = 0; index < count; index++) {
      final double x = _margins[3] + _tabStops[index].position * _scale;
      _tabMarkers[index].style.left = '${x.clamp(0, _pageWidth)}px';
    }
  }

  void _positionMarkers() {
    final double left = _margins[3];
    final double right = _margins[1];
    void setX(DivElement? marker, double x) {
      marker?.style.left = '${x.clamp(0, _pageWidth)}px';
    }

    setX(_markerMarginLeft, left);
    setX(_markerMarginRight, _pageWidth - right);
    setX(_markerFirstLine, left + _indentLeft + _firstLine);
    setX(_markerHanging, left + _indentLeft);
    setX(_markerLeftBox, left + _indentLeft);
    setX(_markerRight, _pageWidth - right - _indentRight);
  }

  void _buildVertical(double pxPerCm) {
    _vertical.children.clear();
    final double pageHeight = _draw.getHeight();
    final double top = _margins[0];
    final double bottom = _margins[2];
    // A escala cobre a página INTEIRA e desliza com o scroll (translateY em
    // _syncVerticalScroll), como no Word — o viewport da régua só recorta.
    final DivElement inner = DivElement()
      ..classes.add('ce-ruler-vertical__inner')
      ..style.height = '${pageHeight}px';
    inner.append(DivElement()
      ..classes.add('ce-ruler__paper')
      ..style.top = '${top.clamp(0, pageHeight)}px'
      ..style.height =
          '${(pageHeight - top - bottom).clamp(0, pageHeight).toDouble()}px');
    _appendTicks(inner,
        extent: pageHeight,
        pxPerCm: pxPerCm,
        zero: top,
        horizontal: false,
        contentEnd: (pageHeight - top - bottom).clamp(1, pageHeight).toDouble());
    _vertical.append(inner);
    _verticalInner = inner;
    _syncVerticalScroll();
  }

  DivElement _marginShade({required bool start, required double size}) {
    final DivElement shade = DivElement()..classes.add('ce-ruler__margin');
    shade.style
      ..width = '${size}px'
      ..setProperty(start ? 'left' : 'right', '0');
    return shade;
  }

  /// Escala da régua. [contentEnd] é a extensão da ÁREA DE TEXTO a partir de
  /// [zero]: como no Word, os números aparecem só dentro dela — as zonas de
  /// margem recebem apenas ponto (¼) e tique curto (½), sem numeração.
  void _appendTicks(Element ruler,
      {required double extent,
      required double pxPerCm,
      required double zero,
      required bool horizontal,
      required double contentEnd}) {
    final double quarter = pxPerCm / 4;
    void appendTick(double position, int distance, {bool numbered = false}) {
      final int part = distance % 4;
      final SpanElement tick = SpanElement()
        ..classes.addAll(<String>[
          'ce-ruler__tick',
          horizontal ? 'horizontal' : 'vertical',
          part == 0
              ? 'major'
              : part == 2
                  ? 'half'
                  : 'quarter',
        ])
        ..style.setProperty(horizontal ? 'left' : 'top', '${position}px');
      if (part == 0 && numbered) {
        final int number = distance ~/ 4;
        if (number > 0) {
          tick.append(SpanElement()
            ..classes.add('ce-ruler__number')
            ..text = '$number');
        }
      }
      ruler.append(tick);
    }

    appendTick(zero.clamp(0, extent).toDouble(), 0);
    for (int distance = 1;; distance++) {
      final double position = zero + distance * quarter;
      if (position > extent) break;
      appendTick(position, distance,
          numbered: position <= zero + contentEnd + 0.5);
    }
    // Margem inicial (à esquerda/acima do zero): ticks sem número, como o Word.
    for (int distance = 1;; distance++) {
      final double position = zero - distance * quarter;
      if (position < 0) break;
      appendTick(position, distance);
    }
  }

  DivElement _marker(String classes, String title, _RulerDrag drag) {
    final DivElement marker = DivElement()
      ..classes.addAll(classes.split(' '))
      ..title = title;
    if (drag != _RulerDrag.none) {
      marker.dataset['drag'] = drag.name;
    }
    return marker;
  }

  void _startDrag(MouseEvent event) {
    final EventTarget? target = event.target;
    if (target is! Element) return;
    final Element? marker = target.closest('[data-drag]');
    final String? name = marker?.dataset['drag'];
    if (name == null) {
      // Clique no fundo da régua dentro da área de texto: adiciona uma
      // parada do tipo selecionado no canto e já inicia o arrasto (Word).
      _startAddTabStop(event);
      return;
    }
    _drag = _RulerDrag.values.firstWhere(
      (_RulerDrag value) => value.name == name,
      orElse: () => _RulerDrag.none,
    );
    if (_drag == _RulerDrag.none) return;
    if (_drag == _RulerDrag.tabStop) {
      _dragTabIndex = int.tryParse(marker?.dataset['tabIndex'] ?? '') ?? -1;
      if (_dragTabIndex < 0 || _dragTabIndex >= _tabStops.length) {
        _drag = _RulerDrag.none;
        return;
      }
      _tabRemovePending = false;
    }
    if (_drag == _RulerDrag.tableColumn) {
      _dragColumnIndex = int.tryParse(marker?.dataset['colIndex'] ?? '') ?? -1;
      if (_dragColumnIndex < 0 || _dragColumnIndex >= _columnEdges.length) {
        _drag = _RulerDrag.none;
        return;
      }
      _dragColumnStartX = _columnEdges[_dragColumnIndex];
    }
    event
      ..preventDefault()
      ..stopPropagation();
    root.classes.add('is-dragging');
    _showGuide(event.client.x.toDouble());
  }

  void _startAddTabStop(MouseEvent event) {
    final Rectangle<num> bounds = _horizontal.getBoundingClientRect();
    final double x = (event.client.x - bounds.left).toDouble();
    final double left = _margins[3];
    final double right = _margins[1];
    if (x <= left + 1 || x >= _pageWidth - right - 1) return;
    _tabStops.add(ITabStop(type: _tabType, position: (x - left) / _scale));
    _renderTabMarkers();
    _drag = _RulerDrag.tabStop;
    _dragTabIndex = _tabStops.length - 1;
    _tabRemovePending = false;
    event
      ..preventDefault()
      ..stopPropagation();
    root.classes.add('is-dragging');
    _showGuide(event.client.x.toDouble());
  }

  void _showGuide(double clientX) {
    final Rectangle<num> bounds = _horizontal.getBoundingClientRect();
    final double top = bounds.bottom.toDouble();
    final DivElement guide =
        _guide ??= DivElement()..classes.add('ce-ruler-guide');
    guide.style
      ..top = '${top}px'
      ..height = '${(window.innerHeight ?? 800) - top}px'
      ..left = '${clientX}px';
    if (guide.parent == null) {
      document.body?.append(guide);
    }
  }

  void _hideGuide() {
    _guide?.remove();
    _guide = null;
  }

  void _handleDrag(MouseEvent event) {
    if (_drag == _RulerDrag.none) return;
    final Rectangle<num> bounds = _horizontal.getBoundingClientRect();
    final double x =
        (event.client.x - bounds.left).clamp(0, _pageWidth).toDouble();
    final double minContent = 48 * _scale;
    switch (_drag) {
      case _RulerDrag.marginLeft:
        _margins[3] =
            x.clamp(0, _pageWidth - _margins[1] - minContent).toDouble();
      case _RulerDrag.marginRight:
        _margins[1] = (_pageWidth - x)
            .clamp(0, _pageWidth - _margins[3] - minContent)
            .toDouble();
      case _RulerDrag.indentLeft:
        // Caixa: move recuo esquerdo mantendo o delta da 1ª linha.
        _indentLeft =
            (x - _margins[3]).clamp(0, _pageWidth - _margins[1]).toDouble();
      case _RulerDrag.hanging:
        // △: muda o recuo das linhas de continuação mantendo a 1ª linha
        // fixa no lugar (o delta compensa), como no Word.
        final double firstLineAbs = _indentLeft + _firstLine;
        _indentLeft =
            (x - _margins[3]).clamp(0, _pageWidth - _margins[1]).toDouble();
        _firstLine = firstLineAbs - _indentLeft;
      case _RulerDrag.firstLine:
        _firstLine = (x - _margins[3] - _indentLeft)
            .clamp(-_indentLeft, _pageWidth - _margins[1])
            .toDouble();
      case _RulerDrag.indentRight:
        _indentRight = (_pageWidth - _margins[1] - x)
            .clamp(0, _pageWidth - _margins[1] - _margins[3] - minContent)
            .toDouble();
      case _RulerDrag.tabStop:
        if (_dragTabIndex < 0 || _dragTabIndex >= _tabStops.length) return;
        final double contentWidth =
            (_pageWidth - _margins[3] - _margins[1]).clamp(1, _pageWidth);
        _tabStops[_dragTabIndex].position =
            ((x - _margins[3]).clamp(0, contentWidth)) / _scale;
        // Arrastar para fora da régua (verticalmente) remove a parada.
        final double clientY = event.client.y.toDouble();
        _tabRemovePending =
            clientY < bounds.top - 14 || clientY > bounds.bottom + 14;
        if (_dragTabIndex < _tabMarkers.length) {
          _tabMarkers[_dragTabIndex]
              .classes
              .toggle('is-removing', _tabRemovePending);
        }
        _positionTabMarkers();
      case _RulerDrag.tableColumn:
        // Só arrasta o marcador; a largura é aplicada no mouseup (um render).
        if (_dragColumnIndex >= 0 && _dragColumnIndex < _columnMarkers.length) {
          _columnMarkers[_dragColumnIndex].style.left =
              '${x.clamp(0, _pageWidth)}px';
        }
      case _RulerDrag.none:
        return;
    }
    _showGuide(event.client.x.toDouble());
    _positionMarkers();
  }

  void _finishDrag(MouseEvent _) {
    if (_drag == _RulerDrag.none) return;
    final _RulerDrag completed = _drag;
    _drag = _RulerDrag.none;
    root.classes.remove('is-dragging');
    _hideGuide();
    if (completed == _RulerDrag.tableColumn) {
      final int index = _dragColumnIndex;
      _dragColumnIndex = -1;
      if (index >= 0 && index < _columnMarkers.length) {
        final double endX = double.tryParse(_columnMarkers[index]
                .style
                .left
                .replaceAll('px', '')) ??
            _dragColumnStartX;
        final double delta = endX - _dragColumnStartX;
        // Fronteira 0 = borda esquerda da tabela (não redimensiona coluna no
        // modelo do editor sem overflow); as demais movem a coluna index-1.
        if (index > 0 && delta.abs() >= 1) {
          _command.executeTableColumnWidth(index - 1, delta);
        }
      }
      window.requestAnimationFrame((_) => refresh());
      return;
    }
    if (completed == _RulerDrag.tabStop) {
      if (_tabRemovePending &&
          _dragTabIndex >= 0 &&
          _dragTabIndex < _tabStops.length) {
        _tabStops.removeAt(_dragTabIndex);
      }
      _tabRemovePending = false;
      _dragTabIndex = -1;
      _tabStops.sort(
          (ITabStop a, ITabStop b) => a.position.compareTo(b.position));
      _command.executeSetTabStops(
          _tabStops.map((ITabStop stop) => stop.clone()).toList());
    } else if (completed == _RulerDrag.marginLeft ||
        completed == _RulerDrag.marginRight) {
      final List<double> visual =
          _margins.map((double value) => value / _scale).toList();
      final PaperDirection? direction = _draw.getOptions().paperDirection;
      _command.executeSetPaperMargin(direction == PaperDirection.horizontal
          ? <double>[visual[3], visual[0], visual[1], visual[2]]
          : visual);
    } else {
      _command.executeParagraphIndent(
          _indentLeft / _scale, _firstLine / _scale, _indentRight / _scale);
    }
    window.requestAnimationFrame((_) => refresh());
  }

  void setVisible(bool visible) {
    root.style.display = visible ? '' : 'none';
    if (visible) window.requestAnimationFrame((_) => refresh());
  }

  @override
  void dispose() {
    _hideGuide();
    super.dispose();
  }
}
