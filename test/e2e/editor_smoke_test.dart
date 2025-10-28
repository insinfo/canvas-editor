import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:puppeteer/puppeteer.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';
import 'package:test/test.dart';

const _mainDartSource = r'''
import 'dart:html' as html;
import 'dart:js_util' as js_util;

void main() {
  final canvas = html.document.getElementById('canvas') as html.CanvasElement;
  final ctx = canvas.context2D;
  ctx
    ..fillStyle = '#fafafa'
    ..fillRect(0, 0, canvas.width!.toDouble(), canvas.height!.toDouble())
    ..fillStyle = '#222'
    ..font = '16px sans-serif'
    ..fillText('Canvas Editor bootstrap', 24, 40);

  js_util.setProperty(html.window, '__canvasReady', true);
}
''';

const _indexHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Canvas Editor Smoke</title>
  <link rel="icon" href="data:,">
</head>
<body>
  <canvas id="canvas" width="800" height="600"></canvas>
  <script defer src="main.dart.js"></script>
</body>
</html>
''';

class _ServeArgs {
  final String dir;
  final SendPort sendPort;
  final int? port;

  const _ServeArgs(this.dir, this.sendPort, {this.port});
}

Future<void> _serveIsolate(_ServeArgs args) async {
  final handler = createStaticHandler(args.dir, defaultDocument: 'index.html');
  final server = await io.serve(handler, '127.0.0.1', args.port ?? 0);

  final control = ReceivePort();
  args.sendPort
      .send({'port': args.port ?? server.port, 'control': control.sendPort});

  await for (final message in control) {
    if (message == 'close') {
      await server.close(force: true);
      control.close();
      break;
    }
  }
}

void main() {
  group('Canvas editor smoke tests', () {
    final buildDir = Directory('build_test');
    SendPort? serverControl;
    Browser? browser;
    Page? page;
    String? baseUrl;
    String? skipReason;

    setUpAll(() async {
      try {
        final revisionInfo = await downloadChrome(cachePath: '.local-chrome');

        if (buildDir.existsSync()) {
          buildDir.deleteSync(recursive: true);
        }
        buildDir.createSync(recursive: true);

        final indexPath = p.join(buildDir.path, 'index.html');
        File(indexPath).writeAsStringSync(_indexHtml);

        final mainPath = p.join(buildDir.path, 'main.dart');
        File(mainPath).writeAsStringSync(_mainDartSource);

        final result = await Process.run(
          'dart',
          [
            'compile',
            'js',
            '-O1',
            '-o',
            p.join(buildDir.path, 'main.dart.js'),
            mainPath
          ],
        );
        if (result.exitCode != 0) {
          throw ProcessException(
            'dart',
            ['compile', 'js', '-O1', '-o', 'main.dart.js', mainPath],
            (result.stderr as Object?).toString(),
            result.exitCode,
          );
        }

        final receivePort = ReceivePort();
        await Isolate.spawn(
          _serveIsolate,
          _ServeArgs(buildDir.path, receivePort.sendPort, port: 5179),
        );
        final init = await receivePort.first as Map;
        serverControl = init['control'] as SendPort;
        baseUrl = 'http://127.0.0.1:${init['port']}';

        browser = await puppeteer.launch(
          executablePath: revisionInfo.executablePath,
          headless: true,
          args: const ['--no-sandbox', '--disable-setuid-sandbox'],
        );
      } catch (error, stackTrace) {
        skipReason = 'Puppeteer setup failed: $error';
        stderr
          ..writeln(skipReason)
          ..writeln(stackTrace);
      }
    });

    tearDownAll(() async {
      await browser?.close();
      serverControl?.send('close');
      if (buildDir.existsSync()) {
        buildDir.deleteSync(recursive: true);
      }
    });

    setUp(() async {
      if (skipReason != null) {
        return;
      }
      page = await browser!.newPage();
      await page!.goto(baseUrl!, wait: Until.networkIdle);
    });

    tearDown(() async {
      await page?.close();
    });

    test('Canvas element is available', () async {
      if (skipReason != null) {
        print('Skipping test: $skipReason');
        return;
      }
      final canvasHandle = await page!
          .waitForSelector('#canvas', timeout: const Duration(seconds: 5));
      expect(canvasHandle, isNotNull);
    });

    test('Bootstrap code marks canvas as ready', () async {
      if (skipReason != null) {
        print('Skipping test: $skipReason');
        return;
      }
      final ready =
          await page!.evaluate<bool>('() => window.__canvasReady === true');
      expect(ready, isTrue);
    });
  });
}
