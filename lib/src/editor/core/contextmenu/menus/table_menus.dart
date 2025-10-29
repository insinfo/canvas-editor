// TODO: Translate from C:\\MyTsProjects\\canvas-editor\\src\\editor\\core\\contextmenu\\menus\\tableMenus.ts
import '../../../dataset/constant/context_menu.dart';
import '../../../dataset/enum/editor.dart';
import '../../../dataset/enum/table/table.dart';
import '../../../dataset/enum/vertical_align.dart';
import '../../../interface/contextmenu/context_menu.dart';
import '../../command/command.dart';

final InternalContextMenuKeyTable _tableKey = InternalContextMenuKey.table;

List<IRegisterContextMenu> get tableMenus => <IRegisterContextMenu>[
			IRegisterContextMenu(isDivider: true),
			IRegisterContextMenu(
				key: _tableKey.border,
				i18nPath: 'contextmenu.table.border',
				icon: 'border-all',
				when: (payload) =>
						!payload.isReadonly && payload.isInTable && payload.options.mode != EditorMode.form,
				childMenus: <IRegisterContextMenu>[
					IRegisterContextMenu(
						key: _tableKey.borderAll,
						i18nPath: 'contextmenu.table.borderAll',
						icon: 'border-all',
						when: (_) => true,
						callback: (command, _) => (command as Command).executeTableBorderType(TableBorder.all),
					),
					IRegisterContextMenu(
						key: _tableKey.borderEmpty,
						i18nPath: 'contextmenu.table.borderEmpty',
						icon: 'border-empty',
						when: (_) => true,
						callback: (command, _) => (command as Command).executeTableBorderType(TableBorder.empty),
					),
					IRegisterContextMenu(
						key: _tableKey.borderDash,
						i18nPath: 'contextmenu.table.borderDash',
						icon: 'border-dash',
						when: (_) => true,
						callback: (command, _) => (command as Command).executeTableBorderType(TableBorder.dash),
					),
					IRegisterContextMenu(
						key: _tableKey.borderExternal,
						i18nPath: 'contextmenu.table.borderExternal',
						icon: 'border-external',
						when: (_) => true,
						callback: (command, _) => (command as Command).executeTableBorderType(TableBorder.external),
					),
					IRegisterContextMenu(
						key: _tableKey.borderInternal,
						i18nPath: 'contextmenu.table.borderInternal',
						icon: 'border-internal',
						when: (_) => true,
						callback: (command, _) => (command as Command).executeTableBorderType(TableBorder.internal),
					),
					IRegisterContextMenu(
						key: _tableKey.borderTd,
						i18nPath: 'contextmenu.table.borderTd',
						icon: 'border-td',
						when: (_) => true,
						childMenus: <IRegisterContextMenu>[
							IRegisterContextMenu(
								key: _tableKey.borderTdTop,
								i18nPath: 'contextmenu.table.borderTdTop',
								icon: 'border-td-top',
								when: (_) => true,
								callback: (command, _) => (command as Command).executeTableTdBorderType(TdBorder.top),
							),
							IRegisterContextMenu(
								key: _tableKey.borderTdRight,
								i18nPath: 'contextmenu.table.borderTdRight',
								icon: 'border-td-right',
								when: (_) => true,
								callback: (command, _) => (command as Command).executeTableTdBorderType(TdBorder.right),
							),
							IRegisterContextMenu(
								key: _tableKey.borderTdBottom,
								i18nPath: 'contextmenu.table.borderTdBottom',
								icon: 'border-td-bottom',
								when: (_) => true,
								callback: (command, _) => (command as Command).executeTableTdBorderType(TdBorder.bottom),
							),
							IRegisterContextMenu(
								key: _tableKey.borderTdLeft,
								i18nPath: 'contextmenu.table.borderTdLeft',
								icon: 'border-td-left',
								when: (_) => true,
								callback: (command, _) => (command as Command).executeTableTdBorderType(TdBorder.left),
							),
							IRegisterContextMenu(
								key: _tableKey.borderTdForward,
								i18nPath: 'contextmenu.table.borderTdForward',
								icon: 'border-td-forward',
								when: (_) => true,
								callback: (command, _) => (command as Command).executeTableTdSlashType(TdSlash.forward),
							),
							IRegisterContextMenu(
								key: _tableKey.borderTdBack,
								i18nPath: 'contextmenu.table.borderTdBack',
								icon: 'border-td-back',
								when: (_) => true,
								callback: (command, _) => (command as Command).executeTableTdSlashType(TdSlash.back),
							),
						],
					),
				],
			),
			IRegisterContextMenu(
				key: _tableKey.verticalAlign,
				i18nPath: 'contextmenu.table.verticalAlign',
				icon: 'vertical-align',
				when: (payload) =>
						!payload.isReadonly && payload.isInTable && payload.options.mode != EditorMode.form,
				childMenus: <IRegisterContextMenu>[
					IRegisterContextMenu(
						key: _tableKey.verticalAlignTop,
						i18nPath: 'contextmenu.table.verticalAlignTop',
						icon: 'vertical-align-top',
						when: (_) => true,
						callback: (command, _) =>
								(command as Command).executeTableTdVerticalAlign(VerticalAlign.top),
					),
					IRegisterContextMenu(
						key: _tableKey.verticalAlignMiddle,
						i18nPath: 'contextmenu.table.verticalAlignMiddle',
						icon: 'vertical-align-middle',
						when: (_) => true,
						callback: (command, _) =>
								(command as Command).executeTableTdVerticalAlign(VerticalAlign.middle),
					),
					IRegisterContextMenu(
						key: _tableKey.verticalAlignBottom,
						i18nPath: 'contextmenu.table.verticalAlignBottom',
						icon: 'vertical-align-bottom',
						when: (_) => true,
						callback: (command, _) =>
								(command as Command).executeTableTdVerticalAlign(VerticalAlign.bottom),
					),
				],
			),
			IRegisterContextMenu(
				key: _tableKey.insertRowCol,
				i18nPath: 'contextmenu.table.insertRowCol',
				icon: 'insert-row-col',
				when: (payload) =>
						!payload.isReadonly && payload.isInTable && payload.options.mode != EditorMode.form,
				childMenus: <IRegisterContextMenu>[
					IRegisterContextMenu(
						key: _tableKey.insertTopRow,
						i18nPath: 'contextmenu.table.insertTopRow',
						icon: 'insert-top-row',
						when: (_) => true,
						callback: (command, _) => (command as Command).executeInsertTableTopRow(),
					),
					IRegisterContextMenu(
						key: _tableKey.insertBottomRow,
						i18nPath: 'contextmenu.table.insertBottomRow',
						icon: 'insert-bottom-row',
						when: (_) => true,
						callback: (command, _) => (command as Command).executeInsertTableBottomRow(),
					),
					IRegisterContextMenu(
						key: _tableKey.insertLeftCol,
						i18nPath: 'contextmenu.table.insertLeftCol',
						icon: 'insert-left-col',
						when: (_) => true,
						callback: (command, _) => (command as Command).executeInsertTableLeftCol(),
					),
					IRegisterContextMenu(
						key: _tableKey.insertRightCol,
						i18nPath: 'contextmenu.table.insertRightCol',
						icon: 'insert-right-col',
						when: (_) => true,
						callback: (command, _) => (command as Command).executeInsertTableRightCol(),
					),
				],
			),
			IRegisterContextMenu(
				key: _tableKey.deleteRowCol,
				i18nPath: 'contextmenu.table.deleteRowCol',
				icon: 'delete-row-col',
				when: (payload) =>
						!payload.isReadonly && payload.isInTable && payload.options.mode != EditorMode.form,
				childMenus: <IRegisterContextMenu>[
					IRegisterContextMenu(
						key: _tableKey.deleteRow,
						i18nPath: 'contextmenu.table.deleteRow',
						icon: 'delete-row',
						when: (_) => true,
						callback: (command, _) => (command as Command).executeDeleteTableRow(),
					),
					IRegisterContextMenu(
						key: _tableKey.deleteCol,
						i18nPath: 'contextmenu.table.deleteCol',
						icon: 'delete-col',
						when: (_) => true,
						callback: (command, _) => (command as Command).executeDeleteTableCol(),
					),
					IRegisterContextMenu(
						key: _tableKey.deleteTable,
						i18nPath: 'contextmenu.table.deleteTable',
						icon: 'delete-table',
						when: (_) => true,
						callback: (command, _) => (command as Command).executeDeleteTable(),
					),
				],
			),
			IRegisterContextMenu(
				key: _tableKey.mergeCell,
				i18nPath: 'contextmenu.table.mergeCell',
				icon: 'merge-cell',
				when: (payload) =>
						!payload.isReadonly && payload.isCrossRowCol && payload.options.mode != EditorMode.form,
				callback: (command, _) => (command as Command).executeMergeTableCell(),
			),
			IRegisterContextMenu(
				key: _tableKey.cancelMergeCell,
				i18nPath: 'contextmenu.table.mergeCancelCell',
				icon: 'merge-cancel-cell',
				when: (payload) =>
						!payload.isReadonly && payload.isInTable && payload.options.mode != EditorMode.form,
				callback: (command, _) => (command as Command).executeCancelMergeTableCell(),
			),
		];