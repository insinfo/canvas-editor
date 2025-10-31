import '../../editor/index.dart';
import '../../editor/interface/element.dart';
import '../../editor/utils/clipboard.dart';

class CopyWithCopyrightOption {
  CopyWithCopyrightOption({this.copyrightText});

  final String? copyrightText;
}

void copyWithCopyrightPlugin(
  Editor editor, [
  CopyWithCopyrightOption? options,
]) {
  final originalCopy = editor.command.copyInvoker;

  editor.command.setCopyOverride(([_]) async {
    final String? copyrightText = options?.copyrightText;
    if (copyrightText == null || copyrightText.isEmpty) {
      await originalCopy();
      return;
    }

    final String rangeText = editor.command.getRangeText();
    if (rangeText.isEmpty) {
      return;
    }

    final String text = '$rangeText$copyrightText';
    try {
      await writeClipboardItem(text, '', <IElement>[]);
    } catch (_) {
      await originalCopy();
    }
  });
}