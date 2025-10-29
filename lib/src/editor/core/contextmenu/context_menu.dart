// TODO: Translate from C:\\MyTsProjects\\canvas-editor\\src\\editor\\core\\contextmenu\\ContextMenu.ts
import 'dart:async';
import 'dart:html';

import '../../dataset/constant/context_menu.dart';
import '../../dataset/constant/editor.dart';
import '../../dataset/enum/editor.dart';
import '../../interface/contextmenu/context_menu.dart';
import '../../interface/editor.dart';
import '../../interface/element.dart';
import '../../utils/element.dart' as element_utils;
import '../../utils/index.dart' show findParent;
import '../command/command.dart';
import 'menus/control_menus.dart';
import 'menus/global_menus.dart';
import 'menus/hyperlink_menus.dart';
import 'menus/image_menus.dart';
import 'menus/table_menus.dart';

class ContextMenu {
	ContextMenu(dynamic draw, Command command)
			: _draw = draw,
				_command = command,
				_options = (draw.getOptions() as IEditorOption?) ?? IEditorOption(),
				_range = draw.getRange(),
				_position = draw.getPosition(),
				_i18n = draw.getI18n(),
				_container = draw.getContainer() as DivElement,
				_contextMenuList = <IRegisterContextMenu>[
					...globalMenus,
					...tableMenus,
					...imageMenus,
					...controlMenus,
					...hyperlinkMenus,
				],
				_contextMenuContainerList = <DivElement>[],
				_contextMenuRelationShip = <DivElement, DivElement>{},
				_context = null {
		_addEvent();
	}

	final dynamic _draw;
	final Command _command;
	final IEditorOption _options;
	final dynamic _range;
	final dynamic _position;
	final dynamic _i18n;
	final DivElement _container;
	final List<IRegisterContextMenu> _contextMenuList;
	final List<DivElement> _contextMenuContainerList;
	final Map<DivElement, DivElement> _contextMenuRelationShip;
	IContextMenuContext? _context;

	StreamSubscription<MouseEvent>? _contextMenuSubscription;
	StreamSubscription<MouseEvent>? _sideEffectSubscription;

	List<IRegisterContextMenu> getContextMenuList() => List.unmodifiable(_contextMenuList);

	void registerContextMenuList(List<IRegisterContextMenu> payload) {
		_contextMenuList.addAll(payload);
	}

	void removeEvent() {
		_contextMenuSubscription?.cancel();
		_contextMenuSubscription = null;
		_sideEffectSubscription?.cancel();
		_sideEffectSubscription = null;
	}

	void dispose() {
		for (final container in _contextMenuContainerList) {
			container.remove();
		}
		_contextMenuContainerList.clear();
		_contextMenuRelationShip.clear();
	}

	List<IRegisterContextMenu> _filterMenuList(List<IRegisterContextMenu> menuList) {
		final disableKeys = _options.contextMenuDisableKeys ?? const <String>[];
		final filtered = <IRegisterContextMenu>[];
		for (final menu in menuList) {
			if (menu.disable == true) {
				continue;
			}
			if (menu.key != null && disableKeys.contains(menu.key)) {
				continue;
			}
			if (menu.isDivider == true) {
				filtered.add(menu);
				continue;
			}
			final condition = menu.when;
			if (condition == null || (_context != null && condition(_context!))) {
				filtered.add(menu);
			}
		}
		return filtered;
	}

	void _addEvent() {
		_contextMenuSubscription = _container.onContextMenu.listen(_proxyContextMenuEvent);
		_sideEffectSubscription = document.onMouseDown.listen(_handleSideEffect);
	}

	void _proxyContextMenuEvent(MouseEvent event) {
		_context = _getContext();
		final renderList = _filterMenuList(_contextMenuList);
		final hasRenderableMenu = renderList.any((menu) => menu.isDivider != true);
		if (hasRenderableMenu) {
			dispose();
			_render(
				renderList: renderList,
				left: event.client.x.toDouble(),
				top: event.client.y.toDouble(),
			);
		}
		event.preventDefault();
	}

	void _handleSideEffect(MouseEvent event) {
		if (_contextMenuContainerList.isEmpty) {
			return;
		}
		final path = event.composedPath();
		final EventTarget? firstTarget = path.isNotEmpty ? path.first : event.target;
		if (firstTarget is! Element) {
			dispose();
			return;
		}
		final contextMenuDom = findParent(
			firstTarget,
			(element) => element.getAttribute(editorComponent) == EditorComponent.contextmenu.name,
			true,
		);
		if (contextMenuDom == null) {
			dispose();
		}
	}

	IContextMenuContext _getContext() {
		final bool isReadonly = _draw.isReadonly() == true;
		final dynamic rangeValue = _range.getRange();
		final int startIndex = rangeValue?.startIndex as int? ?? -1;
		final int endIndex = rangeValue?.endIndex as int? ?? -1;
		final bool editorTextFocus = !(startIndex == -1 && endIndex == -1);
		final bool editorHasSelection = editorTextFocus && startIndex != endIndex;

		final dynamic positionContext = _position.getPositionContext();
		final bool isTable = positionContext?.isTable == true;
		final int? trIndex = positionContext?.trIndex as int?;
		final int? tdIndex = positionContext?.tdIndex as int?;
		final int? tableIndex = positionContext?.index as int?;

		IElement? tableElement;
		if (isTable && tableIndex != null) {
			final List<IElement> originalList =
					element_utils.zipElementList(List<IElement>.from(_draw.getOriginalElementList() as Iterable))
							.toList();
			if (tableIndex >= 0 && tableIndex < originalList.length) {
				tableElement = originalList[tableIndex];
			}
		}

		final bool isCrossRowCol = isTable && (rangeValue?.isCrossRowCol == true);
		final List<IElement> elementList =
				List<IElement>.from((_draw.getElementList() as Iterable?)?.whereType<IElement>() ?? const Iterable<IElement>.empty());
		final IElement? startElement =
				startIndex >= 0 && startIndex < elementList.length ? elementList[startIndex] : null;
		final IElement? endElement =
				endIndex >= 0 && endIndex < elementList.length ? elementList[endIndex] : null;

		EditorZone zone;
		try {
			zone = _draw.getZone().getZone() as EditorZone? ?? EditorZone.main;
		} catch (_) {
			zone = EditorZone.main;
		}

		return IContextMenuContext(
			startElement: startElement,
			endElement: endElement,
			isReadonly: isReadonly,
			editorHasSelection: editorHasSelection,
			editorTextFocus: editorTextFocus,
			isInTable: isTable,
			isCrossRowCol: isCrossRowCol,
			zone: zone,
			trIndex: trIndex,
			tdIndex: tdIndex,
			tableElement: tableElement,
			options: _options,
		);
	}

