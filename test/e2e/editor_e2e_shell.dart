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
  });
}