import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:canvas_text_editor/ce_docx.dart';
import 'package:canvas_text_editor/src/document/zip/codecs/zlib/inflate.dart';
import 'package:path/path.dart' as p;
import 'package:puppeteer/puppeteer.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';
import 'package:test/test.dart';

const String _zeroWidthSpace = '\u200B';

const String _fixtureMain = r'''
import 'dart:convert';
import 'dart:html';
import 'dart:js_util' as js_util;

import 'package:canvas_text_editor/canvas_text_editor.dart';

void main() {
  String? loadedName;
  Object? lastError;
  final List<Map<String, Object?>> rangeStyleEvents = <Map<String, Object?>>[];
  final host = document.querySelector('#host') as DivElement;
  final widget = CanvasEditorWidget(
    host,
    config: CanvasEditorConfig(
      appearance: CanvasEditorAppearance.word,
      height: '520px',
      documentTitle: 'Teste Word completo',
      onDocumentLoaded: (name) => loadedName = name,
      onError: (error) => lastError = error,
      data: IEditorData(
        main: splitText('Teste negrito')
            .map((value) => IElement(value: value))
            .toList(growable: false),
      ),
    ),
  );
  widget.editor.eventBus.on('rangeStyleChange', (dynamic payload) {
    if (payload is! IRangeStyle) return;
    rangeStyleEvents.add(<String, Object?>{
      'type': payload.type?.name,
      'size': payload.size,
      'bold': payload.bold,
      'italic': payload.italic,
      'level': payload.level?.name,
    });
  });

  js_util.setProperty(window, '__embedTest', js_util.jsify({
    'reset': js_util.allowInterop(() {
      widget.command.executeSetValue(
        IEditorData(
          main: splitText('Teste negrito')
              .map((value) => IElement(value: value))
              .toList(growable: false),
        ),
      );
      widget.command.executeSetRange(0, 7);
    }),
    'resetMultipleParagraphs': js_util.allowInterop(() {
      widget.command.executeSetValue(
        IEditorData(main: <IElement>[
          IElement(value: 'Primeiro parágrafo para formatar.'),
          IElement(value: '\nSegundo parágrafo para formatar.'),
          IElement(value: '\nTerceiro parágrafo fora da seleção.'),
        ]),
      );
      final elements = widget.editor.getDraw().getElementList();
      final secondBreak = elements.lastIndexWhere(
        (element) => element.value == '\u200B',
      );
      widget.command.executeSetRange(0, secondBreak - 1);
    }),
    'cachedRowsJson': js_util.allowInterop(() => jsonEncode([
      for (final row in widget.editor.getDraw().getRowList())
        for (final element in row.elementList)
          if (element.value != '\u200B' && element.value.trim().isNotEmpty)
            {'value': element.value, 'bold': element.bold},
    ])),
    'mainJson': js_util.allowInterop(() => jsonEncode([
      for (final element in widget.value.data.main)
        {
          'value': element.value,
          'bold': element.bold,
          'italic': element.italic,
          'color': element.color,
          'highlight': element.highlight,
          'font': element.font,
          'size': element.size,
          'level': element.level?.name,
          'lineSpacingRule': element.lineSpacingRule,
          'lineSpacingValue': element.lineSpacingValue,
          'paraSpacingBefore': element.paraSpacingBefore,
          'paraSpacingAfter': element.paraSpacingAfter,
        },
    ])),
    'flatJson': js_util.allowInterop(() => jsonEncode([
      for (final element in widget.editor.getDraw().getElementList())
        {
          'value': element.value,
          'font': element.font,
          'color': element.color,
          'size': element.size,
          'bold': element.bold,
          'italic': element.italic,
          'level': element.level?.name,
        },
    ])),
    'loadedName': js_util.allowInterop(() => loadedName),
    'lastError': js_util.allowInterop(() => lastError?.toString()),
    'setViewer': js_util.allowInterop(() {
      widget.setMode(CanvasEditorWidgetMode.viewer);
    }),
    'zoneName': js_util.allowInterop(
      () => widget.editor.getDraw().getZone().getZone().name,
    ),
    'refreshFloatingToolbar': js_util.allowInterop(() {
      widget.refreshFloatingToolbar();
    }),
    'setCollapsedCaret': js_util.allowInterop(() {
      widget.command.executeSetRange(5, 5);
      widget.refreshFloatingToolbar();
    }),
    'selectTitleWord': js_util.allowInterop(() {
      widget.command.executeSetValue(IEditorData(main: <IElement>[
        IElement(
          value: '',
          type: ElementType.title,
          level: TitleLevel.first,
          valueList: <IElement>[IElement(value: 'Título estável')],
        ),
        IElement(value: '\nTexto normal'),
      ]));
      final elements = widget.editor.getDraw().getElementList();
      final int start = elements.indexWhere(
        (element) => element.level == TitleLevel.first,
      );
      widget.command.executeSetRange(start - 1, start + 3);
    }),
    'selectSizedTitle': js_util.allowInterop(() {
      widget.command.executeSetValue(IEditorData(main: <IElement>[
        IElement(
          value: '',
          type: ElementType.title,
          level: TitleLevel.first,
          valueList: <IElement>[
            IElement(
              value: 'Título 24',
              size: 24,
              bold: false,
              italic: false,
            ),
          ],
        ),
        IElement(value: '\nTexto normal'),
      ]));
      final elements = widget.editor.getDraw().getElementList();
      final int start = elements.indexWhere(
        (element) => element.level == TitleLevel.first,
      );
      final int end = elements.lastIndexWhere(
        (element) => element.level == TitleLevel.first,
      );
      widget.command.executeSetRange(start - 1, end);
      widget.refreshFloatingToolbar();
    }),
    'clearRangeStyleEvents': js_util.allowInterop(rangeStyleEvents.clear),
    'rangeStyleEventsJson':
        js_util.allowInterop(() => jsonEncode(rangeStyleEvents)),
    'resetLayoutDiagnostics': js_util.allowInterop(
      () => widget.editor.getDraw().resetLayoutDiagnostics(),
    ),
    'layoutDiagnosticsJson': js_util.allowInterop(
      () => jsonEncode(widget.editor.getDraw().getLayoutDiagnostics()),
    ),
    'togglePageBreakMarkers': js_util.allowInterop(() {
      widget.togglePageBreakMarkers();
      return widget.editor.getDraw().getOptions().pageBreak?.showMarker;
    }),
    'saveNewDocxBase64': js_util.allowInterop(() {
      try {
        return base64Encode(widget.saveDocx());
      } catch (error) {
        return 'ERRO: $error';
      }
    }),
    'insertTable': js_util.allowInterop(() {
      widget.command.executeSetValue(IEditorData(
        main: splitText('Antes da tabela')
            .map((value) => IElement(value: value))
            .toList(growable: false),
      ));
      widget.command.executeSetRange(5, 5);
      widget.command.executeInsertTable(3, 3);
    }),
    'setParagraphSpacing': js_util.allowInterop(() {
      widget.command.executeSetRange(0, 7);
      widget.command.executeParagraphSpacing(
        'auto',
        1.5,
        before: 4,
        after: 8,
      );
    }),
    'applyTitleOne': js_util.allowInterop(() {
      widget.command.executeSetRange(0, 7);
      widget.command.executeTitle(TitleLevel.first);
    }),
    'focusFirstTableCell': js_util.allowInterop(() {
      final table = widget.editor.getDraw().getOriginalElementList().firstWhere(
        (element) => element.type == ElementType.table,
      );
      if (table.id == null) return false;
      final range = IRange(
        startIndex: 0,
        endIndex: 0,
        tableId: table.id,
        startTdIndex: 0,
        endTdIndex: 0,
        startTrIndex: 0,
        endTrIndex: 0,
      );
      widget.command.executeSetPositionContext(range);
      widget.command.executeSetRange(0, 0, table.id, 0, 0, 0, 0);
      widget.editor.getDraw().getTableTool()?.render();
      widget.refreshFloatingToolbar();
      return true;
    }),
    'exportPdfBase64': js_util.allowInterop(() {
      try {
        return base64Encode(widget.exportPdfBytes());
      } catch (error) {
        return 'ERRO: $error';
      }
    }),
  }));
  js_util.setProperty(window, '__embedReady', true);
}
''';

