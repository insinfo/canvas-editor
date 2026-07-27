import 'dart:async';

import 'package:canvas_text_editor/src/dom/dom.dart' as html;

import '../../../interface/draw.dart';
import '../../../interface/range.dart';
import '../../../utils/ua.dart';
import 'input.dart';

void compositionstart(dynamic host) {
  host.isComposing = true;
}

void compositionend(dynamic host, dynamic evt) {
  host.isComposing = false;
  final dynamic draw = host.getDraw();
  // CompositionEvent.data lido tipado (dispatch dinâmico em JS falha).
  String data = '';
  if (html.jsIsJSObject(evt)) {
    final html.JSAny? dataProp =
        (evt as html.JSObject).getProperty('data'.toJS);
    if (dataProp.isA<html.JSString>()) {
      data = (dataProp! as html.JSString).toDart;
    }
  }

  if (data.isEmpty) {
    removeComposingInput(host, restoreOriginalSelection: true);
    final dynamic rangeManager = draw.getRange();
    final IRange range = rangeManager.getRange() as IRange;
    final int curIndex = range.endIndex;
    draw.render(
      IDrawOption(
        curIndex: curIndex,
        isSubmitHistory: false,
      ),
    );
  } else {
    void triggerInput() {
      if (host.compositionInfo != null) {
        input(data, host);
      }
    }

    if (isFirefox) {
      Future<void>.delayed(const Duration(milliseconds: 1), triggerInput);
    } else {
      triggerInput();
    }
  }

  draw.getCursor().clearAgentDomValue();
}
