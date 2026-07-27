import 'package:canvas_text_editor/src/dom/dom.dart';

import '../../dataset/constant/editor.dart' as editor_constants;
import '../../dataset/enum/editor.dart';
import '../../interface/editor.dart';
import '../../utils/index.dart' as utils;
import '../draw/draw.dart';
import '../i18n/i18n.dart';
import 'zone.dart';

class ZoneTip {
  ZoneTip(this._draw, this._zone)
      : _i18n = _draw.getI18n(),
        _container = _draw.getContainer(),
        _pageContainer = _draw.getPageContainer() {
    final _TipElements tip = _createTipDom();
    _tipContainer = tip.container;
    _tipContent = tip.content;
    _tipContainer.classList.add('${editor_constants.editorPrefix}-zone-tip');
    _tipContainer.style.position = 'fixed';
    _tipContainer.classList.remove('show');

    _container.append(_tipContainer);

    _isDisableMouseMove = true;
    _currentMoveZone = EditorZone.main;

    final List<EditorZone> watchZones = <EditorZone>[];
    final IEditorOption options = _draw.getOptions();
    final bool isHeaderWatchable = options.header?.disabled != true;
    final bool isFooterWatchable = options.footer?.disabled != true;
    if (isHeaderWatchable) {
      watchZones.add(EditorZone.header);
    }
    if (isFooterWatchable) {
      watchZones.add(EditorZone.footer);
    }
    if (watchZones.isNotEmpty) {
      _watchMouseMoveZoneChange(watchZones);
    }
  }

  final Draw _draw;
  final Zone _zone;
  final I18n _i18n;
  final HTMLDivElement _container;
  final HTMLDivElement _pageContainer;
  late final HTMLDivElement _tipContainer;
  late final HTMLSpanElement _tipContent;
  late bool _isDisableMouseMove;
  late EditorZone _currentMoveZone;

  void _watchMouseMoveZoneChange(List<EditorZone> watchZones) {
    final Function throttled = utils.throttle(
      (MouseEvent evt) {
        if (_isDisableMouseMove || !_draw.getIsPagingMode()) {
          return;
        }
        final Point<num> offsetPoint = evt.offset;
        if (offsetPoint.y.isNaN) {
          _updateZoneTip(false);
          return;
        }
        final EventTarget? target = evt.target;
        if (target != null && target.isA<HTMLCanvasElement>()) {
          final EditorZone moveZone =
              _zone.getZoneByY(offsetPoint.y.toDouble());
          if (!watchZones.contains(moveZone)) {
            _updateZoneTip(false);
            return;
          }
          _currentMoveZone = moveZone;
          final double clientX = evt.clientX.toDouble();
          final double clientY = evt.clientY.toDouble();
          final bool isMainActive = _zone.getZone() == EditorZone.main;
          final bool isWatchedZone =
              moveZone == EditorZone.header || moveZone == EditorZone.footer;
          _updateZoneTip(isMainActive && isWatchedZone, clientX, clientY);
        } else {
          _updateZoneTip(false);
        }
      },
      const Duration(milliseconds: 250),
    );

    _pageContainer.onMouseMove.listen((MouseEvent evt) {
      throttled(evt);
    });
    _pageContainer.onMouseEnter.listen((_) {
      _isDisableMouseMove = false;
    });
    _pageContainer.onMouseLeave.listen((_) {
      _isDisableMouseMove = true;
      _updateZoneTip(false);
    });
  }

  _TipElements _createTipDom() {
    final HTMLDivElement container = HTMLDivElement();
    final HTMLSpanElement content = HTMLSpanElement();
    container.append(content);
    return _TipElements(container: container, content: content);
  }

  void _updateZoneTip(bool visible, [double? left, double? top]) {
    if (!visible) {
      _tipContainer.classList.remove('show');
      return;
    }
    _tipContainer.classList.add('show');
    if (left != null) {
      _tipContainer.style.left = '${left}px';
    }
    if (top != null) {
      _tipContainer.style.top = '${top}px';
    }
    final String key =
        _currentMoveZone == EditorZone.header ? 'headerTip' : 'footerTip';
    _tipContent.text = _i18n.t('zone.$key');
  }
}

class _TipElements {
  _TipElements({required this.container, required this.content});

  final HTMLDivElement container;
  final HTMLSpanElement content;
}
