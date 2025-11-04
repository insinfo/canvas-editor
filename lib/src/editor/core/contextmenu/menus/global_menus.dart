import '../../../utils/ua.dart' show isApple;
import '../../../dataset/constant/context_menu.dart';
import '../../../interface/contextmenu/context_menu.dart';

final InternalContextMenuKeyGlobal _globalKey = InternalContextMenuKey.global;

List<IRegisterContextMenu> get globalMenus {
  final String modifierKey = isApple ? '⌘' : 'Ctrl';
  return <IRegisterContextMenu>[
    IRegisterContextMenu(
      key: _globalKey.cut,
      i18nPath: 'contextmenu.global.cut',
      shortCut: '$modifierKey + X',
      when: (payload) => !payload.isReadonly,
      callback: (command, _) => command.executeCut(),
    ),
    IRegisterContextMenu(
      key: _globalKey.copy,
      i18nPath: 'contextmenu.global.copy',
      shortCut: '$modifierKey + C',
      when: (payload) => payload.editorHasSelection || payload.isCrossRowCol,
      callback: (command, _) => command.executeCopy(),
    ),
    IRegisterContextMenu(
      key: _globalKey.paste,
      i18nPath: 'contextmenu.global.paste',
      shortCut: '$modifierKey + V',
      when: (payload) => !payload.isReadonly && payload.editorTextFocus,
      callback: (command, _) => command.executePaste(),
    ),
    IRegisterContextMenu(
      key: _globalKey.selectAll,
      i18nPath: 'contextmenu.global.selectAll',
      shortCut: '$modifierKey + A',
      when: (payload) => payload.editorTextFocus,
      callback: (command, _) => command.executeSelectAll(),
    ),
    IRegisterContextMenu(isDivider: true),
    IRegisterContextMenu(
      key: _globalKey.print,
      i18nPath: 'contextmenu.global.print',
      icon: 'print',
      when: (_) => true,
      callback: (command, _) => command.executePrint(),
    ),
  ];
}
