import 'dart:html';
import 'dart:js_util' as js_util;

import '../../dataset/constant/editor.dart';
import '../event/handlers/paste.dart';

class CursorAgent {
  CursorAgent(this.draw, this.canvasEvent)
      : container = draw.getContainer() as DivElement,
        eventBus = draw.getEventBus() {
    final TextAreaElement element = TextAreaElement()
      ..setAttribute('autocomplete', 'off')
      ..classes.add('$editorPrefix-inputarea')
      ..value = '';
    container.append(element);
    agentCursorDom = element;

    agentCursorDom.onKeyDown.listen(_handleKeyDown);
    agentCursorDom.onInput.listen(_handleInput);
    agentCursorDom.onPaste.listen(_handlePaste);
    agentCursorDom.on['compositionstart'].listen(_handleCompositionStart);
    agentCursorDom.on['compositionend'].listen(_handleCompositionEnd);
  }

  final dynamic draw;
  final dynamic canvasEvent;
  final DivElement container;
  final dynamic eventBus;
  late final TextAreaElement agentCursorDom;

  TextAreaElement getAgentCursorDom() {
    return agentCursorDom;
  }

  void _handleKeyDown(KeyboardEvent event) {
    canvasEvent.keydown(event);
  }

  void _handleInput(Event event) {
    final dynamic data = js_util.getProperty(event, 'data');
    if (data != null) {
      canvasEvent.input(data);
    }
    if (eventBus.isSubscribe('input') == true) {
      eventBus.emit('input', event);
    }
  }

  void _handlePaste(ClipboardEvent event) {
    if (draw.isReadonly() == true) {
      return;
    }
    final DataTransfer? clipboardData = event.clipboardData;
    if (clipboardData == null) {
      return;
    }
    pasteByEvent(canvasEvent, event);
    event.preventDefault();
  }

  void _handleCompositionStart(Event event) {
    canvasEvent.compositionstart();
  }

  void _handleCompositionEnd(Event event) {
    canvasEvent.compositionend(event);
  }
}
