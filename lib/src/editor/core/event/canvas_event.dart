import 'dart:async';
import 'dart:html';

import '../../dataset/enum/element_style.dart';
import '../../interface/draw.dart';
import '../../interface/element.dart';
import '../../interface/event.dart';
import '../../interface/position.dart';
import '../../interface/range.dart';
import '../../utils/index.dart' show threeClick;
import '../../utils/ua.dart' show isIOS;
import 'handlers/click.dart' as click_handler;
import 'handlers/composition.dart' as composition_handler;
import 'handlers/copy.dart' as copy_handler;
import 'handlers/cut.dart' as cut_handler;
import 'handlers/drag.dart' as drag_handler;
import 'handlers/drop.dart' as drop_handler;
import 'handlers/input.dart' as input_handler;
import 'handlers/keydown/index.dart' as keydown_handler;
import 'handlers/mousedown.dart' as mousedown_handler;
import 'handlers/mouseleave.dart' as mouseleave_handler;
import 'handlers/mousemove.dart' as mousemove_handler;
import 'handlers/mouseup.dart' as mouseup_handler;

class CompositionInfo {
  CompositionInfo({
    required this.elementList,
    required this.startIndex,
    required this.endIndex,
    required this.value,
    required this.defaultStyle,
  });

  final List<IElement> elementList;
  final int startIndex;
  final int endIndex;
  final String value;
  final IRangeElementStyle? defaultStyle;
}

class CanvasEvent {
  CanvasEvent(this.draw)
      : pageContainer = draw.getPageContainer() as DivElement,
        pageList = List<CanvasElement>.from(
          (draw.getPageList() as List?)?.whereType<CanvasElement>() ??
              const <CanvasElement>[],
        ),
  range = draw.getRange(),
  position = draw.getPosition(),
        isAllowSelection = false,
        isComposing = false,
        compositionInfo = null,
        isAllowDrag = false,
        isAllowDrop = false,
        cacheRange = null,
        cacheElementList = null,
        cachePositionList = null,
        cachePositionContext = null,
        mouseDownStartPosition = null;

  final dynamic draw;
  final DivElement pageContainer;
  final List<CanvasElement> pageList;
  final dynamic range;
  final dynamic position;

  bool isAllowSelection;
  bool isComposing;
  CompositionInfo? compositionInfo;

  bool isAllowDrag;
  bool isAllowDrop;
  IRange? cacheRange;
  List<IElement>? cacheElementList;
  List<IElementPosition>? cachePositionList;
  IPositionContext? cachePositionContext;
  ICurrentPosition? mouseDownStartPosition;

  final List<StreamSubscription<dynamic>> _subscriptions =
    <StreamSubscription<dynamic>>[];

  dynamic getDraw() => draw;

  void register() {
    _subscriptions.add(pageContainer.onClick.listen(click));
    _subscriptions.add(pageContainer.onMouseDown.listen(mousedown));
    _subscriptions.add(pageContainer.onMouseUp.listen(mouseup));
    _subscriptions.add(pageContainer.onMouseLeave.listen(mouseleave));
    _subscriptions.add(pageContainer.onMouseMove.listen(mousemove));
    _subscriptions.add(pageContainer.onDoubleClick.listen((Event event) {
      if (event is MouseEvent) {
        dblclick(event);
      }
    }));
    _subscriptions.add(pageContainer.onDragOver.listen(dragover));
    _subscriptions.add(pageContainer.onDrop.listen(drop));
    threeClick(pageContainer, (_) => threeClickInvoke());
  }

