import '../../../dataset/constant/common.dart';
import '../../../dataset/enum/control.dart';
import '../../../dataset/enum/element.dart';
import '../../../interface/element.dart';
import '../../../interface/table/td.dart';
import '../../../interface/table/tr.dart';

const String _wrap = '\n';

/// Computes the number of logical characters within the provided element list.
///
/// Mirrors the original Web Worker implementation by flattening structured
/// elements (tables, hyperlinks, controls) and collapsing alphanumeric runs
/// into single units for the final count.
int computeWordCount(List<IElement> elementList) {
	final String originText = _pickText(elementList);
	final String filterText = originText
		.replaceFirst(RegExp('^$ZERO'), '')
		.replaceAll(ZERO, _wrap);
	final List<String> grouped = _groupText(filterText);
	return grouped.length;
}

String _pickText(List<IElement> elementList) {
	final StringBuffer buffer = StringBuffer();
	int index = 0;
	while (index < elementList.length) {
		final IElement element = elementList[index];
		if (element.type == ElementType.table && element.trList != null) {
			for (final ITr tr in element.trList!) {
				for (final ITd td in tr.tdList) {
					buffer.write(_pickText(td.value));
				}
			}
		} else if (element.type == ElementType.hyperlink &&
				element.hyperlinkId != null) {
			final String hyperlinkId = element.hyperlinkId!;
			final List<IElement> valueList = <IElement>[];
			while (index < elementList.length) {
				final IElement hyperlinkElement = elementList[index];
				if (hyperlinkElement.hyperlinkId != hyperlinkId) {
					index -= 1;
					break;
				}
				valueList.add(_cloneAsTextElement(hyperlinkElement));
				index += 1;
			}
			buffer.write(_pickText(valueList));
		} else if (element.controlId != null) {
			final bool isHiddenControl = element.control?.hide == true;
			if (!isHiddenControl) {
				final String controlId = element.controlId!;
				final List<IElement> valueList = <IElement>[];
				while (index < elementList.length) {
					final IElement controlElement = elementList[index];
					if (controlElement.controlId != controlId) {
						index -= 1;
						break;
					}
					if (controlElement.controlComponent == ControlComponent.value) {
						valueList.add(_cloneAsTextElement(controlElement));
					}
					index += 1;
				}
				buffer.write(_pickText(valueList));
			}
		} else if ((element.type == null || element.type == ElementType.text) &&
				element.area?.hide != true) {
			buffer.write(element.value);
		}
		index += 1;
	}
	return buffer.toString();
}

IElement _cloneAsTextElement(IElement source) {
	return IElement(value: source.value)
		..area = source.area
		..areaId = source.areaId;
}

List<String> _groupText(String text) {
	final List<String> characterList = <String>[];
	final RegExp numberReg = RegExp(r'[0-9]');
	final RegExp letterReg = RegExp(r'[A-Za-z]');
	final RegExp blankReg = RegExp(r'\s');
	bool isPreviousLetter = false;
	bool isPreviousNumber = false;
	final StringBuffer composition = StringBuffer();

	void pushComposition() {
		if (composition.isEmpty) {
			return;
		}
		characterList.add(composition.toString());
		composition.clear();
	}

	for (int i = 0; i < text.length; i++) {
		final String char = text[i];
		if (letterReg.hasMatch(char)) {
			if (!isPreviousLetter) {
				pushComposition();
			}
			composition.write(char);
			isPreviousLetter = true;
			isPreviousNumber = false;
		} else if (numberReg.hasMatch(char)) {
			if (!isPreviousNumber) {
				pushComposition();
			}
			composition.write(char);
			isPreviousLetter = false;
			isPreviousNumber = true;
		} else {
			pushComposition();
			isPreviousLetter = false;
			isPreviousNumber = false;
			if (!blankReg.hasMatch(char)) {
				characterList.add(char);
			}
		}
	}
	pushComposition();
	return characterList;
}
