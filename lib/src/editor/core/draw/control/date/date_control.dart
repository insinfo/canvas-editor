import 'dart:html';

import '../../../../dataset/enum/control.dart';
import '../../../../dataset/enum/element.dart';
import '../../../../dataset/enum/key_map.dart';
import '../../../../interface/control.dart';
import '../../../../interface/editor.dart';
import '../../../../interface/element.dart';
import '../../../../interface/range.dart';
import '../../../../utils/element.dart' as element_utils;
import '../../draw.dart';
import '../../particle/date/date_picker.dart';
import '../control.dart';

class DateControl implements IControlInstance {
	DateControl(this._element, this._control)
			: _draw = _control.getDraw(),
				_options = _control.getDraw().getOptions();

	IElement _element;
	final Control _control;
	final Draw _draw;
	final IEditorOption _options;
	bool _isPopup = false;
	DatePicker? _datePicker;

	Control get control => _control;
	Draw get draw => _draw;
	bool get isPopup => _isPopup;

	@override
	void setElement(IElement element) {
		_element = element;
	}

	@override
	IElement getElement() => _element;

	bool getIsPopup() => _isPopup;

	List<int>? getValueRange({IControlContext? context}) {
		final IControlContext ctx = context ?? IControlContext();
		final List<IElement> elementList =
				ctx.elementList ?? _control.getElementList();
		final IRange range = ctx.range ?? _control.getRange();
		final int startIndex = range.startIndex;
		if (startIndex < 0 || startIndex >= elementList.length) {
			return null;
		}
		final IElement startElement = elementList[startIndex];

		int preIndex = startIndex;
		while (preIndex > 0) {
			final IElement preElement = elementList[preIndex];
			if (preElement.controlId != startElement.controlId ||
					preElement.controlComponent == ControlComponent.prefix ||
					preElement.controlComponent == ControlComponent.preText) {
				break;
			}
			preIndex -= 1;
		}

		int nextIndex = startIndex + 1;
		while (nextIndex < elementList.length) {
			final IElement nextElement = elementList[nextIndex];
			if (nextElement.controlId != startElement.controlId ||
					nextElement.controlComponent == ControlComponent.postfix ||
					nextElement.controlComponent == ControlComponent.postText) {
				break;
			}
			nextIndex += 1;
		}

		if (preIndex == nextIndex) {
			return null;
		}
		return <int>[preIndex, nextIndex - 1];
	}

	@override
	List<IElement> getValue({IControlContext? context}) {
		final IControlContext ctx = context ?? IControlContext();
		final List<IElement> elementList =
				ctx.elementList ?? _control.getElementList();
		final List<int>? range = getValueRange(context: ctx);
		if (range == null) {
			return <IElement>[];
		}
		final int start = range[0];
		final int end = range[1];
		final List<IElement> data = <IElement>[];
		for (int i = start; i <= end; i++) {
			final IElement element = elementList[i];
			if (element.controlComponent == ControlComponent.value) {
				data.add(element);
			}
		}
		return data;
	}

	@override
	int setValue(
		List<IElement> data, {
		IControlContext? context,
		IControlRuleOption? options,
	}) {
		final IControlContext ctx = context ?? IControlContext();
		final IControlRuleOption rule = options ?? IControlRuleOption();
		final bool isIgnoreDisabledRule = rule.isIgnoreDisabledRule ?? false;
		if (!isIgnoreDisabledRule && _control.getIsDisabledControl(ctx)) {
			return -1;
		}

		final List<IElement> elementList =
				ctx.elementList ?? _control.getElementList();
		final IRange range = ctx.range ?? _control.getRange();

		_control.shrinkBoundary(ctx);

		final int startIndex = range.startIndex;
		final int endIndex = range.endIndex;
		if (startIndex < 0 || startIndex >= elementList.length) {
			return -1;
		}
		final IElement startElement = elementList[startIndex];

		if (startIndex != endIndex) {
			_draw.spliceElementList(
				elementList,
				startIndex + 1,
				endIndex - startIndex,
			);
		} else {
			_control.removePlaceholder(startIndex, ctx);
		}

		final int insertBaseIndex = startIndex + 1;
		for (int i = 0; i < data.length; i++) {
			final IElement newElement = _cloneValueElement(data[i], startElement);

			element_utils.formatElementContext(
				elementList,
				<IElement>[newElement],
				startIndex,
				options: element_utils.FormatElementContextOption(
					editorOptions: _options,
				),
			);

			_draw.spliceElementList(
				elementList,
				insertBaseIndex + i,
				0,
				<IElement>[newElement],
			);
		}

		return insertBaseIndex + data.length - 1;
	}

