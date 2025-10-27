import '../../../dataset/enum/key_map.dart';
import '../../../dataset/enum/title.dart';
import '../../../interface/shortcut/shortcut.dart';

final List<IRegisterShortcut> titleKeys = [
  IRegisterShortcut(
    key: KeyMap.zero,
    alt: true,
    ctrl: true,
    callback: (command) {
      final dynamic cmd = command;
      cmd?.executeTitle(null);
    },
  ),
  IRegisterShortcut(
    key: KeyMap.one,
    alt: true,
    ctrl: true,
    callback: (command) {
      final dynamic cmd = command;
      cmd?.executeTitle(TitleLevel.first);
    },
  ),
  IRegisterShortcut(
    key: KeyMap.two,
    alt: true,
    ctrl: true,
    callback: (command) {
      final dynamic cmd = command;
      cmd?.executeTitle(TitleLevel.second);
    },
  ),
  IRegisterShortcut(
    key: KeyMap.three,
    alt: true,
    ctrl: true,
    callback: (command) {
      final dynamic cmd = command;
      cmd?.executeTitle(TitleLevel.third);
    },
  ),
  IRegisterShortcut(
    key: KeyMap.four,
    alt: true,
    ctrl: true,
    callback: (command) {
      final dynamic cmd = command;
      cmd?.executeTitle(TitleLevel.fourth);
    },
  ),
  IRegisterShortcut(
    key: KeyMap.five,
    alt: true,
    ctrl: true,
    callback: (command) {
      final dynamic cmd = command;
      cmd?.executeTitle(TitleLevel.fifth);
    },
  ),
  IRegisterShortcut(
    key: KeyMap.six,
    alt: true,
    ctrl: true,
    callback: (command) {
      final dynamic cmd = command;
      cmd?.executeTitle(TitleLevel.sixth);
    },
  ),
];
