import 'dart:html';

import '../../../../dataset/constant/editor.dart' as editor_constants;
import '../../../../dataset/enum/control.dart';
import '../../../../dataset/enum/editor.dart';
import '../../../../dataset/enum/element.dart';
import '../../../../dataset/enum/key_map.dart';
import '../../../../interface/control.dart';
import '../../../../interface/editor.dart';
import '../../../../interface/element.dart';
import '../../../../interface/range.dart';
import '../../../../utils/element.dart' as element_utils;
import '../../../../utils/index.dart' as utils;
import '../../draw.dart';
import '../control.dart';

class SelectControl implements IControlInstance {
	SelectControl(this._element, this._control)
			: _draw = _control.getDraw(),
				_options = _control.getDraw().getOptions();

	static const String _valueDelimiter = ',';
	static const String _defaultMultiSelectDelimiter = ',';

	IElement _element;
	final Control _control;
	final Draw _draw;
	final IEditorOption _options;
	bool _isPopup = false;
	DivElement? _selectDom;

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

	List<String> getCodes() {
		final String? raw = _element.control?.code;
		if (raw == null || raw.isEmpty) {
			return <String>[];
		}
		return raw.split(_valueDelimiter).where((String code) => code.isNotEmpty).toList();
	}

	String? getText(List<String> codes) {
		final IControl? controlData = _element.control;
		if (controlData == null || controlData.valueSets.isEmpty) {
			return null;
		}
		final String delimiter =
				controlData.multiSelectDelimiter ?? _defaultMultiSelectDelimiter;
		final List<String> valueList = <String>[];
		for (final String code in codes) {
			IValueSet? matched;
			for (final IValueSet valueSet in controlData.valueSets) {
				if (valueSet.code == code) {
					matched = valueSet;
					break;
				}
			}
			if (matched != null && !utils.isNonValue(matched.value)) {
				valueList.add(matched.value);
			}
		}
		if (valueList.isEmpty) {
			return null;
		}
		return valueList.join(delimiter);
	}

