part of 'editor_smoke_test.dart';

void _registerLatexClipboardE2ETests() {
  test('supports latex insertion with generated SVG metadata', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    await _resetContent(page!, '');
    await _setRange(page!, 0, 0);
    await _insertLatex(page!, r'x^2 + y^2 = z^2');

    final elements = await _readMainElements(page!);
    final latexElement = elements.cast<Map<String, dynamic>?>().firstWhere(
          (element) => element?['type'] == 'latex',
          orElse: () => null,
        );

    expect(latexElement, isNotNull);
    expect(latexElement!['value'], r'x^2 + y^2 = z^2');
    expect((latexElement['width'] as num?)?.toDouble() ?? 0, greaterThan(0));
    expect(
      (latexElement['height'] as num?)?.toDouble() ?? 0,
      greaterThan(0),
    );
    expect(latexElement['laTexSVG'], isA<String>());
    expect(
      (latexElement['laTexSVG'] as String),
      startsWith('data:image/svg+xml;base64,'),
    );
  });

  test('supports copy paste and undo redo for text selections', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    await _resetContent(page!, 'abcd');
    await _setRange(page!, 1, 3);
    await _copySelection(page!);
    await _setRange(page!, 4, 4);
    await _pasteStoredClipboard(page!);
    expect(await _readMainText(page!), 'abcdbc');

    await _undo(page!);
    expect(await _readMainText(page!), 'abcd');

    await _redo(page!);
    expect(await _readMainText(page!), 'abcdbc');
  });

  test('supports latex paste from editor clipboard with SVG metadata', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    await _resetContent(page!, '');
    await _setRange(page!, 0, 0);
    await _storeLatexClipboard(page!, r'\frac{a}{b}');
    await _pasteStoredClipboard(page!);

    final elements = await _readMainElements(page!);
    final latexElement = elements.cast<Map<String, dynamic>?>().firstWhere(
          (element) => element?['type'] == 'latex',
          orElse: () => null,
        );

    expect(latexElement, isNotNull);
    expect(latexElement!['value'], r'\frac{a}{b}');
    expect((latexElement['width'] as num?)?.toDouble() ?? 0, greaterThan(0));
    expect((latexElement['height'] as num?)?.toDouble() ?? 0, greaterThan(0));
    expect(
      (latexElement['laTexSVG'] as String),
      startsWith('data:image/svg+xml;base64,'),
    );
  });
}