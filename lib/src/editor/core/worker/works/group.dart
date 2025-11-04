import '../../../dataset/enum/element.dart';
import '../../../interface/element.dart';
import '../../../interface/table/td.dart';
import '../../../interface/table/tr.dart';

/// Returns the unique set of group identifiers referenced by the given
/// element list, including any nested table content.
List<String> computeGroupIds(List<IElement> elementList) {
	final Set<String> groupIds = <String>{};
	void collect(List<IElement> elements) {
		for (final IElement element in elements) {
			if (element.type == ElementType.table && element.trList != null) {
				for (final ITr tr in element.trList!) {
					for (final ITd td in tr.tdList) {
						collect(td.value);
					}
				}
			}
			final List<String>? currentGroupIds = element.groupIds;
			if (currentGroupIds != null) {
				groupIds.addAll(currentGroupIds);
			}
		}
	}
	collect(elementList);
	return groupIds.toList();
}