import 'dart:async';
import 'package:canvas_text_editor/src/dom/dom.dart';
import 'dart:math' as math;

import '../../dataset/constant/cursor.dart';
import '../../dataset/constant/editor.dart';
import '../../dataset/enum/element.dart';
import '../../dataset/enum/observer.dart';
import '../../interface/cursor.dart';
import '../../interface/editor.dart';
import '../../interface/element.dart';
import '../../utils/index.dart' show findScrollContainer;
import '../../utils/ua.dart';
import '../position/position.dart';
import 'cursor_agent.dart';

class IDrawCursorOption extends ICursorOption {
  IDrawCursorOption({
    double? width,
    String? color,
    double? dragWidth,
    String? dragColor,
    bool? dragFloatImageDisabled,
    this.isShow,
    this.isBlink,
    this.isFocus,
    this.hitLineStartIndex,
  }) : super(
          width: width,
          color: color,
          dragWidth: dragWidth,
          dragColor: dragColor,
          dragFloatImageDisabled: dragFloatImageDisabled,
        );

  bool? isShow;
  bool? isBlink;
  bool? isFocus;
  int? hitLineStartIndex;
}

class IMoveCursorToVisibleOption {
  IMoveCursorToVisibleOption({
    required this.direction,
    required this.cursorPosition,
  });

  final MoveDirection direction;
  final IElementPosition cursorPosition;
}

class Cursor {
  Cursor(dynamic drawInstance, dynamic canvasEvent)
      : draw = drawInstance,
        container = drawInstance.getContainer() as HTMLDivElement,
        position = drawInstance.getPosition() as Position,
        options = drawInstance.getOptions() as IEditorOption,
        cursorDom = HTMLDivElement(),
        cursorAgent = CursorAgent(drawInstance, canvasEvent),
        _animationClass = '$editorPrefix-cursor--animation' {
    cursorDom.classList.add('$editorPrefix-cursor');
    container.append(cursorDom);
  }

  final dynamic draw;
  final HTMLDivElement container;
  final Position position;
  final IEditorOption options;

  final HTMLDivElement cursorDom;
  final CursorAgent cursorAgent;
  final String _animationClass;

  Timer? blinkTimer;
  int? hitLineStartIndex;

  HTMLDivElement getCursorDom() {
    return cursorDom;
  }

  HTMLTextAreaElement getAgentDom() {
    return cursorAgent.getAgentCursorDom();
  }

  bool getAgentIsActive() {
    return identical(document.activeElement, getAgentDom());
  }

  String getAgentDomValue() {
    return getAgentDom().value ?? '';
  }

  void clearAgentDomValue() {
    getAgentDom().value = '';
  }

  int? getHitLineStartIndex() {
    return hitLineStartIndex;
  }

  void _blinkStart() {
    cursorDom.classList.add(_animationClass);
  }

  void _blinkStop() {
    cursorDom.classList.remove(_animationClass);
  }

  void _setBlinkTimeout() {
    _clearBlinkTimeout();
    blinkTimer = Timer(const Duration(milliseconds: 500), _blinkStart);
  }

  void _clearBlinkTimeout() {
    if (blinkTimer != null) {
      _blinkStop();
      blinkTimer!.cancel();
      blinkTimer = null;
    }
  }

  void focus() {
    if (isMobile && draw.isReadonly() == true) {
      return;
    }
    final HTMLTextAreaElement agentCursorDom = cursorAgent.getAgentCursorDom();
    if (!identical(document.activeElement, agentCursorDom)) {
      try {
        agentCursorDom.focus(FocusOptions(preventScroll: true));
      } catch (_) {
        agentCursorDom.focus();
      }
      agentCursorDom.setSelectionRange(0, 0);
    }
  }

