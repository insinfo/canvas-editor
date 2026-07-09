part of 'editor_smoke_test.dart';

void _registerShellE2ETests() {
  test('boots the full demo shell', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    expect(
      await page!.waitForSelector('.menu', timeout: const Duration(seconds: 5)),
      isNotNull,
    );
    expect(
      await page!
          .waitForSelector('.editor', timeout: const Duration(seconds: 5)),
      isNotNull,
    );
    expect(
      await page!
          .waitForSelector('.page-mode', timeout: const Duration(seconds: 5)),
      isNotNull,
    );
    expect(
      await page!
          .waitForSelector('.paper-size', timeout: const Duration(seconds: 5)),
      isNotNull,
    );
    expect(
      await page!.waitForSelector('.ce-page-container canvas',
          timeout: const Duration(seconds: 5)),
      isNotNull,
    );
    expect(
      await page!.waitForSelector('.ce-tabler-icons-ready',
          timeout: const Duration(seconds: 5)),
      isNotNull,
    );
    expect(
      await page!.waitForSelector('.word-ruler-horizontal',
          timeout: const Duration(seconds: 5)),
      isNotNull,
    );
    expect(
      await page!.waitForSelector('.word-ruler-vertical',
          timeout: const Duration(seconds: 5)),
      isNotNull,
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final rulerJson = await page!.evaluate<String>('''() => {
      const canvas = document.querySelector('.ce-page-container canvas');
      const ruler = document.querySelector('.word-ruler-horizontal');
      const vertical = document.querySelector('.word-ruler-vertical');
      if (!canvas || !ruler || !vertical) {
        return JSON.stringify({ aligned: false, hasVertical: false });
      }
      const canvasRect = canvas.getBoundingClientRect();
      const rulerRect = ruler.getBoundingClientRect();
      const verticalRect = vertical.getBoundingClientRect();
      return JSON.stringify({
        aligned: Math.abs(canvasRect.left - rulerRect.left) < 3 &&
          Math.abs(canvasRect.width - rulerRect.width) < 3,
        hasVertical: verticalRect.width >= 24 && verticalRect.height > 200,
        horizontalLabels:
          document.querySelectorAll('.word-ruler-horizontal__labels span').length > 5
      });
    }''');
    final ruler = jsonDecode(rulerJson) as Map<String, dynamic>;
    expect(ruler['aligned'], isTrue);
    expect(ruler['hasVertical'], isTrue);
    expect(ruler['horizontalLabels'], isTrue);
  });

  test('shows Word-like page controls in the Layout ribbon tab', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    await page!.click('.ribbon-tab[data-tab="layout"]');
    final stateJson = await page!.evaluate<String>('''() => {
      function visible(selector) {
        const el = document.querySelector(selector);
        if (!el) return false;
        return !el.classList.contains('ribbon-hidden') &&
          getComputedStyle(el).display !== 'none';
      }
      return JSON.stringify({
        paperSize: visible('.menu-item__paper-size'),
        paperDirection: visible('.menu-item__paper-direction'),
        paperMargin: visible('.menu-item__paper-margin'),
        pageMode: visible('.menu-item__page-mode'),
        editHeader: visible('.menu-item__edit-header'),
        editFooter: visible('.menu-item__edit-footer'),
        tablerIcon: visible('.menu-item__paper-size > .ce-tabler-icon'),
        largeLabel: document.querySelector('.menu-item__paper-size')?.dataset.ribbonLabel === 'Tamanho',
        homeBoldHidden: !visible('.menu-item__bold')
      });
    }''');
    final state = jsonDecode(stateJson) as Map<String, dynamic>;

    expect(state['paperSize'], isTrue);
    expect(state['paperDirection'], isTrue);
    expect(state['paperMargin'], isTrue);
    expect(state['pageMode'], isTrue);
    expect(state['editHeader'], isTrue);
    expect(state['editFooter'], isTrue);
    expect(state['tablerIcon'], isTrue);
    expect(state['largeLabel'], isTrue);
    expect(state['homeBoldHidden'], isTrue);

    await page!.click('.menu-item__paper-size');
    expect(
      await page!.waitForSelector('.menu-item__paper-size .options.visible',
          timeout: const Duration(seconds: 5)),
      isNotNull,
    );
    final dropdownJson = await page!.evaluate<String>('''() => {
      const menu = document.querySelector('.menu')?.getBoundingClientRect();
      const options =
        document.querySelector('.menu-item__paper-size .options.visible')
          ?.getBoundingClientRect();
      const optionNode =
        document.querySelector('.menu-item__paper-size .options.visible');
      return JSON.stringify({
        visible: !!options,
        top: options?.top ?? 0,
        height: options?.height ?? 0,
        menuBottom: menu?.bottom ?? 0,
        zIndex: optionNode ? Number(getComputedStyle(optionNode).zIndex) : 0
      });
    }''');
    final dropdown = jsonDecode(dropdownJson) as Map<String, dynamic>;
    expect(dropdown['visible'], isTrue);
    expect(dropdown['top'], greaterThanOrEqualTo(dropdown['menuBottom'] - 1));
    expect(dropdown['height'], greaterThan(80));
    expect(dropdown['zIndex'], greaterThanOrEqualTo(1000));
  });
}
