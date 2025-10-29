import 'dart:html';

import 'dataset/constant/common.dart';
import 'dataset/constant/editor.dart';
import 'dataset/enum/common.dart';
import 'dataset/enum/editor.dart';
import 'interface/editor.dart';
import 'interface/element.dart';
import 'interface/event_bus.dart';
import 'interface/plugin.dart';
import 'utils/element.dart' as element_utils;
import 'utils/option.dart' as option_utils;
import 'core/command/command.dart';
import 'core/command/command_adapt.dart';
import 'core/contextmenu/context_menu.dart';
import 'core/draw/draw.dart';
import 'core/event/eventbus/event_bus.dart';
import 'core/listener/listener.dart';
import 'core/override/override.dart';
import 'core/plugin/plugin.dart';
import 'core/register/register.dart';
import 'core/shortcut/shortcut.dart';

// Exports for external use
export 'dataset/enum/row.dart';
export 'dataset/enum/common.dart';
export 'dataset/enum/element.dart';
export 'dataset/enum/editor.dart';
export 'dataset/enum/control.dart';
export 'dataset/enum/key_map.dart';
export 'dataset/enum/block.dart';
export 'dataset/enum/table/table.dart';
export 'dataset/enum/title.dart';
export 'dataset/enum/list.dart';
export 'dataset/enum/vertical_align.dart';
export 'dataset/enum/background.dart';
export 'dataset/enum/text.dart';
export 'dataset/enum/line_number.dart';
export 'dataset/enum/area.dart';
export 'dataset/enum/watermark.dart';

export 'interface/element.dart';
export 'interface/editor.dart';
export 'interface/contextmenu/context_menu.dart';
export 'interface/watermark.dart';
export 'interface/block.dart';
export 'interface/i18n/i18n.dart';
export 'interface/catalog.dart';
export 'interface/range.dart';
export 'interface/listener.dart';
export 'interface/badge.dart';

export 'dataset/constant/editor.dart';
export 'dataset/constant/common.dart';
export 'dataset/constant/context_menu.dart';
export 'dataset/constant/shortcut.dart';

export 'core/command/command.dart';

class Editor {
  late Command command;
  late Listener listener;
  late EventBus<EventBusMap> eventBus;
  late Override override;
  late Register register;
  late void Function() destroy;
  late UsePlugin use;

  Editor(
    HtmlElement container,
    dynamic data, // IEditorData or List<IElement>
    [IEditorOption? options]
  ) {
    final editorOptions = option_utils.mergeOption(options);

    List<IElement> headerElementList = [];
    List<IElement> mainElementList = [];
    List<IElement> footerElementList = [];

    if (data is List<IElement>) {
      mainElementList = data;
    } else if (data is IEditorData) {
      headerElementList = data.header ?? [];
      mainElementList = data.main;
      footerElementList = data.footer ?? [];
    }

    final pageComponentData = [
      headerElementList,
      mainElementList,
      footerElementList
    ];
    for (var elementList in pageComponentData) {
      element_utils.formatElementList(elementList, element_utils.FormatElementListOption(editorOptions: editorOptions, isForceCompensation: true));
    }

    listener = Listener();
    eventBus = EventBus<EventBusMap>();
    override = Override();

    final draw = Draw(
      container,
      editorOptions,
      IEditorData(
        header: headerElementList,
        main: mainElementList,
        footer: footerElementList,
      ),
      listener,
      eventBus,
      override,
    );

    command = Command(CommandAdapt(draw));
    final contextMenu = ContextMenu(draw, command);
    final shortcut = Shortcut(draw, command);

    register = Register(
      contextMenu: contextMenu,
      shortcut: shortcut,
      i18n: draw.getI18n(),
    );

    destroy = () {
      draw.destroy();
      shortcut.removeEvent();
      contextMenu.removeEvent();
    };

    final plugin = Plugin(this);
    use = plugin.use;
  }
}
