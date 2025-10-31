import 'dart:html';

import '../../dataset/enum/common.dart';
import '../../dataset/enum/editor.dart';
import '../../dataset/enum/list.dart';
import '../../dataset/enum/row.dart';
import '../../dataset/enum/table/table.dart';
import '../../dataset/enum/title.dart';
import '../../dataset/enum/vertical_align.dart';
import '../../interface/badge.dart';
import '../../interface/catalog.dart';
import '../../interface/command.dart';
import '../../interface/draw.dart';
import '../../interface/editor.dart';
import '../../interface/element.dart';
import '../../interface/event.dart';
import '../../interface/margin.dart';
import '../../interface/range.dart';
import '../../interface/search.dart';
import '../../interface/watermark.dart';
import 'command_adapt.dart';

/// Bridges command invocations to the underlying adapter.
///
/// The original TypeScript implementation exposes a collection of bound
/// functions that forward to `CommandAdapt`. This Dart translation follows the
/// same idea using instance methods that proxy each call to the supplied
/// adapter. The adapter itself is still pending translation and is therefore
/// typed dynamically for the time being.
class Command {
  Command(this._adapt);

  final CommandAdapt _adapt;
    Future<void> Function([ICopyOption? payload])? _copyOverride;
      void Function(String markdown)? _insertMarkdownHandler;

  // Global commands -------------------------------------------------------
  void executeMode(EditorMode payload) => _adapt.mode(payload);

  Future<void> executeCut() => _adapt.cut();

    Future<void> executeCopy([ICopyOption? payload]) {
        final override = _copyOverride;
        if (override != null) {
            return override(payload);
        }
        return _invokeCopy(payload);
    }

    Future<void> Function([ICopyOption? payload]) get copyInvoker => _invokeCopy;

    void setCopyOverride(
        Future<void> Function([ICopyOption? payload])? override,
    ) {
        _copyOverride = override;
    }

    Future<void> _invokeCopy([ICopyOption? payload]) => _adapt.copy(payload);

  void executePaste([IPasteOption? payload]) => _adapt.paste(payload);

  void executeSelectAll() => _adapt.selectAll();

  void executeBackspace() => _adapt.backspace();

  void executeSetRange(
    int startIndex,
    int endIndex, [
    String? tableId,
    int? startTdIndex,
    int? endTdIndex,
    int? startTrIndex,
    int? endTrIndex,
  ]) {
    _adapt.setRange(
      startIndex,
      endIndex,
      tableId,
      startTdIndex,
      endTdIndex,
      startTrIndex,
      endTrIndex,
    );
  }

  void executeReplaceRange(IRange range) => _adapt.replaceRange(range);

  void executeSetPositionContext(IRange range) =>
      _adapt.setPositionContext(range);

  void executeForceUpdate([IForceUpdateOption? options]) =>
      _adapt.forceUpdate(options);

  void executeBlur() => _adapt.blur();

  void executeUndo() => _adapt.undo();

  void executeRedo() => _adapt.redo();

  // Painter & formatting --------------------------------------------------
  void executePainter(IPainterOption options) => _adapt.painter(options);

  void executeApplyPainterStyle() => _adapt.applyPainterStyle();

  void executeFormat([IRichtextOption? options]) => _adapt.format(options);

  void executeFont(String payload, [IRichtextOption? options]) =>
      _adapt.font(payload, options);

  void executeSize(int payload, [IRichtextOption? options]) =>
      _adapt.size(payload, options);

  void executeSizeAdd([IRichtextOption? options]) => _adapt.sizeAdd(options);

  void executeSizeMinus([IRichtextOption? options]) =>
      _adapt.sizeMinus(options);

  void executeBold([IRichtextOption? options]) => _adapt.bold(options);

  void executeItalic([IRichtextOption? options]) => _adapt.italic(options);

  void executeUnderline([
    ITextDecoration? textDecoration,
    IRichtextOption? options,
  ]) =>
      _adapt.underline(textDecoration, options);

  void executeStrikeout([IRichtextOption? options]) =>
      _adapt.strikeout(options);

  void executeSuperscript([IRichtextOption? options]) =>
      _adapt.superscript(options);

  void executeSubscript([IRichtextOption? options]) =>
      _adapt.subscript(options);

  void executeColor(String? payload, [IRichtextOption? options]) =>
      _adapt.color(payload, options);

  void executeHighlight(String? payload, [IRichtextOption? options]) =>
      _adapt.highlight(payload, options);

  void executeTitle(TitleLevel? payload) => _adapt.title(payload);

  void executeList(ListType? listType, [ListStyle? listStyle]) =>
      _adapt.list(listType, listStyle);

  void executeRowFlex(RowFlex payload) => _adapt.rowFlex(payload);

  void executeRowMargin(double payload) => _adapt.rowMargin(payload);

  // Table commands --------------------------------------------------------
  void executeInsertTable(int row, int col) => _adapt.insertTable(row, col);

  void executeInsertTableTopRow() => _adapt.insertTableTopRow();

