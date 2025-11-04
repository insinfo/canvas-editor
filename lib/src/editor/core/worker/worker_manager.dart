import 'dart:async';

import '../../interface/catalog.dart';
import '../../interface/draw.dart';
import '../../interface/editor.dart';
import '../../interface/element.dart' show IElement, IElementPosition;
import '../../utils/option.dart' as option_utils;
import '../draw/draw.dart';
import 'works/catalog.dart';
import 'works/group.dart';
import 'works/value.dart';
import 'works/word_count.dart';

const String _packageVersion = String.fromEnvironment(
  'CANVAS_EDITOR_VERSION',
  defaultValue: 'dev',
);

class WorkerManager {
  WorkerManager(this._draw);

  final Draw _draw;

  IEditorOption _cloneEditorOptions() {
    return option_utils.mergeOption(_draw.getOptions());
  }

  Future<T> _runAsync<T>(T Function() callback) => Future<T>(callback);

  Future<int> getWordCount() {
    final List<IElement> elementList =
        List<IElement>.from(_draw.getOriginalMainElementList());
    return _runAsync<int>(() => computeWordCount(elementList));
  }

  Future<ICatalog?> getCatalog() {
    final List<IElement> elementList =
        List<IElement>.from(_draw.getOriginalMainElementList());
    final dynamic position = _draw.getPosition();
    final List<dynamic> rawPositionList =
        (position?.getOriginalMainPositionList() as List?) ?? const <dynamic>[];
    final List<IElementPosition> positionList =
        rawPositionList.whereType<IElementPosition>().toList();
    return _runAsync<ICatalog?>(
        () => computeCatalog(elementList, positionList));
  }

  Future<List<String>> getGroupIds() {
    final List<IElement> elementList =
        List<IElement>.from(_draw.getOriginalMainElementList());
    return _runAsync<List<String>>(() => computeGroupIds(elementList));
  }

  Future<IEditorResult> getValue([IGetValueOption? options]) {
    return _runAsync<IEditorResult>(() {
      final IEditorData originData = _draw.getOriginValue(options);
      final IEditorData data = computeZippedValue(originData, options);
      return IEditorResult(
        version: _packageVersion,
        data: data,
        options: _cloneEditorOptions(),
      );
    });
  }
}
