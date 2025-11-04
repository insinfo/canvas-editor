import 'dart:async';
import 'dart:html';

import '../../dataset/constant/context_menu.dart';
import '../../dataset/constant/editor.dart';
import '../../dataset/enum/editor.dart';
import '../../interface/contextmenu/context_menu.dart';
import '../../interface/editor.dart';
import '../../interface/element.dart';
import '../../interface/position.dart';
import '../../interface/range.dart';
import '../../utils/element.dart' as element_utils;
import '../../utils/index.dart' show findParent;
import '../command/command.dart';
import '../draw/draw.dart';
import '../i18n/i18n.dart';
import '../position/position.dart';
import '../range/range_manager.dart';
import 'menus/control_menus.dart';
import 'menus/global_menus.dart';
import 'menus/hyperlink_menus.dart';
import 'menus/image_menus.dart';
import 'menus/table_menus.dart';

class _RenderPayload {
	const _RenderPayload({
		required this.contextMenuList,
		required this.left,
		required this.top,
		this.parentMenuContainer,
	});

	final List<IRegisterContextMenu> contextMenuList;
	final double left;
	final double top;
	final DivElement? parentMenuContainer;
}

class ContextMenu {
	ContextMenu(Draw draw, Command command)
		: _draw = draw,
			_command = command,
			_options = (draw.getOptions() as IEditorOption?) ?? IEditorOption(),
			_range = draw.getRange() as RangeManager,
			_position = draw.getPosition() as Position,
			_i18n = draw.getI18n(),
			_container = draw.getContainer(),
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

