import 'dart:async';
import 'dart:html';

import '../../editor/index.dart';
import '../../editor/interface/search.dart' show IReplaceOption;
import '../core/ui_component.dart';

/// Comentário associado a um grupo de elementos do documento.
///
/// [id] deve corresponder ao `groupId` gravado nos elementos comentados. A
/// aplicação hospedeira mantém o conteúdo/autoria; o editor cuida apenas da
/// navegação e da remoção da marcação no documento.
class CanvasEditorComment {
  const CanvasEditorComment({
    required this.id,
    required this.content,
    this.author,
    this.quotedText,
    this.createdAt,
  });

  final String id;
  final String content;
  final String? author;
  final String? quotedText;
  final DateTime? createdAt;
}

/// Sidebar de comentários desacoplada de mocks. Somente comentários cujos
/// grupos ainda existem no documento são mostrados.
class WidgetCommentsPanel extends UiComponent {
  WidgetCommentsPanel(
    this._command, {
    required List<CanvasEditorComment> comments,
    required void Function() onClose,
    this.onDelete,
    this.readOnly = false,
  })  : _comments = List<CanvasEditorComment>.from(comments),
        _onClose = onClose {
    _main = DivElement()..classes.add('ce-panel__main');
    root = DivElement()
      ..classes.addAll(<String>['ce-panel', 'ce-panel--comments'])
      ..style.display = 'none'
      ..children.addAll(<Element>[
        _buildHeader('Comentários', hide),
        _main,
      ]);
  }

  final Command _command;
  final void Function() _onClose;
  final void Function(CanvasEditorComment comment)? onDelete;
  final bool readOnly;
  final List<CanvasEditorComment> _comments;

  @override
  late final DivElement root;
  late final DivElement _main;

  bool get isVisible => root.style.display != 'none';

  Future<void> show() async {
    root.style.display = 'flex';
    await refresh();
  }

  void hide() {
    root.style.display = 'none';
    _onClose();
  }

  void setComments(Iterable<CanvasEditorComment> comments) {
    _comments
      ..clear()
      ..addAll(comments);
    if (isVisible) unawaited(refresh());
  }

  Future<void> refresh() async {
    final Set<String> groupIds = (await _command.getGroupIds()).toSet();
    final List<CanvasEditorComment> visible = _comments
        .where((CanvasEditorComment comment) => groupIds.contains(comment.id))
        .toList(growable: false);
    _main.children.clear();
    if (visible.isEmpty) {
      _main.append(DivElement()
        ..classes.add('ce-panel__empty')
        ..text = 'O documento não tem comentários.');
      return;
    }
    for (final CanvasEditorComment comment in visible) {
      _main.append(_buildComment(comment));
    }
  }

  Element _buildComment(CanvasEditorComment comment) {
    final DivElement card = DivElement()
      ..classes.add('ce-comment')
      ..tabIndex = 0
      ..onClick.listen((_) => _command.executeLocationGroup(comment.id))
      ..onKeyDown.listen((KeyboardEvent event) {
        if (event.key == 'Enter' || event.key == ' ') {
          event.preventDefault();
          _command.executeLocationGroup(comment.id);
        }
      });
    if (comment.author?.isNotEmpty == true) {
      card.append(SpanElement()
        ..classes.add('ce-comment__author')
        ..text = comment.author);
    }
    if (comment.quotedText?.isNotEmpty == true) {
      card.append(DivElement()
        ..classes.add('ce-comment__quote')
        ..text = comment.quotedText);
    }
    card.append(DivElement()
      ..classes.add('ce-comment__content')
      ..text = comment.content);
    if (!readOnly) {
      card.append(ButtonElement()
        ..type = 'button'
        ..classes.add('ce-comment__delete')
        ..title = 'Excluir comentário'
        ..setAttribute('aria-label', 'Excluir comentário')
        ..append(SpanElement()..classes.addAll(<String>['ti', 'ti-trash']))
        ..onClick.listen((MouseEvent event) {
          event.stopPropagation();
          _command.executeDeleteGroup(comment.id);
          _comments.removeWhere((item) => item.id == comment.id);
          onDelete?.call(comment);
          unawaited(refresh());
        }));
    }
    return card;
  }
}

