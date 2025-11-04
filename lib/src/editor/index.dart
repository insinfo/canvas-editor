import 'dart:core' hide override;
import 'dart:core' as core show override;
import 'dart:html';

import 'interface/editor.dart';
import 'interface/element.dart';
import 'interface/event_bus.dart';
import 'interface/plugin.dart';
import 'utils/element.dart' as element_utils;
import 'utils/index.dart' as utils;
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

export 'utils/element.dart'
    show
        GetElementListByHtmlOption,
        createDomFromElementList,
        getElementListByHTML,
        getTextFromElementList;

export 'utils/index.dart' show splitText;

typedef IGetElementListByHTMLOption = element_utils.GetElementListByHtmlOption;

List<IElement> _cloneElementList(List<IElement>? source) {
  if (source == null || source.isEmpty) {
    return <IElement>[];
  }
  return element_utils.cloneElementList(source);
}

class Editor implements IPluginHost {
  late Command _command;
  late Listener _listener;
  late EventBus<EventBusMap> _eventBus;
  late Override _overrideHost;
  late Register _register;
  late void Function() _destroy;
  late UsePlugin _use;

  @core.override
  Command get command => _command;

  @core.override
  Listener get listener => _listener;

  @core.override
  EventBus<EventBusMap> get eventBus => _eventBus;

  @core.override
  Override get override => _overrideHost;

  @core.override
  Register get register => _register;

  @core.override
  void Function() get destroy => _destroy;

  @core.override
  UsePlugin get use => _use;

  Editor(
    HtmlElement container,
    dynamic data, [
    IEditorOption? options,
  ]) {
    final IEditorOption editorOptions = option_utils.mergeOption(options);

    final List<IElement> headerElementList;
    final List<IElement> mainElementList;
    final List<IElement> footerElementList;

    if (data is List<IElement>) {
      headerElementList = <IElement>[];
      mainElementList = element_utils.cloneElementList(data);
      footerElementList = <IElement>[];
    } else if (data is IEditorData) {
      headerElementList = _cloneElementList(data.header);
      mainElementList = element_utils.cloneElementList(data.main);
      footerElementList = _cloneElementList(data.footer);
    } else {
      final dynamic cloned = utils.deepClone(data);
      if (cloned is List<IElement>) {
        headerElementList = <IElement>[];
        mainElementList = element_utils.cloneElementList(cloned);
        footerElementList = <IElement>[];
      } else if (cloned is IEditorData) {
        headerElementList = _cloneElementList(cloned.header);
        mainElementList = element_utils.cloneElementList(cloned.main);
        footerElementList = _cloneElementList(cloned.footer);
      } else {
        throw ArgumentError(
            'Editor data must be an IEditorData or List<IElement>.');
      }
    }

    final List<List<IElement>> pageComponentData = <List<IElement>>[
      headerElementList,
      mainElementList,
      footerElementList,
    ];
    for (final List<IElement> elementList in pageComponentData) {
      element_utils.formatElementList(
        elementList,
        element_utils.FormatElementListOption(
          editorOptions: editorOptions,
          isForceCompensation: true,
        ),
      );
    }

  _listener = Listener();
  _eventBus = EventBus<EventBusMap>();
  _overrideHost = Override();

    final Draw draw = Draw(
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

  _command = Command(CommandAdapt(draw));
    final ContextMenu contextMenu = ContextMenu(draw, command);
    final Shortcut shortcut = Shortcut(draw, command);

  _register = Register(
      contextMenu: contextMenu,
      shortcut: shortcut,
      i18n: draw.getI18n(),
    );

  _destroy = () {
      draw.destroy();
      shortcut.removeEvent();
      contextMenu.removeEvent();
    };

    final Plugin plugin = Plugin(this);
  _use = plugin.use;
  }
}
