import '../../../../dataset/enum/control.dart';
import '../../../../interface/control.dart';
import '../../../../interface/element.dart';
import '../checkbox/checkbox_control.dart';
import '../control.dart';

class RadioControl extends CheckboxControl {
  RadioControl(IElement element, Control control) : super(element, control);

  @override
  void setSelect(
    List<String> codes, {
    IControlContext? context,
    IControlRuleOption? options,
  }) {
    final IControlContext ctx = context ?? IControlContext();
    final IControlRuleOption rule = options ?? IControlRuleOption();
    final bool isIgnoreDisabledRule = rule.isIgnoreDisabledRule ?? false;
    if (!isIgnoreDisabledRule && control.getIsDisabledControl(ctx)) {
      return;
    }

    final List<IElement> elementList =
        ctx.elementList ?? control.getElementList();
    final int startIndex =
        ctx.range?.startIndex ?? control.getRange().startIndex;
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
      if (preElement.controlComponent == ControlComponent.radio) {
        final radio = preElement.radio;
        final String? code = radio?.code;
        if (radio != null && code != null) {
          radio.value = codes.contains(code);
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
      if (nextElement.controlComponent == ControlComponent.radio) {
        final radio = nextElement.radio;
        final String? code = radio?.code;
        if (radio != null && code != null) {
          radio.value = codes.contains(code);
        }
      }
      nextIndex += 1;
    }

    final IControl? currentControl = element.control;
    if (currentControl != null) {
      currentControl.code = codes.join(',');
    }

    control.repaintControl(
      IRepaintControlOption(curIndex: startIndex, isSetCursor: false),
    );
    control.emitControlContentChange(
      IControlChangeOption(context: ctx),
    );
  }
}