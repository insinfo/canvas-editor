import 'dart:async';
import 'dart:html' as html;

import '../../interface/shortcut/shortcut.dart';
import '../../utils/hotkey.dart';
import 'keys/list_keys.dart';
import 'keys/richtext_keys.dart';
import 'keys/title_keys.dart';

class Shortcut {
  final dynamic _draw;
  final dynamic command;
  final List<IRegisterShortcut> _globalShortcutList = [];
  final List<IRegisterShortcut> _agentShortcutList = [];
  StreamSubscription<html.KeyboardEvent>? _globalSubscription;
  StreamSubscription<html.KeyboardEvent>? _agentSubscription;

  Shortcut(this._draw, this.command) {
    _addShortcutList([
      ...richtextKeys,
      ...titleKeys,
      ...listKeys,
    ]);
    _addEvent();
    final agentDom = _getAgentDom();
    if (agentDom != null) {
      _agentSubscription = agentDom.onKeyDown.listen(_agentKeydown);
    }
  }

  void _addEvent() {
    _globalSubscription = html.document.onKeyDown.listen(_globalKeydown);
  }

  void removeEvent() {
    _globalSubscription?.cancel();
    _globalSubscription = null;
    _agentSubscription?.cancel();
    _agentSubscription = null;
  }

  html.Element? _getAgentDom() {
    try {
      final dynamic cursor = _draw?.getCursor();
      final dynamic agentDom = cursor?.getAgentDom();
      if (agentDom is html.Element) {
        return agentDom;
      }
    } catch (_) {
      // Ignore missing cursor agent during early initialization.
    }
    return null;
  }

  void _addShortcutList(List<IRegisterShortcut> payload) {
    for (var s = payload.length - 1; s >= 0; s--) {
      final shortCut = payload[s];
      if (shortCut.isGlobal == true) {
        _globalShortcutList.insert(0, shortCut);
      } else {
        _agentShortcutList.insert(0, shortCut);
      }
    }
  }

  void registerShortcutList(List<IRegisterShortcut> payload) {
    _addShortcutList(payload);
  }

  void _globalKeydown(html.KeyboardEvent evt) {
    if (_globalShortcutList.isEmpty) {
      return;
    }
    _execute(evt, _globalShortcutList);
  }

  void _agentKeydown(html.KeyboardEvent evt) {
    if (_agentShortcutList.isEmpty) {
      return;
    }
    _execute(evt, _agentShortcutList);
  }

  void _execute(html.KeyboardEvent evt, List<IRegisterShortcut> shortCutList) {
    final eventKey = evt.key?.toLowerCase();
    for (final shortCut in shortCutList) {
      final expectedKey = shortCut.key.value.toLowerCase();
      final bool modMatch;
      if (shortCut.mod != null) {
        modMatch = isMod(evt) == (shortCut.mod ?? false);
      } else {
        modMatch = evt.ctrlKey == (shortCut.ctrl ?? false) &&
            evt.metaKey == (shortCut.meta ?? false);
      }

      if (modMatch &&
          evt.shiftKey == (shortCut.shift ?? false) &&
          evt.altKey == (shortCut.alt ?? false) &&
          eventKey == expectedKey) {
        if (shortCut.disable != true) {
          shortCut.callback?.call(command);
          evt.preventDefault();
        }
        break;
      }
    }
  }
}
