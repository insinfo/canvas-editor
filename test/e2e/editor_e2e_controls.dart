part of 'editor_smoke_test.dart';

void _registerControlUtilityE2ETests() {
  test('supports embedded control insertion scenarios', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    await _resetContent(page!, '');
    await _setRange(page!, 0, 0);
    await _insertTextControl(page!, 'Nome completo', 'Maria');
    await _insertCheckboxControl(page!);

    final elements = await _readMainElements(page!);
    final textControl = elements.cast<Map<String, dynamic>?>().firstWhere(
          (element) => element?['type'] == 'control' &&
              element?['controlType'] == 'text',
          orElse: () => null,
        );
    final checkboxControl = elements.cast<Map<String, dynamic>?>().firstWhere(
          (element) => element?['type'] == 'control' &&
              element?['controlType'] == 'checkbox',
          orElse: () => null,
        );

    expect(textControl, isNotNull);
    expect(textControl!['controlPlaceholder'], 'Nome completo');
    expect(textControl['controlValue'], 'Maria');

    expect(checkboxControl, isNotNull);
    expect(checkboxControl!['controlValueSetCount'], 2);
  });

  test('respects filterEmptyControl when entering print mode', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    await _resetContent(page!, '');
    await _setRange(page!, 0, 0);
    await _insertTextControl(page!, 'Vazio', '');

    await _setPrintModeOptions(page!, filterEmptyControl: true);
    await _setMode(page!, 'print');
    var elements = await _readDrawElements(page!);
    expect(
      elements.any(
        (element) => element['controlComponent'] == 'placeholder',
      ),
      isFalse,
    );

    await _setMode(page!, 'edit');
    await _setPrintModeOptions(page!, filterEmptyControl: false);
    await _setMode(page!, 'print');
    elements = await _readDrawElements(page!);
    expect(
      elements.any(
        (element) => element['controlComponent'] == 'placeholder',
      ),
      isTrue,
    );

    await _setMode(page!, 'edit');
  });

  test('exposes cursor and height utility commands', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    await _resetContent(page!, 'Utilitarios');
    await _setRange(page!, 2, 2);

    expect(await _readCursorDisplay(page!), 'block');

    await _hideCursor(page!);
    expect(await _readCursorDisplay(page!), 'none');

    final remainingHeight = await _readRemainingContentHeight(page!);
    final emptyHeight = await _computeTextHeight(page!, '');
    final textHeight = await _computeTextHeight(page!, 'Altura de teste');

    expect(remainingHeight, greaterThan(0));
    expect(emptyHeight, 0);
    expect(textHeight, greaterThan(0));
  });

  test('supports jumping to the next control through the public command', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    await _resetContent(page!, '');
    await _setRange(page!, 0, 0);
    await _insertTextControl(page!, 'Primeiro', 'A');
    await _insertTextControl(page!, 'Segundo', 'B');

    final List<String> controlIds = await _readControlIds(page!);
    expect(controlIds.length, greaterThanOrEqualTo(2));

    final String firstControlId = controlIds.first;

    await _locationControl(page!, firstControlId);
    final beforeRange = await _readRange(page!);
    await _jumpControl(page!);

    final afterRange = await _readRange(page!);
    expect(afterRange['startIndex'], afterRange['endIndex']);
    expect(afterRange['startIndex'], isNot(beforeRange['startIndex']));
  });

  test('keeps document stable when deleting a missing area through the public command', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    await _resetContent(page!, 'Texto base');
    final beforeText = await _readMainText(page!);
    expect(await _areaExists(page!, 'area-inexistente'), isFalse);

    await _deleteArea(page!, 'area-inexistente');

    expect(await _areaExists(page!, 'area-inexistente'), isFalse);
    expect(await _readMainText(page!), beforeText);
  });
}