import 'package:canvas_text_editor/src/dom/dom.dart';

import '../../dataset/constant/editor.dart';
import '../event/handlers/paste.dart';

class CursorAgent {
  CursorAgent(this.draw, this.canvasEvent)
      : container = draw.getContainer() as HTMLDivElement,
        eventBus = draw.getEventBus() {
    final HTMLTextAreaElement element = HTMLTextAreaElement()
      ..setAttribute('autocomplete', 'off')
      ..setAttribute('spellcheck', 'false')
      ..classList.add('$editorPrefix-inputarea')
      ..style.position = 'absolute'
      ..style.left = '0'
      ..style.top = '0'
      ..style.width = '100px'
      ..style.height = '30px'
      ..style.minWidth = '0'
      ..style.minHeight = '0'
      ..style.margin = '0'
      ..style.padding = '0'
      ..style.border = 'none'
      ..style.outline = 'none'
      ..style.resize = 'none'
      ..style.overflow = 'hidden'
      ..style.backgroundColor = 'transparent'
      ..style.color = 'transparent'
      ..style.userSelect = 'none'
      ..style.zIndex = '-1'
      ..value = '';
    element.style.setProperty('caret-color', 'transparent');
    container.append(element);
    agentCursorDom = element;

    agentCursorDom.onKeyDown.listen(_handleKeyDown);
    agentCursorDom.onInput.listen(_handleInput);
    agentCursorDom.onPaste.listen(_handlePaste);
    const EventStreamProvider<Event>('compositionstart')
        .forTarget(agentCursorDom)
        .listen(_handleCompositionStart);
    const EventStreamProvider<Event>('compositionend')
        .forTarget(agentCursorDom)
        .listen(_handleCompositionEnd);
  }

  final dynamic draw;
  final dynamic canvasEvent;
  final HTMLDivElement container;
  final dynamic eventBus;
  late final HTMLTextAreaElement agentCursorDom;

  HTMLTextAreaElement getAgentCursorDom() {
    return agentCursorDom;
  }

  void _handleKeyDown(KeyboardEvent event) {
    canvasEvent.keydown(event);
  }

  void _handleInput(Event event) {
    // InputEvent.data (null em deleções/composition — só repassa texto real).
    final JSAny? dataProp = (event as JSObject).getProperty('data'.toJS);
    if (dataProp.isA<JSString>()) {
      canvasEvent.input((dataProp! as JSString).toDart);
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
