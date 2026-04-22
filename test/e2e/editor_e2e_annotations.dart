part of 'editor_smoke_test.dart';

void _registerAnnotationE2ETests() {
  test('renders optional visible whitespace markers', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    await _resetContent(page!, 'A B');

    final hiddenImages = await _readPageImages(page!);
    expect(hiddenImages, isNotEmpty);

    await _setWhiteSpaceVisible(page!, true);
    final visibleImages = await _readPageImages(page!);
    expect(visibleImages.first, isNot(hiddenImages.first));

    await _setWhiteSpaceVisible(page!, false);
    final restoredImages = await _readPageImages(page!);
    expect(restoredImages.first, hiddenImages.first);
  });

  test('supports label rendering and label mousedown events', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    await _resetContent(page!, '');
    await _setRange(page!, 0, 0);
    await _insertLabel(page!, 'Etiqueta');

    final elements = await _readMainElements(page!);
    final labelElement = elements.cast<Map<String, dynamic>?>().firstWhere(
          (element) => element?['type'] == 'label',
          orElse: () => null,
        );
    expect(labelElement, isNotNull);
    expect(labelElement!['value'], 'Etiqueta');
    expect(labelElement['labelId'], 'label-Etiqueta');

    final beforeState = await _readLabelMousedownState(page!);
    expect(beforeState['count'], 0);

    expect(await _clickFirstLabel(page!), isTrue);

    final afterState = await _readLabelMousedownState(page!);
    expect(afterState['count'], 1);
    expect(afterState['value'], 'Etiqueta');
  });

  test('supports graffiti drawing and clear through the public command', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    await _resetContent(page!, 'Modo graffiti');
    await _setMode(page!, 'graffiti');

    try {
      final beforeImages = await _readPageImages(page!);

      expect(
        await _seedGraffitiStroke(
          page!,
          startX: 90,
          startY: 110,
          endX: 220,
          endY: 170,
        ),
        isTrue,
      );

      final graffiti = await _readGraffitiData(page!);
      expect(graffiti, isNotEmpty);
      expect(graffiti.first['pageNo'], 0);
      final strokes =
          (graffiti.first['strokes'] as List<dynamic>? ?? const <dynamic>[]);
      expect(strokes, isNotEmpty);
      final firstStroke =
          Map<String, dynamic>.from(strokes.first as Map<dynamic, dynamic>);
      final points = firstStroke['points'] as List<dynamic>? ?? const <dynamic>[];
      expect(points.length, greaterThanOrEqualTo(4));

      final afterDrawImages = await _readPageImages(page!);
      expect(afterDrawImages, isNotEmpty);
      expect(afterDrawImages.first, isNot(beforeImages.first));

      await _clearGraffiti(page!);
      final clearedGraffiti = await _readGraffitiData(page!);
      expect(clearedGraffiti, isEmpty);

      final afterClearImages = await _readPageImages(page!);
      expect(afterClearImages.first, beforeImages.first);
    } finally {
      await _setMode(page!, 'edit');
    }
  });
}