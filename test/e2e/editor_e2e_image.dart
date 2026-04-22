part of 'editor_smoke_test.dart';

void _registerImageE2ETests() {
  test('supports image crop and caption updates with serialized state', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    const svg = '<svg xmlns="http://www.w3.org/2000/svg" width="40" height="20" viewBox="0 0 40 20"><rect width="20" height="20" fill="#ff0000"/><rect x="20" width="20" height="20" fill="#0000ff"/></svg>';
    final imageDataUrl =
        'data:image/svg+xml;base64,${base64Encode(utf8.encode(svg))}';

    await _resetContent(page!, '');
    await _setRange(page!, 0, 0);
    await _insertImage(page!, imageDataUrl, 40, 20);
    final beforeImages = await _readPageImages(page!);

    expect(await _setImageCrop(page!, 0, 0, 20, 20), isTrue);
    final afterCropImages = await _readPageImages(page!);
    expect(afterCropImages, isNotEmpty);
    expect(afterCropImages.first, isNot(beforeImages.first));

    expect(await _setImageCaption(page!, 'Figura {imageNo}'), isTrue);
    final afterCaptionImages = await _readPageImages(page!);
    expect(afterCaptionImages.first, isNot(afterCropImages.first));

    final elements = await _readMainElements(page!);
    final imageElement = elements.cast<Map<String, dynamic>?>().firstWhere(
          (element) => element?['type'] == 'image',
          orElse: () => null,
        );

    expect(imageElement, isNotNull);
    expect(imageElement!['imgCrop'], isA<Map<String, dynamic>>());
    expect((imageElement['imgCrop'] as Map<String, dynamic>)['width'], 20);
    expect(imageElement['imgCaption'], isA<Map<String, dynamic>>());
    expect(
      (imageElement['imgCaption'] as Map<String, dynamic>)['value'],
      'Figura {imageNo}',
    );
  });

  test('supports interactive previewer crop move and resize through DOM', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    const svg = '<svg xmlns="http://www.w3.org/2000/svg" width="48" height="24" viewBox="0 0 48 24"><rect width="12" height="24" fill="#ef4444"/><rect x="12" width="24" height="24" fill="#22c55e"/><rect x="36" width="12" height="24" fill="#2563eb"/></svg>';
    final imageDataUrl =
        'data:image/svg+xml;base64,${base64Encode(utf8.encode(svg))}';

    await _resetContent(page!, '');
    await _setRange(page!, 0, 0);
    await _insertImage(page!, imageDataUrl, 48, 24);
    final beforeImages = await _readPageImages(page!);

    expect(await _openFirstImagePreviewer(page!), isTrue);
    expect(
      await _clickPreviewerAction(page!, '.ce-image-previewer .crop-toggle'),
      isTrue,
    );

    final rect = await _readPreviewerImageRect(page!);
    expect(rect, isNotNull);

    final double startX = (rect!['x'] as num).toDouble() +
        (rect['width'] as num).toDouble() * 0.25;
    final double startY = (rect['y'] as num).toDouble() +
        (rect['height'] as num).toDouble() * 0.25;
    final double endX = (rect['x'] as num).toDouble() +
        (rect['width'] as num).toDouble() * 0.75;
    final double endY = (rect['y'] as num).toDouble() +
        (rect['height'] as num).toDouble() * 0.75;

    expect(
      await _dragPreviewerCropSelection(page!, startX, startY, endX, endY),
      isTrue,
    );
    expect(await _readPreviewerCropSelectionRect(page!), isNotNull);
    expect(
      await _movePreviewerCropSelection(
        page!,
        (rect['width'] as num).toDouble() * 0.125,
        (rect['height'] as num).toDouble() * 0.125,
      ),
      isTrue,
    );
    expect(
      await _dragPreviewerCropHandle(
        page!,
        'se',
        -(rect['width'] as num).toDouble() * 0.125,
        (rect['height'] as num).toDouble() * 0.125,
      ),
      isTrue,
    );
    expect(
      await _clickPreviewerAction(page!, '.ce-image-previewer .crop-apply'),
      isTrue,
    );

    final elements = await _readMainElements(page!);
    final imageElement = elements.cast<Map<String, dynamic>?>().firstWhere(
          (element) => element?['type'] == 'image',
          orElse: () => null,
        );
    expect(imageElement, isNotNull);

    final crop = imageElement!['imgCrop'] as Map<String, dynamic>;
    expect((crop['x'] as num).toDouble(), closeTo(18, 2));
    expect((crop['y'] as num).toDouble(), closeTo(9, 2));
    expect((crop['width'] as num).toDouble(), closeTo(18, 2));
    expect((crop['height'] as num).toDouble(), closeTo(15, 2));

    List<String> afterImages = beforeImages;
    for (int attempt = 0; attempt < 8; attempt++) {
      afterImages = await _readPageImages(page!);
      if (afterImages.isNotEmpty && afterImages.first != beforeImages.first) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }

    expect(afterImages, isNotEmpty);
    expect(afterImages.first, isNot(beforeImages.first));
  });

  test('changes image display through the image context menu', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    const svg = '<svg xmlns="http://www.w3.org/2000/svg" width="48" height="24" viewBox="0 0 48 24"><rect width="48" height="24" fill="#f59e0b"/></svg>';
    final imageDataUrl =
        'data:image/svg+xml;base64,${base64Encode(utf8.encode(svg))}';

    await _resetContent(page!, 'Imagem');
    await _setRange(page!, 6, 6);
    await _insertImage(page!, imageDataUrl, 48, 24);

    expect(await _clickFirstImage(page!), isTrue);
    expect(await _openContextMenuAtFirstImage(page!), isTrue);
    expect(await _hoverContextMenuItem(page!, 'Ajuste do texto'), isTrue);
    expect(await _clickContextMenuItem(page!, 'Ao redor'), isTrue);

    var elements = await _readMainElements(page!);
    var imageElement = elements.cast<Map<String, dynamic>?>().firstWhere(
          (element) => element?['type'] == 'image',
          orElse: () => null,
        );
    expect(imageElement, isNotNull);
    expect(imageElement!['imgDisplay'], 'surround');
    expect(imageElement['imgFloatPosition'], isA<Map<String, dynamic>>());

    expect(await _clickFirstImage(page!), isTrue);
    expect(await _openContextMenuAtFirstImage(page!), isTrue);
    expect(await _hoverContextMenuItem(page!, 'Ajuste do texto'), isTrue);
    expect(
      await _clickContextMenuItem(page!, 'Superior e inferior'),
      isTrue,
    );

    elements = await _readMainElements(page!);
    imageElement = elements.cast<Map<String, dynamic>?>().firstWhere(
          (element) => element?['type'] == 'image',
          orElse: () => null,
        );
    expect(imageElement, isNotNull);
    expect(imageElement!['imgDisplay'], 'inline');
    expect(imageElement['imgFloatPosition'], isNull);
  });

  test('supports richer previewer interactions for image zoom rotate and navigation', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    const svgA = '<svg xmlns="http://www.w3.org/2000/svg" width="48" height="24" viewBox="0 0 48 24"><rect width="48" height="24" fill="#ef4444"/></svg>';
    const svgB = '<svg xmlns="http://www.w3.org/2000/svg" width="48" height="24" viewBox="0 0 48 24"><rect width="48" height="24" fill="#22c55e"/></svg>';
    final imageDataUrlA =
        'data:image/svg+xml;base64,${base64Encode(utf8.encode(svgA))}';
    final imageDataUrlB =
        'data:image/svg+xml;base64,${base64Encode(utf8.encode(svgB))}';

    await _resetContent(page!, '');
    await _setRange(page!, 0, 0);
    await _insertImage(page!, imageDataUrlA, 48, 24);
    await _setRange(page!, 1, 1);
    await _insertImage(page!, imageDataUrlB, 48, 24);

    expect(await _openFirstImagePreviewer(page!), isTrue);

    final Map<String, dynamic> beforeState = Map<String, dynamic>.from(
      await page!.evaluate<Map<String, dynamic>>('''() => {
        const img = document.querySelector('.ce-image-previewer .ce-image-container img');
        const count = document.querySelector('.ce-image-previewer .image-count');
        return {
          src: img?.getAttribute('src') || '',
          transform: img ? getComputedStyle(img).transform : '',
          count: (count?.textContent || '').trim(),
        };
      }'''),
    );

    await page!.evaluate<void>('''() => {
      document.querySelector('.ce-image-previewer .zoom-in')
        ?.dispatchEvent(new MouseEvent('click', { bubbles: true }));
      document.querySelector('.ce-image-previewer .rotate')
        ?.dispatchEvent(new MouseEvent('click', { bubbles: true }));
    }''');
    await Future<void>.delayed(const Duration(milliseconds: 120));

    final Map<String, dynamic> transformedState = Map<String, dynamic>.from(
      await page!.evaluate<Map<String, dynamic>>('''() => {
        const img = document.querySelector('.ce-image-previewer .ce-image-container img');
        return {
          transform: img?.style.transform || '',
        };
      }'''),
    );

    expect(beforeState['count'], '1 / 2');
    expect((beforeState['src'] as String), imageDataUrlA);
    expect(
      (transformedState['transform'] as String),
      contains('scale(1.1)'),
    );
    expect(
      (transformedState['transform'] as String),
      contains('rotate(90deg)'),
    );

    await page!.evaluate<void>('''() => {
      document.querySelector('.ce-image-previewer .image-next')
        ?.dispatchEvent(new MouseEvent('click', { bubbles: true }));
    }''');
    await Future<void>.delayed(const Duration(milliseconds: 120));

    final Map<String, dynamic> nextState = Map<String, dynamic>.from(
      await page!.evaluate<Map<String, dynamic>>('''() => {
        const img = document.querySelector('.ce-image-previewer .ce-image-container img');
        const count = document.querySelector('.ce-image-previewer .image-count');
        return {
          src: img?.getAttribute('src') || '',
          count: (count?.textContent || '').trim(),
        };
      }'''),
    );

    expect(nextState['count'], '2 / 2');
    expect((nextState['src'] as String), imageDataUrlB);
  });

  test('supports previewer pan wheel zoom and resizer drag through real DOM interactions', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    const svg = '<svg xmlns="http://www.w3.org/2000/svg" width="48" height="24" viewBox="0 0 48 24"><rect width="48" height="24" fill="#0ea5e9"/></svg>';
    final imageDataUrl =
        'data:image/svg+xml;base64,${base64Encode(utf8.encode(svg))}';

    await _resetContent(page!, '');
    await _setRange(page!, 0, 0);
    await _insertImage(page!, imageDataUrl, 48, 24);

    expect(await _openFirstImagePreviewer(page!), isTrue);
    expect(await _wheelPreviewer(page!, -120), isTrue);

    final Map<String, dynamic> startRect = Map<String, dynamic>.from(
      await page!.evaluate<Map<String, dynamic>>('''() => {
        const image = document.querySelector('.ce-image-previewer .ce-image-container img');
        const rect = image?.getBoundingClientRect();
        return rect
          ? {
              x: rect.left + rect.width / 2,
              y: rect.top + rect.height / 2,
            }
          : { x: 0, y: 0 };
      }'''),
    );

    expect(
      await _dragPreviewerImage(
        page!,
        (startRect['x'] as num).toDouble(),
        (startRect['y'] as num).toDouble(),
        (startRect['x'] as num).toDouble() + 36,
        (startRect['y'] as num).toDouble() + 18,
      ),
      isTrue,
    );

    final Map<String, dynamic> previewerState = Map<String, dynamic>.from(
      await page!.evaluate<Map<String, dynamic>>('''() => {
        const image = document.querySelector('.ce-image-previewer .ce-image-container img');
        return {
          left: image?.style.left || '',
          top: image?.style.top || '',
          transform: image?.style.transform || '',
        };
      }'''),
    );

    expect((previewerState['transform'] as String), contains('scale(1.1)'));
    expect(previewerState['left'], isNot('0px'));
    expect(previewerState['top'], isNot('0px'));

    expect(await _dragResizerHandle(page!, 4, 24, 12), isTrue);

    final elements = await _readMainElements(page!);
    final imageElement = elements.cast<Map<String, dynamic>?>().firstWhere(
          (element) => element?['type'] == 'image',
          orElse: () => null,
        );
    expect(imageElement, isNotNull);
    expect((imageElement!['width'] as num).toDouble(), greaterThan(48));
    expect((imageElement['height'] as num).toDouble(), greaterThan(24));
  });

  test('renders previewer and resizer UI for images in the web shell', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    const svg = '<svg xmlns="http://www.w3.org/2000/svg" width="48" height="24" viewBox="0 0 48 24"><rect width="48" height="24" fill="#88c0d0"/></svg>';
    final imageDataUrl =
        'data:image/svg+xml;base64,${base64Encode(utf8.encode(svg))}';

    await _resetContent(page!, '');
    await _setRange(page!, 0, 0);
    await _insertImage(page!, imageDataUrl, 48, 24);

    expect(await _openFirstImagePreviewer(page!), isTrue);

    final Map<String, dynamic> state = Map<String, dynamic>.from(
      await page!.evaluate<Map<String, dynamic>>('''() => {
        const previewer = document.querySelector('.ce-image-previewer');
        const close = document.querySelector('.ce-image-previewer .image-close');
        const zoomIn = document.querySelector('.ce-image-previewer .zoom-in');
        const zoomOut = document.querySelector('.ce-image-previewer .zoom-out');
        const rotate = document.querySelector('.ce-image-previewer .rotate');
        const originalSize = document.querySelector('.ce-image-previewer .original-size');
        const download = document.querySelector('.ce-image-previewer .image-download');
        const resizer = document.querySelector('.ce-resizer-selection');
        const closeStyle = close ? getComputedStyle(close) : null;
        const previewerStyle = previewer ? getComputedStyle(previewer) : null;
        const resizerStyle = resizer ? getComputedStyle(resizer) : null;
        return {
          hasPreviewer: !!previewer,
          hasClose: !!close,
          hasZoomIn: !!zoomIn,
          hasZoomOut: !!zoomOut,
          hasRotate: !!rotate,
          hasOriginalSize: !!originalSize,
          hasDownload: !!download,
          previewerPosition: previewerStyle ? previewerStyle.position : '',
          previewerBackground: previewerStyle ? previewerStyle.backgroundColor : '',
          closeBackgroundImage: closeStyle ? closeStyle.backgroundImage : '',
          resizerDisplay: resizerStyle ? resizerStyle.display : '',
          resizerBorderStyle: resizerStyle ? resizerStyle.borderStyle : '',
        };
      }'''),
    );

    expect(state['hasPreviewer'], isTrue);
    expect(state['hasClose'], isTrue);
    expect(state['hasZoomIn'], isTrue);
    expect(state['hasZoomOut'], isTrue);
    expect(state['hasRotate'], isTrue);
    expect(state['hasOriginalSize'], isTrue);
    expect(state['hasDownload'], isTrue);
    expect(state['previewerPosition'], 'fixed');
    expect(state['previewerBackground'], isNotEmpty);
    expect((state['closeBackgroundImage'] as String), isNot('none'));
    expect(state['resizerDisplay'], 'block');
    expect((state['resizerBorderStyle'] as String), isNot('none'));

    await page!.evaluate<void>(
      '() => document.querySelector(\'.ce-image-previewer .image-close\')?.dispatchEvent(new MouseEvent(\'click\', { bubbles: true }))',
    );
    await Future<void>.delayed(const Duration(milliseconds: 120));

    final bool previewerClosed = await page!.evaluate<bool>(
      '() => !document.querySelector(\'.ce-image-previewer\')',
    );
    expect(previewerClosed, isTrue);
  });
}