	int clearSelect({
		IControlContext? context,
		IControlRuleOption? options,
	}) {
		final IControlContext ctx = context ?? IControlContext();
		final IControlRuleOption rule = options ?? IControlRuleOption();
		final bool isIgnoreDisabledRule = rule.isIgnoreDisabledRule ?? false;
		if (!isIgnoreDisabledRule && _control.getIsDisabledControl(ctx)) {
			return -1;
		}
		final List<int>? range = getValueRange(context: ctx);
		if (range == null) {
			return -1;
		}
		final int leftIndex = range[0];
		final int rightIndex = range[1];
		if (leftIndex < 0 || rightIndex < leftIndex) {
			return -1;
		}

		final List<IElement> elementList =
				ctx.elementList ?? _control.getElementList();
		_draw.spliceElementList(
			elementList,
			leftIndex + 1,
			rightIndex - leftIndex,
		);

		final bool shouldAddPlaceholder = rule.isAddPlaceholder ?? true;
		if (shouldAddPlaceholder) {
			_control.addPlaceholder(leftIndex, ctx);
		}
		return leftIndex;
	}

	void setSelect(
		String date, {
		IControlContext? context,
		IControlRuleOption? options,
	}) {
		final IControlContext ctx = context ?? IControlContext();
		final IControlRuleOption rule = options ?? IControlRuleOption();
		final bool isIgnoreDisabledRule = rule.isIgnoreDisabledRule ?? false;
		if (!isIgnoreDisabledRule && _control.getIsDisabledControl(ctx)) {
			return;
		}

		final List<IElement> elementList =
				ctx.elementList ?? _control.getElementList();
		final IRange range = ctx.range ?? _control.getRange();
		final List<IElement> currentValue = getValue(context: ctx);
		final IElement? valueElement =
				currentValue.isNotEmpty ? currentValue.first : null;

		final IElement styleSource = valueElement ?? elementList[range.startIndex];

		final int prefixIndex = clearSelect(
			context: ctx,
			options: IControlRuleOption(
				isAddPlaceholder: false,
				isIgnoreDeletedRule: rule.isIgnoreDeletedRule,
			),
		);
		if (prefixIndex < 0) {
			return;
		}

		final IElement propertySource = elementList[prefixIndex];
		final int start = prefixIndex + 1;

		for (int i = 0; i < date.length; i++) {
			final String char = date[i];
			final IElement newElement = IElement(
				value: char,
				type: ElementType.text,
				control: propertySource.control,
				controlId: propertySource.controlId,
				controlComponent: ControlComponent.value,
			);
			_applyStyle(newElement, styleSource, propertySource);

			element_utils.formatElementContext(
				elementList,
				<IElement>[newElement],
				prefixIndex,
				options: element_utils.FormatElementContextOption(
					editorOptions: _options,
				),
			);

			_draw.spliceElementList(
				elementList,
				start + i,
				0,
				<IElement>[newElement],
			);
		}

		if (context?.range == null) {
			final int newIndex = start + date.length - 1;
			_control.repaintControl(
				IRepaintControlOption(curIndex: newIndex),
			);
			_control.emitControlContentChange(
				IControlChangeOption(context: ctx),
			);
			destroy();
		}
	}

	@override
	int? keydown(dynamic evt) {
		if (_control.getIsDisabledControl()) {
			return null;
		}
		final List<IElement> elementList = _control.getElementList();
		final IRange range = _control.getRange();

		_control.shrinkBoundary();

		final int startIndex = range.startIndex;
		final int endIndex = range.endIndex;
		if (startIndex < 0 || startIndex >= elementList.length) {
			return endIndex;
		}
		if (endIndex < 0 || endIndex >= elementList.length) {
			return endIndex;
		}

		final IElement startElement = elementList[startIndex];
		final IElement endElement = elementList[endIndex];
		final KeyboardEvent? keyboardEvent = evt as KeyboardEvent?;
		final String? key = keyboardEvent?.key;

		if (key == KeyMap.backspace.value) {
			if (startIndex != endIndex) {
				_draw.spliceElementList(
					elementList,
					startIndex + 1,
					endIndex - startIndex,
				);
				final List<IElement> value = getValue();
				if (value.isEmpty) {
					_control.addPlaceholder(startIndex);
				}
				return startIndex;
			}

			final bool shouldRemoveControl =
					startElement.controlComponent == ControlComponent.prefix ||
							startElement.controlComponent == ControlComponent.preText ||
							endElement.controlComponent == ControlComponent.postfix ||
							endElement.controlComponent == ControlComponent.postText ||
							startElement.controlComponent == ControlComponent.placeholder;
			if (shouldRemoveControl) {
				return _control.removeControl(startIndex);
			}

			_draw.spliceElementList(elementList, startIndex, 1);
			final List<IElement> value = getValue();
			if (value.isEmpty) {
				_control.addPlaceholder(startIndex - 1);
			}
			return startIndex - 1;
		}

		if (key == KeyMap.delete.value) {
			if (startIndex != endIndex) {
				_draw.spliceElementList(
					elementList,
					startIndex + 1,
					endIndex - startIndex,
				);
				final List<IElement> value = getValue();
				if (value.isEmpty) {
					_control.addPlaceholder(startIndex);
				}
				return startIndex;
			}

			final int deleteIndex = endIndex + 1;
			final IElement? endNextElement =
					deleteIndex < elementList.length ? elementList[deleteIndex] : null;
			final bool shouldRemoveControl =
					((startElement.controlComponent == ControlComponent.prefix ||
									startElement.controlComponent == ControlComponent.preText) &&
							endNextElement?.controlComponent ==
									ControlComponent.placeholder) ||
							endNextElement?.controlComponent == ControlComponent.postfix ||
							endNextElement?.controlComponent == ControlComponent.postText ||
							startElement.controlComponent == ControlComponent.placeholder;
			if (shouldRemoveControl) {
				return _control.removeControl(startIndex);
			}

			_draw.spliceElementList(elementList, startIndex + 1, 1);
			final List<IElement> value = getValue();
			if (value.isEmpty) {
				_control.addPlaceholder(startIndex);
			}
			return startIndex;
		}

		return endIndex;
	}