/// Painel de navegação (catálogo/sumário) estilo Word: lista os títulos do
/// documento e navega até eles via `executeLocationCatalog`.
class WidgetCatalogPanel extends UiComponent {
  WidgetCatalogPanel(this._command, {required void Function() onClose}) {
    _main = DivElement()..classes.add('ce-panel__main');
    root = DivElement()
      ..classes.addAll(<String>['ce-panel', 'ce-panel--catalog'])
      ..style.display = 'none'
      ..children.addAll(<Element>[
        _buildHeader('Navegação', onClose),
        _main,
      ]);
  }

  final Command _command;

  @override
  late final DivElement root;
  late final DivElement _main;

  bool get isVisible => root.style.display != 'none';

  void show() => root.style.display = 'flex';

  void hide() => root.style.display = 'none';

  Future<void> refresh() async {
    final ICatalog? catalog = await _command.getCatalog();
    _main.children.clear();
    if (catalog == null || catalog.isEmpty) {
      _main.append(DivElement()
        ..classes.add('ce-panel__empty')
        ..text = 'O documento não tem títulos.');
      return;
    }
    _appendItems(_main, catalog);
  }

  void _appendItems(Element parent, List<ICatalogItem> entries) {
    for (final ICatalogItem entry in entries) {
      final DivElement item = DivElement()..classes.add('ce-catalog-item');
      final DivElement content = DivElement()
        ..classes.add('ce-catalog-item__content')
        ..append(SpanElement()..text = entry.name)
        ..title = entry.name;
      content.onClick.listen((_) => _command.executeLocationCatalog(entry.id));
      item.append(content);
      if (entry.subCatalog.isNotEmpty) {
        _appendItems(item, entry.subCatalog);
      }
      parent.append(item);
    }
  }
}

/// Painel Localizar/Substituir estilo Word, ligado a `executeSearch`,
/// `executeSearchNavigatePre/Next` e `executeReplace`.
class WidgetFindPanel extends UiComponent {
  WidgetFindPanel(this._command, {required void Function() onClose})
      : _onClose = onClose {
    _buildDom();
  }

  final Command _command;
  final void Function() _onClose;

  @override
  late final DivElement root;
  late final InputElement _searchInput;
  late final InputElement _replaceInput;
  late final SpanElement _countLabel;

  /// Índice 0-based do resultado destacado, usado pelo "Substituir".
  int? _currentGroupIndex;

  bool get isVisible => root.style.display != 'none';

