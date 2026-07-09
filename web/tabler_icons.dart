import 'dart:async';
import 'dart:html';

/// Porte 1:1 do antigo `web/icons.js` para Dart puro (regra do projeto: sem
/// JavaScript). Aplica os ícones Tabler aos itens de menu via classes/CSS custom
/// properties e sincroniza as réguas (rulers) com a geometria do canvas.
///
/// Chamado por `main.dart` no início da inicialização do editor. Um
/// [MutationObserver] reaplica os ícones conforme o editor constrói seu DOM.

const String _basePath = 'assets/icons/tabler/';

/// (seletor CSS do `<i>` do item, nome do ícone Tabler).
const List<List<String>> _iconRules = <List<String>>[
  <String>['.menu-item__undo > i', 'arrow-back-up'],
  <String>['.menu-item__redo > i', 'arrow-forward-up'],
  <String>['.menu-item__painter > i', 'brush'],
  <String>['.menu-item__format > i', 'clear-formatting'],
  <String>['.menu-item__docx > i', 'file-type-docx'],
  <String>['.menu-item__docx-save > i', 'device-floppy'],
  <String>['.menu-item__size-add > i', 'text-increase'],
  <String>['.menu-item__size-minus > i', 'text-decrease'],
  <String>['.menu-item__bold > i', 'bold'],
  <String>['.menu-item__italic > i', 'italic'],
  <String>['.menu-item__underline > i', 'underline'],
  <String>['.menu-item__strikeout > i', 'strikethrough'],
  <String>['.menu-item__superscript > i', 'superscript'],
  <String>['.menu-item__subscript > i', 'subscript'],
  <String>['.menu-item__color > i', 'text-color'],
  <String>['.menu-item__highlight > i', 'highlight'],
  <String>['.menu-item__title > i', 'heading'],
  <String>['.menu-item__left > i', 'align-left'],
  <String>['.menu-item__center > i', 'align-center'],
  <String>['.menu-item__right > i', 'align-right'],
  <String>['.menu-item__alignment > i', 'align-justified'],
  <String>['.menu-item__justify > i', 'align-justified'],
  <String>['.menu-item__row-margin > i', 'line-height'],
  <String>['.menu-item__list > i', 'list'],
  <String>['.menu-item__table > i', 'table'],
  <String>['.menu-item__image > i', 'photo'],
  <String>['.menu-item__hyperlink > i', 'link'],
  <String>['.menu-item__separator > i', 'separator-horizontal'],
  <String>['.menu-item__watermark > i', 'droplet'],
  <String>['.menu-item__codeblock > i', 'code'],
  <String>['.menu-item__page-break > i', 'page-break'],
  <String>['.menu-item__control > i', 'forms'],
  <String>['.menu-item__checkbox > i', 'checkbox'],
  <String>['.menu-item__radio > i', 'circle-dot'],
  <String>['.menu-item__latex > i', 'math-function'],
  <String>['.menu-item__date > i', 'calendar-event'],
  <String>['.menu-item__block > i', 'layout-grid'],
  <String>['.menu-item__paper-size > i', 'dimensions'],
  <String>['.menu-item__paper-direction > i', 'rotate-rectangle'],
  <String>['.menu-item__paper-margin > i', 'layout'],
  <String>['.menu-item__page-mode > i', 'book'],
  <String>['.menu-item__edit-header > i', 'layout-navbar'],
  <String>['.menu-item__edit-footer > i', 'layout-bottombar'],
  <String>['.menu-item__close-zone > i', 'x'],
  <String>['.menu-item__remove-header-textbox > i', 'trash'],
  <String>['.menu-item__search > i', 'search'],
  <String>['.menu-item__print > i', 'printer'],
  <String>['.catalog-mode > i', 'list-tree'],
  <String>['.page-mode > i', 'book'],
  <String>['.page-scale-minus > i', 'zoom-out'],
  <String>['.page-scale-add > i', 'zoom-in'],
  <String>['.paper-size > i', 'dimensions'],
  <String>['.paper-direction > i', 'rotate-rectangle'],
  <String>['.paper-margin > i', 'layout'],
  <String>['.fullscreen > i', 'arrows-maximize'],
  <String>['.fullscreen.exist > i', 'arrows-minimize'],
  <String>['.editor-option > i', 'settings'],
  <String>['.catalog__header__close > i', 'x'],
  <String>['.find-sidebar__close > i', 'x'],
  <String>['.find-sidebar__prev > i', 'chevron-up'],
  <String>['.find-sidebar__next > i', 'chevron-down'],
  <String>['.dialog-title > i', 'x'],
  <String>['.signature-title > i', 'x'],
  <String>['.signature-operation__undo', 'arrow-back-up'],
  <String>['.signature-operation__trash', 'trash'],
];

