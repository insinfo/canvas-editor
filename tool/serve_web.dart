// Servidor de desenvolvimento em build RELEASE (doc/plano_otimizacao_performance.md, A1).
//
// `webdev serve` usa DDC (JS de desenvolvimento, sem otimização) e fica 5–20×
// mais lento nos loops de layout — NÃO use DDC para avaliar performance.
// Este script compila com dart2js -O2 e serve `web/` como estático:
//
//   dart run tool/serve_web.dart            # compila e serve em :8080
//   dart run tool/serve_web.dart --port=9090
//   dart run tool/serve_web.dart --no-build # só serve (usa o último build)
//
// O JS é gerado em web/main.dart.js (mesmo nome que o index.html referencia).

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';

Future<void> main(List<String> args) async {
  final port = int.tryParse(
        args
            .firstWhere((a) => a.startsWith('--port='), orElse: () => '')
            .replaceFirst('--port=', ''),
      ) ??
      8080;
  final skipBuild = args.contains('--no-build');

  if (!skipBuild) {
    stdout.writeln('[serve_web] compilando web/main.dart com dart2js -O2...');
    final result = await Process.run('dart', <String>[
      'compile',
      'js',
      '-O2',
      '-o',
      p.join('web', 'main.dart.js'),
      p.join('web', 'main.dart'),
    ]);
    stdout.write(result.stdout);
    if (result.exitCode != 0) {
      stderr
        ..writeln('[serve_web] compilação falhou:')
        ..writeln(result.stderr);
      exitCode = 1;
      return;
    }
  }

  final staticHandler =
      createStaticHandler('web', defaultDocument: 'index.html');
  final handler = const Pipeline().addHandler((Request request) {
    // DOCX de resources/ acessíveis em /resources/<arquivo> (testes manuais).
    if (request.url.path.startsWith('resources/')) {
      final file = File(Uri.decodeComponent(request.url.path));
      if (file.existsSync()) {
        return Response.ok(
          file.readAsBytesSync(),
          headers: <String, String>{
            'Content-Type': 'application/octet-stream',
          },
        );
      }
      return Response.notFound('não encontrado');
    }
    return staticHandler(request);
  });

  await io.serve(handler, '127.0.0.1', port);
  stdout.writeln('[serve_web] release em http://127.0.0.1:$port');
}
