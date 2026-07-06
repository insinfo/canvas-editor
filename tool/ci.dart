// CI local do roteiro_editor_profissional (Fase 0.4).
//
// Roda, em ordem:
//   1. dart pub get + dart analyze + dart test em cada package de packages/;
//   2. dart analyze na raiz;
//   3. tool/docx_inventory.dart --verify (aceite F0 contra a seção 2.2);
//   4. (opcional, --e2e) suíte E2E do editor (puppeteer + shelf).
//
// Uso: dart run tool/ci.dart [--e2e]

import 'dart:io';

const _packages = ['ce_zip', 'ce_xml', 'ce_opc', 'ce_docx', 'ce_fonts', 'ce_pdf'];

Future<int> _run(String executable, List<String> args,
    {String? workingDirectory}) async {
  stdout.writeln('\n\$ $executable ${args.join(' ')}'
      '${workingDirectory == null ? '' : '  (em $workingDirectory)'}');
  final process = await Process.start(executable, args,
      workingDirectory: workingDirectory,
      mode: ProcessStartMode.inheritStdio,
      runInShell: true);
  return process.exitCode;
}

Future<void> main(List<String> args) async {
  final runE2e = args.contains('--e2e');
  final failures = <String>[];

  for (final package in _packages) {
    final dir = 'packages/$package';
    final hasTests = Directory('$dir/test')
        .listSync(recursive: true)
        .whereType<File>()
        .any((f) => f.path.endsWith('_test.dart'));

    if (await _run('dart', ['pub', 'get'], workingDirectory: dir) != 0) {
      failures.add('$package: pub get');
      continue;
    }
    if (await _run('dart', ['analyze', '--fatal-infos'],
            workingDirectory: dir) !=
        0) {
      failures.add('$package: analyze');
    }
    if (hasTests &&
        await _run('dart', ['test'], workingDirectory: dir) != 0) {
      failures.add('$package: test');
    }
  }

  if (await _run('dart', ['analyze']) != 0) {
    failures.add('raiz: analyze');
  }

  // Conversor DOCX→IElement (F2.3) roda na VM.
  if (await _run('dart', ['test', 'test/word']) != 0) {
    failures.add('conversor: test/word');
  }

  if (await _run('dart', ['run', 'tool/docx_inventory.dart', '--verify']) !=
      0) {
    failures.add('inventário: divergência com a seção 2.2 do roteiro');
  }

  if (runE2e) {
    if (await _run('dart', ['test', 'test/e2e']) != 0) {
      failures.add('e2e');
    }
  }

  stdout.writeln('\n${'=' * 60}');
  if (failures.isEmpty) {
    stdout.writeln('CI verde: packages + raiz + inventário'
        '${runE2e ? ' + e2e' : ''} OK.');
  } else {
    stdout.writeln('CI FALHOU:');
    for (final failure in failures) {
      stdout.writeln('  - $failure');
    }
    exitCode = 1;
  }
}