  void executeInsertTableBottomRow() => _adapt.insertTableBottomRow();

  void executeInsertTableLeftCol() => _adapt.insertTableLeftCol();

  void executeInsertTableRightCol() => _adapt.insertTableRightCol();

  void executeDeleteTableRow() => _adapt.deleteTableRow();

  void executeDeleteTableCol() => _adapt.deleteTableCol();

  void executeDeleteTable() => _adapt.deleteTable();

  void executeMergeTableCell() => _adapt.mergeTableCell();

  void executeCancelMergeTableCell() => _adapt.cancelMergeTableCell();

  void executeSplitVerticalTableCell() => _adapt.splitVerticalTableCell();

  void executeSplitHorizontalTableCell() => _adapt.splitHorizontalTableCell();

  void executeTableTdVerticalAlign(VerticalAlign payload) =>
      _adapt.tableTdVerticalAlign(payload);

  void executeTableBorderType(TableBorder payload) =>
      _adapt.tableBorderType(payload);

  void executeTableBorderColor(String payload) =>
      _adapt.tableBorderColor(payload);

  void executeTableTdBorderType(TdBorder payload) =>
      _adapt.tableTdBorderType(payload);

  void executeTableTdSlashType(TdSlash payload) =>
      _adapt.tableTdSlashType(payload);

  void executeTableTdBackgroundColor(String payload) =>
      _adapt.tableTdBackgroundColor(payload);

  void executeTableSelectAll() => _adapt.tableSelectAll();

  // Media & hyperlink -----------------------------------------------------
  String? executeImage(IDrawImagePayload payload) => _adapt.image(payload);

  void executeHyperlink(IElement payload) => _adapt.hyperlink(payload);

  void executeDeleteHyperlink() => _adapt.deleteHyperlink();

  void executeCancelHyperlink() => _adapt.cancelHyperlink();

  void executeEditHyperlink(String payload) => _adapt.editHyperlink(payload);

  void executeSeparator(List<num> payload) => _adapt.separator(payload);

  void executePageBreak() => _adapt.pageBreak();

  Future<void> executePrint() => _adapt.print();

  void executeReplaceImageElement(String payload) =>
      _adapt.replaceImageElement(payload);

  void executeSaveAsImageElement() => _adapt.saveAsImageElement();

  void executeChangeImageDisplay(IElement element, ImageDisplay display) =>
      _adapt.changeImageDisplay(element, display);

  // Watermark -------------------------------------------------------------
  void executeAddWatermark(IWatermark payload) => _adapt.addWatermark(payload);

  void executeDeleteWatermark() => _adapt.deleteWatermark();

  // Search & replace ------------------------------------------------------
  void executeSearch(String? payload) => _adapt.search(payload);

  void executeSearchNavigatePre() => _adapt.searchNavigatePre();

  void executeSearchNavigateNext() => _adapt.searchNavigateNext();

  void executeReplace(String payload, [IReplaceOption? options]) =>
      _adapt.replace(payload, options);

  // Page operations -------------------------------------------------------
  void executePageMode(PageMode payload) => _adapt.pageMode(payload);

  void executePageScale(double scale) => _adapt.pageScale(scale);

  void executePageScaleRecovery() => _adapt.pageScaleRecovery();

  void executePageScaleMinus() => _adapt.pageScaleMinus();

  void executePageScaleAdd() => _adapt.pageScaleAdd();

  void executePaperSize(double width, double height) =>
      _adapt.paperSize(width, height);

  void executePaperDirection(PaperDirection payload) =>
      _adapt.paperDirection(payload);

  dynamic executeSetPaperMargin(IMargin payload) =>
      _adapt.setPaperMargin(payload);

  // Badge & area ----------------------------------------------------------
  void executeSetMainBadge(IBadge? payload) => _adapt.setMainBadge(payload);

  void executeSetAreaBadge(List<IAreaBadge> payload) =>
      _adapt.setAreaBadge(payload);

  dynamic executeInsertArea(IInsertAreaOption payload) =>
      _adapt.insertArea(payload);

  dynamic executeSetAreaValue(ISetAreaValueOption payload) =>
      _adapt.setAreaValue(payload);

  void executeSetAreaProperties(ISetAreaPropertiesOption payload) =>
      _adapt.setAreaProperties(payload);

  void executeLocationArea(String areaId, [ILocationAreaOption? options]) =>
      _adapt.locationArea(areaId, options);

  // Element operations ----------------------------------------------------
  void executeInsertElementList(
    List<IElement> payload, [
    IInsertElementListOption? options,
  ]) =>
      _adapt.insertElementList(payload, options);

  void executeAppendElementList(
    List<IElement> payload, [
    IAppendElementListOption? options,
  ]) =>
      _adapt.appendElementList(payload, options);

  void executeUpdateElementById(IUpdateElementByIdOption payload) =>
      _adapt.updateElementById(payload);

  void executeDeleteElementById(IDeleteElementByIdOption payload) =>
      _adapt.deleteElementById(payload);