const String _fixtureHtml = '''<!doctype html>
<html><head><meta charset="utf-8">
<link rel="stylesheet" href="packages/canvas_text_editor/assets/icons/tabler/tabler-icons.css">
<link rel="stylesheet" href="packages/canvas_text_editor/assets/canvas_editor.css">
<script defer src="main.dart.js"></script></head>
<body><div id="host"></div></body></html>''';

void main() {
  Directory? fixtureDir;
  Browser? browser;
  Page? page;
  SendPort? serverControl;
  String? baseUrl;

  setUpAll(() async {
    final chrome = await downloadChrome(cachePath: '.local-chrome');
    fixtureDir = Directory(p.join('.dart_tool', 'embed_widget_ui_test'))
      ..createSync(recursive: true);
    File(p.join(fixtureDir!.path, 'index.html'))
        .writeAsStringSync(_fixtureHtml);
    final File mainFile = File(p.join(fixtureDir!.path, 'main.dart'))
      ..writeAsStringSync(_fixtureMain);
    await _copyDirectory(
      Directory(p.join('lib', 'assets')),
      Directory(p.join(
        fixtureDir!.path,
        'packages',
        'canvas_text_editor',
        'assets',
      )),
    );
    final ProcessResult compile = await Process.run('dart', <String>[
      'compile',
      'js',
      '-O1',
      '-o',
      p.join(fixtureDir!.path, 'main.dart.js'),
      mainFile.path,
    ]);
    expect(compile.exitCode, 0, reason: '${compile.stdout}\n${compile.stderr}');

    final ReceivePort receivePort = ReceivePort();
    await Isolate.spawn<_ServeArgs>(
      _serve,
      _ServeArgs(fixtureDir!.path, receivePort.sendPort),
    );
    final Map<dynamic, dynamic> init =
        await receivePort.first as Map<dynamic, dynamic>;
    serverControl = init['control'] as SendPort;
    baseUrl = 'http://127.0.0.1:${init['port']}';
    browser = await puppeteer.launch(
      executablePath: chrome.executablePath,
      headless: true,
      args: const <String>['--no-sandbox', '--disable-setuid-sandbox'],
    );
  });

  tearDownAll(() async {
    await browser?.close();
    serverControl?.send('close');
    if (fixtureDir?.existsSync() == true) {
      fixtureDir!.deleteSync(recursive: true);
    }
  });

  setUp(() async {
    page = await browser!.newPage();
    await page!.goto(baseUrl!, wait: Until.networkIdle);
    await page!.waitForSelector('.ce-word-titlebar');
    expect(
      await page!.evaluate<bool>('() => window.__embedReady === true'),
      isTrue,
    );
  });

  tearDown(() async => page?.close());

  test('renderiza a aparência Word completa com ribbon dinâmica', () async {
    // Seis abas fixas + Tabela/Imagem contextuais (ocultas até a seleção).
    expect(await page!.$$('.ce-word-tabs [data-ce-tab]'), hasLength(8));
    expect(await page!.$$('[data-ce-tab="review"]'), hasLength(1));
    await page!.click('[data-ce-tab="review"]');
    expect(await page!.$$('[data-ce-command="comments"]'), hasLength(1));
    await page!.click('[data-ce-tab="file"]');
    expect(await page!.$$('[data-ce-command="export-pdf"]'), hasLength(1));
    expect(await page!.$$('.ce-word-panel.active .ce-word-group'), isNotEmpty);
    expect(await page!.$$('.ce-embed__scroll'), hasLength(1));
  });

  test('ribbon usa duas linhas e galeria de estilos sem scrollbar', () async {
    await page!.click('[data-ce-tab="home"]');
    final Map<dynamic, dynamic> metrics =
        await page!.evaluate<Map<dynamic, dynamic>>('''() => {
      const panel = document.querySelector('[data-ce-panel="home"]');
      const fontRows = panel.querySelectorAll(
        '.ce-word-group--two-row .ce-word-command-row');
      return {
        rows: fontRows.length,
        scrollWidth: panel.scrollWidth,
        clientWidth: panel.clientWidth,
        visibleStyles: panel.querySelectorAll('.ce-word-style-gallery .ce-word-style').length,
        more: panel.querySelectorAll('[data-ce-command="styles-more"]').length,
      };
    }''');
    expect(metrics['rows'], 4); // duas em Fonte + duas em Parágrafo
    expect(metrics['scrollWidth'], lessThanOrEqualTo(metrics['clientWidth']));
    expect(metrics['visibleStyles'], 3);
    expect(metrics['more'], 1);

    await page!.click('[data-ce-command="styles-more"]');
    expect(await page!.$$('.ce-word-menu__item'), hasLength(4));
  });

  test('réguas e modos de visualização seguem a aba Exibir', () async {
    expect(await page!.$$('.ce-ruler-horizontal .ce-ruler__tick'), isNotEmpty);
    expect(await page!.$$('.ce-ruler-vertical .ce-ruler__tick'), isNotEmpty);
    final Map<dynamic, dynamic> ruler =
        await page!.evaluate<Map<dynamic, dynamic>>('''() => {
      const horizontal = document.querySelector('.ce-ruler-horizontal');
      const vertical = document.querySelector('.ce-ruler-vertical');
      const canvas = document.querySelector('.ce-page-container canvas');
      const scroll = document.querySelector('.ce-embed__scroll');
      const major = horizontal.querySelectorAll('.ce-ruler__tick.major');
      return {
        rulerWidth: horizontal.getBoundingClientRect().width,
        pageWidth: canvas.getBoundingClientRect().width,
        verticalHeight: vertical.getBoundingClientRect().height,
        viewportHeight: scroll.clientHeight,
        horizontalTicks: horizontal.querySelectorAll('.ce-ruler__tick').length,
        majorGap: major[1].getBoundingClientRect().left -
          major[0].getBoundingClientRect().left,
        margins: horizontal.querySelectorAll('.ce-ruler__margin').length,
        indents: horizontal.querySelectorAll('.ce-ruler__indent').length,
        corner: document.querySelectorAll('.ce-ruler-corner').length,
      };
    }''');
    expect(ruler['rulerWidth'], closeTo(ruler['pageWidth'] as num, 1));
    expect(ruler['verticalHeight'], lessThanOrEqualTo(ruler['viewportHeight']));
    expect(ruler['horizontalTicks'], inInclusiveRange(60, 100));
    expect(ruler['majorGap'], closeTo(96 / 2.54, 1));
    expect(ruler['margins'], 2);
    // Primeira linha, deslocado, caixa esquerda e recuo direito.
    expect(ruler['indents'], 4);
    expect(ruler['corner'], 1);
    await page!.click('[data-ce-tab="view"]');
    await page!.click('[data-ce-command="view-draft"]');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(
        await page!
            .$eval('.ce-embed', '(e) => e.classList.contains("ce-view-draft")'),
        isTrue);
    expect(
        await page!.$eval('.ce-rulers', '(e) => getComputedStyle(e).display'),
        'none');
    await page!.click('[data-ce-command="page-paging"]');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(
        await page!
            .$eval('.ce-embed', '(e) => e.classList.contains("ce-view-draft")'),
        isFalse);
  });

  test('configura espaçamento de linhas e parágrafos', () async {
    await page!.evaluate<void>('() => window.__embedTest.reset()');
    await page!.click('[data-ce-command="line-spacing"]');
    expect(await page!.$$('.ce-word-menu__item'), hasLength(7));
    await page!
        .evaluate<void>('() => window.__embedTest.setParagraphSpacing()');
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final List<dynamic> elements = jsonDecode(
            await page!.evaluate<String>('() => window.__embedTest.mainJson()'))
        as List<dynamic>;
    final List<dynamic> changed = elements
        .where((dynamic item) =>
            (item as Map<String, dynamic>)['lineSpacingRule'] == 'auto')
        .toList();
    expect(changed, isNotEmpty);
    expect(
        changed.every((dynamic item) =>
            (item as Map<String, dynamic>)['lineSpacingValue'] == 1.5),
        isTrue);
    expect(
        changed.every((dynamic item) =>
            (item as Map<String, dynamic>)['paraSpacingBefore'] == 4),
        isTrue);
    expect(
        changed.every((dynamic item) =>
            (item as Map<String, dynamic>)['paraSpacingAfter'] == 8),
        isTrue);
  });

  test('abre um DOCX pelo seletor de arquivo da UI', () async {
    await page!.click('[data-ce-tab="file"]');
    final Future<FileChooser> chooserFuture = page!.waitForFileChooser();
    await page!.click('[data-ce-command="open"]');
    final FileChooser chooser = await chooserFuture;
    final File docx = File(p.join(
      'resources',
      'PGCTIC1_-_ETP_-_Sistema_de_Gestão_Pública.docx',
    ));
    await chooser.accept(<File>[docx.absolute]);
    await _waitUntil(page!, '() => window.__embedTest.loadedName() !== null',
        timeout: const Duration(seconds: 30));
    expect(
      await page!.evaluate<String?>('() => window.__embedTest.loadedName()'),
      endsWith('.docx'),
    );
    expect(
      await page!.evaluate<String?>('() => window.__embedTest.lastError()'),
      isNull,
    );
  });

  test('negrito conserva redo depois de undo', () async {
    await page!.evaluate<void>('() => window.__embedTest.reset()');
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await page!.click('[data-ce-command="bold"]');
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(await _hasBold(page!), isTrue);
    final String boldCanvas = await _canvasData(page!);

    await page!.click('[data-ce-command="undo"]');
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(await _hasBold(page!), isFalse);
    final String undoCanvas = await _canvasData(page!);
    expect(undoCanvas, isNot(boldCanvas));

    await page!.click('[data-ce-command="redo"]');
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(await _hasBold(page!), isTrue);
    expect(await _canvasData(page!), boldCanvas);
  });

  test(
      'ribbon e mini-toolbar preservam tamanho e estilo sem estado transitório',
      () async {
    await page!.evaluate<void>('() => window.__embedTest.selectSizedTitle()');
    await Future<void>.delayed(const Duration(milliseconds: 180));

    expect(
      await page!.$eval<String>(
        '.ce-embed',
        '(element) => element.getAttribute("editor-component")',
      ),
      'component',
    );

    Future<void> expectSelectionStyle({
      required bool bold,
      required bool italic,
    }) async {
      final List<dynamic> flat = jsonDecode(
        await page!.evaluate<String>('() => window.__embedTest.flatJson()'),
      ) as List<dynamic>;
      final List<Map<String, dynamic>> titleElements = flat
          .cast<Map<String, dynamic>>()
          .where((Map<String, dynamic> element) =>
              element['level'] == 'first' &&
              element['value'] != _zeroWidthSpace)
          .toList(growable: false);
      expect(titleElements, isNotEmpty);
      expect(titleElements.every((element) => element['size'] == 24), isTrue);
      expect(
        titleElements.every((element) => (element['bold'] == true) == bold),
        isTrue,
      );
      expect(
        titleElements.every((element) => (element['italic'] == true) == italic),
        isTrue,
      );

      final Map<dynamic, dynamic> toolbar =
          await page!.evaluate<Map<dynamic, dynamic>>('''() => ({
        size: document.querySelector(
          '[data-ce-panel="home"] select[title="Tamanho"]').value,
        ribbonBold: document.querySelector(
          '[data-ce-panel="home"] [data-ce-command="bold"]')
          .classList.contains('active'),
        ribbonItalic: document.querySelector(
          '[data-ce-panel="home"] [data-ce-command="italic"]')
          .classList.contains('active'),
        miniBold: document.querySelector(
          '.ce-floating-toolbar [aria-label="Negrito"]')
          .classList.contains('active'),
        titleOne: document.querySelector(
          '.ce-word-style[data-style-level="first"]')
          .classList.contains('active')
      })''');
      expect(toolbar['size'], '24');
      expect(toolbar['ribbonBold'], bold);
      expect(toolbar['ribbonItalic'], italic);
      expect(toolbar['miniBold'], bold);
      expect(toolbar['titleOne'], isTrue);
    }

    Future<void> expectNoRecoveryPayload() async {
      final List<dynamic> events = jsonDecode(
        await page!.evaluate<String>(
          '() => window.__embedTest.rangeStyleEventsJson()',
        ),
      ) as List<dynamic>;
      expect(events, isNotEmpty);
      expect(
        events.any(
            (dynamic event) => (event as Map<String, dynamic>)['type'] == null),
        isFalse,
        reason: jsonEncode(events),
      );
      expect(
        events.every(
            (dynamic event) => (event as Map<String, dynamic>)['size'] == 24),
        isTrue,
        reason: jsonEncode(events),
      );
    }

    await expectSelectionStyle(bold: false, italic: false);

    await page!
        .evaluate<void>('() => window.__embedTest.clearRangeStyleEvents()');
    await page!
        .evaluate<void>('() => window.__embedTest.resetLayoutDiagnostics()');
    await page!.click(
      '[data-ce-panel="home"] [data-ce-command="italic"]',
    );
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await expectSelectionStyle(bold: false, italic: true);
    await expectNoRecoveryPayload();
    final Map<String, dynamic> titleLayout = jsonDecode(
      await page!.evaluate<String>(
        '() => window.__embedTest.layoutDiagnosticsJson()',
      ),
    ) as Map<String, dynamic>;
    expect(titleLayout['fastTextLayouts'], 1);
    expect(titleLayout['fullLayouts'], 0);

    await page!
        .evaluate<void>('() => window.__embedTest.clearRangeStyleEvents()');
    await page!.click('.ce-floating-toolbar [aria-label="Negrito"]');
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await expectSelectionStyle(bold: true, italic: true);
    await expectNoRecoveryPayload();

    await page!
        .evaluate<void>('() => window.__embedTest.clearRangeStyleEvents()');
    await page!.click('.ce-floating-toolbar [aria-label="Negrito"]');
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await expectSelectionStyle(bold: false, italic: true);
    await expectNoRecoveryPayload();
  });

  test('mini-toolbar aparece na seleção e aplica formatação rápida', () async {
    await page!.evaluate<void>('() => window.__embedTest.reset()');
    await Future<void>.delayed(const Duration(milliseconds: 180));
    await page!
        .evaluate<void>('() => window.__embedTest.refreshFloatingToolbar()');
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(
      await page!.evaluate<String>(
        "() => getComputedStyle(document.querySelector('.ce-floating-toolbar')).display",
      ),
      'flex',
    );
    await page!.click('.ce-floating-toolbar [aria-label="Negrito"]');
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(await _hasBold(page!), isTrue);
  });

  test('formata imediatamente uma seleção que atravessa parágrafos', () async {
    await page!
        .evaluate<void>('() => window.__embedTest.resetMultipleParagraphs()');
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await page!
        .evaluate<void>('() => window.__embedTest.resetLayoutDiagnostics()');
    await page!.click('[data-ce-command="bold"]');
    await Future<void>.delayed(const Duration(milliseconds: 150));

    final List<dynamic> cachedRows = jsonDecode(await page!.evaluate<String>(
      '() => window.__embedTest.cachedRowsJson()',
    )) as List<dynamic>;
    final int thirdParagraph = cachedRows.indexWhere(
      (dynamic item) => (item as Map<String, dynamic>)['value'] == 'T',
    );
    expect(thirdParagraph, greaterThan(0));
    final List<dynamic> selectedRows = cachedRows.take(thirdParagraph).toList();
    expect(selectedRows, isNotEmpty);
    expect(
      selectedRows.every(
        (dynamic item) => (item as Map<String, dynamic>)['bold'] == true,
      ),
      isTrue,
      reason: jsonEncode(cachedRows),
    );
    final Map<String, dynamic> layout = jsonDecode(
      await page!.evaluate<String>(
        '() => window.__embedTest.layoutDiagnosticsJson()',
      ),
    ) as Map<String, dynamic>;
    expect(layout['fastTextLayouts'], 1);
    expect(layout['fullLayouts'], 0);
  });

  test('clique com caret colapsado não quebra a atualização contextual',
      () async {
    await page!.evaluate<void>('() => window.__embedTest.reset()');
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await page!.evaluate<void>('() => window.__embedTest.setCollapsedCaret()');
    expect(await page!.$$('.ce-floating-toolbar[style*="display: flex"]'),
        isEmpty);
  });

  test('estilo de título permanece estável ao selecionar uma palavra',
      () async {
    await page!.evaluate<void>('() => window.__embedTest.selectTitleWord()');
    for (int i = 0; i < 4; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final List<dynamic> active = await page!.evaluate<List<dynamic>>('''() =>
        Array.from(document.querySelectorAll('.ce-word-style.active'))
          .map((element) => element.textContent.trim())''');
      expect(active, <String>['Título 1']);
    }
  });

  test('botão de título é preview da formatação aplicada', () async {
    final Map<dynamic, dynamic> preview =
        await page!.evaluate<Map<dynamic, dynamic>>('''() => {
      const button = document.querySelector(
        '.ce-word-style[data-style-level="first"]');
      const style = getComputedStyle(button);
      return {font: style.fontFamily, color: style.color, size: style.fontSize};
    }''');
    expect(preview['font'].toString(), contains('Calibri Light'));
    expect(preview['color'], 'rgb(47, 84, 150)');
    expect(preview['size'], '16px');

    await page!.evaluate<void>('() => window.__embedTest.reset()');
    await page!.evaluate<void>('() => window.__embedTest.applyTitleOne()');
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final List<dynamic> elements = jsonDecode(
            await page!.evaluate<String>('() => window.__embedTest.flatJson()'))
        as List<dynamic>;
    final List<dynamic> titled = elements
        .where((dynamic item) =>
            (item as Map<String, dynamic>)['level'] == 'first')
        .toList();
    expect(titled, isNotEmpty);
    expect(
        titled.every((dynamic item) =>
            (item as Map<String, dynamic>)['font'] == 'Calibri Light'),
        isTrue);
    expect(
        titled.every((dynamic item) =>
            (item as Map<String, dynamic>)['color'] == '#2F5496'),
        isTrue);
  });

  test('permite ocultar e reexibir as marcas de quebra de página', () async {
    expect(
      await page!
          .evaluate<bool>('() => window.__embedTest.togglePageBreakMarkers()'),
      isFalse,
    );
    expect(
      await page!
          .evaluate<bool>('() => window.__embedTest.togglePageBreakMarkers()'),
      isTrue,
    );
  });

  test('exporta DOCX mesmo sem um arquivo previamente aberto', () async {
    await page!.evaluate<void>('() => window.__embedTest.selectTitleWord()');
    final String encoded = await page!
        .evaluate<String>('() => window.__embedTest.saveNewDocxBase64()');
    expect(encoded, isNot(startsWith('ERRO')), reason: encoded);
    final Uint8List bytes = base64Decode(encoded);
    expect(bytes.take(2), <int>[0x50, 0x4b]);
    final DocxFile reopened = DocxReader.read(bytes);
    expect(reopened.document.body, isNotEmpty);
    expect(
      reopened.document.body
          .whereType<WpParagraph>()
          .map((WpParagraph paragraph) => paragraph.text)
          .join('\n'),
      contains('Título estável'),
    );
    expect(
      reopened.package.partString('word/document.xml'),
      contains('<w:pStyle w:val="Heading1"/>'),
    );
  });

  test('aba Layout mantém rótulos compactos e comandos alinhados', () async {
    await page!.click('[data-ce-tab="layout"]');
    final Map<dynamic, dynamic> metrics =
        await page!.evaluate<Map<dynamic, dynamic>>('''() => {
      const labels = Array.from(document.querySelectorAll(
        '.ce-word-panel.active .ce-word-command__label'));
      const buttons = Array.from(document.querySelectorAll(
        '.ce-word-panel.active .ce-word-command--labeled'));
      return {
        labels: labels.length,
        maxFont: Math.max(...labels.map(e => parseFloat(getComputedStyle(e).fontSize))),
        maxHeight: Math.max(...buttons.map(e => e.getBoundingClientRect().height)),
        panelHeight: document.querySelector('.ce-word-panel.active')
          .getBoundingClientRect().height,
      };
    }''');
    expect(metrics['labels'], 4);
    expect(metrics['maxFont']!, lessThanOrEqualTo(11));
    expect(metrics['maxHeight']!, lessThanOrEqualTo(60));
    expect(metrics['panelHeight']!, lessThanOrEqualTo(90));
  });

  test('focar tabela não aumenta o stage e mostra a toolbar contextual',
      () async {
    await page!.evaluate<void>('() => window.__embedTest.insertTable()');
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final num before = await page!.$eval(
      '.ce-embed__scroll',
      '(element) => element.scrollHeight',
    );
    expect(
      await page!
          .evaluate<bool>('() => window.__embedTest.focusFirstTableCell()'),
      isTrue,
    );
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final num after = await page!.$eval(
      '.ce-embed__scroll',
      '(element) => element.scrollHeight',
    );
    expect(after, before);
    expect(
      await page!.evaluate<String>('''() => getComputedStyle(
        document.querySelector('.ce-floating-toolbar [data-group="tabela"]'))
        .display'''),
      'contents',
    );
    expect(
      await page!.$$('.ce-floating-toolbar [aria-label="Inserir linha acima"]'),
      hasLength(1),
    );
  });

  test('paletas aplicam cor da fonte e fundo do texto', () async {
    await page!.evaluate<void>('() => window.__embedTest.reset()');
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await page!.click('[data-ce-command="text-color"]');
    await page!.click('.ce-color-palette__swatch[data-color="#ff0000"]');
    await Future<void>.delayed(const Duration(milliseconds: 120));
    List<dynamic> elements = jsonDecode(
            await page!.evaluate<String>('() => window.__embedTest.mainJson()'))
        as List<dynamic>;
    final List<dynamic> colored = elements
        .where(
            (dynamic item) => (item as Map<String, dynamic>)['color'] != null)
        .toList();
    expect(colored, isNotEmpty);
    expect(
        colored.every((dynamic item) =>
            (item as Map<String, dynamic>)['color'] == '#ff0000'),
        isTrue);

    await page!.click('[data-ce-command="text-highlight"]');
    await page!.click('.ce-color-palette__swatch[data-color="#ffff00"]');
    await Future<void>.delayed(const Duration(milliseconds: 120));
    elements = jsonDecode(
            await page!.evaluate<String>('() => window.__embedTest.mainJson()'))
        as List<dynamic>;
    final List<dynamic> highlighted = elements
        .where((dynamic item) =>
            (item as Map<String, dynamic>)['highlight'] != null)
        .toList();
    expect(highlighted, isNotEmpty);
    expect(
        highlighted.every((dynamic item) =>
            (item as Map<String, dynamic>)['highlight'] == '#ffff00'),
        isTrue);
  });

  test('exporta PDF vetorial com texto selecionável', () async {
    await page!.evaluate<void>('() => window.__embedTest.reset()');
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final String base64 = await page!
        .evaluate<String>('() => window.__embedTest.exportPdfBase64()');
    expect(base64, isNot(startsWith('ERRO')), reason: base64);
    final List<int> bytes = base64Decode(base64);
    final String text = latin1.decode(bytes, allowInvalid: true);
    expect(text, startsWith('%PDF-1.4'));
    expect(text, contains('/BaseFont /Helvetica'));
    expect(text, contains('/Encoding /WinAnsiEncoding'));
    expect(text, contains('/Filter /FlateDecode'));
    expect(text, contains('%%EOF'));
    // Inflar os content streams e reconstruir o texto dos operadores Tj:
    // deve conter o conteúdo do documento (selecionável/pesquisável).
    final String ops = _inflateAllStreams(bytes);
    final String shown = RegExp(r'\(([^)]*)\) Tj')
        .allMatches(ops)
        .map((Match m) => m.group(1))
        .join();
    expect(shown, contains('Teste negrito'));
  });

  test('modo viewer oculta ribbon e entrada de edição', () async {
    await page!.evaluate<void>('() => window.__embedTest.setViewer()');
    expect(
        await page!
            .$eval('.ce-word-ribbon', '(e) => getComputedStyle(e).display'),
        'none');
    expect(
        await page!
            .$eval('.ce-inputarea', '(e) => getComputedStyle(e).display'),
        'none');
    expect(
        await page!
            .$eval('.ce-viewer-toolbar', '(e) => getComputedStyle(e).display'),
        'flex');
    expect(
        await page!
            .$eval('.ce-statusbar', '(e) => getComputedStyle(e).display'),
        'none');
    expect(await page!.$$('.ce-viewer-toolbar button'), hasLength(6));
    expect(
        await page!.$eval(
            '.ce-floating-toolbar', '(e) => getComputedStyle(e).display'),
        'none');
    await page!.evaluate<void>('''() => {
      const canvas = document.querySelector('.ce-page-container canvas');
      const rect = canvas.getBoundingClientRect();
      canvas.dispatchEvent(new MouseEvent('dblclick', {
        bubbles: true,
        clientX: rect.left + rect.width / 2,
        clientY: rect.top + 8,
      }));
    }''');
    expect(
      await page!.evaluate<String>('() => window.__embedTest.zoneName()'),
      'main',
    );
  });
}

