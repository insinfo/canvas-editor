// Captura screenshots das páginas renderizadas pelo editor, para comparar
// com os goldens do Word em resources/*/ (fidelidade visual).
//
// Uso: dart run tool/screenshot_pages.dart <etp|tr> [páginas separadas por vírgula]
//   ex.: dart run tool/screenshot_pages.dart tr 1,2,4,7,8
//
// Salva em .dart_tool/shots/<doc>-page-NN.png. Reusa o harness do bench
// (dart2js -O2 + shelf_static + puppeteer).

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:puppeteer/puppeteer.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';

const _mainSource = r'''
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';

import 'package:canvas_text_editor/src/editor.dart';

Future<int> _open(EditorApp app, String url) async {
  final req = await html.HttpRequest.request(url, responseType: 'arraybuffer');
  final bytes = (req.response as ByteBuffer).asUint8List();
  await app.openDocxBytes(url, bytes);
  return app.editor.getDraw().getPageList().length;
}

void main() {
  html.window.onLoad.listen((_) async {
    final app = EditorApp(isApple: false);
    await app.initialize();
    js_util.setProperty(html.window, '__shot', js_util.jsify({
      'open': js_util.allowInterop((String url, Object cb) {
        _open(app, url).then((n) =>
            js_util.callMethod(cb, 'call', <Object?>[null, n]));
      }),
      'pageCount': js_util.allowInterop(
          () => app.editor.getDraw().getPageList().length),
      'pageYRange': js_util.allowInterop((num pageIndex) {
        final d = app.editor.getDraw();
        final pageRows = d.getPageRowList();
        final i = pageIndex.toInt();
        if (i < 0 || i >= pageRows.length) return 'fora do range';
        final rows = pageRows[i] as List;
        final posList = d.getPosition().getOriginalMainPositionList() as List;
        double? minY, maxY;
        int? firstIdx, lastIdx;
        for (final row in rows) {
          final start = (row as dynamic).startIndex as int;
          final n = (row.elementList as List).length;
          for (var k = start; k < start + n && k < posList.length; k++) {
            final lt = (posList[k] as dynamic).coordinate['leftTop'] as List?;
            if (lt == null || lt.length < 2) continue;
            final yv = (lt[1] as num).toDouble();
            if (minY == null || yv < minY) { minY = yv; firstIdx = k; }
            if (maxY == null || yv > maxY) { maxY = yv; lastIdx = k; }
          }
        }
        return 'page $i: rows=${rows.length} yMin=${minY?.toStringAsFixed(1)} '
            'yMax=${maxY?.toStringAsFixed(1)} firstIdx=$firstIdx lastIdx=$lastIdx';
      }),
      'itemHeader': js_util.allowInterop(() {
        final d = app.editor.getDraw();
        final els = d.getOriginalMainElementList() as List;
        final buf = StringBuffer();
        var found = 0;
        for (final el in els) {
          final trList = (el as dynamic).trList as List?;
          if (trList == null) continue;
          for (final tr in trList) {
            final tds = (tr as dynamic).tdList as List;
            if (tds.length != 1) continue; // cabeçalho mesclado tem 1 célula
            final td = tds.first as dynamic;
            final val = (td.value as List)
                .map((e) => '${(e as dynamic).value}').join();
            if (!val.contains('Item 2') && !val.contains('Item 3')) continue;
            final pl = td.positionList as List?;
            buf.write('[colspan=${td.colspan} w=${(td.width ?? 0).toStringAsFixed(0)} '
                'nEls=${pl?.length ?? 0} xy=[');
            if (pl != null) {
              for (var k = 0; k < pl.length; k++) {
                final pos = pl[k] as dynamic;
                final lt = pos.coordinate['leftTop'] as List?;
                final v = '${pos.value}';
                if (lt != null && lt.length > 1) {
                  buf.write('"$v"@${(lt[0] as num).toStringAsFixed(0)},'
                      '${(lt[1] as num).toStringAsFixed(0)} ');
                }
              }
            }
            buf.write(']] ');
            found++;
            if (found >= 1) return buf.toString();
          }
        }
        return buf.isEmpty ? '(nenhum Item 2/3)' : buf.toString();
      }),
      'rowYList': js_util.allowInterop((num pageIndex) {
        final d = app.editor.getDraw();
        final pageRows = d.getPageRowList();
        final i = pageIndex.toInt();
        if (i < 0 || i >= pageRows.length) return 'fora do range';
        final rows = pageRows[i] as List;
        final posList = d.getPosition().getOriginalMainPositionList() as List;
        final buf = StringBuffer();
        for (final row in rows) {
          final start = (row as dynamic).startIndex as int;
          final h = (row.height as num).toDouble();
          final oy = ((row.offsetY ?? 0) as num).toDouble();
          double? y;
          if (start >= 0 && start < posList.length) {
            final lt = (posList[start] as dynamic).coordinate['leftTop'] as List?;
            if (lt != null && lt.length > 1) y = (lt[1] as num).toDouble();
          }
          buf.write('y=${y?.toStringAsFixed(0) ?? "?"}h=${h.toStringAsFixed(0)}oy=${oy.toStringAsFixed(0)} ');
        }
        return buf.toString();
      }),
      'cellSpacing': js_util.allowInterop(() {
        final d = app.editor.getDraw();
        final els = d.getOriginalMainElementList() as List;
        final buf = StringBuffer();
        for (final el in els) {
          final trList = (el as dynamic).trList as List?;
          if (trList == null || trList.isEmpty) continue;
          // Primeira tabela: dump das alturas de tr e do spacing da 1ª célula.
          buf.write('h/minH=[');
          for (final tr in trList.take(8)) {
            final t = tr as dynamic;
            buf.write('${(t.height as num).toStringAsFixed(0)}/${t.minHeight}·');
          }
          buf.write('] ');
          final firstTd = (trList.first as dynamic).tdList.first;
          final cellEls = (firstTd as dynamic).value as List;
          final tr0 = trList.first as dynamic;
          buf.write('tr0.minH=${tr0.minHeight} cellN=${cellEls.length}');
          return buf.toString();
        }
        return '(sem tabela)';
      }),
      'footerInfo': js_util.allowInterop(() {
        final d = app.editor.getDraw();
        final f = d.getFooter();
        final els = f.getElementList() as List;
        final types = els.take(20).map((e) {
          final ed = e as dynamic;
          String t = 'text';
          try { t = '${ed.type ?? "text"}'; } catch (_) {}
          final v = '${ed.value}';
          return '$t:${v.length > 10 ? v.substring(0, 10) : v}';
        }).join('|');
        return 'footerEls=${els.length} h=${f.getHeight().toStringAsFixed(0)} '
            'rows=${(f.getRowList() as List).length} [$types]';
      }),
      'geom': js_util.allowInterop(() {
        final d = app.editor.getDraw();
        final m = d.getMargins();
        return 'width=${d.getWidth()} height=${d.getHeight()} '
            'dpr=${d.getPagePixelRatio()} '
            'margins=[${m.map((v) => (v as num).toStringAsFixed(1)).join(",")}]';
      }),
      'headerInfo': js_util.allowInterop(() {
        final d = app.editor.getDraw();
        final h = d.getHeader();
        final els = h.getElementList()
            .map((e) => '${e.type?.name ?? "text"}:"${e.value.length > 12 ? e.value.substring(0, 12) : e.value}"'
                'w=${e.width}h=${e.height}')
            .join(' | ');
        final rows = h.getRowList()
            .map((r) => 'h=${r.height.toStringAsFixed(0)}oy=${r.offsetY?.toStringAsFixed(0)}a=${r.ascent?.toStringAsFixed(0)}')
            .join(',');
        final posY = h.getPositionList()
            .map((p) {
              final lt = p.coordinate['leftTop'] as List?;
              final lb = p.coordinate['leftBottom'] as List?;
              final y0 = (lt != null && lt.length > 1) ? (lt[1] as num).toDouble() : null;
              final y1 = (lb != null && lb.length > 1) ? (lb[1] as num).toDouble() : null;
              return '${y0?.toStringAsFixed(0)}..${y1?.toStringAsFixed(0)}';
            })
            .join(',');
        return 'posY=[$posY] headerHeight=${h.getHeight().toStringAsFixed(1)} '
            'extraHeight=${h.getExtraHeight().toStringAsFixed(1)} '
            'headerTop=${h.getHeaderTop().toStringAsFixed(1)} '
            'rows=[$rows] elems=[$els]';
      }),
    }));
    js_util.setProperty(html.window, '__shotReady', true);
  });
}
''';

