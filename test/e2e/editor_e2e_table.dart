part of 'editor_smoke_test.dart';

void _registerTableE2ETests() {
  test('imports HTML tables into table elements', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    await _resetContent(page!, '');
    await _setRange(page!, 0, 0);
    await _importHtml(
      page!,
      '<table><tr><td>A1</td><td>B1</td></tr><tr><td>A2</td><td>B2</td></tr></table>',
    );

    final elements = await _readMainElements(page!);
    final tableElement = elements.cast<Map<String, dynamic>?>().firstWhere(
          (element) => element?['type'] == 'table',
          orElse: () => null,
        );

    expect(tableElement, isNotNull);
    expect(tableElement!['tableRowCount'], 2);
    expect(tableElement['tableColCount'], 2);
    expect(tableElement['tableTexts'], isA<List<dynamic>>());
  });

  test('supports table insertion and undo redo', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    await _resetContent(page!, '');
    await _setRange(page!, 0, 0);
    await _insertTable(page!, 2, 2);

    var elements = await _readMainElements(page!);
    expect(elements.any((element) => element['type'] == 'table'), isTrue);

    await _undo(page!);
    elements = await _readMainElements(page!);
    expect(elements.any((element) => element['type'] == 'table'), isFalse);

    await _redo(page!);
    elements = await _readMainElements(page!);
    expect(elements.any((element) => element['type'] == 'table'), isTrue);
  });

  test('ships the demo mock with a preloaded table sample', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    await _resetMockContent(page!);

    final elements = await _readMainElements(page!);
    final tableElement = _firstTable(elements);

    expect(tableElement, isNotNull);
    expect(tableElement!['tableRowCount'], 3);
    expect(tableElement['tableColgroupCount'], 4);
    expect(tableElement['tableTexts'], isA<List<dynamic>>());
  });

  test('renders table editing controls for the focused table cell', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    await _resetMockContent(page!);
    expect(await _focusFirstTableCell(page!), isTrue);

    final Map<String, dynamic> metrics = Map<String, dynamic>.from(
      jsonDecode(
        await page!.evaluate<String>('''() => JSON.stringify({
          rowItems: document.querySelectorAll('.ce-table-tool__row__item').length,
          colItems: document.querySelectorAll('.ce-table-tool__col__item').length,
          quickAdds: document.querySelectorAll('.ce-table-tool__quick__add').length,
          hasSelect: !!document.querySelector('.ce-table-tool__select'),
          hasBorder: !!document.querySelector('.ce-table-tool__border'),
          rowHeight: document.querySelector('.ce-table-tool__row')?.getBoundingClientRect().height ?? 0,
          colWidth: document.querySelector('.ce-table-tool__col')?.getBoundingClientRect().width ?? 0
        })'''),
      ) as Map<String, dynamic>,
    );
    expect(metrics['rowItems'], greaterThan(0));
    expect(metrics['colItems'], greaterThan(0));
    expect(metrics['quickAdds'], 2);
    expect(metrics['hasSelect'], isTrue);
    expect(metrics['hasBorder'], isTrue);
    expect((metrics['rowHeight'] as num).toDouble(), greaterThan(0));
    expect((metrics['colWidth'] as num).toDouble(), greaterThan(0));
  });

  test('supports public row and column mutations on a simple table', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    await _resetContent(page!, '');
    await _setRange(page!, 0, 0);
    await _insertTable(page!, 2, 2);
    expect(await _focusFirstTableCell(page!), isTrue);

    await _insertTableTopRow(page!);
    var elements = await _readMainElements(page!);
    var tableElement = _firstTable(elements);
    expect(tableElement, isNotNull);
    expect(tableElement!['tableRowCount'], 3);

    expect(await _focusFirstTableCell(page!), isTrue);
    await _insertTableLeftCol(page!);
    elements = await _readMainElements(page!);
    tableElement = _firstTable(elements);
    expect(tableElement, isNotNull);
    expect(tableElement!['tableColgroupCount'], 3);

    expect(await _focusFirstTableCell(page!), isTrue);
    await _insertTableBottomRow(page!);
    elements = await _readMainElements(page!);
    tableElement = _firstTable(elements);
    expect(tableElement, isNotNull);
    expect(tableElement!['tableRowCount'], 4);

    expect(await _focusFirstTableCell(page!), isTrue);
    await _insertTableRightCol(page!);
    elements = await _readMainElements(page!);
    tableElement = _firstTable(elements);
    expect(tableElement, isNotNull);
    expect(tableElement!['tableColgroupCount'], 4);

    expect(await _focusFirstTableCell(page!), isTrue);
    await _deleteTableRow(page!);
    elements = await _readMainElements(page!);
    tableElement = _firstTable(elements);
    expect(tableElement, isNotNull);
    expect(tableElement!['tableRowCount'], 3);

    expect(await _focusFirstTableCell(page!), isTrue);
    await _deleteTableCol(page!);
    elements = await _readMainElements(page!);
    tableElement = _firstTable(elements);
    expect(tableElement, isNotNull);
    expect(tableElement!['tableColgroupCount'], 3);
  });

  test('supports deeper table context menu actions through DOM', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    await _resetContent(page!, '');
    await _setRange(page!, 0, 0);
    await _insertTable(page!, 2, 2);
    expect(await _focusFirstTableCell(page!), isTrue);

    expect(await _openContextMenuOnEditor(page!), isTrue);
    expect(await _hoverContextMenuItem(page!, 'Inserir linha ou coluna'), isTrue);
    expect(await _clickContextMenuItem(page!, 'Inserir 1 linha abaixo'), isTrue);

    var elements = await _readMainElements(page!);
    var tableElement = _firstTable(elements);
    expect(tableElement, isNotNull);
    expect(tableElement!['tableRowCount'], 3);

    expect(await _focusFirstTableCell(page!), isTrue);
    expect(await _openContextMenuOnEditor(page!), isTrue);
    expect(await _hoverContextMenuItem(page!, 'Alinhamento vertical'), isTrue);
    expect(
      await _clickContextMenuItem(page!, 'Centralizar verticalmente'),
      isTrue,
    );

    elements = await _readMainElements(page!);
    tableElement = _firstTable(elements);
    expect(tableElement, isNotNull);
    expect(tableElement!['tableVerticalAligns'], isA<List<dynamic>>());
    expect(
      ((tableElement['tableVerticalAligns'] as List<dynamic>).first as List<dynamic>).first,
      'middle',
    );

    expect(await _focusFirstTableCell(page!), isTrue);
    expect(await _openContextMenuOnEditor(page!), isTrue);
    expect(await _hoverContextMenuItem(page!, 'Borda da tabela'), isTrue);
    expect(await _clickContextMenuItem(page!, 'Sem bordas'), isTrue);

    elements = await _readMainElements(page!);
    tableElement = _firstTable(elements);
    expect(tableElement, isNotNull);
    expect(tableElement!['tableBorderType'], 'empty');
  });

  test('supports table merge cancel merge and cell border submenus through DOM', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    await _resetContent(page!, '');
    await _setRange(page!, 0, 0);
    await _insertTable(page!, 2, 2);

    expect(await _focusTableRange(page!, 0, 0, 0, 1), isTrue);
    expect(await _openContextMenuOnEditor(page!), isTrue);
    expect(await _clickContextMenuItem(page!, 'Mesclar células'), isTrue);

    var elements = await _readMainElements(page!);
    var tableElement = _firstTable(elements);
    expect(tableElement, isNotNull);
    final mergedFirstRow =
        (tableElement!['tableCellSpans'] as List<dynamic>).first as List<dynamic>;
    expect(
      mergedFirstRow.any(
        (cell) => (cell as Map<String, dynamic>)['colspan'] == 2,
      ),
      isTrue,
    );

    expect(await _focusFirstTableCell(page!), isTrue);
    expect(await _openContextMenuOnEditor(page!), isTrue);
    expect(await _clickContextMenuItem(page!, 'Desfazer mesclagem'), isTrue);

    elements = await _readMainElements(page!);
    tableElement = _firstTable(elements);
    expect(tableElement, isNotNull);
    final unmergedFirstRow =
        (tableElement!['tableCellSpans'] as List<dynamic>).first as List<dynamic>;
    expect(unmergedFirstRow.length, 2);
    expect(
      unmergedFirstRow.every(
        (cell) =>
            (cell as Map<String, dynamic>)['colspan'] == 1 &&
            cell['rowspan'] == 1,
      ),
      isTrue,
    );

    expect(await _focusFirstTableCell(page!), isTrue);
    expect(await _openContextMenuOnEditor(page!), isTrue);
    expect(await _hoverContextMenuItem(page!, 'Borda da tabela'), isTrue);
    expect(await _hoverContextMenuItem(page!, 'Borda da célula'), isTrue);
    expect(await _clickContextMenuItem(page!, 'Borda superior'), isTrue);

    expect(await _focusFirstTableCell(page!), isTrue);
    expect(await _openContextMenuOnEditor(page!), isTrue);
    expect(await _hoverContextMenuItem(page!, 'Borda da tabela'), isTrue);
    expect(await _hoverContextMenuItem(page!, 'Borda da célula'), isTrue);
    expect(await _clickContextMenuItem(page!, 'Diagonal principal'), isTrue);

    elements = await _readMainElements(page!);
    tableElement = _firstTable(elements);
    final firstCellBorders = (((tableElement!['tableCellBorders'] as List<dynamic>)
        .first as List<dynamic>).first as Map<String, dynamic>);
    expect(firstCellBorders['borderTypes'], contains('top'));
    expect(firstCellBorders['slashTypes'], contains('forward'));
  });

  test('supports table split vertical horizontal and delete table through DOM context menu', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    await _resetContent(page!, '');
    await _setRange(page!, 0, 0);
    await _insertTable(page!, 2, 2);

    expect(
      await _focusTableRange(page!, 0, 0, 0, 1),
      isTrue,
      reason: 'focus horizontal merge range',
    );
    expect(
      await _openContextMenuOnEditor(page!),
      isTrue,
      reason: 'open context menu before horizontal merge',
    );
    expect(
      await _clickContextMenuItem(page!, 'Mesclar células'),
      isTrue,
      reason: 'click horizontal merge item',
    );

    expect(
      await _focusFirstTableCell(page!),
      isTrue,
      reason: 'focus merged cell before vertical split',
    );
    expect(
      await _openContextMenuOnEditor(page!),
      isTrue,
      reason: 'open context menu before vertical split',
    );
    expect(
      await _clickContextMenuItem(page!, 'Dividir verticalmente'),
      isTrue,
      reason: 'click vertical split item',
    );

    var elements = await _readMainElements(page!);
    var tableElement = _firstTable(elements);
    expect(tableElement, isNotNull);
    var firstRow =
        (tableElement!['tableCellSpans'] as List<dynamic>).first as List<dynamic>;
    expect(firstRow.length, 2);
    expect(
      firstRow.every(
        (cell) =>
            (cell as Map<String, dynamic>)['colspan'] == 1 &&
            cell['rowspan'] == 1,
      ),
      isTrue,
    );

    await _resetContent(page!, '');
    await _setRange(page!, 0, 0);
    await _insertTable(page!, 2, 2);

    expect(
      await _focusTableRange(page!, 0, 0, 1, 0),
      isTrue,
      reason: 'focus vertical merge range',
    );
    expect(
      await _openContextMenuOnEditor(page!),
      isTrue,
      reason: 'open context menu before vertical merge',
    );
    expect(
      await _clickContextMenuItem(page!, 'Mesclar células'),
      isTrue,
      reason: 'click vertical merge item',
    );

    expect(
      await _focusFirstTableCell(page!),
      isTrue,
      reason: 'focus merged cell before horizontal split',
    );
    expect(
      await _openContextMenuOnEditor(page!),
      isTrue,
      reason: 'open context menu before horizontal split',
    );
    expect(
      await _clickContextMenuItem(page!, 'Dividir horizontalmente'),
      isTrue,
      reason: 'click horizontal split item',
    );

    elements = await _readMainElements(page!);
    tableElement = _firstTable(elements);
    final firstCol = <Map<String, dynamic>>[
      Map<String, dynamic>.from(
        ((tableElement!['tableCellSpans'] as List<dynamic>)[0] as List<dynamic>)[0]
            as Map<dynamic, dynamic>,
      ),
      Map<String, dynamic>.from(
        ((tableElement['tableCellSpans'] as List<dynamic>)[1] as List<dynamic>)[0]
            as Map<dynamic, dynamic>,
      ),
    ];
    expect(
      firstCol.every(
        (cell) => cell['colspan'] == 1 && cell['rowspan'] == 1,
      ),
      isTrue,
    );

    expect(
      await _focusFirstTableCell(page!),
      isTrue,
      reason: 'focus first cell before delete table',
    );
    expect(
      await _openContextMenuOnEditor(page!),
      isTrue,
      reason: 'open context menu before delete table',
    );
    expect(
      await _hoverContextMenuItem(page!, 'Excluir linha ou coluna'),
      isTrue,
      reason: 'hover delete row/col submenu',
    );
    expect(
      await _clickContextMenuItem(page!, 'Excluir tabela'),
      isTrue,
      reason: 'click delete table item',
    );

    elements = await _readMainElements(page!);
    tableElement = _firstTable(elements);
    expect(tableElement, isNull);
  });

  test('inserts a new table into a filled document without removing the existing one', () async {
    if (skipReason != null) {
      print('Skipping test: $skipReason');
      return;
    }

    await _resetMockContent(page!);
    expect(
      await _setRangeBeforeTextValue(page!, 'Observações finais: '),
      isTrue,
    );

    final beforeElements = await _readMainElements(page!);
    final beforeTableCount = beforeElements
        .where((element) => element['type'] == 'table')
        .length;
    final beforeControlCount = beforeElements
        .where((element) => element['type'] == 'control')
        .length;

    expect(beforeTableCount, 1);

    await _insertTable(page!, 2, 2);

    final afterElements = await _readMainElements(page!);
    final afterTableCount = afterElements
        .where((element) => element['type'] == 'table')
        .length;
    final afterControlCount = afterElements
        .where((element) => element['type'] == 'control')
        .length;
    final firstTable = _firstTable(afterElements);

    expect(afterTableCount, 2);
    expect(afterControlCount, beforeControlCount);
    expect(firstTable, isNotNull);
    expect(firstTable!['tableRowCount'], 3);
    expect(firstTable['tableColgroupCount'], 4);
  });
}