/// Localiza streams FlateDecode no PDF e concatena o conteúdo inflado.
String _inflateAllStreams(List<int> pdf) {
  final String text = latin1.decode(pdf, allowInvalid: true);
  final StringBuffer out = StringBuffer();
  for (final Match match in 'stream\n'.allMatches(text)) {
    final int end = text.indexOf('\nendstream', match.end);
    if (end < 0) continue;
    final List<int> zlib = latin1.encode(text.substring(match.end, end));
    if (zlib.length < 6 || zlib[0] != 0x78) continue;
    try {
      out.write(
          latin1.decode(Inflate(zlib.sublist(2, zlib.length - 4)).getBytes()));
    } catch (_) {
      // stream de imagem ou não-zlib: ignora
    }
  }
  return out.toString();
}

Future<bool> _hasBold(Page page) async {
  final String json =
      await page.evaluate<String>('() => window.__embedTest.mainJson()');
  final List<dynamic> elements = jsonDecode(json) as List<dynamic>;
  return elements
      .any((dynamic item) => (item as Map<String, dynamic>)['bold'] == true);
}

Future<String> _canvasData(Page page) async =>
    await page.$eval<String>(
      '.ce-page-container canvas',
      '(canvas) => canvas.toDataURL()',
    ) ??
    '';

