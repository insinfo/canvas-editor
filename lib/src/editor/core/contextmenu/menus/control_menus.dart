import '../../../dataset/constant/context_menu.dart';
import '../../../dataset/enum/editor.dart';
import '../../../interface/contextmenu/context_menu.dart';

final InternalContextMenuKeyControl _controlKey =
    InternalContextMenuKey.control;

List<IRegisterContextMenu> get controlMenus {
  return <IRegisterContextMenu>[
    IRegisterContextMenu(
      key: _controlKey.delete,
      i18nPath: 'contextmenu.control.delete',
      when: (payload) {
        final String? controlId = payload.startElement?.controlId;
        final EditorMode? mode = payload.options.mode;
        final bool isFormMode = mode == EditorMode.form;
        return !payload.isReadonly &&
            !payload.editorHasSelection &&
            controlId != null &&
            !isFormMode;
      },
      callback: (command, _) => command.executeRemoveControl(),
    ),
  ];
}
