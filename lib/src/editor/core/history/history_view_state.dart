import '../../dataset/enum/editor.dart';
import '../../interface/position.dart';
import '../../interface/range.dart';

/// UI/navigation state associated with a reversible document endpoint.
///
/// Document deltas deliberately do not know about the editor UI. Keeping this
/// small value beside a history transition makes a composite endpoint restore
/// the correct zone and table context without taking another document clone.
class HistoryViewState {
  const HistoryViewState({
    required this.zone,
    required this.positionContext,
    required this.range,
    required this.pageNo,
  });

  final EditorZone zone;
  final IPositionContext positionContext;
  final IRange range;
  final int pageNo;
}