	@override
	int cut() {
		if (_control.getIsDisabledControl()) {
			return -1;
		}
		_control.shrinkBoundary();
		final IRange range = _control.getRange();
		final int startIndex = range.startIndex;
		final int endIndex = range.endIndex;
		if (startIndex == endIndex) {
			return startIndex;
		}

		final List<IElement> elementList = _control.getElementList();
		_draw.spliceElementList(
			elementList,
			startIndex + 1,
			endIndex - startIndex,
		);
		final List<IElement> value = getValue();
		if (value.isEmpty) {
			_control.addPlaceholder(startIndex);
		}
		return startIndex;
	}

	void awake() {
		if (_isPopup ||
				_control.getIsDisabledControl() ||
				!_control.getIsRangeWithinControl()) {
			return;
		}

		final IElementPosition? position = _control.getPosition();
		if (position == null) {
			return;
		}

		final List<IElement> elementList = _draw.getElementList();
		final IRange range = _control.getRange();
		final int startIndex = range.startIndex;
		if (startIndex < 0 || startIndex + 1 >= elementList.length) {
			return;
		}
		if (elementList[startIndex + 1].controlId != _element.controlId) {
			return;
		}

		_datePicker = DatePicker(
			_draw,
			IDatePickerOption(onSubmit: _setDate),
		);
		final String value =
				getValue().map((IElement element) => element.value).join();
		final String? dateFormat = _element.control?.dateFormat;
		_datePicker?.render(
			DatePickerRenderOption(
				value: value,
				position: position,
				dateFormat: dateFormat,
			),
		);
		_isPopup = true;
	}

	void destroy() {
		if (!_isPopup) {
			return;
		}
		_datePicker?.destroy();
		_datePicker = null;
		_isPopup = false;
	}

	void _setDate(String date) {
		if (date.isEmpty) {
			clearSelect();
		} else {
			setSelect(date);
		}
		destroy();
	}

	IElement _cloneValueElement(IElement source, IElement anchor) {
		final List<IElement> clonedList =
				element_utils.cloneElementList(<IElement>[source]);
		final IElement valueElement = clonedList.first
			..control = anchor.control
			..controlId = anchor.controlId
			..controlComponent = ControlComponent.value
			..type = source.type ?? anchor.type ?? ElementType.text;

		if (valueElement.font == null && anchor.font != null) {
			valueElement.font = anchor.font;
		}
		if (valueElement.size == null && anchor.size != null) {
			valueElement.size = anchor.size;
		}
		if (valueElement.bold == null && anchor.bold != null) {
			valueElement.bold = anchor.bold;
		}
		if (valueElement.color == null && anchor.color != null) {
			valueElement.color = anchor.color;
		}
		if (valueElement.highlight == null && anchor.highlight != null) {
			valueElement.highlight = anchor.highlight;
		}
		if (valueElement.italic == null && anchor.italic != null) {
			valueElement.italic = anchor.italic;
		}
		if (valueElement.underline == null && anchor.underline != null) {
			valueElement.underline = anchor.underline;
		}
		if (valueElement.strikeout == null && anchor.strikeout != null) {
			valueElement.strikeout = anchor.strikeout;
		}
		if (valueElement.rowFlex == null && anchor.rowFlex != null) {
			valueElement.rowFlex = anchor.rowFlex;
		}
		if (valueElement.rowMargin == null && anchor.rowMargin != null) {
			valueElement.rowMargin = anchor.rowMargin;
		}
		if (valueElement.letterSpacing == null && anchor.letterSpacing != null) {
			valueElement.letterSpacing = anchor.letterSpacing;
		}
		valueElement.textDecoration ??= anchor.textDecoration;
		return valueElement;
	}

	void _applyStyle(
		IElement target,
		IElement primary,
		IElement fallback,
	) {
		target.font = primary.font ?? fallback.font;
		target.size = primary.size ?? fallback.size;
		target.bold = primary.bold ?? fallback.bold;
		target.color = primary.color ?? fallback.color;
		target.highlight = primary.highlight ?? fallback.highlight;
		target.italic = primary.italic ?? fallback.italic;
		target.underline = primary.underline ?? fallback.underline;
		target.strikeout = primary.strikeout ?? fallback.strikeout;
		target.rowFlex = primary.rowFlex ?? fallback.rowFlex;
		target.rowMargin = primary.rowMargin ?? fallback.rowMargin;
		target.letterSpacing = primary.letterSpacing ?? fallback.letterSpacing;
		target.textDecoration = primary.textDecoration ?? fallback.textDecoration;
	}
}