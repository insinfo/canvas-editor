import '../../dataset/enum/editor.dart';
import '../editor.dart';
import '../element.dart';

class IContextMenuContext {
  IElement? startElement;
  IElement? endElement;
  bool isReadonly;
  bool editorHasSelection;
  bool editorTextFocus;
  bool isInTable;
  bool isCrossRowCol;
  EditorZone zone;
  int? trIndex;
  int? tdIndex;
  IElement? tableElement;
  IEditorOption options;

  IContextMenuContext({
    this.startElement,
    this.endElement,
    required this.isReadonly,
    required this.editorHasSelection,
    required this.editorTextFocus,
    required this.isInTable,
    required this.isCrossRowCol,
    required this.zone,
    this.trIndex,
    this.tdIndex,
    this.tableElement,
    required this.options,
  });
}

typedef ContextMenuCondition = bool Function(IContextMenuContext payload);
typedef ContextMenuCallback = dynamic Function(Object? command, IContextMenuContext context);

class IRegisterContextMenu {
  String? key;
  String? i18nPath;
  bool? isDivider;
  String? icon;
  String? name;
  String? shortCut;
  bool? disable;
  ContextMenuCondition? when;
  ContextMenuCallback? callback;
  List<IRegisterContextMenu>? childMenus;

  IRegisterContextMenu({
    this.key,
    this.i18nPath,
    this.isDivider,
    this.icon,
    this.name,
    this.shortCut,
    this.disable,
    this.when,
    this.callback,
    this.childMenus,
  });
}

class ContextmenuGlobalLang {
  String cut;
  String copy;
  String paste;
  String selectAll;
  String print;

  ContextmenuGlobalLang({
    required this.cut,
    required this.copy,
    required this.paste,
    required this.selectAll,
    required this.print,
  });
}

class ContextmenuControlLang {
  String delete;

  ContextmenuControlLang({required this.delete});
}

class ContextmenuHyperlinkLang {
  String delete;
  String cancel;
  String edit;

  ContextmenuHyperlinkLang({
    required this.delete,
    required this.cancel,
    required this.edit,
  });
}

class ContextmenuImageTextWrapTypeLang {
  String embed;
  String upDown;

  ContextmenuImageTextWrapTypeLang({required this.embed, required this.upDown});
}

class ContextmenuImageLang {
  String change;
  String saveAs;
  String textWrap;
  ContextmenuImageTextWrapTypeLang textWrapType;

  ContextmenuImageLang({
    required this.change,
    required this.saveAs,
    required this.textWrap,
    required this.textWrapType,
  });
}

class ContextmenuTableLang {
  String insertRowCol;
  String insertTopRow;
  String insertBottomRow;
  String insertLeftCol;
  String insertRightCol;
  String deleteRowCol;
  String deleteRow;
  String deleteCol;
  String deleteTable;
  String mergeCell;
  String mergeCancelCell;

  ContextmenuTableLang({
    required this.insertRowCol,
    required this.insertTopRow,
    required this.insertBottomRow,
    required this.insertLeftCol,
    required this.insertRightCol,
    required this.deleteRowCol,
    required this.deleteRow,
    required this.deleteCol,
    required this.deleteTable,
    required this.mergeCell,
    required this.mergeCancelCell,
  });
}

class IContextmenuLang {
  ContextmenuGlobalLang global;
  ContextmenuControlLang control;
  ContextmenuHyperlinkLang hyperlink;
  ContextmenuImageLang image;
  ContextmenuTableLang table;

  IContextmenuLang({
    required this.global,
    required this.control,
    required this.hyperlink,
    required this.image,
    required this.table,
  });
}