  void dispose() {
    for (final StreamSubscription<dynamic> subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }

  void setIsAllowSelection(bool value) {
    isAllowSelection = value;
    if (!value) {
      applyPainterStyle();
    }
  }

  void setIsAllowDrag(bool value) {
    isAllowDrag = value;
    isAllowDrop = value;
  }

  void clearPainterStyle() {
    for (final CanvasElement page in pageList) {
      page.style.cursor = 'text';
    }
    draw.setPainterStyle(null);
  }

  void applyPainterStyle() {
    final dynamic painterStyle = draw.getPainterStyle();
    if (painterStyle == null) {
      return;
    }
    if (draw.isReadonly() == true || draw.isDisabled() == true) {
      return;
    }
    if (range == null) {
      return;
    }
    final List<IElement>? selection = range.getSelection();
    if (selection == null) {
      return;
    }
    final Map<String, dynamic> styleMap = _resolveStyleMap(painterStyle);
    for (final IElement element in selection) {
      styleMap.forEach((String key, dynamic value) {
        _applyElementStyle(element, key, value);
      });
    }
    draw.render(IDrawOption(isSetCursor: false));
    final dynamic painterOptions = draw.getPainterOptions();
    if (painterOptions == null || painterOptions.isDblclick != true) {
      clearPainterStyle();
    }
  }

  void selectAll() {
    if (position == null || range == null) {
      return;
    }
    final List<IElementPosition> positionList = position.getPositionList();
    range.setRange(0, positionList.length - 1);
    draw.render(
      IDrawOption(
        isSubmitHistory: false,
        isSetCursor: false,
        isCompute: false,
      ),
    );
  }

  void mousemove(MouseEvent evt) {
    if (range == null || position == null) {
      return;
    }
    mousemove_handler.mousemove(evt, this);
  }

  void mousedown(MouseEvent evt) {
    if (range == null || position == null) {
      return;
    }
    mousedown_handler.mousedown(evt, this);
  }

  void click(MouseEvent evt) {
    if (isIOS && draw.isReadonly() != true) {
      draw.getCursor().getAgentDom().focus();
    }
  }

  void mouseup(MouseEvent evt) {
    if (range == null || position == null) {
      return;
    }
    mouseup_handler.mouseup(evt, this);
  }

  void mouseleave(MouseEvent evt) {
    if (range == null || position == null) {
      return;
    }
    mouseleave_handler.mouseleave(evt, this);
  }

  void keydown(KeyboardEvent evt) {
    if (range == null || position == null) {
      return;
    }
    keydown_handler.keydown(evt, this);
  }

  void dblclick(MouseEvent evt) {
    click_handler.dblclick(this, evt);
  }

  void threeClickInvoke() {
    click_handler.threeClick(this);
  }

  void input(String data) {
    if (range == null || position == null) {
      return;
    }
    input_handler.input(data, this);
  }

  Future<void> cut() async {
    if (range == null || position == null) {
      return;
    }
    await cut_handler.cut(this);
  }

  Future<void> copy([ICopyOption? options]) async {
    if (range == null || position == null) {
      return;
    }
    await copy_handler.copy(this, options);
  }

  void compositionstart() {
    if (range == null || position == null) {
      return;
    }
    composition_handler.compositionstart(this);
  }

  void compositionend(CompositionEvent evt) {
    if (range == null || position == null) {
      return;
    }
    composition_handler.compositionend(this, evt);
  }

  void drop(MouseEvent evt) {
    if (range == null || position == null) {
      return;
    }
    drop_handler.drop(evt, this);
  }

  void dragover(MouseEvent evt) {
    if (range == null || position == null) {
      return;
    }
    drag_handler.dragover(evt, this);
  }

  Map<String, dynamic> _resolveStyleMap(dynamic painterStyle) {
    if (painterStyle is Map<String, dynamic>) {
      return Map<String, dynamic>.from(painterStyle);
    }
    final Map<String, dynamic> result = <String, dynamic>{};
    if (painterStyle is IElementStyle) {
      if (painterStyle.font != null) {
        result[ElementStyleKey.font.value] = painterStyle.font;
      }
      if (painterStyle.size != null) {
        result[ElementStyleKey.size.value] = painterStyle.size;
      }
      if (painterStyle.width != null) {
        result[ElementStyleKey.width.value] = painterStyle.width;
      }
      if (painterStyle.height != null) {
        result[ElementStyleKey.height.value] = painterStyle.height;
      }
      if (painterStyle.bold != null) {
        result[ElementStyleKey.bold.value] = painterStyle.bold;
      }
      if (painterStyle.color != null) {
        result[ElementStyleKey.color.value] = painterStyle.color;
      }
      if (painterStyle.highlight != null) {
        result[ElementStyleKey.highlight.value] = painterStyle.highlight;
      }
      if (painterStyle.italic != null) {
        result[ElementStyleKey.italic.value] = painterStyle.italic;
      }
      if (painterStyle.underline != null) {
        result[ElementStyleKey.underline.value] = painterStyle.underline;
      }
      if (painterStyle.strikeout != null) {
        result[ElementStyleKey.strikeout.value] = painterStyle.strikeout;
      }
    }
    return result;
  }

  void _applyElementStyle(IElement element, String key, dynamic value) {
    switch (key) {
      case 'font':
        element.font = value as String?;
        break;
      case 'size':
        element.size = (value as num?)?.toInt();
        break;
      case 'width':
        element.width = (value as num?)?.toDouble();
        break;
      case 'height':
        element.height = (value as num?)?.toDouble();
        break;
      case 'bold':
        element.bold = value as bool?;
        break;
      case 'color':
        element.color = value as String?;
        break;
      case 'highlight':
        element.highlight = value as String?;
        break;
      case 'italic':
        element.italic = value as bool?;
        break;
      case 'underline':
        element.underline = value as bool?;
        break;
      case 'strikeout':
        element.strikeout = value as bool?;
        break;
      default:
        break;
    }
  }

  void disposeCache() {
    cacheRange = null;
    cacheElementList = null;
    cachePositionList = null;
    cachePositionContext = null;
    mouseDownStartPosition = null;
  }

}
