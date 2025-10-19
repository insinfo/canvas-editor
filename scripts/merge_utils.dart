import 'dart:io';

void main() {
  final libDir = Directory(r'C:\MyDartProjects\canvas-editor-port\lib');
  //final libDir = Directory(r'C:\MyDartProjects\canvas-editor-port\lib\test');
  final outputFile = File(r'C:\MyDartProjects\canvas-editor-port\lib\scripts\codigo_mesclado.dart.txt');

  if (outputFile.existsSync()) {
    outputFile.deleteSync();
  }

  final outputSink = outputFile.openWrite(mode: FileMode.append);

  final files = libDir.listSync(recursive: true);
  for (final file in files) {
    if (file is File && file.path.endsWith('.dart')) {
      final content = file.readAsStringSync();
      outputSink.write('// Merged from ${file.path}\n');
      outputSink.write(content);
      outputSink.write('\n\n');
    }
  }

  outputSink.close();
  print('Merged all .dart files from lib/ to scripts/codigo_mesclado.dart.txt');
}
