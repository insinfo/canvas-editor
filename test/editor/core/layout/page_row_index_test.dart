import 'package:canvas_text_editor/src/editor/core/layout/page_row_index.dart';
import 'package:canvas_text_editor/src/editor/interface/row.dart';
import 'package:test/test.dart';

void main() {
  test('append reinspeciona somente a antiga ultima pagina e novas rows', () {
    final List<IRow> rows = <IRow>[
      for (int index = 0; index < 1000; index++) _row(index),
    ];
    final PageRowAggregation initial = PageRowIndex.paginateAll(
      rows: rows,
      pageHeight: 110,
      marginHeight: 10,
    );
    expect(initial.pages, hasLength(100));
    final List<List<IRow>> oldPages = initial.pages;

    rows.addAll(<IRow>[
      for (int index = 1000; index < 1020; index++) _row(index),
    ]);
    final PageRowAggregation appended = PageRowIndex.append(
      rows: rows,
      previousPages: oldPages,
      pageHeight: 110,
      marginHeight: 10,
    );

    expect(appended.pages, hasLength(102));
    expect(appended.reusedPrefixPageCount, 99);
    expect(appended.inspectedRowCount, 30,
        reason: '10 rows da ultima pagina antiga + 20 novas');
    for (int page = 0; page < 99; page++) {
      expect(identical(appended.pages[page], oldPages[page]), isTrue);
    }
    expect(
      appended.pages.expand((List<IRow> page) => page),
      orderedEquals(rows),
    );
  });

  test('fallback completo quando o prefixo anterior nao pertence as rows', () {
    final List<IRow> rows = <IRow>[_row(0), _row(1), _row(2)];
    final PageRowAggregation result = PageRowIndex.append(
      rows: rows,
      previousPages: <List<IRow>>[
        <IRow>[_row(99)],
      ],
      pageHeight: 30,
      marginHeight: 0,
    );
    expect(result.inspectedRowCount, rows.length);
    expect(result.reusedPrefixPageCount, 0);
    expect(result.pages.expand((List<IRow> page) => page), orderedEquals(rows));
  });

  test('preserva page break explicito no sufixo incremental', () {
    final List<IRow> rows = <IRow>[
      for (int index = 0; index < 4; index++) _row(index),
    ];
    rows[1].isPageBreak = true;
    final PageRowAggregation initial = PageRowIndex.paginateAll(
      rows: rows,
      pageHeight: 100,
      marginHeight: 0,
    );
    expect(initial.pages.map((List<IRow> page) => page.length), <int>[2, 2]);

    rows.addAll(<IRow>[_row(4), _row(5)]);
    final PageRowAggregation appended = PageRowIndex.append(
      rows: rows,
      previousPages: initial.pages,
      pageHeight: 100,
      marginHeight: 0,
    );
    expect(appended.pages.map((List<IRow> page) => page.length), <int>[2, 4]);
  });

  test('mutacao local para quando a pagina seguinte converge', () {
    final List<IRow> rows = <IRow>[
      for (int index = 0; index < 1000; index++) _row(index),
    ];
    final PageRowAggregation initial = PageRowIndex.paginateAll(
      rows: rows,
      pageHeight: 110,
      marginHeight: 10,
    );
    final List<List<IRow>> oldPages = initial.pages;
    rows[205] = _row(205);

    final PageRowAggregation updated = PageRowIndex.repaginateFromRow(
      rows: rows,
      previousPages: oldPages,
      dirtyRowIndex: 205,
      pageHeight: 110,
      marginHeight: 10,
    );

    expect(updated.reusedPrefixPageCount, 20);
    expect(updated.reusedSuffixPageCount, 79);
    expect(updated.inspectedRowCount, 20,
        reason: 'pagina suja + pagina de convergencia');
    expect(identical(updated.pages[19], oldPages[19]), isTrue);
    expect(identical(updated.pages[20], oldPages[20]), isFalse);
    expect(identical(updated.pages[21], oldPages[21]), isTrue);
    expect(
      updated.pages.expand((List<IRow> page) => page),
      orderedEquals(rows),
    );
  });
}

IRow _row(int index) => IRow(
      width: 10,
      height: 10,
      ascent: 8,
      startIndex: index,
      rowIndex: index,
      elementList: <IRowElement>[],
    );
