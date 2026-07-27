import 'dart:io';
import 'dart:typed_data';

import 'package:canvas_text_editor/src/editor/interface/element.dart';
import 'package:canvas_text_editor/src/word/docx_to_element.dart';
import 'package:canvas_text_editor/src/word/element_to_docx.dart';
import 'package:canvas_text_editor/ce_docx.dart';
import 'package:test/test.dart';

const _etpPath = 'resources/PGCTIC1_-_ETP_-_Sistema_de_Gestão_Pública.docx';

Uint8List _read(String path) =>
    Uint8List.fromList(File(path).readAsBytesSync());

({DocxFile file, DocxConversionResult original, DocxConversionResult current})
    _openTwice(Uint8List bytes) {
  final fileA = DocxReader.read(bytes);
  final original = DocxToElementConverter.convert(fileA);
  final fileB = DocxReader.read(bytes);
  final current = DocxToElementConverter.convert(fileB);
  return (file: fileB, original: original, current: current);
}

/// Índice de um elemento de TEXTO de parágrafo de topo (fora de tabela)
/// com valor razoável para servir de alvo.
int _findParagraphTextIndex(List<IElement> elements) {
  for (var i = 0; i < elements.length; i++) {
    final e = elements[i];
    if (e.type == null &&
        e.value != '\n' &&
        e.value.trim().length > 20 &&
        e.externalId != null) {
      return i;
    }
  }
  fail('nenhum elemento de texto de parágrafo encontrado');
}

/// Estampa [stops] em todos os elementos do parágrafo que contém [index]
/// (mesma semântica do CommandAdapt.setTabStops).
void _stampParagraph(List<IElement> elements, int index, List<ITabStop> stops) {
  var start = index;
  while (start > 0 && elements[start - 1].value != '\n') {
    start--;
  }
  var end = index;
  while (end < elements.length && elements[end].value != '\n') {
    elements[end].paraTabStops =
        stops.map((ITabStop s) => s.clone()).toList();
    end++;
  }
  // O separador '\n' que abre o parágrafo também carrega o pPr na conversão.
  if (start > 0) {
    elements[start - 1].paraTabStops =
        stops.map((ITabStop s) => s.clone()).toList();
  }
}

void main() {
  group('tab stops (F4.4): régua ↔ w:tabs', () {
    late Uint8List original;

    setUpAll(() => original = _read(_etpPath));

    test('definir paradas no editor → salvar → reabrir preserva w:tabs', () {
      final env = _openTwice(original);
      final index = _findParagraphTextIndex(env.current.main);
      final targetValue = env.current.main[index].value;
      final stops = <ITabStop>[
        ITabStop(type: 'left', position: 100),
        ITabStop(type: 'center', position: 250),
        ITabStop(type: 'right', position: 500),
      ];
      _stampParagraph(env.current.main, index, stops);

      EditorToDocx.apply(env.file, env.current.main, env.original.main);
      final saved = DocxWriter.write(env.file);
      expect(DocxValidator.validate(saved), isEmpty);

      final reopened =
          DocxToElementConverter.convert(DocxReader.read(saved));
      final reIndex = reopened.main.indexWhere(
          (IElement e) => e.type == null && e.value == targetValue);
      expect(reIndex, greaterThanOrEqualTo(0));
      final roundTripped = reopened.main[reIndex].paraTabStops;
      expect(roundTripped, isNotNull);
      expect(roundTripped!.length, 3);
      expect(roundTripped[0].type, 'left');
      expect(roundTripped[0].position, closeTo(100, 0.1));
      expect(roundTripped[1].type, 'center');
      expect(roundTripped[1].position, closeTo(250, 0.1));
      expect(roundTripped[2].type, 'right');
      expect(roundTripped[2].position, closeTo(500, 0.1));
    });

    test('sem edição de paradas → save continua byte-idêntico', () {
      final env = _openTwice(original);
      EditorToDocx.apply(env.file, env.current.main, env.original.main);
      final saved = DocxWriter.write(env.file);
      expect(saved.length, original.length);
    });
  });
}
