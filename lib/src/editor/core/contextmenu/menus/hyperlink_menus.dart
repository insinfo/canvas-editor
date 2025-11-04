import 'dart:html' as html;
import 'dart:js_util' as js_util;

import '../../../dataset/constant/context_menu.dart';
import '../../../dataset/enum/element.dart';
import '../../../interface/contextmenu/context_menu.dart';

final InternalContextMenuKeyHyperlink _hyperlinkKey =
    InternalContextMenuKey.hyperlink;

List<IRegisterContextMenu> get hyperlinkMenus => <IRegisterContextMenu>[
      IRegisterContextMenu(
        key: _hyperlinkKey.delete,
        i18nPath: 'contextmenu.hyperlink.delete',
        when: (payload) =>
            !payload.isReadonly &&
            payload.startElement?.type == ElementType.hyperlink,
        callback: (command, _) => command.executeDeleteHyperlink(),
      ),
      IRegisterContextMenu(
        key: _hyperlinkKey.cancel,
        i18nPath: 'contextmenu.hyperlink.cancel',
        when: (payload) =>
            !payload.isReadonly &&
            payload.startElement?.type == ElementType.hyperlink,
        callback: (command, _) => command.executeCancelHyperlink(),
      ),
      IRegisterContextMenu(
        key: _hyperlinkKey.edit,
        i18nPath: 'contextmenu.hyperlink.edit',
        when: (payload) =>
            !payload.isReadonly &&
            payload.startElement?.type == ElementType.hyperlink,
        callback: (command, context) {
          final currentUrl = context.startElement?.url;
          final newUrl = js_util.callMethod<String?>(
            html.window,
            'prompt',
            <Object?>[
              command.executeTranslate('contextmenu.hyperlink.edit'),
              currentUrl ?? '',
            ],
          );
          if (newUrl != null && newUrl.isNotEmpty) {
            command.executeEditHyperlink(newUrl);
          }
        },
      ),
    ];
