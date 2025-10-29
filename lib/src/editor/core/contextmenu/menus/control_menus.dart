import '../../../dataset/constant/context_menu.dart';
import '../../../dataset/enum/editor.dart';
import '../../../interface/contextmenu/context_menu.dart';
import '../../command/command.dart';

final InternalContextMenuKeyControl _controlKey = InternalContextMenuKey.control;

List<IRegisterContextMenu> get controlMenus => <IRegisterContextMenu>[
			IRegisterContextMenu(
				key: _controlKey.delete,
				i18nPath: 'contextmenu.control.delete',
				when: (payload) {
					final hasControl = payload.startElement?.controlId != null;
					return !payload.isReadonly && !payload.editorHasSelection && hasControl && payload.options.mode != EditorMode.form;
				},
				callback: (command, _) => (command as Command).executeRemoveControl(),
			),
		];