import '../../../utils/ua.dart' show isApple;
import '../../../dataset/constant/context_menu.dart';
import '../../../interface/contextmenu/context_menu.dart';
import '../../command/command.dart';

final InternalContextMenuKeyGlobal _globalKey = InternalContextMenuKey.global;

List<IRegisterContextMenu> get globalMenus => <IRegisterContextMenu>[
			IRegisterContextMenu(
				key: _globalKey.cut,
				i18nPath: 'contextmenu.global.cut',
				shortCut: '${isApple ? '⌘' : 'Ctrl'} + X',
				when: (payload) => !payload.isReadonly,
				callback: (command, _) => (command as Command).executeCut(),
			),
			IRegisterContextMenu(
				key: _globalKey.copy,
				i18nPath: 'contextmenu.global.copy',
				shortCut: '${isApple ? '⌘' : 'Ctrl'} + C',
				when: (payload) => payload.editorHasSelection || payload.isCrossRowCol,
				callback: (command, _) => (command as Command).executeCopy(),
			),
			IRegisterContextMenu(
				key: _globalKey.paste,
				i18nPath: 'contextmenu.global.paste',
				shortCut: '${isApple ? '⌘' : 'Ctrl'} + V',
				when: (payload) => !payload.isReadonly && payload.editorTextFocus,
				callback: (command, _) => (command as Command).executePaste(),
			),
			IRegisterContextMenu(
				key: _globalKey.selectAll,
				i18nPath: 'contextmenu.global.selectAll',
				shortCut: '${isApple ? '⌘' : 'Ctrl'} + A',
				when: (payload) => payload.editorTextFocus,
				callback: (command, _) => (command as Command).executeSelectAll(),
			),
			IRegisterContextMenu(isDivider: true),
			IRegisterContextMenu(
				key: _globalKey.print,
				i18nPath: 'contextmenu.global.print',
				icon: 'print',
				when: (_) => true,
				callback: (command, _) => (command as Command).executePrint(),
			),
		];