  void _buildDom() {
    _searchInput = InputElement(type: 'text')
      ..classes.add('ce-find__input')
      ..placeholder = 'Localizar no documento';
    _replaceInput = InputElement(type: 'text')
      ..classes.add('ce-find__input')
      ..placeholder = 'Substituir por';
    _countLabel = SpanElement()..classes.add('ce-find__count');

    final ButtonElement prevButton =
        _navButton('ti-chevron-up', 'Anterior', () {
      _command.executeSearchNavigatePre();
      _updateCount();
    });
    final ButtonElement nextButton =
        _navButton('ti-chevron-down', 'Próximo', () {
      _command.executeSearchNavigateNext();
      _updateCount();
    });

    final ButtonElement replaceOne = ButtonElement()
      ..type = 'button'
      ..classes.add('ce-find__action')
      ..text = 'Substituir'
      ..onClick.listen((_) => _replaceCurrent());
    final ButtonElement replaceAll = ButtonElement()
      ..type = 'button'
      ..classes.add('ce-find__action')
      ..text = 'Substituir tudo'
      ..onClick.listen((_) => _replaceAll());

    _searchInput.onInput.listen((_) => runSearch());
    _searchInput.onKeyDown.listen((KeyboardEvent event) {
      if (event.key == 'Enter') {
        event.preventDefault();
        event.shiftKey
            ? _command.executeSearchNavigatePre()
            : _command.executeSearchNavigateNext();
        _updateCount();
      } else if (event.key == 'Escape') {
        close();
      }
    });
    _replaceInput.onKeyDown.listen((KeyboardEvent event) {
      if (event.key == 'Enter') {
        event.preventDefault();
        _replaceCurrent();
      } else if (event.key == 'Escape') {
        close();
      }
    });

    root = DivElement()
      ..classes.addAll(<String>['ce-panel', 'ce-panel--find'])
      ..style.display = 'none'
      ..children.addAll(<Element>[
        _buildHeader('Localizar e substituir', close),
        DivElement()
          ..classes.add('ce-panel__main')
          ..children.addAll(<Element>[
            DivElement()
              ..classes.add('ce-find__row')
              ..children
                  .addAll(<Element>[_searchInput, prevButton, nextButton]),
            DivElement()
              ..classes.add('ce-find__meta')
              ..append(_countLabel),
            DivElement()
              ..classes.add('ce-find__row')
              ..append(_replaceInput),
            DivElement()
              ..classes.add('ce-find__actions')
              ..children.addAll(<Element>[replaceOne, replaceAll]),
          ]),
      ]);
  }

  ButtonElement _navButton(
      String iconClass, String label, void Function() action) {
    return ButtonElement()
      ..type = 'button'
      ..classes.add('ce-find__nav')
      ..title = label
      ..setAttribute('aria-label', label)
      ..append(SpanElement()..classes.addAll(<String>['ti', iconClass]))
      ..onClick.listen((_) => action());
  }

  void open({bool focusReplace = false}) {
    root.style.display = 'flex';
    if (focusReplace) {
      _replaceInput.focus();
    } else {
      _searchInput
        ..focus()
        ..select();
    }
    if (_searchInput.value?.isNotEmpty == true) {
      runSearch();
    }
  }

  void close() {
    root.style.display = 'none';
    _command.executeSearch(null);
    _countLabel.text = '';
    _currentGroupIndex = null;
    _onClose();
  }

  void runSearch() {
    final String? value = _searchInput.value;
    _command.executeSearch(value != null && value.isNotEmpty ? value : null);
    _updateCount();
  }

  void _updateCount() {
    final dynamic info = _command.getSearchNavigateInfo();
    if (info != null) {
      final dynamic index = info.index;
      final dynamic count = info.count;
      if (index is int && count is int && count > 0) {
        _countLabel.text = '$index de $count';
        _currentGroupIndex = index - 1;
        return;
      }
    }
    final bool hasQuery = _searchInput.value?.isNotEmpty == true;
    _countLabel.text = hasQuery ? 'Nenhum resultado' : '';
    _currentGroupIndex = null;
  }

  void _replaceCurrent() {
    if (_searchInput.value?.isNotEmpty != true) return;
    final String replaceValue = _replaceInput.value ?? '';
    final int? index = _currentGroupIndex;
    if (index != null && index >= 0) {
      _command.executeReplace(replaceValue, IReplaceOption(index: index));
    } else {
      _command.executeReplace(replaceValue);
    }
    runSearch();
  }

  void _replaceAll() {
    if (_searchInput.value?.isNotEmpty != true) return;
    _command.executeReplace(_replaceInput.value ?? '');
    runSearch();
  }
}

DivElement _buildHeader(String title, void Function() onClose) {
  return DivElement()
    ..classes.add('ce-panel__header')
    ..children.addAll(<Element>[
      SpanElement()
        ..classes.add('ce-panel__title')
        ..text = title,
      ButtonElement()
        ..type = 'button'
        ..classes.add('ce-panel__close')
        ..title = 'Fechar'
        ..setAttribute('aria-label', 'Fechar painel')
        ..append(SpanElement()..classes.addAll(<String>['ti', 'ti-x']))
        ..onClick.listen((_) => onClose()),
    ]);
}
