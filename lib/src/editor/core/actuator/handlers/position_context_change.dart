import '../../../interface/listener.dart';
import '../../../interface/position.dart';
import '../../draw/draw.dart';

/// Handles cross-module updates when the caret context transitions.
void positionContextChange(
	Draw draw,
	IPositionContextChangePayload payload,
) {
	final IPositionContext value = payload.value;
	final IPositionContext oldValue = payload.oldValue;
	if (oldValue.isTable && !value.isTable) {
		final dynamic tableTool = draw.getTableTool();
		if (tableTool != null) {
			final dynamic dispose = tableTool.dispose;
			if (dispose is Function) {
				dispose();
			}
		}
	}
}