	DivElement _createContextMenuContainer() {
		final container = DivElement()
			..classes.add('${editorPrefix}-contextmenu-container')
			..setAttribute(editorComponent, EditorComponent.contextmenu.name);
		_container.append(container);
		return container;
	}

	DivElement _render({
		required List<IRegisterContextMenu> renderList,
		required double left,
		required double top,
		DivElement? parent,
	}) {
		final container = _createContextMenuContainer();
		final content = DivElement()..classes.add('${editorPrefix}-contextmenu-content');
		container.append(content);

		if (parent != null) {
			_contextMenuRelationShip[parent] = container;
		}

		DivElement? childContainer;

		for (var index = 0; index < renderList.length; index++) {
			final menu = renderList[index];
			if (menu.isDivider == true) {
				final bool isFirst = index == 0;
				final bool isLast = index == renderList.length - 1;
				final prevIsDivider = index > 0 && renderList[index - 1].isDivider == true;
				if (!isFirst && !isLast && !prevIsDivider) {
					content.append(DivElement()..classes.add('${editorPrefix}-contextmenu-divider'));
				}
				continue;
			}

			final item = DivElement()..classes.add('${editorPrefix}-contextmenu-item');

			if (menu.childMenus != null && menu.childMenus!.isNotEmpty) {
				final childMenus = _filterMenuList(menu.childMenus!);
				final hasChild = childMenus.any((child) => child.isDivider != true);
				if (hasChild) {
					item.classes.add('${editorPrefix}-contextmenu-sub-item');
								item.onMouseEnter.listen((_) {
						_setHoverStatus(item, true);
						_removeSubMenu(container);
						final rect = item.getBoundingClientRect();
						childContainer = _render(
							renderList: childMenus,
										left: rect.right.toDouble(),
										top: rect.top.toDouble(),
							parent: container,
						);
					});
					item.onMouseLeave.listen((evt) {
						final related = evt.relatedTarget;
						if (childContainer == null || related == null || !childContainer!.contains(related as Node)) {
							_setHoverStatus(item, false);
						}
					});
				}
			} else {
				item.onMouseEnter.listen((_) {
					_setHoverStatus(item, true);
					_removeSubMenu(container);
				});
				item.onMouseLeave.listen((_) => _setHoverStatus(item, false));
				item.onClick.listen((_) {
					if (menu.callback != null && _context != null) {
						menu.callback!(_command, _context!);
					}
					dispose();
				});
			}

			final icon = Element.tag('i');
			if (menu.icon != null && menu.icon!.isNotEmpty) {
				icon.classes.add('${editorPrefix}-contextmenu-${menu.icon}');
			}
			item.append(icon);

			final label = SpanElement();
			final name = menu.i18nPath != null
					? _formatName(_i18n?.t(menu.i18nPath) as String? ?? '')
					: _formatName(menu.name ?? '');
			label.text = name;
			item.append(label);

			if (menu.shortCut != null && menu.shortCut!.isNotEmpty) {
				final shortcut = SpanElement()
					..classes.add('${editorPrefix}-shortcut')
					..text = menu.shortCut;
				item.append(shortcut);
			}

			content.append(item);
		}

		container.style
			..display = 'block'
			..left = '0px'
			..top = '0px';

		_contextMenuContainerList.add(container);

		_adjustPosition(container, left, top);
		return container;
	}

	void _adjustPosition(DivElement container, double left, double top) {
		final rect = container.getBoundingClientRect();
		final width = rect.width;
		final height = rect.height;

		final viewportWidth = window.innerWidth?.toDouble() ?? width;
		final viewportHeight = window.innerHeight?.toDouble() ?? height;

		final adjustedLeft = left + width > viewportWidth ? left - width : left;
		final adjustedTop = top + height > viewportHeight ? top - height : top;

		container.style
			..left = '${adjustedLeft}px'
			..top = '${adjustedTop}px';
	}

	void _removeSubMenu(DivElement parent) {
		final child = _contextMenuRelationShip.remove(parent);
		if (child != null) {
			_removeSubMenu(child);
			child.remove();
		}
	}

	void _setHoverStatus(DivElement target, bool status) {
		final parent = target.parent;
		if (parent is Element) {
			for (final element in parent.children.whereType<Element>()) {
				element.classes.remove('hover');
			}
		}
		if (status) {
			target.classes.add('hover');
		} else {
			target.classes.remove('hover');
		}
	}

	String _formatName(String name) {
		if (name.isEmpty) {
			return name;
		}
		const placeholder = ContextMenuNamePlaceholder.selectedText;
		if (name.contains(placeholder)) {
			final selectedText = _range.toString() as String? ?? '';
			return name.replaceAll(placeholder, selectedText);
		}
		return name;
	}
}