Future<void> _copyDir(Directory src, Directory dst) async {
  if (!dst.existsSync()) dst.createSync(recursive: true);
  await for (final e in src.list(recursive: false)) {
    final t = p.join(dst.path, p.basename(e.path));
    if (e is Directory) {
      await _copyDir(e, Directory(t));
    } else if (e is File) {
      File(t).writeAsBytesSync(e.readAsBytesSync());
    }
  }
}

Future<void> main(List<String> args) async {
  final which = args.isNotEmpty ? args[0] : 'tr';
  final pages = (args.length > 1 ? args[1] : '1,2,3,4')
      .split(',')
      .map((s) => int.parse(s.trim()))
      .toList();
  final docFile = which == 'etp'
      ? 'PGCTIC1_-_ETP_-_Sistema_de_Gestão_Pública.docx'
      : 'PGCTIC1_-_TR_-_SISTEMA_GESTAO_PUBLICA__Recuperação_Automática_.docx';

  final revision = await downloadChrome(cachePath: '.local-chrome');
  final buildDir = Directory(p.join('.dart_tool', 'canvas_editor_shot'))
    ..createSync(recursive: true);
  await _copyDir(Directory('web'), buildDir);
  final mainPath = p.join(buildDir.path, 'main.dart');
  File(mainPath).writeAsStringSync(_mainSource);
  stdout.writeln('[shot] compilando -O2...');
  final c = await Process.run('dart', <String>[
    'compile', 'js', '-O2', '-o', p.join(buildDir.path, 'main.dart.js'), mainPath,
  ]);
  if (c.exitCode != 0) {
    stderr..writeln(c.stdout)..writeln(c.stderr);
    exitCode = 1;
    return;
  }
  File(p.join('resources', docFile)).copySync(p.join(buildDir.path, 'doc.docx'));

  final server = await io.serve(
      createStaticHandler(buildDir.path, defaultDocument: 'index.html'),
      '127.0.0.1', 0);
  final outDir = Directory(p.join('.dart_tool', 'shots'))
    ..createSync(recursive: true);
  Browser? browser;
  try {
    browser = await puppeteer.launch(
      executablePath: revision.executablePath,
      headless: true,
      args: const <String>['--no-sandbox', '--disable-setuid-sandbox'],
      defaultViewport: DeviceViewport(width: 900, height: 1300),
    );
    final page = await browser.newPage();
    page.onConsole.listen((m) {
      if (m.type == ConsoleMessageType.error) stderr.writeln('[page] ${m.text}');
    });
    await page.goto('http://127.0.0.1:${server.port}', wait: Until.networkIdle);
    await page.waitForFunction('() => window.__shotReady === true',
        timeout: const Duration(seconds: 30));
    final n = await page.evaluate<num?>(
        '(u) => new Promise((r) => window.__shot.open(u, (c) => r(c)))',
        args: <dynamic>['doc.docx']);
    stdout.writeln('[shot] aberto: $n páginas (1ª fatia). Aguardando '
        'paginação async...');
    // Espera a paginação progressiva estabilizar.
    var prev = -1, stable = 0;
    while (stable < 3) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final cur =
          (await page.evaluate<num?>('() => window.__shot.pageCount()'))!.toInt();
      if (cur == prev) {
        stable++;
      } else {
        stable = 0;
      }
      prev = cur;
    }
    stdout.writeln('[shot] paginação estável: $prev páginas.');
    // Captura só o topo da interface (titlebar + ribbon + menu) para ver o F6.
    final List<int> uiBytes = await page.screenshot(
        clip: Rectangle<num>(0, 0, 900, 700));
    File(p.join(outDir.path, '$which-ui.png')).writeAsBytesSync(uiBytes);
    stdout.writeln('[shot] salvo ${p.join(outDir.path, '$which-ui.png')} (interface)');
    stdout.writeln('[shot] geom: '
        '${await page.evaluate<String?>('() => window.__shot.geom()')}');
    stdout.writeln('[shot] footerInfo: '
        '${await page.evaluate<String?>('() => window.__shot.footerInfo()')}');
    stdout.writeln('[shot] cellSpacing: '
        '${await page.evaluate<String?>('() => window.__shot.cellSpacing()')}');
    stdout.writeln('[shot] itemHeader: '
        '${await page.evaluate<String?>('() => window.__shot.itemHeader()')}');
    stdout.writeln('[shot] headerInfo: '
        '${await page.evaluate<String?>('() => window.__shot.headerInfo()')}');
    for (final pg in pages) {
      stdout.writeln('[shot] ${await page.evaluate<String?>(
          '(i) => window.__shot.pageYRange(i)', args: <dynamic>[pg - 1])}');
      stdout.writeln('[shot] rowYs ${await page.evaluate<String?>(
          '(i) => window.__shot.rowYList(i)', args: <dynamic>[pg - 1])}');
    }
    // Esconde o chrome fixo (titlebar/abas/menu) para não sobrepor o canvas
    // nas capturas por-página (element.screenshot compõe overlays fixos).
    await page.evaluate<void>('''() => {
      for (const sel of ['.word-titlebar', '.ribbon-tabs', '.menu', '.catalog']) {
        document.querySelectorAll(sel).forEach((e) => e.style.display = 'none');
      }
    }''');
    for (final pg in pages) {
      // Rola a página alvo ao viewport para materializá-la (virtualização).
      await page.evaluate<void>(
          '(i) => { const c = document.querySelectorAll(".editor canvas")[i-1];'
          ' if (c) c.scrollIntoView(); }',
          args: <dynamic>[pg]);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final handle = await page.$$('.editor canvas');
      if (pg - 1 < 0 || pg - 1 >= handle.length) {
        stderr.writeln('[shot] página $pg fora do range (${handle.length})');
        continue;
      }
      final outPath = p.join(outDir.path, '$which-page-${pg.toString().padLeft(2, '0')}.png');
      final List<int> bytes = await handle[pg - 1].screenshot();
      File(outPath).writeAsBytesSync(bytes);
      stdout.writeln('[shot] salvo $outPath');
    }
  } finally {
    await browser?.close();
    await server.close(force: true);
  }
}