  List<IElement> getElementById(IGetElementByIdOption payload) =>
      _adapt.getElementById(payload);

  // Value operations ------------------------------------------------------
  void executeSetValue(dynamic payload, [ISetValueOption? options]) =>
      _adapt.setValue(payload, options);

  void executeSetHTML(dynamic payload) => _adapt.setHTML(payload);

  void executeRemoveControl([IRemoveControlOption? payload]) =>
      _adapt.removeControl(payload);

  String executeTranslate(String path) => _adapt.translate(path);

  void executeSetLocale(String locale) => _adapt.setLocale(locale);

  void executeLocationCatalog(String titleId) =>
      _adapt.locationCatalog(titleId);

  void executeWordTool() => _adapt.wordTool();

  String? executeSetGroup() => _adapt.setGroup();

  void executeDeleteGroup(String groupId) => _adapt.deleteGroup(groupId);

  void executeLocationGroup(String groupId) => _adapt.locationGroup(groupId);

  void executeSetZone(EditorZone zone) => _adapt.setZone(zone);

  void executeSetControlValue(ISetControlValueOption payload) =>
      _adapt.setControlValue(payload);

  void executeSetControlValueList(List<ISetControlValueOption> payload) =>
      _adapt.setControlValueList(payload);

  void executeSetControlExtension(ISetControlExtensionOption payload) =>
      _adapt.setControlExtension(payload);

  void executeSetControlExtensionList(
    List<ISetControlExtensionOption> payload,
  ) =>
      _adapt.setControlExtensionList(payload);

  void executeSetControlProperties(ISetControlProperties payload) =>
      _adapt.setControlProperties(payload);

  void executeSetControlPropertiesList(
    List<ISetControlProperties> payload,
  ) =>
      _adapt.setControlPropertiesList(payload);

  void executeSetControlHighlight(ISetControlHighlightOption payload) =>
      _adapt.setControlHighlight(payload);

  void executeLocationControl(
    String controlId, [
    ILocationControlOption? options,
  ]) =>
      _adapt.locationControl(controlId, options);

  void executeInsertControl(IElement payload) => _adapt.insertControl(payload);

  void executeUpdateOptions(IUpdateOption payload) =>
      _adapt.updateOptions(payload);

  void executeInsertTitle(IElement payload) => _adapt.insertTitle(payload);

  void executeFocus([IFocusOption? options]) => _adapt.focus(options);

  // Fetch operations ------------------------------------------------------
  Future<ICatalog?> getCatalog() => _adapt.getCatalog();

  Future<List<String>> getImage([IGetImageOption? options]) =>
      _adapt.getImage(options);

  IEditorOption getOptions() => _adapt.getOptions();

  IEditorResult getValue([IGetValueOption? options]) =>
      _adapt.getValue(options);

  Future<IEditorResult> getValueAsync([IGetValueOption? options]) =>
      _adapt.getValueAsync(options);

  IGetAreaValueResult<IElement>? getAreaValue([
    IGetAreaValueOption? options,
  ]) =>
      _adapt.getAreaValue(options);

  IEditorHTML getHTML() => _adapt.getHTML();

  IEditorText getText() => _adapt.getText();

  Future<int> getWordCount() => _adapt.getWordCount();

  IElementPosition? getCursorPosition() => _adapt.getCursorPosition();

  IRange getRange() => _adapt.getRange();

  String getRangeText() => _adapt.getRangeText();

  RangeContext? getRangeContext() => _adapt.getRangeContext();

  List<IElement>? getRangeRow() => _adapt.getRangeRow();

  List<IElement>? getRangeParagraph() => _adapt.getRangeParagraph();

  List<IRange> getKeywordRangeList(String payload) =>
      _adapt.getKeywordRangeList(payload);

  List<ISearchResultContext>? getKeywordContext(String payload) =>
      _adapt.getKeywordContext(payload);

  List<num> getPaperMargin() {
    return List<num>.from(_adapt.getPaperMargin());
  }

  dynamic getSearchNavigateInfo() => _adapt.getSearchNavigateInfo();

  String getLocale() => _adapt.getLocale();

  Future<List<String>> getGroupIds() => _adapt.getGroupIds();

  IGetControlValueResult? getControlValue(
    IGetControlValueOption payload,
  ) =>
      _adapt.getControlValue(payload);

  List<IElement> getControlList() => _adapt.getControlList();

  DivElement getContainer() => _adapt.getContainer();

  List<ITitleValueItem<IElement>>? getTitleValue(
    IGetTitleValueOption payload,
  ) =>
      _adapt.getTitleValue(payload);

  IPositionContextByEventResult? getPositionContextByEvent(
    MouseEvent evt, [
    IPositionContextByEventOption? options,
  ]) =>
      _adapt.getPositionContextByEvent(evt, options);

    void executeInsertMarkdown(String markdown) {
        final handler = _insertMarkdownHandler;
        handler?.call(markdown);
    }

    void setInsertMarkdownHandler(void Function(String markdown)? handler) {
        _insertMarkdownHandler = handler;
    }
}