  void drawCursor([IDrawCursorOption? payload]) {
    IElementPosition? cursorPosition = position.getCursorPosition();
    if (cursorPosition == null) {
      return;
    }

    final double scale = options.scale?.toDouble() ?? 1;
    final ICursorOption cursorOption = options.cursor ?? defaultCursorOption;

    final double cursorWidth =
        (payload?.width ?? cursorOption.width ?? defaultCursorOption.width ?? 1)
            .toDouble();
    final String cursorColor = payload?.color ??
        cursorOption.color ??
        defaultCursorOption.color ??
        '#000000';

    final bool isShow = payload?.isShow ?? true;
    final bool isBlink = payload?.isBlink ?? true;
    final bool isFocus = payload?.isFocus ?? true;
    final int? requestedHitLineStartIndex = payload?.hitLineStartIndex;
    hitLineStartIndex = requestedHitLineStartIndex;

    final double height = (draw.getHeight() as num).toDouble();
    final double pageGap = (draw.getPageGap() as num).toDouble();

    if (requestedHitLineStartIndex != null && requestedHitLineStartIndex != 0) {
      final List<IElementPosition> positionList = position.getPositionList();
      if (requestedHitLineStartIndex >= 0 &&
          requestedHitLineStartIndex < positionList.length) {
        cursorPosition = positionList[requestedHitLineStartIndex];
      }
    }

    final IElementMetrics metrics = cursorPosition.metrics;
    final Map<String, List<double>> coordinate = cursorPosition.coordinate;
    final List<double> leftTop = coordinate['leftTop'] ?? <double>[0, 0];
    final List<double> rightTop = coordinate['rightTop'] ?? <double>[0, 0];

    final dynamic zoneManager = draw.getZone();
    final int cursorPageNo = zoneManager.isMainActive() == true
        ? cursorPosition.pageNo
        : draw.getPageNo();
    final double preY = cursorPageNo * (height + pageGap);

    // Word: o caret tem a altura do TEXTO na posição, NÃO a do objeto. Com o
    // caret ao lado de uma imagem inline (ex.: logo do rodapé) as métricas da
    // posição são as da IMAGEM e o caret virava uma barra gigante.
    double caretBase = metrics.height;
    final int cursorIndex = cursorPosition.index;
    final List<IElement> cursorElementList =
        (draw.getElementList() as List).cast<IElement>();
    if (cursorIndex >= 0 && cursorIndex < cursorElementList.length) {
      final IElement cursorElement = cursorElementList[cursorIndex];
      final ElementType? type = cursorElement.type;
      final bool isObject = type == ElementType.image ||
          type == ElementType.latex ||
          type == ElementType.block ||
          type == ElementType.table;
      if (isObject) {
        caretBase = (cursorElement.size ?? options.defaultSize ?? 16)
                .toDouble() *
            scale;
      }
    }

    final double defaultOffsetHeight = cursorAgentOffsetHeight * scale;
    final double increaseHeight = math.min(
      caretBase / 4,
      defaultOffsetHeight,
    );
    final double cursorHeight = caretBase + increaseHeight * 2;
    final HTMLTextAreaElement agentCursorDom = cursorAgent.getAgentCursorDom();
    if (isFocus) {
      Timer.run(focus);
    }

    final double descent = math.max(0, metrics.boundingBoxDescent);
    final double cursorTop = leftTop[1] +
        cursorPosition.ascent +
        descent -
        (cursorHeight - increaseHeight) +
        preY;
    final double cursorLeft =
        (requestedHitLineStartIndex != null && requestedHitLineStartIndex != 0)
            ? leftTop[0]
            : rightTop[0];

    agentCursorDom.style.left = '${cursorLeft}px';
    agentCursorDom.style.top =
        '${cursorTop + cursorHeight - defaultOffsetHeight}px';

    if (!isShow) {
      recoveryCursor();
      return;
    }

    final bool isReadonly = draw.isReadonly() == true;
    cursorDom.style
      ..width = '${cursorWidth * scale}px'
      ..backgroundColor = cursorColor
      ..left = '${cursorLeft}px'
      ..top = '${cursorTop}px'
      ..display = isReadonly ? 'none' : 'block'
      ..height = '${cursorHeight}px';

    if (isBlink) {
      _setBlinkTimeout();
    } else {
      _clearBlinkTimeout();
    }
  }

  void recoveryCursor() {
    cursorDom.style.display = 'none';
    _clearBlinkTimeout();
  }

  void moveCursorToVisible(IMoveCursorToVisibleOption payload) {
    final IElementPosition cursorPosition = payload.cursorPosition;
    final MoveDirection direction = payload.direction;

    final Map<String, List<double>> coordinate = cursorPosition.coordinate;
    final List<double> leftTop = coordinate['leftTop'] ?? <double>[0, 0];
    final List<double> leftBottom = coordinate['leftBottom'] ?? <double>[0, 0];
    final double prePageY = cursorPosition.pageNo *
            ((draw.getHeight() as num).toDouble() +
                (draw.getPageGap() as num).toDouble()) +
        container.getBoundingClientRect().top.toDouble();
    final bool isUp = direction == MoveDirection.up;
    final double x = leftBottom[0];
    final double y = (isUp ? leftTop[1] : leftBottom[1]) + prePageY;

    final Element scrollContainer = findScrollContainer(container);
    final bool isDocumentElement =
        identical(scrollContainer, document.documentElement);

    double left = 0;
    double right = 0;
    double top = 0;
    double bottom = 0;
    if (isDocumentElement) {
      right = window.innerWidth?.toDouble() ?? 0;
      bottom = window.innerHeight?.toDouble() ?? 0;
    } else {
      final DOMRect rect = scrollContainer.getBoundingClientRect();
      left = rect.left.toDouble();
      right = rect.right.toDouble();
      top = rect.top.toDouble();
      bottom = rect.bottom.toDouble();
    }

    final List<double> maskMargin = _resolveMaskMargin();
    top += maskMargin[0];
    bottom -= maskMargin[2];

    final bool isWithinViewport =
        x >= left && x <= right && y >= top && y <= bottom;
    if (isWithinViewport) {
      return;
    }

    final double scrollLeft = isDocumentElement
        ? window.scrollX.toDouble()
        : (scrollContainer.scrollLeft as num).toDouble();
    final double scrollTop = isDocumentElement
        ? window.scrollY.toDouble()
        : (scrollContainer.scrollTop as num).toDouble();

    final double targetScrollTop =
        isUp ? scrollTop - (top - y) : scrollTop + (y - bottom);

    if (isDocumentElement) {
      window.scrollTo(ScrollToOptions(
          left: scrollLeft.toDouble(), top: targetScrollTop.toDouble()));
    } else {
      scrollContainer.scrollLeft = scrollLeft.round();
      scrollContainer.scrollTop = targetScrollTop.round();
    }
  }

  List<double> _resolveMaskMargin() {
    final dynamic margin = options.maskMargin;
    final List<double> result = <double>[0, 0, 0, 0];
    if (margin is List) {
      for (var i = 0; i < margin.length && i < 4; i++) {
        final dynamic value = margin[i];
        result[i] = value is num ? value.toDouble() : 0;
      }
    }
    return result;
  }
}