Future<void> _waitUntil(
  Page page,
  String expression, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final Stopwatch stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < timeout) {
    if (await page.evaluate<bool>(expression)) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  fail('Timeout aguardando: $expression');
}

class _ServeArgs {
  const _ServeArgs(this.directory, this.sendPort);
  final String directory;
  final SendPort sendPort;
}

Future<void> _serve(_ServeArgs args) async {
  final handler =
      createStaticHandler(args.directory, defaultDocument: 'index.html');
  final HttpServer server = await shelf_io.serve(handler, '127.0.0.1', 0);
  final ReceivePort control = ReceivePort();
  args.sendPort.send(<String, Object>{
    'port': server.port,
    'control': control.sendPort,
  });
  await for (final Object? message in control) {
    if (message == 'close') {
      await server.close(force: true);
      control.close();
      break;
    }
  }
}

Future<void> _copyDirectory(Directory source, Directory target) async {
  target.createSync(recursive: true);
  await for (final FileSystemEntity entity in source.list(recursive: false)) {
    final String destination = p.join(target.path, p.basename(entity.path));
    if (entity is Directory) {
      await _copyDirectory(entity, Directory(destination));
    } else if (entity is File) {
      File(destination)
        ..createSync(recursive: true)
        ..writeAsBytesSync(entity.readAsBytesSync());
    }
  }
}
