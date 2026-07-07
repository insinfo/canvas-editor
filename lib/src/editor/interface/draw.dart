import '../dataset/enum/common.dart';
import '../dataset/enum/editor.dart';
import './element.dart';
import './row.dart';

class IDrawOption {
  int? curIndex;
  bool? isSetCursor;
  bool? isSubmitHistory;

  /// Adia o snapshot de histórico para o fim da rajada de digitação
  /// (debounce). Clonar o documento inteiro a cada tecla era um dos custos
  /// dominantes da digitação; com o adiamento o undo agrupa a rajada,
  /// como no Word (doc/plano_otimizacao_performance.md).
  bool? isSubmitHistoryDeferred;

  /// Índice de elemento âncora da edição (digitação/backspace): habilita o
  /// fast path de layout que recomputa só as rows do parágrafo editado
  /// (Draw._tryFastParagraphLayout). Ignorado quando as guardas do fast path
  /// não valem — o render cai no relayout completo normal.
  int? fastLayoutIndex;
  bool? isCompute;
  bool? isLazy;
  bool? isInit;
  bool? isSourceHistory;
  bool? isFirstRender;

  IDrawOption({
    this.curIndex,
    this.isSetCursor,
    this.isSubmitHistory,
    this.isSubmitHistoryDeferred,
    this.fastLayoutIndex,
    this.isCompute,
    this.isLazy,
    this.isInit,
    this.isSourceHistory,
    this.isFirstRender,
  });
}

class IForceUpdateOption {
  bool? isSubmitHistory;

  IForceUpdateOption({this.isSubmitHistory});
}

class IDrawImagePayload {
  String? id;
  String? conceptId;
  double width;
  double height;
  String value;
  ImageDisplay? imgDisplay;
  Map<String, num>? imgFloatPosition;
  String? hyperlinkId;
  String? url;
  dynamic extension;

  IDrawImagePayload({
    this.id,
    this.conceptId,
    required this.width,
    required this.height,
    required this.value,
    this.imgDisplay,
    this.imgFloatPosition,
    this.hyperlinkId,
    this.url,
    this.extension,
  });
}

class IDrawRowPayload {
  List<IElement> elementList;
  List<IElementPosition> positionList;
  List<IRow> rowList;
  int pageNo;
  int startIndex;
  double innerWidth;
  EditorZone? zone;
  bool? isDrawLineBreak;
  bool? isDrawWhiteSpace;

  IDrawRowPayload({
    required this.elementList,
    required this.positionList,
    required this.rowList,
    required this.pageNo,
    required this.startIndex,
    required this.innerWidth,
    this.zone,
    this.isDrawLineBreak,
    this.isDrawWhiteSpace,
  });
}

class IDrawFloatPayload {
  int pageNo;
  List<ImageDisplay> imgDisplays;

  IDrawFloatPayload({
    required this.pageNo,
    required this.imgDisplays,
  });
}

class IDrawPagePayload {
  List<IElement> elementList;
  List<IElementPosition> positionList;
  List<IRow> rowList;
  int pageNo;

  IDrawPagePayload({
    required this.elementList,
    required this.positionList,
    required this.rowList,
    required this.pageNo,
  });
}

class IPainterOption {
  bool isDblclick;

  IPainterOption({required this.isDblclick});
}

class IGetValueOption {
  int? pageNo;
  List<String>? extraPickAttrs;

  IGetValueOption({this.pageNo, this.extraPickAttrs});
}

class IGetOriginValueOption {
  int? pageNo;

  IGetOriginValueOption({this.pageNo});
}

class IAppendElementListOption {
  bool? isPrepend;
  bool? isSubmitHistory;

  IAppendElementListOption({this.isPrepend, this.isSubmitHistory});
}

class IGetImageOption {
  double? pixelRatio;
  EditorMode? mode;

  IGetImageOption({this.pixelRatio, this.mode});
}

class IComputeRowListPayload {
  double innerWidth;
  List<IElement> elementList;
  double? startX;
  double? startY;
  bool? isFromTable;
  bool? isPagingMode;
  double? pageHeight;
  double? mainOuterHeight;
  List<IElement>? surroundElementList;

  IComputeRowListPayload({
    required this.innerWidth,
    required this.elementList,
    this.startX,
    this.startY,
    this.isFromTable,
    this.isPagingMode,
    this.pageHeight,
    this.mainOuterHeight,
    this.surroundElementList,
  });
}
