import 'dart:html';

import '../../../dataset/constant/context_menu.dart';
import '../../../dataset/enum/common.dart';
import '../../../dataset/enum/element.dart';
import '../../../interface/contextmenu/context_menu.dart';

final InternalContextMenuKeyImage _imageKey = InternalContextMenuKey.image;

List<IRegisterContextMenu> get imageMenus => <IRegisterContextMenu>[
      IRegisterContextMenu(
        key: _imageKey.change,
        i18nPath: 'contextmenu.image.change',
        icon: 'image-change',
        when: (payload) =>
            !payload.isReadonly &&
            !payload.editorHasSelection &&
            payload.startElement?.type == ElementType.image,
        callback: (command, _) {
          final FileUploadInputElement input = FileUploadInputElement()
            ..accept = '.png, .jpg, .jpeg';
          input.onChange.first.then((_) {
            final File? file = input.files?.first;
            if (file == null) {
              return;
            }
            final FileReader reader = FileReader()..readAsDataUrl(file);
            reader.onLoad.first.then((_) {
              final dynamic value = reader.result;
              if (value is String && value.isNotEmpty) {
                command.executeReplaceImageElement(value);
              }
            });
          });
          input.click();
        },
      ),
      IRegisterContextMenu(
        key: _imageKey.saveAs,
        i18nPath: 'contextmenu.image.saveAs',
        icon: 'image',
        when: (payload) =>
            !payload.editorHasSelection &&
            payload.startElement?.type == ElementType.image,
        callback: (command, _) => command.executeSaveAsImageElement(),
      ),
      IRegisterContextMenu(
        key: _imageKey.textWrap,
        i18nPath: 'contextmenu.image.textWrap',
        when: (payload) =>
            !payload.isReadonly &&
            !payload.editorHasSelection &&
            payload.startElement?.type == ElementType.image,
        childMenus: <IRegisterContextMenu>[
          IRegisterContextMenu(
            key: _imageKey.textWrapEmbed,
            i18nPath: 'contextmenu.image.textWrapType.embed',
            callback: (command, context) => command.executeChangeImageDisplay(
                context.startElement!, ImageDisplay.block),
            when: (_) => true,
          ),
          IRegisterContextMenu(
            key: _imageKey.textWrapUpDown,
            i18nPath: 'contextmenu.image.textWrapType.upDown',
            callback: (command, context) => command.executeChangeImageDisplay(
                context.startElement!, ImageDisplay.inline),
            when: (_) => true,
          ),
          IRegisterContextMenu(
            key: _imageKey.textWrapSurround,
            i18nPath: 'contextmenu.image.textWrapType.surround',
            callback: (command, context) => command.executeChangeImageDisplay(
                context.startElement!, ImageDisplay.surround),
            when: (_) => true,
          ),
          IRegisterContextMenu(
            key: _imageKey.textWrapFloatTop,
            i18nPath: 'contextmenu.image.textWrapType.floatTop',
            callback: (command, context) => command.executeChangeImageDisplay(
                context.startElement!, ImageDisplay.floatTop),
            when: (_) => true,
          ),
          IRegisterContextMenu(
            key: _imageKey.textWrapFloatBottom,
            i18nPath: 'contextmenu.image.textWrapType.floatBottom',
            callback: (command, context) => command.executeChangeImageDisplay(
                context.startElement!, ImageDisplay.floatBottom),
            when: (_) => true,
          ),
        ],
      ),
    ];
