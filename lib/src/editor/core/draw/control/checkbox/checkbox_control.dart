import 'dart:html';

import '../../../../dataset/enum/control.dart';
import '../../../../dataset/enum/key_map.dart';
import '../../../../interface/control.dart';
import '../../../../interface/element.dart';
import '../../../../interface/range.dart';
import '../control.dart';

class CheckboxControl implements IControlInstance {
	CheckboxControl(this._element, this._control);

	IElement _element;
	final Control _control;

	Control get control => _control;

	IElement get element => _element;

	@override
	void setElement(IElement element) {
		_element = element;
	}

	@override
	IElement getElement() => _element;

	String? getCode() => _element.control?.code;

	@override
	List<IElement> getValue({IControlContext? context}) {
		final IControlContext ctx = context ?? IControlContext();
		final List<IElement> elementList =
				ctx.elementList ?? _control.getElementList();
		final int startIndex =
				ctx.range?.startIndex ?? _control.getRange().startIndex;
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
		return -1;
	}

	void setSelect(
		List<String> codes, {
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
		final int startIndex =
				ctx.range?.startIndex ?? _control.getRange().startIndex;
		if (startIndex < 0 || startIndex >= elementList.length) {
			return;
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
			if (preElement.controlComponent == ControlComponent.checkbox) {
				final checkbox = preElement.checkbox;
				final String? code = checkbox?.code;
				if (checkbox != null && code != null) {
					checkbox.value = codes.contains(code);
				}
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
			if (nextElement.controlComponent == ControlComponent.checkbox) {
				final checkbox = nextElement.checkbox;
				final String? code = checkbox?.code;
				if (checkbox != null && code != null) {
					checkbox.value = codes.contains(code);
				}
			}
			nextIndex += 1;
		}

		final IControl? control = _element.control;
		if (control != null) {
			control.code = codes.join(',');
		}

		_control.repaintControl(
			IRepaintControlOption(curIndex: startIndex, isSetCursor: false),
		);
		_control.emitControlContentChange(
			IControlChangeOption(context: ctx),
		);
	}

	@override
	int? keydown(dynamic evt) {
		if (_control.getIsDisabledControl()) {
			return null;
		}
		final IRange range = _control.getRange();
		_control.shrinkBoundary();
		final int startIndex = range.startIndex;
		final int endIndex = range.endIndex;
		final KeyboardEvent? keyboardEvent = evt as KeyboardEvent?;
		final String? key = keyboardEvent?.key;
		if (key == KeyMap.backspace.value || key == KeyMap.delete.value) {
			return _control.removeControl(startIndex) ?? endIndex;
		}
		return endIndex;
	}

	@override
	int cut() => -1;
}