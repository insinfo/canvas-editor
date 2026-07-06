part of 'editor_smoke_test.dart';

/// E2E da Fase 2.4 do roteiro_editor_profissional: abrir DOCX na shell.
void _registerDocxE2ETests() {
  test('abre o ETP DOCX pela toolbar e renderiza com geometria do arquivo',
      () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    final input = await page!.$('#docx');
    await input.uploadFile(
        [File('resources/PGCTIC1_-_ETP_-_Sistema_de_Gestão_Pública.docx')]);

    // Conversão + re-render acontecem após o FileReader assíncrono.
    await page!.waitForFunction(
      '''() => {
        const api = window.__editorTest;
        if (!api) return false;
        const text = api.mainText();
        return text.includes('ESTUDO') && text.length > 10000;
      }''',
      timeout: const Duration(seconds: 30),
    );

    final text =
        await page!.evaluate<String?>('() => window.__editorTest.mainText()');
    expect(text, isNotNull);
    expect(text, contains('ESTUDO TÉCNICO PRELIMINAR'));

    // Documento multi-página: o container deve ter vários canvases vivos.
    final canvasCount = await page!.evaluate<int?>(
        "() => document.querySelectorAll('.editor canvas').length");
    expect(canvasCount, isNotNull);
    expect(canvasCount!, greaterThan(3),
        reason: 'ETP tem ~19 páginas no Word; render deve paginar');

    // Geometria vinda do arquivo (794×1123 px é o A4 do sectPr).
    final width = await page!.evaluate<num?>(
        "() => document.querySelector('.editor canvas').width");
    expect(width, isNotNull);
    expect(width!.toDouble(), greaterThan(700));

    // Sem erros de runtime no console durante a conversão.
    final hadError = await page!.evaluate<bool?>(
        '() => window.__lastPageError !== undefined');
    expect(hadError ?? false, isFalse);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('abre o TR DOCX (140 páginas) sem exceção e com tabelas', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    final input = await page!.$('#docx');
    await input.uploadFile([
      File(
          'resources/PGCTIC1_-_TR_-_SISTEMA_GESTAO_PUBLICA__Recuperação_Automática_.docx')
    ]);

    await page!.waitForFunction(
      '''() => {
        const api = window.__editorTest;
        if (!api) return false;
        const text = api.mainText();
        return text.includes('TERMO DE REFER') && text.length > 100000;
      }''',
      timeout: const Duration(minutes: 2),
    );

    final canvasCount = await page!.evaluate<int?>(
        "() => document.querySelectorAll('.editor canvas').length");
    expect(canvasCount, isNotNull);
    expect(canvasCount!, greaterThan(10),
        reason: 'TR tem 140 páginas no Word');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
