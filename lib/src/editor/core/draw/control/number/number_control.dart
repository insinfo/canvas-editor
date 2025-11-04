import '../../../../dataset/enum/control.dart';
import '../../../../interface/control.dart';
import '../../../../interface/element.dart';
import '../../../../interface/range.dart';
import '../../../../utils/element.dart' as element_utils;
import '../control.dart';
import '../text/text_control.dart';

class NumberControl extends TextControl {
  NumberControl(IElement element, Control control) : super(element, control);

  @override
  int setValue(
    List<IElement> data, {
    IControlContext? context,
    IControlRuleOption? options,
  }) {
    final IControlContext ctx = context ?? IControlContext();
    final List<IElement> elementList =
        ctx.elementList ?? control.getElementList();
    final IRange range = ctx.range ?? control.getRange();

    control.shrinkBoundary(ctx);

    final List<IElement> controlElementList = <IElement>[...data];
    final int startIndex = range.startIndex;
    final int endIndex = range.endIndex;
    if (startIndex < 0 || startIndex >= elementList.length) {
      return -1;
    }
    final IElement startElement = elementList[startIndex];

    if (control.getIsExistValueByElementListIndex(elementList, startIndex)) {
      int preIndex = startIndex;
      while (preIndex > 0) {
        final IElement preElement = elementList[preIndex];
        if (preElement.controlId != startElement.controlId ||
            preElement.controlComponent == ControlComponent.prefix ||
            preElement.controlComponent == ControlComponent.preText) {
          break;
        }
        controlElementList.insert(0, preElement);
        preIndex -= 1;
      }

      int nextIndex = endIndex + 1;
      while (nextIndex < elementList.length) {
        final IElement nextElement = elementList[nextIndex];
        if (nextElement.controlId != startElement.controlId ||
            nextElement.controlComponent == ControlComponent.postfix ||
            nextElement.controlComponent == ControlComponent.postText) {
          break;
        }
        controlElementList.add(nextElement);
        nextIndex += 1;
      }
    }

    final String text = element_utils.getElementListText(controlElementList);
    final num? parsed = num.tryParse(text);
    if (parsed == null || parsed.isNaN || !parsed.isFinite) {
      return -1;
    }

    return super.setValue(
      data,
      context: context,
      options: options,
    );
  }
}