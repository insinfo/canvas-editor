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
import '../control.dart';

class TextControl implements IControlInstance {
  TextControl(this._element, this._control)
      : _draw = _control.getDraw(),
        _options = _control.getDraw().getOptions();

  IElement _element;
  final Control _control;
  final Draw _draw;
  final IEditorOption _options;

  Control get control => _control;
  Draw get draw => _draw;
  IEditorOption get options => _options;

  @override
  void setElement(IElement element) {
    _element = element;
  }

  @override
  IElement getElement() => _element;

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

  @override
  int? keydown(dynamic evt) {
    if (_control.getIsDisabledControl()) {
      return null;
    }

    final KeyboardEvent? keyboardEvent = evt as KeyboardEvent?;
    final String? key = keyboardEvent?.key;
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

      final bool isPrefixOrPlaceholder =
          startElement.controlComponent == ControlComponent.prefix ||
              startElement.controlComponent == ControlComponent.preText ||
              endElement.controlComponent == ControlComponent.postfix ||
              endElement.controlComponent == ControlComponent.postText ||
              startElement.controlComponent == ControlComponent.placeholder;
      if (isPrefixOrPlaceholder) {
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

  int clearValue({
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
    final int endIndex = range.endIndex;

    _draw.spliceElementList(
      elementList,
      startIndex + 1,
      endIndex - startIndex,
    );

    final List<IElement> value = getValue(context: ctx);
    final bool shouldAddPlaceholder = rule.isAddPlaceholder ?? true;
    if (shouldAddPlaceholder && value.isEmpty) {
      _control.addPlaceholder(startIndex, ctx);
    }
    return startIndex;
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
}