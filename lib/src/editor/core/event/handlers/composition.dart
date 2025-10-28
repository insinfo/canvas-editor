import 'dart:async';

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
  final String data = evt?.data as String? ?? '';

  if (data.isEmpty) {
    removeComposingInput(host);
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
