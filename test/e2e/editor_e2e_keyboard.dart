part of 'editor_smoke_test.dart';

void _registerKeyboardE2ETests() {
  test('supports basic typing and backspace', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    await _resetContent(page!, 'abc');
    await _setRange(page!, 1, 1);
    await page!.keyboard.type('X');
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(await _readMainText(page!), 'aXbc');

    await page!.keyboard.press(Key.backspace);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(await _readMainText(page!), 'abc');
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