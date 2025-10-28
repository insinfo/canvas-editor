import 'dart:js_util' as js_util;

import '../../../dataset/enum/element.dart';
import '../../../interface/editor.dart';
import '../../../interface/element.dart';
import '../../../interface/event.dart';
import '../../../interface/table/td.dart';
import '../../../interface/range.dart';
import '../../../utils/clipboard.dart';
import '../../../utils/element.dart' as element_utils;

Future<void> copy(dynamic host, [ICopyOption? options]) async {
  final dynamic draw = host.getDraw();
  final dynamic override = draw.getOverride();
  final dynamic overrideCopy = override?.copy;
  if (overrideCopy is Function) {
    final dynamic overrideResult = overrideCopy();
    if (_shouldPreventDefault(overrideResult)) {
      return;
    }
  }

  final dynamic rangeManager = draw.getRange();
  final IRange range = rangeManager.getRange() as IRange;
  List<IElement>? copyElementList;

  if (range.isCrossRowCol == true) {
    final IElement? tableElement =
        rangeManager.getRangeTableElement() as IElement?;
    if (tableElement == null) {
      return;
    }
    final dynamic tableParticle = draw.getTableParticle();
    final dynamic rowColRaw = tableParticle?.getRangeRowCol();
    if (rowColRaw == null) {
      return;
    }
    final List<List<ITd>> rowCol = _normalizeRowCol(rowColRaw);
    if (rowCol.isEmpty || rowCol.first.isEmpty) {
      return;
    }
    final ITd firstCell = rowCol.first.first;
    final ITd lastCell = rowCol.first.last;
    final int? colStartIndex = firstCell.colIndex;
    final int? colEndIndex = lastCell.colIndex == null
        ? null
        : lastCell.colIndex! + lastCell.colspan - 1;
    if (colStartIndex == null || colEndIndex == null) {
      return;
    }
    final IElement copyTableElement = IElement(
      type: ElementType.table,
      value: '',
      colgroup: <IColgroup>[],
      trList: <ITr>[],
    );
    final List<IColgroup>? colgroup = tableElement.colgroup;
    if (colgroup != null && colgroup.isNotEmpty) {
      for (var c = colStartIndex;
          c <= colEndIndex && c >= 0 && c < colgroup.length;
          c++) {
        copyTableElement.colgroup!.add(colgroup[c]);
      }
    }
    final List<ITr>? trList = tableElement.trList;
    if (trList == null || trList.isEmpty) {
      return;
    }
    for (final List<ITd> row in rowCol) {
      if (row.isEmpty) {
        continue;
      }
      final int? rowIndex = row.first.rowIndex;
      if (rowIndex == null || rowIndex < 0 || rowIndex >= trList.length) {
        continue;
      }
      final ITr templateTr = trList[rowIndex];
      final ITr copyTr = ITr(
        tdList: <ITd>[],
        height: templateTr.height,
        minHeight: templateTr.minHeight,
      );
      for (final ITd cell in row) {
        copyTr.tdList.add(cell);
      }
      copyTableElement.trList!.add(copyTr);
    }
    copyElementList =
        element_utils.zipElementList(<IElement>[copyTableElement]);
  } else {
    final bool isCollapsed = rangeManager.getIsCollapsed() == true;
    final dynamic sourceList = isCollapsed
        ? rangeManager.getRangeRowElementList()
        : rangeManager.getSelectionElementList();
    copyElementList = (sourceList as List?)?.cast<IElement>();
  }

  if (options?.isPlainText == true && (copyElementList?.isNotEmpty ?? false)) {
    final String text = element_utils.getTextFromElementList(copyElementList!);
    copyElementList = <IElement>[IElement(value: text)];
  }

  if (copyElementList == null || copyElementList.isEmpty) {
    return;
  }

  await writeElementList(
    copyElementList,
    draw.getOptions() as IEditorOption,
  );
}

bool _shouldPreventDefault(dynamic overrideResult) {
  if (overrideResult == null) {
    return false;
  }
  if (overrideResult is Map) {
    final dynamic value = overrideResult['preventDefault'];
    return value != null && value != false;
  }
  try {
    if (js_util.hasProperty(overrideResult, 'preventDefault')) {
      final dynamic value =
          js_util.getProperty(overrideResult, 'preventDefault');
      if (value != null && value != false) {
        return true;
      }
    }
  } catch (_) {
    // ignore interop read failure
  }
  try {
    final dynamic value = overrideResult.preventDefault;
    return value != null && value != false;
  } catch (_) {
    // ignore missing field
  }
  return false;
}

List<List<ITd>> _normalizeRowCol(dynamic payload) {
  if (payload is! List) {
    return <List<ITd>>[];
  }
  final List<List<ITd>> result = <List<ITd>>[];
  for (final dynamic row in payload) {
    if (row is List) {
      final List<ITd> cells = row.whereType<ITd>().toList();
      if (cells.isNotEmpty) {
        result.add(cells);
      }
    }
  }
  return result;
}
