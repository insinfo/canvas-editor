part of 'editor_smoke_test.dart';

void _registerKeyboardE2ETests() {
  test('creates history baseline on setValue, not on first focus', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    final Map<String, dynamic> before =
        await page!.evaluate<Map<String, dynamic>>(
      '() => window.__editorTest.historyDiagnostics()',
    );
    await _resetContent(page!, 'abcdef');
    final Map<String, dynamic> afterSetValue =
        await page!.evaluate<Map<String, dynamic>>(
      '() => window.__editorTest.historyDiagnostics()',
    );

    // setValue/recovery cria exatamente o novo endpoint absoluto; o setRange e
    // focusInput executados por _resetContent não podem criar outro snapshot.
    expect(
      afterSetValue['deepSnapshots'],
      (before['deepSnapshots'] as num).toInt() + 1,
    );
    expect(afterSetValue['transitions'], 0);

    await _setRange(page!, 1, 4);
    final Map<String, dynamic> afterFirstSelection =
        await page!.evaluate<Map<String, dynamic>>(
      '() => window.__editorTest.historyDiagnostics()',
    );
    expect(
      afterFirstSelection['deepSnapshots'],
      afterSetValue['deepSnapshots'],
    );

    await page!.keyboard.type('X');
    final String afterTyping = await _readMainText(page!);
    expect(afterTyping, isNot('abcdef'));
    await _undo(page!);
    expect(await _readMainText(page!), 'abcdef');
    await _redo(page!);
    expect(await _readMainText(page!), afterTyping);
  });

  test('supports basic typing and backspace', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    await _resetContent(page!, 'abc');
    await _setRange(page!, 1, 1);
    await page!.evaluate<void>(
      '() => window.__editorTest.resetLayoutDiagnostics()',
    );
    await page!.keyboard.type('X');
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(await _readMainText(page!), 'aXbc');
    final Map<String, dynamic> typingLayout =
        await page!.evaluate<Map<String, dynamic>>(
      '() => window.__editorTest.layoutDiagnostics()',
    );
    expect(typingLayout['partialPageRepaints'], 1);
    expect(typingLayout['partialPageRepaintRows'], 1);

    await page!.keyboard.press(Key.backspace);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(await _readMainText(page!), 'abc');
  });

  test('groups a typing burst and preserves undo redo', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    await _resetContent(page!, 'abc');
    await _setRange(page!, 1, 1);
    await page!.keyboard.type('XYZ');
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(await _readMainText(page!), 'aXYZbc');
    final Map<String, dynamic> diagnostics =
        await page!.evaluate<Map<String, dynamic>>(
      '() => window.__editorTest.historyDiagnostics()',
    );
    expect(diagnostics['pendingBurstMutations'], 1);
    expect(diagnostics['compactTransitions'], 1);

    await _undo(page!);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(await _readMainText(page!), 'abc');

    await _redo(page!);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(await _readMainText(page!), 'aXYZbc');
  });

  test('notifies content changes for typed mutations and history replay',
      () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    await _resetContent(page!, 'abc');
    await _setRange(page!, 1, 1);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await page!.evaluate<void>(
      '() => window.__editorTest.resetContentChangeCount()',
    );

    await page!.keyboard.type('X');
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(
      await page!.evaluate<num>(
        '() => window.__editorTest.contentChangeCount()',
      ),
      1,
    );

    await _undo(page!);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(
      await page!.evaluate<num>(
        '() => window.__editorTest.contentChangeCount()',
      ),
      2,
    );

    await _redo(page!);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(
      await page!.evaluate<num>(
        '() => window.__editorTest.contentChangeCount()',
      ),
      3,
    );
  });

  test('preserves list paste around a leading zero through undo redo',
      () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    await _resetContent(page!, 'abc');
    await _setRange(page!, 0, 0);
    await page!.evaluate<void>(
      "() => window.__editorTest.insertListText('XY')",
    );
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(await _readMainText(page!), 'XYabc');

    await _undo(page!);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(await _readMainText(page!), 'abc');

    await _redo(page!);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(await _readMainText(page!), 'XYabc');
  });

  test('IME replacement restores the original selection on undo', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    await _resetContent(page!, 'abcd');
    await _setRange(page!, 0, 2);
    await page!.evaluate<void>(r'''() => {
      const input = document.querySelector('.ce-inputarea');
      input.dispatchEvent(new CompositionEvent('compositionstart', {
        bubbles: true,
        data: ''
      }));
      input.dispatchEvent(new InputEvent('input', {
        bubbles: true,
        data: '文',
        inputType: 'insertCompositionText',
        isComposing: true
      }));
      input.dispatchEvent(new CompositionEvent('compositionend', {
        bubbles: true,
        data: '文'
      }));
    }''');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(await _readMainText(page!), '文cd');

    await _undo(page!);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(await _readMainText(page!), 'abcd');

    await _redo(page!);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(await _readMainText(page!), '文cd');
  });

  test('mixes compact typing with a legacy snapshot transition', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    await _resetContent(page!, 'abc');
    await _setRange(page!, 1, 1);
    await page!.keyboard.type('X');
    await Future<void>.delayed(const Duration(milliseconds: 60));
    await page!.evaluate<void>(
      "() => window.__editorTest.setRowFlex('center')",
    );
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(await _readMainText(page!), 'aXbc');
    expect(
      (await _readMainElements(page!)).any(
        (element) => element['rowFlex'] == 'center',
      ),
      isTrue,
    );

    await _undo(page!);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(await _readMainText(page!), 'aXbc');
    expect(
      (await _readMainElements(page!)).any(
        (element) => element['rowFlex'] == 'center',
      ),
      isFalse,
    );

    await _undo(page!);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(await _readMainText(page!), 'abc');

    await _redo(page!);
    await _redo(page!);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(await _readMainText(page!), 'aXbc');
    expect(
      (await _readMainElements(page!)).any(
        (element) => element['rowFlex'] == 'center',
      ),
      isTrue,
    );
  });

  test('supports arrow navigation and selection expansion', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    await _resetContent(page!, 'abcd');
    await _setRange(page!, 1, 1);

    await page!.keyboard.press(Key.arrowRight);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final collapsedRange = await _readRange(page!);
    expect(collapsedRange['startIndex'], 2);
    expect(collapsedRange['endIndex'], 2);

    await page!.keyboard.down(Key.shift);
    await page!.keyboard.press(Key.arrowRight);
    await page!.keyboard.up(Key.shift);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final expandedRange = await _readRange(page!);
    expect(expandedRange['startIndex'], 2);
    expect(expandedRange['endIndex'], 3);
  });

  test('supports home and end keyboard navigation', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    await _resetContent(page!, 'abcd');
    await _setRange(page!, 2, 2);

    await page!.keyboard.press(Key.home);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await page!.keyboard.type('X');
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(await _readMainText(page!), 'Xabcd');

    await _resetContent(page!, 'abcd');
    await _setRange(page!, 1, 1);

    await page!.keyboard.press(Key.end);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await page!.keyboard.type('Y');
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(await _readMainText(page!), 'abcdY');
  });

  test('supports end key selection expansion with shift', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    await _resetContent(page!, 'abcd');
    await _setRange(page!, 1, 1);

    await page!.keyboard.down(Key.shift);
    await page!.keyboard.press(Key.end);
    await page!.keyboard.up(Key.shift);
    await Future<void>.delayed(const Duration(milliseconds: 120));

    final range = await _readRange(page!);
    expect(range['startIndex'], 1);
    expect(range['endIndex'], 4);
  });

  test('supports enter inserting a new line element', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    await _resetContent(page!, 'abcd');
    await _setRange(page!, 1, 1);
    final beforeText = await _readMainText(page!);

    await page!.keyboard.press(Key.enter);
    await Future<void>.delayed(const Duration(milliseconds: 120));

    final afterText = await _readMainText(page!);
    final range = await _readRange(page!);
    expect(afterText, isNot(beforeText));
    expect(
      afterText.contains('\n') || afterText.contains(_zeroWidthSpace),
      isTrue,
    );
    expect(range['startIndex'], range['endIndex']);
    expect(range['startIndex'], greaterThanOrEqualTo(1));
  });

  test('coalesces an enter burst and preserves undo redo', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    await _resetContent(page!, 'abcd');
    await _setRange(page!, 1, 1);
    final beforeText = await _readMainText(page!);

    await page!.keyboard.press(Key.enter);
    await page!.keyboard.press(Key.enter);
    await page!.keyboard.press(Key.enter);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final afterText = await _readMainText(page!);
    expect(afterText, isNot(beforeText));

    final Map<String, dynamic> diagnostics =
        await page!.evaluate<Map<String, dynamic>>(
      '() => window.__editorTest.historyDiagnostics()',
    );
    expect(diagnostics['pendingBurstMutations'], 1);

    await _undo(page!);
    expect(await _readMainText(page!), beforeText);
    await _redo(page!);
    expect(await _readMainText(page!), afterText);
  });

  test('coalesces alternating enter and typing into one restorer', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    await _resetContent(page!, 'abcd');
    await _setRange(page!, 1, 1);
    final beforeText = await _readMainText(page!);

    await page!.keyboard.press(Key.enter);
    await page!.keyboard.type('x');
    await page!.keyboard.press(Key.enter);
    await page!.keyboard.type('y');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final afterText = await _readMainText(page!);
    expect(afterText, isNot(beforeText));

    final Map<String, dynamic> diagnostics =
        await page!.evaluate<Map<String, dynamic>>(
      '() => window.__editorTest.historyDiagnostics()',
    );
    expect(diagnostics['pendingBurstMutations'], 1);
    expect(diagnostics['compactTransitions'], 1);

    await _undo(page!);
    expect(await _readMainText(page!), beforeText);
    await _redo(page!);
    expect(await _readMainText(page!), afterText);
  });

  test('replays first-header typing through an absolute checkpoint', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    await page!.evaluate<void>(
      '() => window.__editorTest.resetFirstHeaderVariant()',
    );
    final String before = await page!.evaluate<String>(
      '() => window.__editorTest.firstHeaderVariantText()',
    );
    await page!.keyboard.type('X');
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final String after = await page!.evaluate<String>(
      '() => window.__editorTest.firstHeaderVariantText()',
    );
    expect(after, isNot(before));

    await page!.evaluate<void>(
      '() => window.__editorTest.submitHistoryCheckpoint()',
    );
    await _undo(page!); // restaura baseline + reaplica delta pelo locator
    expect(
      await page!.evaluate<String>(
        '() => window.__editorTest.firstHeaderVariantText()',
      ),
      after,
    );
    await _undo(page!);
    expect(
      await page!.evaluate<String>(
        '() => window.__editorTest.firstHeaderVariantText()',
      ),
      before,
    );
    await _redo(page!);
    expect(
      await page!.evaluate<String>(
        '() => window.__editorTest.firstHeaderVariantText()',
      ),
      after,
    );
  });

  test('selection delete is one reversible compact mutation', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    await _resetContent(page!, 'abcdefghij');
    final beforeText = await _readMainText(page!);
    await _setRange(page!, 2, 7);
    await page!.keyboard.press(Key.delete);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final afterText = await _readMainText(page!);
    expect(afterText, isNot(beforeText));

    final Map<String, dynamic> diagnostics =
        await page!.evaluate<Map<String, dynamic>>(
      '() => window.__editorTest.historyDiagnostics()',
    );
    expect(diagnostics['pendingBurstMutations'], 1);

    await _undo(page!);
    expect(await _readMainText(page!), beforeText);
    await _redo(page!);
    expect(await _readMainText(page!), afterText);
  });

  test('selection delete preserves interleaved protected elements in order',
      () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    await page!.evaluate<void>(
      '() => window.__editorTest.resetProtectedDeleteContent()',
    );
    final beforeText = await _readMainText(page!);
    await _setRange(page!, 0, 7);
    await page!.keyboard.press(Key.delete);
    await Future<void>.delayed(const Duration(milliseconds: 80));

    // P e Q (title deletable=false) sobrevivem na ordem original. H é hidden
    // e, como antes, continua removível mesmo protegido.
    expect(await _readMainText(page!), 'PQd');

    await _undo(page!);
    expect(await _readMainText(page!), beforeText);
    await _redo(page!);
    expect(await _readMainText(page!), 'PQd');
  });

  test('enter and multi-paragraph delete stay on text-range layout', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    await _resetContent(page!, 'aa\nbb\ncc\nzz');
    await _setRange(page!, 1, 1);
    await page!.evaluate<void>(
      '() => window.__editorTest.resetLayoutDiagnostics()',
    );
    await page!.keyboard.press(Key.enter);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    var diagnostics = await page!.evaluate<Map<String, dynamic>>(
      '() => window.__editorTest.layoutDiagnostics()',
    );
    expect(diagnostics['mode'], 'text-range');
    expect(diagnostics['fastTextLayouts'], 1);
    expect(diagnostics['fullLayouts'], 0);

    await _resetContent(page!, 'aa\nbb\ncc\nzz');
    await _setRange(page!, 2, 8);
    await page!.evaluate<void>(
      '() => window.__editorTest.resetLayoutDiagnostics()',
    );
    await page!.keyboard.press(Key.delete);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    diagnostics = await page!.evaluate<Map<String, dynamic>>(
      '() => window.__editorTest.layoutDiagnostics()',
    );
    expect(diagnostics['mode'], 'text-range');
    expect(diagnostics['fastTextLayouts'], 1);
    expect(diagnostics['fullLayouts'], 0);
  });

  test('supports real mouse drag selection on canvas text', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    await _resetContent(page!, 'abcd');
    expect(await _dragMouseSelection(page!, 1, 3), isTrue);

    final range = await _readRange(page!);
    expect(range['startIndex'], 1);
    expect(range['endIndex'], 3);
  });
}
