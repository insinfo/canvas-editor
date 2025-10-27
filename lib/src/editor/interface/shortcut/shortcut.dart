import '../../dataset/enum/key_map.dart';

typedef ShortcutCallback = void Function(dynamic command);

class IRegisterShortcut {
  KeyMap key;
  bool? ctrl;
  bool? meta;
  bool? mod;
  bool? shift;
  bool? alt;
  bool? isGlobal;
  ShortcutCallback? callback;
  bool? disable;

  IRegisterShortcut({
    required this.key,
    this.ctrl,
    this.meta,
    this.mod,
    this.shift,
    this.alt,
    this.isGlobal,
    this.callback,
    this.disable,
  });
}