	@override
	List<IElement> getValue({IControlContext? context}) {
		final IControlContext ctx = context ?? IControlContext();
		final List<IElement> elementList =
				ctx.elementList ?? _control.getElementList();
		final IRange range = ctx.range ?? _control.getRange();
		final int startIndex = range.startIndex;
		if (startIndex < 0 || startIndex >= elementList.length) {
			return <IElement>[];
		}
		final IElement startElement = elementList[startIndex];
		final List<IElement> data = <IElement>[];

		int preIndex = startIndex;
		while (preIndex > 0) {
			final IElement preElement = elementList[preIndex];
			if (preElement.controlId != startElement.controlId ||
					preElement.controlComponent == ControlComponent.prefix ||
					preElement.controlComponent == ControlComponent.preText) {
				break;
			}
			if (preElement.controlComponent == ControlComponent.value) {
				data.insert(0, preElement);
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
			if (nextElement.controlComponent == ControlComponent.value) {
				data.add(nextElement);
			}
			nextIndex += 1;
		}
		return data;
	}

	@override
	int setValue(
		List<IElement> data, {
		IControlContext? context,
		IControlRuleOption? options,
	}) {
		final IControl? controlData = _element.control;
		final bool inputAble =
				controlData?.selectExclusiveOptions?['inputAble'] ?? true;
		final IControlContext ctx = context ?? IControlContext();
		final IControlRuleOption rule = options ?? IControlRuleOption();
		final bool isIgnoreDisabledRule = rule.isIgnoreDisabledRule ?? false;
		if (!inputAble ||
				(!isIgnoreDisabledRule && _control.getIsDisabledControl(ctx))) {
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
				return clearSelect();
			}
					if (startElement.controlComponent == ControlComponent.prefix ||
							startElement.controlComponent == ControlComponent.preText ||
							endElement.controlComponent == ControlComponent.postfix ||
							endElement.controlComponent == ControlComponent.postText ||
							startElement.controlComponent == ControlComponent.placeholder) {
						return _control.removeControl(startIndex);
			}
			return clearSelect();
		}

		if (key == KeyMap.delete.value) {
			if (startIndex != endIndex) {
				return clearSelect();
			}
			final int deleteIndex = endIndex + 1;
			final IElement? endNextElement =
					deleteIndex < elementList.length ? elementList[deleteIndex] : null;
		      if (((startElement.controlComponent == ControlComponent.prefix ||
			      startElement.controlComponent == ControlComponent.preText) &&
			      endNextElement?.controlComponent ==
				  ControlComponent.placeholder) ||
			  endNextElement?.controlComponent == ControlComponent.postfix ||
			  endNextElement?.controlComponent == ControlComponent.postText ||
			  startElement.controlComponent == ControlComponent.placeholder) {
			return _control.removeControl(startIndex);
			}
			return clearSelect();
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
		return clearSelect();
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

		final List<IElement> elementList =
				ctx.elementList ?? _control.getElementList();
		final IRange range = ctx.range ?? _control.getRange();
		final int startIndex = range.startIndex;
		if (startIndex < 0 || startIndex >= elementList.length) {
			return -1;
		}
		final IElement startElement = elementList[startIndex];

		int leftIndex = -1;
		int rightIndex = -1;
		int preIndex = startIndex;

		while (preIndex > 0) {
			final IElement preElement = elementList[preIndex];
			if (preElement.controlId != startElement.controlId ||
					preElement.controlComponent == ControlComponent.prefix ||
					preElement.controlComponent == ControlComponent.preText) {
				leftIndex = preIndex;
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
				rightIndex = nextIndex - 1;
				break;
			}
			nextIndex += 1;
		}

		if (rightIndex == -1 && nextIndex == elementList.length) {
			rightIndex = elementList.length - 1;
		}

		if (leftIndex < 0 || rightIndex < 0 || rightIndex < leftIndex) {
			return -1;
		}

		_draw.spliceElementList(
			elementList,
			leftIndex + 1,
			rightIndex - leftIndex,
			null,
			ISpliceElementListOption(
				isIgnoreDeletedRule: rule.isIgnoreDeletedRule,
			),
		);

		if (rule.isAddPlaceholder ?? true) {
			_control.addPlaceholder(preIndex, ctx);
		}

		_control.setControlProperties(
			<String, dynamic>{'code': null},
			context: IControlContext(
				elementList: elementList,
				range: IRange(startIndex: preIndex, endIndex: preIndex),
			),
		);

		return preIndex;
	}

	void setSelect(
		String code, {
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
		final IControl? controlData = _element.control;
		if (controlData == null) {
			return;
		}

		final List<String> newCodes =
				code.isEmpty ? <String>[] : code.split(_valueDelimiter);
		final String? oldCode = controlData.code;
		final List<String> oldCodes =
				oldCode?.isEmpty ?? true ? <String>[] : oldCode!.split(_valueDelimiter);
		final bool isMultiSelect = controlData.isMultiSelect ?? false;

		if ((!isMultiSelect && code == oldCode) ||
				(isMultiSelect && utils.isArrayEqual(oldCodes, newCodes))) {
			_control.repaintControl(
				IRepaintControlOption(
					curIndex: range.startIndex,
					isCompute: false,
					isSubmitHistory: false,
				),
			);
			destroy();
			return;
		}

		final List<IValueSet> valueSets = controlData.valueSets;
		if (valueSets.isEmpty) {
			return;
		}

		final String? text = getText(newCodes);
		if (text == null) {
			if (oldCode != null && oldCode.isNotEmpty) {
				final int prefixIndex = clearSelect(
					context: ctx,
					options: IControlRuleOption(
						isIgnoreDeletedRule: rule.isIgnoreDeletedRule,
					),
				);
				if (prefixIndex >= 0) {
					_control.repaintControl(
						IRepaintControlOption(curIndex: prefixIndex),
					);
					_control.emitControlContentChange(
						IControlChangeOption(controlValue: <IElement>[]),
					);
				}
			}
			return;
		}

		final List<IElement> existingValue = getValue(context: ctx);
		final IElement? valueElement =
				existingValue.isNotEmpty ? existingValue.first : null;
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

		if (oldCode == null || oldCode.isEmpty) {
			_control.removePlaceholder(prefixIndex, ctx);
		}

		final IElement propertySource =
				elementList[prefixIndex];
		final IElement propertyElement =
				element_utils.cloneElementList(<IElement>[propertySource]).first;
		_clearStyle(propertyElement);

		final List<String> data = utils.splitText(text);
		final int start = prefixIndex + 1;

		for (int i = 0; i < data.length; i++) {
			final String value = data[i];
			final IElement newElement = element_utils
					.cloneElementList(<IElement>[propertyElement]).first
				..value = value
				..type = ElementType.text
				..control = propertySource.control
				..controlId = propertySource.controlId
				..controlComponent = ControlComponent.value;
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

		_control.setControlProperties(
			<String, dynamic>{'code': code},
			context: IControlContext(
				elementList: elementList,
				range: IRange(startIndex: prefixIndex, endIndex: prefixIndex),
			),
		);

		if (context?.range == null) {
			final int newIndex = start + data.length - 1;
			_control.repaintControl(IRepaintControlOption(curIndex: newIndex));
			_control.emitControlContentChange(IControlChangeOption(context: ctx));
			if (!isMultiSelect) {
				destroy();
			}
		}
	}

	void awake() {
		if (_isPopup ||
				_control.getIsDisabledControl() ||
				!_control.getIsRangeWithinControl()) {
			return;
		}

		final IRange range = _control.getRange();
		final List<IElement> elementList = _control.getElementList();
		final int startIndex = range.startIndex;
		if (startIndex < 0 || startIndex + 1 >= elementList.length) {
			return;
		}
		if (elementList[startIndex + 1].controlId != _element.controlId) {
			return;
		}
		_createSelectPopupDom();
		_isPopup = true;
	}

	void destroy() {
		if (!_isPopup) {
			return;
		}
		_selectDom?.remove();
		_selectDom = null;
		_isPopup = false;
	}

	void _createSelectPopupDom() {
		final IControl? controlData = _element.control;
		if (controlData == null || controlData.valueSets.isEmpty) {
			return;
		}
		final IElementPosition? position = _control.getPosition();
		if (position == null) {
			return;
		}

		final DivElement selectPopupContainer = DivElement()
			..classes.add('${editor_constants.editorPrefix}-select-control-popup')
			..setAttribute(
				editor_constants.editorComponent,
				EditorComponent.popup.name,
			);

		final UListElement ul = UListElement();
		for (final IValueSet valueSet in controlData.valueSets) {
			final LIElement li = LIElement();
			final List<String> currentCodes = getCodes();
			if (currentCodes.contains(valueSet.code)) {
				li.classes.add('active');
			}
			li.onClick.listen((MouseEvent event) {
				event.stopPropagation();
				final List<String> codes = List<String>.from(getCodes());
				final int index = codes.indexOf(valueSet.code);
				if (controlData.isMultiSelect == true) {
					if (index >= 0) {
						codes.removeAt(index);
					} else {
						codes.add(valueSet.code);
					}
				} else {
					if (index >= 0) {
						codes.clear();
					} else {
						codes
							..clear()
							..add(valueSet.code);
					}
				}
				setSelect(codes.join(_valueDelimiter));
			});
			li.appendText(valueSet.value);
			ul.append(li);
		}
		selectPopupContainer.append(ul);

		final List<double>? leftTop = position.coordinate['leftTop'];
		if (leftTop == null || leftTop.length < 2) {
			return;
		}
		final double left = leftTop[0];
		final double top = leftTop[1];
		final double preY = _control.getPreY();
		selectPopupContainer.style
			..left = '${left}px'
			..top = '${top + preY + position.lineHeight}px';

		_control.getContainer().append(selectPopupContainer);
		_selectDom = selectPopupContainer;
	}

	IElement _cloneValueElement(IElement source, IElement anchor) {
		final IElement clone =
				element_utils.cloneElementList(<IElement>[source]).first
					..control = anchor.control
					..controlId = anchor.controlId
					..controlComponent = ControlComponent.value
					..type = source.type ?? anchor.type ?? ElementType.text;

		if (clone.font == null && anchor.font != null) {
			clone.font = anchor.font;
		}
		if (clone.size == null && anchor.size != null) {
			clone.size = anchor.size;
		}
		if (clone.bold == null && anchor.bold != null) {
			clone.bold = anchor.bold;
		}
		if (clone.color == null && anchor.color != null) {
			clone.color = anchor.color;
		}
		if (clone.highlight == null && anchor.highlight != null) {
			clone.highlight = anchor.highlight;
		}
		if (clone.italic == null && anchor.italic != null) {
			clone.italic = anchor.italic;
		}
		if (clone.underline == null && anchor.underline != null) {
			clone.underline = anchor.underline;
		}
		if (clone.strikeout == null && anchor.strikeout != null) {
			clone.strikeout = anchor.strikeout;
		}
		if (clone.rowFlex == null && anchor.rowFlex != null) {
			clone.rowFlex = anchor.rowFlex;
		}
		if (clone.rowMargin == null && anchor.rowMargin != null) {
			clone.rowMargin = anchor.rowMargin;
		}
		if (clone.letterSpacing == null && anchor.letterSpacing != null) {
			clone.letterSpacing = anchor.letterSpacing;
		}
		clone.textDecoration ??= anchor.textDecoration;
		return clone;
	}

	void _clearStyle(IElement element) {
		element
			..font = null
			..size = null
			..bold = null
			..highlight = null
			..italic = null
			..strikeout = null
			..color = null
			..underline = null
			..textDecoration = null;
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