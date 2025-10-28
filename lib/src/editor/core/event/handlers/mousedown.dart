import 'dart:html' as html;
import 'dart:js_util' as js_util;

import '../../../dataset/enum/common.dart';
import '../../../dataset/enum/control.dart';
import '../../../dataset/enum/editor.dart';
import '../../../dataset/enum/element.dart';
import '../../../dataset/enum/event.dart';
import '../../../interface/draw.dart';
import '../../../interface/element.dart';
import '../../../interface/position.dart';
import '../../../interface/previewer.dart';
import '../../../interface/range.dart';
import '../../../utils/hotkey.dart';
import '../../cursor/cursor.dart';

void setRangeCache(dynamic host) {
  final dynamic draw = host.getDraw();
  final dynamic position = draw.getPosition();
  final dynamic rangeManager = draw.getRange();

  host.isAllowDrag = true;

  final IRange currentRange = rangeManager.getRange() as IRange;
  host.cacheRange = _cloneRange(currentRange);
  host.cacheElementList =
      (draw.getElementList() as List?)?.cast<IElement>() ?? <IElement>[];
  host.cachePositionList =
      (position.getPositionList() as List?)?.cast<IElementPosition>() ??
          <IElementPosition>[];
  final IPositionContext positionContext =
      position.getPositionContext() as IPositionContext;
  host.cachePositionContext = _clonePositionContext(positionContext);
}

void hitCheckbox(IElement element, dynamic draw) {
  final ICheckbox? checkbox = element.checkbox;
  final IControl? control = element.control;
  // Standalone checkbox outside of a control updates particle directly.
  if (control == null) {
    draw.getCheckboxParticle()?.setSelect(element);
    return;
  }

  final String controlCode = control.code ?? '';
  final List<String> codes =
      controlCode.isEmpty ? <String>[] : controlCode.split(',');
  final String? checkboxCode = checkbox?.code;
  if (checkbox?.value == true) {
    final int codeIndex = codes.indexOf(checkboxCode ?? '');
    if (codeIndex >= 0) {
      codes.removeAt(codeIndex);
    }
  } else {
    if (checkboxCode != null && checkboxCode.isNotEmpty) {
      codes.add(checkboxCode);
    }
  }

  final dynamic controlManager = draw.getControl();
  final dynamic activeControl = controlManager?.getActiveControl();
  _invokeControlSetSelect(activeControl, codes);
}

void hitRadio(IElement element, dynamic draw) {
  final IRadio? radio = element.radio;
  final IControl? control = element.control;
  // Standalone radio outside of a control updates particle directly.
  if (control == null) {
    draw.getRadioParticle()?.setSelect(element);
    return;
  }

  final List<String> codes =
      radio?.code != null ? <String>[radio!.code!] : <String>[];
  final dynamic controlManager = draw.getControl();
  final dynamic activeControl = controlManager?.getActiveControl();
  _invokeControlSetSelect(activeControl, codes);
}

