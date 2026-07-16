import '../../interface/row.dart';

class PageRowAggregation {
  const PageRowAggregation({
    required this.pages,
    required this.inspectedRowCount,
    required this.reusedPrefixPageCount,
    required this.reusedSuffixPageCount,
  });

  final List<List<IRow>> pages;
  final int inspectedRowCount;
  final int reusedPrefixPageCount;
  final int reusedSuffixPageCount;
}

/// Incremental aggregation of laid-out rows into fixed-height pages.
///
/// Progressive layout only appends rows. All pages before the formerly-last
/// page are closed and immutable, so pagination can restart at that last page
/// instead of scanning the accumulated prefix on every scheduler slice.
class PageRowIndex {
  const PageRowIndex._();

  static PageRowAggregation paginateAll({
    required List<IRow> rows,
    required double pageHeight,
    required double marginHeight,
  }) {
    if (rows.isEmpty) {
      return const PageRowAggregation(
        pages: <List<IRow>>[],
        inspectedRowCount: 0,
        reusedPrefixPageCount: 0,
        reusedSuffixPageCount: 0,
      );
    }
    return PageRowAggregation(
      pages: _paginateRows(
        rows,
        startRow: 0,
        pageHeight: pageHeight,
        marginHeight: marginHeight,
        firstRowStartsPage: false,
      ),
      inspectedRowCount: rows.length,
      reusedPrefixPageCount: 0,
      reusedSuffixPageCount: 0,
    );
  }

  static PageRowAggregation append({
    required List<IRow> rows,
    required List<List<IRow>> previousPages,
    required double pageHeight,
    required double marginHeight,
  }) {
    if (rows.isEmpty || previousPages.isEmpty) {
      return paginateAll(
        rows: rows,
        pageHeight: pageHeight,
        marginHeight: marginHeight,
      );
    }

    final int reusedPrefixPageCount = previousPages.length - 1;
    int startRow = 0;
    for (int page = 0; page < reusedPrefixPageCount; page++) {
      startRow += previousPages[page].length;
    }
    if (startRow >= rows.length ||
        previousPages.last.isEmpty ||
        !identical(previousPages.last.first, rows[startRow])) {
      return paginateAll(
        rows: rows,
        pageHeight: pageHeight,
        marginHeight: marginHeight,
      );
    }

    final List<List<IRow>> suffix = _paginateRows(
      rows,
      startRow: startRow,
      pageHeight: pageHeight,
      marginHeight: marginHeight,
      firstRowStartsPage: true,
    );
    return PageRowAggregation(
      pages: <List<IRow>>[
        for (int page = 0; page < reusedPrefixPageCount; page++)
          previousPages[page],
        ...suffix,
      ],
      inspectedRowCount: rows.length - startRow,
      reusedPrefixPageCount: reusedPrefixPageCount,
      reusedSuffixPageCount: 0,
    );
  }

  /// Reflows from the page containing [dirtyRowIndex] and stops as soon as a
  /// complete page has the same row identities as an old page. At that point
  /// pagination state has converged and the untouched suffix is reusable.
  static PageRowAggregation repaginateFromRow({
    required List<IRow> rows,
    required List<List<IRow>> previousPages,
    required int dirtyRowIndex,
    required double pageHeight,
    required double marginHeight,
  }) {
    if (rows.isEmpty || previousPages.isEmpty || dirtyRowIndex < 0) {
      return paginateAll(
        rows: rows,
        pageHeight: pageHeight,
        marginHeight: marginHeight,
      );
    }

    int dirtyPage = 0;
    int startRow = 0;
    while (dirtyPage < previousPages.length - 1 &&
        startRow + previousPages[dirtyPage].length <= dirtyRowIndex) {
      startRow += previousPages[dirtyPage].length;
      dirtyPage += 1;
    }
    if (startRow >= rows.length ||
        (startRow > 0 &&
            previousPages[dirtyPage - 1].isNotEmpty &&
            !identical(
                previousPages[dirtyPage - 1].last, rows[startRow - 1]))) {
      return paginateAll(
        rows: rows,
        pageHeight: pageHeight,
        marginHeight: marginHeight,
      );
    }

    final Map<IRow, int> oldPageByFirstRow = Map<IRow, int>.identity();
    for (int page = dirtyPage; page < previousPages.length; page++) {
      final List<IRow> oldPage = previousPages[page];
      if (oldPage.isNotEmpty) oldPageByFirstRow[oldPage.first] = page;
    }

    final List<List<IRow>> result = <List<IRow>>[
      for (int page = 0; page < dirtyPage; page++) previousPages[page],
    ];
    final List<IRow> current = <IRow>[rows[startRow]];
    double usedHeight =
        marginHeight + rows[startRow].height + (rows[startRow].offsetY ?? 0);
    int inspected = 1;

    for (int index = startRow + 1; index < rows.length; index++) {
      final IRow row = rows[index];
      final double rowHeight = row.height + (row.offsetY ?? 0);
      final bool explicitBreak = rows[index - 1].isPageBreak == true;
      if (usedHeight + rowHeight > pageHeight || explicitBreak) {
        final int? oldPage = oldPageByFirstRow[current.first];
        if (oldPage != null && _sameRows(current, previousPages[oldPage])) {
          result.addAll(previousPages.sublist(oldPage));
          return PageRowAggregation(
            pages: result,
            inspectedRowCount: inspected,
            reusedPrefixPageCount: dirtyPage,
            reusedSuffixPageCount: previousPages.length - oldPage,
          );
        }
        result.add(List<IRow>.of(current));
        current
          ..clear()
          ..add(row);
        usedHeight = marginHeight + rowHeight;
      } else {
        current.add(row);
        usedHeight += rowHeight;
      }
      inspected += 1;
    }
    result.add(List<IRow>.of(current));
    return PageRowAggregation(
      pages: result,
      inspectedRowCount: inspected,
      reusedPrefixPageCount: dirtyPage,
      reusedSuffixPageCount: 0,
    );
  }

  static List<List<IRow>> _paginateRows(
    List<IRow> rows, {
    required int startRow,
    required double pageHeight,
    required double marginHeight,
    required bool firstRowStartsPage,
  }) {
    final List<List<IRow>> pages = <List<IRow>>[<IRow>[]];
    double usedHeight = marginHeight;
    int pageNo = 0;
    int index = startRow;

    if (firstRowStartsPage && index < rows.length) {
      final IRow first = rows[index];
      pages[0].add(first);
      usedHeight += first.height + (first.offsetY ?? 0);
      index += 1;
    }

    for (; index < rows.length; index++) {
      final IRow row = rows[index];
      final double rowHeight = row.height + (row.offsetY ?? 0);
      final bool explicitBreak =
          index > startRow && rows[index - 1].isPageBreak == true;
      if (usedHeight + rowHeight > pageHeight || explicitBreak) {
        pages.add(<IRow>[row]);
        pageNo += 1;
        usedHeight = marginHeight + rowHeight;
      } else {
        pages[pageNo].add(row);
        usedHeight += rowHeight;
      }
    }
    return pages;
  }
}

bool _sameRows(List<IRow> left, List<IRow> right) {
  if (left.length != right.length) return false;
  for (int index = 0; index < left.length; index++) {
    if (!identical(left[index], right[index])) return false;
  }
  return true;
}
