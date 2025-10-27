import '../../../dataset/enum/key_map.dart';
import '../../../dataset/enum/list.dart';
import '../../../interface/shortcut/shortcut.dart';

final List<IRegisterShortcut> listKeys = [
  IRegisterShortcut(
    key: KeyMap.i,
    shift: true,
    mod: true,
    callback: (command) {
      final dynamic cmd = command;
      cmd?.executeList(ListType.unordered, ListStyle.disc);
    },
  ),
  IRegisterShortcut(
    key: KeyMap.u,
    shift: true,
    mod: true,
    callback: (command) {
      final dynamic cmd = command;
      cmd?.executeList(ListType.ordered, null);
    },
  ),
];
