import '../../../../dataset/enum/element.dart';
import '../../../../interface/editor.dart';
import '../../../../interface/element.dart';
import '../../../../interface/range.dart';
import '../../../../utils/element.dart' as element_utils;
import '../../draw.dart';
import '../../../range/range_manager.dart';
import 'date_picker.dart';

class DateParticle {
	DateParticle(Draw draw)
		: _draw = draw,
			_options = draw.getOptions(),
			_range = draw.getRange() as RangeManager {
		_datePicker = DatePicker(
			draw,
			IDatePickerOption(onSubmit: _setValue),
		);
	}

	final Draw _draw;
	final IEditorOption _options;
	final RangeManager _range;
	late final DatePicker _datePicker;

	void _setValue(String date) {
		if (date.isEmpty) {
			return;
		}
		final List<int>? range = getDateElementRange();
		if (range == null || range.length < 2) {
			return;
		}
		final int leftIndex = range[0];
		final int rightIndex = range[1];
		final List<IElement> elementList = _draw.getElementList();
		if (leftIndex + 1 >= elementList.length) {
			return;
		}
		final IElement startElement = elementList[leftIndex + 1];
		_draw.spliceElementList(
			elementList,
			leftIndex + 1,
			rightIndex - leftIndex,
		);
		_range.setRange(leftIndex, leftIndex);
		final IElement dateElement = IElement(
			type: ElementType.date,
			value: '',
			dateFormat: startElement.dateFormat,
			valueList: <IElement>[IElement(value: date)],
		);
		element_utils.formatElementContext(
			elementList,
			<IElement>[dateElement],
			leftIndex,
			options: element_utils.FormatElementContextOption(
				editorOptions: _options,
			),
		);
		(_draw as dynamic).insertElementList(<IElement>[dateElement]);
	}

	List<int>? getDateElementRange() {
		int leftIndex = -1;
		int rightIndex = -1;
		final IRange range = _range.getRange();
		final int startIndex = range.startIndex;
		final int endIndex = range.endIndex;
		if (startIndex < 0 && endIndex < 0) {
			return null;
		}
		final List<IElement> elementList = _draw.getElementList();
		if (startIndex < 0 || startIndex >= elementList.length) {
			return null;
		}
		final IElement startElement = elementList[startIndex];
		if (startElement.type != ElementType.date) {
			return null;
		}
		final String? dateId = startElement.dateId;
		int preIndex = startIndex;
		while (preIndex >= 0) {
			final IElement preElement = elementList[preIndex];
			if (preElement.dateId != dateId) {
				leftIndex = preIndex;
				break;
			}
			preIndex -= 1;
		}
		int nextIndex = startIndex + 1;
		while (nextIndex < elementList.length) {
			final IElement nextElement = elementList[nextIndex];
			if (nextElement.dateId != dateId) {
				rightIndex = nextIndex - 1;
				break;
			}
			nextIndex += 1;
		}
		if (nextIndex == elementList.length) {
			rightIndex = nextIndex - 1;
		}
		if (leftIndex < 0 || rightIndex < 0) {
			return null;
		}
		return <int>[leftIndex, rightIndex];
	}

	void clearDatePicker() {
		_datePicker.dispose();
	}

	void renderDatePicker(IElement element, IElementPosition position) {
		final List<IElement> elementList = _draw.getElementList();
		final List<int>? range = getDateElementRange();
		final String value = range == null
			? ''
			: elementList
					.sublist(range[0] + 1, range[1] + 1)
					.map((IElement el) => el.value)
					.join();
		_datePicker.render(
			DatePickerRenderOption(
				value: value,
				position: position,
				dateFormat: element.dateFormat,
			),
		);
	}
}