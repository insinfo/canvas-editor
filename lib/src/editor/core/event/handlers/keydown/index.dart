import 'dart:html';

import '../../../../dataset/enum/editor.dart';
import '../../../../dataset/enum/key_map.dart';
import '../../../../utils/hotkey.dart';
import 'backspace.dart';
import 'delete.dart';
import 'enter.dart';
import 'left.dart';
import 'right.dart';
import 'tab.dart';
import 'updown.dart';

void keydown(KeyboardEvent evt, dynamic host) {
  if (host?.isComposing == true) {
    return;
  }

  final dynamic draw = host.getDraw();
  final String key = evt.key ?? '';
  final String lowerKey = key.toLowerCase();

  if (key == KeyMap.backspace.value) {
    backspace(evt, host);
  } else if (key == KeyMap.delete.value) {
    del(evt, host);
  } else if (key == KeyMap.enter.value) {
    enter(evt, host);
  } else if (key == KeyMap.left.value) {
    left(evt, host);
  } else if (key == KeyMap.right.value) {
    right(evt, host);
  } else if (key == KeyMap.up.value || key == KeyMap.down.value) {
    updown(evt, host);
  } else if (isMod(evt) && lowerKey == KeyMap.z.value) {
    if (draw.isReadonly() == true && draw.getMode() != EditorMode.form) {
      return;
    }
    draw.getHistoryManager()?.undo();
    evt.preventDefault();
  } else if (isMod(evt) && lowerKey == KeyMap.y.value) {
    if (draw.isReadonly() == true && draw.getMode() != EditorMode.form) {
      return;
    }
    draw.getHistoryManager()?.redo();
    evt.preventDefault();
  } else if (isMod(evt) && lowerKey == KeyMap.c.value) {
    host.copy();
    evt.preventDefault();
  } else if (isMod(evt) && lowerKey == KeyMap.x.value) {
    host.cut();
    evt.preventDefault();
  } else if (isMod(evt) && lowerKey == KeyMap.a.value) {
    host.selectAll();
    evt.preventDefault();
  } else if (isMod(evt) && lowerKey == KeyMap.s.value) {
    if (draw.isReadonly() == true) {
      return;
    }
    final dynamic listener = draw.getListener();
    final dynamic savedListener = listener?.saved;
    if (savedListener is Function) {
      savedListener(draw.getValue());
    }
    final dynamic eventBus = draw.getEventBus();
    if (eventBus?.isSubscribe('saved') == true) {
      eventBus.emit('saved', draw.getValue());
    }
    evt.preventDefault();
  } else if (key == KeyMap.esc.value) {
    host.clearPainterStyle();
    final dynamic zoneManager = draw.getZone();
    if (zoneManager?.isMainActive() != true) {
      zoneManager?.setZone(EditorZone.main);
    }
    evt.preventDefault();
  } else if (key == KeyMap.tab.value) {
    tab(evt, host);
  }
}
