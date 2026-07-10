import 'package:canvas_text_editor/src/editor/dataset/enum/element.dart';
import 'package:canvas_text_editor/src/editor/dataset/enum/list.dart';
import 'package:canvas_text_editor/src/editor/dataset/enum/row.dart';
import 'package:canvas_text_editor/src/editor/dataset/enum/title.dart';
import 'package:canvas_text_editor/src/editor/interface/element.dart';
import 'package:canvas_text_editor/src/editor/interface/table/td.dart';
import 'package:canvas_text_editor/src/word/quill_delta.dart';
import 'package:test/test.dart';

void main() {
  group('QuillDeltaConverter.toDelta', () {
    test('exporta texto com formatação inline e newline final', () {
      final delta = QuillDeltaConverter.toDelta(<IElement>[
        IElement(value: 'Olá '),
        IElement(value: 'mundo', bold: true, italic: true, size: 18),
      ]);
      final ops = delta['ops'] as List;
      expect(ops[0], <String, dynamic>{'insert': 'Olá '});
      expect(ops[1]['insert'], 'mundo');
      expect(ops[1]['attributes'],
          <String, dynamic>{'bold': true, 'italic': true, 'size': '18px'});
      expect((ops.last['insert'] as String).endsWith('\n'), isTrue);
    });

    test('exporta título como atributo header do terminador de linha', () {
      final delta = QuillDeltaConverter.toDelta(<IElement>[
        IElement(
          value: '',
          type: ElementType.title,
          level: TitleLevel.second,
          valueList: <IElement>[IElement(value: 'Capítulo\n')],
        ),
      ]);
      final ops = delta['ops'] as List;
      expect(ops[0]['insert'], 'Capítulo');
      expect(ops[1]['insert'], '\n');
      expect(ops[1]['attributes']['header'], 2);
    });

    test('exporta hyperlink e imagem', () {
      final delta = QuillDeltaConverter.toDelta(<IElement>[
        IElement(
          value: '',
          type: ElementType.hyperlink,
          url: 'https://example.com',
          valueList: <IElement>[IElement(value: 'link')],
        ),
        IElement(
            value: 'data:image/png;base64,x',
            type: ElementType.image,
            width: 100,
            height: 50),
      ]);
      final ops = delta['ops'] as List;
      expect(ops[0]['attributes']['link'], 'https://example.com');
      expect(ops[1]['insert'], <String, dynamic>{
        'image': 'data:image/png;base64,x',
      });
      expect(ops[1]['attributes']['width'], 100);
    });
  });

  group('QuillDeltaConverter.fromDelta', () {
    test('importa texto formatado, header e alinhamento', () {
      final main = QuillDeltaConverter.fromDelta(<String, dynamic>{
        'ops': <Map<String, dynamic>>[
          <String, dynamic>{'insert': 'Título'},
          <String, dynamic>{
            'insert': '\n',
            'attributes': <String, dynamic>{'header': 1, 'align': 'center'},
          },
          <String, dynamic>{
            'insert': 'corpo ',
          },
          <String, dynamic>{
            'insert': 'negrito',
            'attributes': <String, dynamic>{'bold': true},
          },
          <String, dynamic>{'insert': '\n'},
        ],
      });
      final title = main.first;
      expect(title.type, ElementType.title);
      expect(title.level, TitleLevel.first);
      expect(title.rowFlex, RowFlex.center);
      expect(title.valueList!.single.value, 'Título');

      final body = main.sublist(1);
      expect(body[0].value, '\ncorpo ');
      expect(body[1].value, 'negrito');
      expect(body[1].bold, isTrue);
    });

    test('importa lista, link e imagem', () {
      final main = QuillDeltaConverter.fromDelta(<String, dynamic>{
        'ops': <Map<String, dynamic>>[
          <String, dynamic>{'insert': 'item'},
          <String, dynamic>{
            'insert': '\n',
            'attributes': <String, dynamic>{'list': 'ordered'},
          },
          <String, dynamic>{
            'insert': 'site',
            'attributes': <String, dynamic>{'link': 'https://a.b'},
          },
          <String, dynamic>{'insert': '\n'},
          <String, dynamic>{
            'insert': <String, dynamic>{'image': 'data:image/png;base64,y'},
            'attributes': <String, dynamic>{'width': 10, 'height': 20},
          },
          <String, dynamic>{'insert': '\n'},
        ],
      });
      final list = main.first;
      expect(list.type, ElementType.list);
      expect(list.listType, ListType.ordered);
      expect(list.valueList!.single.value, 'item');

      final hyperlink = main.firstWhere((e) => e.type == ElementType.hyperlink);
      expect(hyperlink.url, 'https://a.b');
      expect(hyperlink.valueList!.single.value, 'site');

      final image = main.firstWhere((e) => e.type == ElementType.image);
      expect(image.width, 10);
      expect(image.height, 20);
    });

    test('exporta tabela no formato quill-table-better', () {
      final delta = QuillDeltaConverter.toDelta(<IElement>[
        IElement(
          value: '',
          type: ElementType.table,
          colgroup: <IColgroup>[
            IColgroup(width: 100),
            IColgroup(width: 200),
          ],
          trList: <ITr>[
            ITr(height: 40, tdList: <ITd>[
              ITd(
                  colspan: 1,
                  rowspan: 1,
                  value: <IElement>[IElement(value: 'A1', bold: true)]),
              ITd(colspan: 1, rowspan: 1, value: <IElement>[
                IElement(value: 'B1'),
              ]),
            ]),
            ITr(height: 40, tdList: <ITd>[
              ITd(colspan: 2, rowspan: 1, value: <IElement>[
                IElement(value: 'mesclada'),
              ]),
            ]),
          ],
        ),
      ]);
      final ops = (delta['ops'] as List).cast<Map<String, dynamic>>();

      // Duas colunas com largura.
      final cols = ops
          .where((op) =>
              (op['attributes'] as Map?)?.containsKey('table-col') == true)
          .toList();
      expect(cols, hasLength(2));
      expect(cols.first['attributes']['table-col']['width'], '100');

      // Terminadores de célula com table-cell-block + table-cell.
      final cellEnds = ops
          .where((op) =>
              (op['attributes'] as Map?)?.containsKey('table-cell-block') ==
              true)
          .toList();
      expect(cellEnds, hasLength(3));
      final Map<String, dynamic> a1 =
          (cellEnds[0]['attributes'] as Map).cast<String, dynamic>();
      final Map<String, dynamic> b1 =
          (cellEnds[1]['attributes'] as Map).cast<String, dynamic>();
      expect(a1['table-cell']['data-row'], b1['table-cell']['data-row']);
      final Map<String, dynamic> merged =
          (cellEnds[2]['attributes'] as Map).cast<String, dynamic>();
      expect(merged['table-cell']['colspan'], '2');
      expect(merged['table-cell']['data-row'],
          isNot(a1['table-cell']['data-row']));

      // Conteúdo inline preserva formatação.
      final boldOp = ops.firstWhere((op) => op['insert'] == 'A1');
      expect((boldOp['attributes'] as Map)['bold'], isTrue);
    });

    test('round-trip de tabela preserva estrutura e conteúdo', () {
      final original = <IElement>[
        IElement(value: 'antes'),
        IElement(
          value: '',
          type: ElementType.table,
          colgroup: <IColgroup>[IColgroup(width: 120), IColgroup(width: 80)],
          trList: <ITr>[
            ITr(height: 40, tdList: <ITd>[
              ITd(colspan: 1, rowspan: 1, value: <IElement>[
                IElement(value: 'linha1\nlinha2'),
              ]),
              ITd(colspan: 1, rowspan: 2, value: <IElement>[
                IElement(value: 'alta'),
              ]),
            ]),
            ITr(height: 40, tdList: <ITd>[
              ITd(colspan: 1, rowspan: 1, value: <IElement>[
                IElement(value: 'fim', italic: true),
              ]),
            ]),
          ],
        ),
        IElement(value: '\ndepois'),
      ];
      final delta = QuillDeltaConverter.toDelta(original);
      final restored = QuillDeltaConverter.fromDelta(delta);

      final table = restored.firstWhere((e) => e.type == ElementType.table);
      expect(table.colgroup, hasLength(2));
      expect(table.colgroup![0].width, 120);
      expect(table.trList, hasLength(2));
      expect(table.trList![0].tdList, hasLength(2));
      expect(table.trList![1].tdList, hasLength(1));
      expect(table.trList![0].tdList[1].rowspan, 2);

      // Parágrafos internos da célula preservados como '\n'.
      final cellText =
          table.trList![0].tdList[0].value.map((e) => e.value).join();
      expect(cellText, 'linha1\nlinha2');
      expect(table.trList![1].tdList[0].value.first.italic, isTrue);

      // Texto ao redor da tabela preservado.
      expect(restored.first.value, 'antes');
      expect(restored.map((e) => e.value).join(), contains('depois'));
    });

    test('round-trip preserva texto e formatação básica', () {
      final original = <IElement>[
        IElement(value: 'Um '),
        IElement(value: 'dois', bold: true),
        IElement(value: '\nsegunda linha'),
      ];
      final delta = QuillDeltaConverter.toDelta(original);
      final restored = QuillDeltaConverter.fromDelta(delta);
      final text = restored
          .map((e) => e.valueList?.map((v) => v.value).join() ?? e.value)
          .join();
      expect(text, 'Um dois\nsegunda linha');
      expect(restored.any((e) => e.bold == true), isTrue);
    });
  });
}