/// (seletor CSS do item, rótulo do ribbon "grande").
const List<List<String>> _labeledCommands = <List<String>>[
  <String>['.menu-item__docx', 'Abrir'],
  <String>['.menu-item__docx-save', 'Salvar'],
  <String>['.menu-item__table', 'Tabela'],
  <String>['.menu-item__image', 'Imagem'],
  <String>['.menu-item__hyperlink', 'Link'],
  <String>['.menu-item__page-break', 'Quebra'],
  <String>['.menu-item__control', 'Campos'],
  <String>['.menu-item__watermark', 'Marca'],
  <String>['.menu-item__paper-size', 'Tamanho'],
  <String>['.menu-item__paper-direction', 'Orientação'],
  <String>['.menu-item__paper-margin', 'Margens'],
  <String>['.menu-item__page-mode', 'Modo'],
  <String>['.menu-item__edit-header', 'Cabeçalho'],
  <String>['.menu-item__edit-footer', 'Rodapé'],
  <String>['.menu-item__close-zone', 'Fechar'],
  <String>['.menu-item__remove-header-textbox', 'Remover'],
  <String>['.menu-item__search', 'Localizar'],
  <String>['.menu-item__print', 'Imprimir'],
];

int _rulerFrame = 0;
String _rulerLabelKey = '';

void _eachMatch(Node root, String selector, void Function(Element) callback) {
  if (root is Element) {
    if (root.matches(selector)) {
      callback(root);
    }
    root.querySelectorAll(selector).forEach(callback);
  } else if (root is Document) {
    root.querySelectorAll(selector).forEach(callback);
  }
}

void _applyIcons(Node root) {
  for (final List<String> rule in _iconRules) {
    _eachMatch(root, rule[0], (Element node) {
      node.classes.add('ce-tabler-icon');
      node.style.setProperty('--ce-icon-url', 'url("$_basePath${rule[1]}.svg")');
    });
  }
  for (final List<String> rule in _labeledCommands) {
    _eachMatch(root, rule[0], (Element node) {
      node.classes.add('ce-ribbon-large');
      node.dataset['ribbonLabel'] = rule[1];
    });
  }
}

void _rebuildRulerLabels(double width, double height, double pxPerCm) {
  final String key =
      '${width.round()}:${height.round()}:${(pxPerCm * 10).round()}';
  if (key == _rulerLabelKey) {
    return;
  }
  _rulerLabelKey = key;
  final Element? horizontal =
      document.querySelector('.word-ruler-horizontal__labels');
  final Element? vertical =
      document.querySelector('.word-ruler-vertical__labels');
  if (horizontal == null || vertical == null) {
    return;
  }
  final int hCount = (width / pxPerCm).floor().clamp(1, 1 << 30);
  final int vCount = (height / pxPerCm).floor().clamp(1, 1 << 30);
  horizontal.children.clear();
  vertical.children.clear();
  for (int i = 1; i <= hCount; i += 1) {
    final SpanElement label = SpanElement()
      ..text = '$i'
      ..style.left = '${i * pxPerCm}px';
    horizontal.append(label);
  }
  for (int i = 1; i <= vCount; i += 1) {
    final SpanElement label = SpanElement()
      ..text = '$i'
      ..style.top = '${i * pxPerCm}px';
    vertical.append(label);
  }
}

void _syncRulers() {
  final Element? canvas =
      document.querySelector('.ce-page-container canvas');
  if (canvas == null) {
    return;
  }
  final Rectangle<num> rect = canvas.getBoundingClientRect();
  if (rect.width <= 0 || rect.height <= 0) {
    return;
  }
  final double width = rect.width.toDouble();
  final double height = rect.height.toDouble();
  final double left = rect.left.toDouble();
  final double pxPerCm = (width / 21) < 20 ? 20 : (width / 21);
  final Element rulerRoot =
      document.querySelector('.word-rulers') ?? document.documentElement!;
  final CssStyleDeclaration rootStyle = rulerRoot.style;
  rootStyle.setProperty('--ce-ruler-left', '${left < 0 ? 0 : left}px');
  rootStyle.setProperty('--ce-ruler-width', '${width}px');
  rootStyle.setProperty('--ce-ruler-cm', '${pxPerCm}px');
  _rebuildRulerLabels(width, height, pxPerCm);
}

void _scheduleRulerSync() {
  if (_rulerFrame != 0) {
    return;
  }
  _rulerFrame = window.requestAnimationFrame((_) {
    _rulerFrame = 0;
    _syncRulers();
  });
}

/// Ponto de entrada: registra ícones, réguas e observadores. Idempotente por
/// natureza (reaplica classes/labels sem efeito colateral).
void setupTablerIcons() {
  document.documentElement!.classes.add('ce-tabler-icons-ready');
  _applyIcons(document);
  _scheduleRulerSync();
  window.addEventListener('resize', (_) => _scheduleRulerSync());
  window.addEventListener('scroll', (_) => _scheduleRulerSync(), true);
  final MutationObserver observer =
      MutationObserver((List<dynamic> mutations, MutationObserver obs) {
    for (final dynamic mutation in mutations) {
      final MutationRecord record = mutation as MutationRecord;
      final List<Node>? added = record.addedNodes;
      if (added != null) {
        for (final Node node in added) {
          _applyIcons(node);
        }
      }
    }
    _scheduleRulerSync();
  });
  observer.observe(document.body!, childList: true, subtree: true);
  Timer(const Duration(milliseconds: 250), _scheduleRulerSync);
  Timer(const Duration(milliseconds: 1000), _scheduleRulerSync);
}
