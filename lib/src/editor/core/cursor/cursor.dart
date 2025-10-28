import 'dart:async';
import 'dart:html';
import 'dart:math' as math;

import '../../dataset/constant/cursor.dart';
import '../../dataset/constant/editor.dart';
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
        container = drawInstance.getContainer() as DivElement,
        position = drawInstance.getPosition() as Position,
        options = drawInstance.getOptions() as IEditorOption,
        cursorDom = DivElement(),
        cursorAgent = CursorAgent(drawInstance, canvasEvent),
        _animationClass = '$editorPrefix-cursor--animation' {
    cursorDom.classes.add('$editorPrefix-cursor');
    container.append(cursorDom);
  }

  final dynamic draw;
  final DivElement container;
  final Position position;
  final IEditorOption options;

  final DivElement cursorDom;
  final CursorAgent cursorAgent;
  final String _animationClass;

  Timer? blinkTimer;
  int? hitLineStartIndex;

  DivElement getCursorDom() {
    return cursorDom;
  }

  TextAreaElement getAgentDom() {
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
    cursorDom.classes.add(_animationClass);
  }

  void _blinkStop() {
    cursorDom.classes.remove(_animationClass);
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
    final TextAreaElement agentCursorDom = cursorAgent.getAgentCursorDom();
    if (!identical(document.activeElement, agentCursorDom)) {
      agentCursorDom.focus();
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

    final double defaultOffsetHeight = cursorAgentOffsetHeight * scale;
    final double increaseHeight = math.min(
      metrics.height / 4,
      defaultOffsetHeight,
    );
    final double cursorHeight = metrics.height + increaseHeight * 2;
    final TextAreaElement agentCursorDom = cursorAgent.getAgentCursorDom();
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
      final Rectangle<num> rect = scrollContainer.getBoundingClientRect();
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
      window.scrollTo(scrollLeft, targetScrollTop);
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
