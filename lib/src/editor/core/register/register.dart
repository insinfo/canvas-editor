import '../../interface/common.dart';
import '../../interface/contextmenu/context_menu.dart';
import '../../interface/i18n/i18n.dart';
import '../../interface/shortcut/shortcut.dart';
import '../contextmenu/context_menu.dart';
import '../i18n/i18n.dart';
import '../shortcut/shortcut.dart';

class Register {
  Register({
    required ContextMenu contextMenu,
    required Shortcut shortcut,
    required I18n i18n,
  })  : contextMenuList = contextMenu.registerContextMenuList,
        getContextMenuList = contextMenu.getContextMenuList,
        shortcutList = shortcut.registerShortcutList,
        langMap = i18n.registerLangMap;

  void Function(List<IRegisterContextMenu> payload) contextMenuList;
  List<IRegisterContextMenu> Function() getContextMenuList;
  void Function(List<IRegisterShortcut> payload) shortcutList;
  void Function(String locale, DeepPartial<ILang> lang) langMap;
}