	final Draw _draw;
	final Command _command;
	final IEditorOption _options;
	final RangeManager _range;
	final Position _position;
	final I18n _i18n;
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
		for (final DivElement container in _contextMenuContainerList) {
			container.remove();
		}
		_contextMenuContainerList.clear();
		_contextMenuRelationShip.clear();
	}

	void _addEvent() {
		_contextMenuSubscription = _container.onContextMenu.listen(_proxyContextMenuEvent);
		_sideEffectSubscription = document.onMouseDown.listen(_handleSideEffect);
	}

	void _proxyContextMenuEvent(MouseEvent evt) {
		_context = _getContext();
		final List<IRegisterContextMenu> renderList = _filterMenuList(_contextMenuList);
		final bool hasRenderableMenu = renderList.any((IRegisterContextMenu menu) => menu.isDivider != true);
		if (hasRenderableMenu) {
			dispose();
			_render(
				_RenderPayload(
					contextMenuList: renderList,
					left: evt.client.x.toDouble(),
					top: evt.client.y.toDouble(),
				),
			);
		}
		evt.preventDefault();
	}

	void _handleSideEffect(MouseEvent evt) {
		if (_contextMenuContainerList.isEmpty) {
			return;
		}
		final List<EventTarget> path = evt.composedPath();
		final EventTarget? target = path.isNotEmpty ? path.first : evt.target;
		if (target is! Element) {
			dispose();
			return;
		}
		final Element? contextMenuDom = findParent(
			target,
			(Element element) => element.getAttribute(editorComponent) == EditorComponent.contextmenu.name,
			true,
		);
		if (contextMenuDom == null) {
			dispose();
		}
	}

	List<IRegisterContextMenu> _filterMenuList(List<IRegisterContextMenu> menuList) {
		final List<String> disableKeys = _options.contextMenuDisableKeys ?? const <String>[];
		final List<IRegisterContextMenu> filtered = <IRegisterContextMenu>[];
		for (final IRegisterContextMenu menu in menuList) {
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
			final ContextMenuCondition? condition = menu.when;
			if (condition == null || (_context != null && condition(_context!))) {
				filtered.add(menu);
			}
		}
		return filtered;
	}

	IContextMenuContext _getContext() {
		final bool isReadonly = _draw.isReadonly() == true;
		final IRange rangeValue = _range.getRange();
		final int startIndex = rangeValue.startIndex;
		final int endIndex = rangeValue.endIndex;
		final bool editorTextFocus = startIndex != -1 || endIndex != -1;
		final bool editorHasSelection = editorTextFocus && startIndex != endIndex;

		final IPositionContext positionContext = _position.getPositionContext();
		final bool isTable = positionContext.isTable;
		final int? trIndex = positionContext.trIndex;
		final int? tdIndex = positionContext.tdIndex;
		final int? tableIndex = positionContext.index;

		IElement? tableElement;
		if (isTable && tableIndex != null) {
			final List<IElement> originalList = (_draw.getOriginalElementList() as List).cast<IElement>();
			if (tableIndex >= 0 && tableIndex < originalList.length) {
				final List<IElement> zipped = element_utils.zipElementList(
					<IElement>[originalList[tableIndex]],
					options: const element_utils.ZipElementListOption(
						extraPickAttrs: <String>['id'],
					),
				);
				if (zipped.isNotEmpty) {
					tableElement = zipped.first;
				}
			}
		}

		final bool isCrossRowCol = isTable && (rangeValue.isCrossRowCol == true);
		final List<IElement> elementList = (_draw.getElementList() as List).cast<IElement>();
		final IElement? startElement =
			(startIndex >= 0 && startIndex < elementList.length) ? elementList[startIndex] : null;
		final IElement? endElement =
			(endIndex >= 0 && endIndex < elementList.length) ? elementList[endIndex] : null;

		EditorZone zone = EditorZone.main;
		try {
			zone = (_draw.getZone().getZone() as EditorZone?) ?? EditorZone.main;
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
		final DivElement container = DivElement()
			..classes.add('${editorPrefix}-contextmenu-container')
			..setAttribute(editorComponent, EditorComponent.contextmenu.name);
		_container.append(container);
		return container;
	}

	DivElement _render(_RenderPayload payload) {
		final DivElement container = _createContextMenuContainer();
		final DivElement content = DivElement()
			..classes.add('${editorPrefix}-contextmenu-content');
		container.append(content);

		if (payload.parentMenuContainer != null) {
			_contextMenuRelationShip[payload.parentMenuContainer!] = container;
		}

		DivElement? childMenuContainer;

		for (int index = 0; index < payload.contextMenuList.length; index++) {
			final IRegisterContextMenu menu = payload.contextMenuList[index];
			if (menu.isDivider == true) {
				final bool isFirst = index == 0;
				final bool isLast = index == payload.contextMenuList.length - 1;
				final bool prevIsDivider =
					index > 0 && payload.contextMenuList[index - 1].isDivider == true;
				if (!isFirst && !isLast && !prevIsDivider) {
					content.append(DivElement()..classes.add('${editorPrefix}-contextmenu-divider'));
				}
				continue;
			}

			final DivElement menuItem = DivElement()
				..classes.add('${editorPrefix}-contextmenu-item');

			if (menu.childMenus != null && menu.childMenus!.isNotEmpty) {
				final List<IRegisterContextMenu> childMenus = _filterMenuList(menu.childMenus!);
				final bool hasRenderableChild = childMenus.any((IRegisterContextMenu child) => child.isDivider != true);
				if (hasRenderableChild) {
					menuItem.classes.add('${editorPrefix}-contextmenu-sub-item');
					menuItem.onMouseEnter.listen((_) {
						_setHoverStatus(menuItem, true);
						_removeSubMenu(container);
						final Rectangle<num> rect = menuItem.getBoundingClientRect();
						childMenuContainer = _render(
							_RenderPayload(
								contextMenuList: childMenus,
								left: rect.right.toDouble(),
								top: rect.top.toDouble(),
								parentMenuContainer: container,
							),
						);
					});
					menuItem.onMouseLeave.listen((MouseEvent evt) {
						final EventTarget? related = evt.relatedTarget;
						if (childMenuContainer == null ||
							related == null ||
							!childMenuContainer!.contains(related as Node)) {
							_setHoverStatus(menuItem, false);
						}
					});
				}
			} else {
				menuItem.onMouseEnter.listen((_) {
					_setHoverStatus(menuItem, true);
					_removeSubMenu(container);
				});
				menuItem.onMouseLeave.listen((_) => _setHoverStatus(menuItem, false));
				menuItem.onClick.listen((_) {
					if (menu.callback != null && _context != null) {
						menu.callback!(_command, _context!);
					}
					dispose();
				});
			}

			final Element icon = Element.tag('i');
			if (menu.icon != null && menu.icon!.isNotEmpty) {
				icon.classes.add('${editorPrefix}-contextmenu-${menu.icon}');
			}
			menuItem.append(icon);

			final SpanElement label = SpanElement();
			final String labelText;
			if (menu.i18nPath != null) {
				final dynamic translation = _i18n.t(menu.i18nPath!);
				labelText = _formatName(translation is String ? translation : (translation?.toString() ?? ''));
			} else {
				labelText = _formatName(menu.name ?? '');
			}
			label.text = labelText;
			menuItem.append(label);

			if (menu.shortCut != null && menu.shortCut!.isNotEmpty) {
				final SpanElement shortcut = SpanElement()
					..classes.add('${editorPrefix}-shortcut')
					..text = menu.shortCut;
				menuItem.append(shortcut);
			}

			content.append(menuItem);
		}

		container.style
			..display = 'block'
			..left = '0px'
			..top = '0px';

		_contextMenuContainerList.add(container);
		_adjustPosition(container, payload.left, payload.top);
		return container;
	}

	void _adjustPosition(DivElement container, double left, double top) {
		final Rectangle<num> rect = container.getBoundingClientRect();
		final double width = rect.width.toDouble();
		final double height = rect.height.toDouble();
		final double viewportWidth = window.innerWidth?.toDouble() ?? width;
		final double viewportHeight = window.innerHeight?.toDouble() ?? height;
		final double adjustedLeft = left + width > viewportWidth ? left - width : left;
		final double adjustedTop = top + height > viewportHeight ? top - height : top;
		container.style
			..left = '${adjustedLeft}px'
			..top = '${adjustedTop}px';
	}

	void _removeSubMenu(DivElement parent) {
		final DivElement? child = _contextMenuRelationShip.remove(parent);
		if (child != null) {
			_removeSubMenu(child);
			child.remove();
		}
	}

	void _setHoverStatus(DivElement target, bool status) {
		final Element? parent = target.parent;
		if (parent != null) {
			for (final Element element in parent.children.whereType<Element>()) {
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
		const String placeholder = ContextMenuNamePlaceholder.selectedText;
		if (name.contains(placeholder)) {
			final String selectedText = _range.toString();
			return name.replaceAll(placeholder, selectedText);
		}
		return name;
	}
}