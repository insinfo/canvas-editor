import '../../../dataset/enum/key_map.dart';
import '../../../dataset/enum/row.dart';
import '../../../interface/shortcut/shortcut.dart';
import '../../../utils/ua.dart';

final List<IRegisterShortcut> richtextKeys = [
  IRegisterShortcut(
    key: KeyMap.x,
    ctrl: true,
    shift: true,
    callback: (command) {
      final dynamic cmd = command;
      cmd?.executeStrikeout();
    },
  ),
  IRegisterShortcut(
    key: KeyMap.leftBracket,
    mod: true,
    callback: (command) {
      final dynamic cmd = command;
      cmd?.executeSizeAdd();
    },
  ),
  IRegisterShortcut(
    key: KeyMap.rightBracket,
    mod: true,
    callback: (command) {
      final dynamic cmd = command;
      cmd?.executeSizeMinus();
    },
  ),
  IRegisterShortcut(
    key: KeyMap.b,
    mod: true,
    callback: (command) {
      final dynamic cmd = command;
      cmd?.executeBold();
    },
  ),
  IRegisterShortcut(
    key: KeyMap.i,
    mod: true,
    callback: (command) {
      final dynamic cmd = command;
      cmd?.executeItalic();
    },
  ),
  IRegisterShortcut(
    key: KeyMap.u,
    mod: true,
    callback: (command) {
      final dynamic cmd = command;
      cmd?.executeUnderline();
    },
  ),
  IRegisterShortcut(
    key: isApple ? KeyMap.comma : KeyMap.rightAngleBracket,
    mod: true,
    shift: true,
    callback: (command) {
      final dynamic cmd = command;
      cmd?.executeSuperscript();
    },
  ),
  IRegisterShortcut(
    key: isApple ? KeyMap.period : KeyMap.leftAngleBracket,
    mod: true,
    shift: true,
    callback: (command) {
      final dynamic cmd = command;
      cmd?.executeSubscript();
    },
  ),
  IRegisterShortcut(
    key: KeyMap.l,
    mod: true,
    callback: (command) {
      final dynamic cmd = command;
      cmd?.executeRowFlex(RowFlex.left);
    },
  ),
  IRegisterShortcut(
    key: KeyMap.e,
    mod: true,
    callback: (command) {
      final dynamic cmd = command;
      cmd?.executeRowFlex(RowFlex.center);
    },
  ),
  IRegisterShortcut(
    key: KeyMap.r,
    mod: true,
    callback: (command) {
      final dynamic cmd = command;
      cmd?.executeRowFlex(RowFlex.right);
    },
  ),
  IRegisterShortcut(
    key: KeyMap.j,
    mod: true,
    callback: (command) {
      final dynamic cmd = command;
      cmd?.executeRowFlex(RowFlex.alignment);
    },
  ),
  IRegisterShortcut(
    key: KeyMap.j,
    mod: true,
    shift: true,
    callback: (command) {
      final dynamic cmd = command;
      cmd?.executeRowFlex(RowFlex.justify);
    },
  ),
];
