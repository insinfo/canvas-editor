part of 'editor_smoke_test.dart';

void _registerToolbarE2ETests() {
  test('applies font and color without runtime type errors', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    await _resetContent(page!, 'FonteCor');
    await _setRange(page!, 0, 8);
    await _setFont(page!, 'Arial');
    await _setColor(page!, '#ff0000');

    final elements = await _readMainElements(page!);
    final styledElement = elements.cast<Map<String, dynamic>?>().firstWhere(
          (element) =>
              element?['value'] == 'FonteCor' &&
              element?['font'] == 'Arial' &&
              element?['color'] == '#ff0000',
          orElse: () => null,
        );

    expect(styledElement, isNotNull);
  });

  test('applies toolbar color through native input events', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    await _resetContent(page!, 'Cor');
    await _setRange(page!, 0, 3);
    await page!.evaluate<void>('''() => {
      const colorInput = document.querySelector('#color');
      colorInput.value = '#00ff00';
      colorInput.dispatchEvent(new Event('input', { bubbles: true }));
    }''');
    await Future<void>.delayed(const Duration(milliseconds: 120));

    final elements = await _readMainElements(page!);
    final styledElement = elements.cast<Map<String, dynamic>?>().firstWhere(
          (element) =>
              element?['value'] == 'Cor' &&
              element?['color'] == '#00ff00',
          orElse: () => null,
        );

    expect(styledElement, isNotNull);
  });

  test('applies toolbar color through native change events', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    await _resetContent(page!, 'Change');
    await _setRange(page!, 0, 6);
    await page!.evaluate<void>('''() => {
      const colorInput = document.querySelector('#color');
      colorInput.value = '#008000';
      colorInput.dispatchEvent(new Event('change', { bubbles: true }));
    }''');
    await Future<void>.delayed(const Duration(milliseconds: 120));

    final elements = await _readMainElements(page!);
    final styledElement = elements.cast<Map<String, dynamic>?>().firstWhere(
          (element) =>
              element?['value'] == 'Change' &&
              element?['color'] == '#008000',
          orElse: () => null,
        );

    expect(styledElement, isNotNull);
  });

  test('respects backgroundDisabled in print mode', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    await _resetContent(page!, 'Fundo');
    await _setMode(page!, 'print');
    await _setPrintModeOptions(
      page!,
      backgroundColor: '#fde68a',
      backgroundDisabled: false,
    );
    final withBackground = await _readPageImages(page!);
    expect(withBackground, isNotEmpty);

    await _setPrintModeOptions(
      page!,
      backgroundColor: '#fde68a',
      backgroundDisabled: true,
    );
    final withoutBackground = await _readPageImages(page!);
    expect(withoutBackground, isNotEmpty);
    expect(withoutBackground.first, isNot(withBackground.first));

    await _setMode(page!, 'edit');
  });
}