void mousedown(dynamic evt, dynamic host) {
  final dynamic draw = host.getDraw();
  final bool isReadonly = draw.isReadonly() == true;
  final dynamic rangeManager = draw.getRange();
  final dynamic position = draw.getPosition();

  final IRange range = rangeManager.getRange() as IRange;
  final int button =
      (evt?.button as num?)?.toInt() ?? MouseEventButton.left.value;
  if (button == MouseEventButton.right.value &&
      (range.isCrossRowCol == true || rangeManager.getIsCollapsed() != true)) {
    return;
  }

  final Map<String, double> offsets = _extractOffsets(evt);
  final double offsetX = offsets['x'] ?? 0;
  final double offsetY = offsets['y'] ?? 0;

  if (host.isAllowDrag != true) {
    if (!isReadonly && range.startIndex != range.endIndex) {
      final bool isPointInRange =
          rangeManager.getIsPointInRange(offsetX, offsetY) == true;
      if (isPointInRange) {
        setRangeCache(host);
        return;
      }
    }
  }

  final html.Element? target = evt?.target as html.Element?;
  final String? pageIndex = target?.dataset['index'];
  if (pageIndex != null) {
    final int? parsed = int.tryParse(pageIndex);
    if (parsed != null) {
      draw.setPageNo(parsed);
    }
  }

  host.isAllowSelection = true;
  final IPositionContext oldPositionContext =
      _clonePositionContext(position.getPositionContext() as IPositionContext);
  final ICurrentPosition? positionResult = position.adjustPositionContext(
    IGetPositionByXYPayload(x: offsetX, y: offsetY),
  ) as ICurrentPosition?;
  if (positionResult == null) {
    return;
  }

  final int index = positionResult.index;
  final bool isDirectHit = positionResult.isDirectHit == true;
  final bool isCheckbox = positionResult.isCheckbox == true;
  final bool isRadio = positionResult.isRadio == true;
  final bool isImage = positionResult.isImage == true;
  final bool isTable = positionResult.isTable == true;
  final int? tdValueIndex = positionResult.tdValueIndex;
  final int? hitLineStartIndex = positionResult.hitLineStartIndex;

  host.mouseDownStartPosition = _cloneCurrentPosition(
    positionResult,
    indexOverride: isTable ? (tdValueIndex ?? index) : index,
    xOverride: offsetX,
    yOverride: offsetY,
  );

  final List<IElement> elementList =
      (draw.getElementList() as List?)?.cast<IElement>() ?? <IElement>[];
  final List<IElementPosition> positionList =
      (position.getPositionList() as List?)?.cast<IElementPosition>() ??
          <IElementPosition>[];
  final int curIndex = isTable ? (tdValueIndex ?? -1) : index;
  if (curIndex < 0 || curIndex >= elementList.length) {
    return;
  }
  final IElement curElement = elementList[curIndex];
  final bool isDirectHitImage = isDirectHit && isImage;
  final bool isDirectHitCheckbox = isDirectHit && isCheckbox;
  final bool isDirectHitRadio = isDirectHit && isRadio;

  if (index >= 0) {
    int startIndex = curIndex;
    int endIndex = curIndex;
    if (evt?.shiftKey == true) {
      final IRange currentRange = rangeManager.getRange() as IRange;
      final int oldStartIndex = currentRange.startIndex;
      if (oldStartIndex >= 0) {
        final IPositionContext newPositionContext =
            position.getPositionContext() as IPositionContext;
        if (newPositionContext.tdId == oldPositionContext.tdId) {
          if (curIndex > oldStartIndex) {
            startIndex = oldStartIndex;
          } else {
            endIndex = oldStartIndex;
          }
        }
      }
    }
    rangeManager.setRange(startIndex, endIndex);
    if (curIndex >= 0 && curIndex < positionList.length) {
      position.setCursorPosition(positionList[curIndex]);
    }

    if (isDirectHitCheckbox && !isReadonly) {
      hitCheckbox(curElement, draw);
    } else if (isDirectHitRadio && !isReadonly) {
      hitRadio(curElement, draw);
    } else if (curElement.controlComponent == ControlComponent.value &&
        (curElement.control?.type == ControlType.checkbox ||
            curElement.control?.type == ControlType.radio)) {
      int preIndex = curIndex;
      while (preIndex > 0) {
        final IElement preElement = elementList[preIndex];
        if (preElement.controlComponent == ControlComponent.checkbox) {
          hitCheckbox(preElement, draw);
          break;
        } else if (preElement.controlComponent == ControlComponent.radio) {
          hitRadio(preElement, draw);
          break;
        }
        preIndex--;
      }
    } else {
      draw.render(
        IDrawOption(
          curIndex: curIndex,
          isCompute: false,
          isSubmitHistory: false,
          isSetCursor:
              !isDirectHitImage && !isDirectHitCheckbox && !isDirectHitRadio,
        ),
      );
    }

    if (hitLineStartIndex != null && hitLineStartIndex != 0) {
      draw
          .getCursor()
          .drawCursor(IDrawCursorOption(hitLineStartIndex: hitLineStartIndex));
    }
  }

  final dynamic previewer = draw.getPreviewer();
  previewer?.clearResizer();
  if (isDirectHitImage && curIndex >= 0 && curIndex < positionList.length) {
    final IPreviewerDrawOption previewerDrawOption = IPreviewerDrawOption(
      dragDisable: isReadonly ||
          (curElement.controlId == null && draw.getMode() == EditorMode.form),
    );
    if (curElement.type == ElementType.latex) {
      previewerDrawOption
        ..mime = PreviewerMime.svg
        ..srcKey = 'laTexSVG';
    }
    previewer?.drawResizer(
      curElement,
      positionList[curIndex],
      previewerDrawOption,
    );
    draw.getCursor().drawCursor(IDrawCursorOption(isShow: false));
    setRangeCache(host);

    final ImageDisplay? display = curElement.imgDisplay;
    if (display == ImageDisplay.surround ||
        display == ImageDisplay.floatTop ||
        display == ImageDisplay.floatBottom) {
      draw.getImageParticle()?.createFloatImage(curElement);
    }

    final dynamic eventBus = draw.getEventBus();
    if (eventBus?.isSubscribe('imageMousedown') == true) {
      eventBus.emit('imageMousedown', <String, dynamic>{
        'evt': evt,
        'element': curElement,
      });
    }
  }

  final dynamic tableTool = draw.getTableTool();
  tableTool?.dispose();
  if (isTable && !isReadonly && draw.getMode() != EditorMode.form) {
    tableTool?.render();
  }

  final dynamic hyperlinkParticle = draw.getHyperlinkParticle();
  if (hyperlinkParticle != null) {
    hyperlinkParticle.clearHyperlinkPopup();
    if (curElement.type == ElementType.hyperlink &&
        curIndex >= 0 &&
        curIndex < positionList.length) {
      final bool modPressed = evt is html.Event && isMod(evt);
      if (modPressed) {
        hyperlinkParticle.openHyperlink(curElement);
      } else {
        hyperlinkParticle.drawHyperlinkPopup(
          curElement,
          positionList[curIndex],
        );
      }
    }
  }

  final dynamic dateParticle = draw.getDateParticle();
  dateParticle?.clearDatePicker();
  if (curElement.type == ElementType.date &&
      !isReadonly &&
      curIndex >= 0 &&
      curIndex < positionList.length) {
    dateParticle?.renderDatePicker(curElement, positionList[curIndex]);
  }
}

IRange _cloneRange(IRange source) {
  return IRange(
    startIndex: source.startIndex,
    endIndex: source.endIndex,
    isCrossRowCol: source.isCrossRowCol,
    tableId: source.tableId,
    startTdIndex: source.startTdIndex,
    endTdIndex: source.endTdIndex,
    startTrIndex: source.startTrIndex,
    endTrIndex: source.endTrIndex,
    zone: source.zone,
  );
}

IPositionContext _clonePositionContext(IPositionContext source) {
  return IPositionContext(
    isTable: source.isTable,
    isCheckbox: source.isCheckbox,
    isRadio: source.isRadio,
    isControl: source.isControl,
    isImage: source.isImage,
    isDirectHit: source.isDirectHit,
    index: source.index,
    trIndex: source.trIndex,
    tdIndex: source.tdIndex,
    tdId: source.tdId,
    trId: source.trId,
    tableId: source.tableId,
  );
}

ICurrentPosition _cloneCurrentPosition(
  ICurrentPosition source, {
  int? indexOverride,
  double? xOverride,
  double? yOverride,
}) {
  return ICurrentPosition(
    index: indexOverride ?? source.index,
    x: xOverride ?? source.x,
    y: yOverride ?? source.y,
    isCheckbox: source.isCheckbox,
    isRadio: source.isRadio,
    isControl: source.isControl,
    isImage: source.isImage,
    isTable: source.isTable,
    isDirectHit: source.isDirectHit,
    trIndex: source.trIndex,
    tdIndex: source.tdIndex,
    tdValueIndex: source.tdValueIndex,
    tdId: source.tdId,
    trId: source.trId,
    tableId: source.tableId,
    zone: source.zone,
    hitLineStartIndex: source.hitLineStartIndex,
  );
}

Map<String, double> _extractOffsets(dynamic evt) {
  final Map<String, double> result = <String, double>{'x': 0, 'y': 0};
  try {
    final dynamic offsetPoint = evt?.offset;
    if (offsetPoint != null) {
      final double? offsetX = (offsetPoint.x as num?)?.toDouble();
      final double? offsetY = (offsetPoint.y as num?)?.toDouble();
      if (offsetX != null) {
        result['x'] = offsetX;
      }
      if (offsetY != null) {
        result['y'] = offsetY;
      }
    }
  } catch (_) {}

  final double? offsetX = (evt?.offsetX as num?)?.toDouble();
  final double? offsetY = (evt?.offsetY as num?)?.toDouble();
  if (offsetX != null) {
    result['x'] = offsetX;
  }
  if (offsetY != null) {
    result['y'] = offsetY;
  }
  return result;
}

void _invokeControlSetSelect(dynamic control, List<String> codes) {
  if (control == null) {
    return;
  }
  try {
    js_util.callMethod(control, 'setSelect', <Object?>[codes]);
    return;
  } catch (_) {
    // Fallback for pure Dart control implementations.
  }
  try {
    // ignore: avoid_dynamic_calls
    control.setSelect(codes);
  } catch (_) {}
}
