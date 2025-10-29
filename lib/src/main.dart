import 'dart:async';
import 'dart:convert';
import 'dart:html';
import 'dart:js_util' as js_util;

import 'components/dialog/dialog.dart';
import 'editor/core/command/command.dart';
import 'editor/dataset/enum/block.dart';
import 'editor/dataset/enum/common.dart';
import 'editor/dataset/enum/control.dart';
import 'editor/dataset/enum/editor.dart';
import 'editor/dataset/enum/element.dart';
import 'editor/dataset/enum/list.dart';
import 'editor/dataset/enum/row.dart';
import 'editor/dataset/enum/text.dart';
import 'editor/dataset/enum/title.dart';
import 'editor/index.dart';
import 'editor/interface/block.dart';
import 'editor/interface/catalog.dart';
import 'editor/interface/checkbox.dart';
import 'editor/interface/control.dart';
import 'editor/interface/draw.dart';
import 'editor/interface/editor.dart';
import 'editor/interface/element.dart';
import 'editor/interface/radio.dart';
import 'editor/interface/text.dart';
import 'editor/interface/watermark.dart';
import 'editor/utils/index.dart' as editor_utils;
import 'mock.dart';
import 'utils/index.dart' as app_utils;
import 'utils/prism.dart';

void main() {
	window.onLoad.listen((_) {
		final userAgent = window.navigator.userAgent;
		final isApple = userAgent.contains('Mac OS X');
		_EditorApp(isApple: isApple).initialize();
	});
}

class _EditorApp {
	_EditorApp({required this.isApple});

	final bool isApple;

	late final Editor editor;
	Command get command => editor.command;

	late final DivElement undoDom;
	late final DivElement redoDom;
	late final DivElement painterDom;
	late final DivElement fontSelectDom;
	late final DivElement fontOptionDom;
	late final DivElement sizeSelectDom;
	late final DivElement sizeOptionDom;
	late final DivElement boldDom;
	late final DivElement italicDom;
	late final DivElement underlineDom;
	late final DivElement underlineOptionDom;
	late final DivElement strikeoutDom;
	late final DivElement superscriptDom;
	late final DivElement subscriptDom;
	late final DivElement colorDom;
	late final InputElement colorControlDom;
	late final SpanElement colorSpanDom;
	late final DivElement highlightDom;
	late final InputElement highlightControlDom;
	late final SpanElement highlightSpanDom;
	late final DivElement titleSelectDom;
	late final DivElement titleOptionDom;
	late final DivElement leftDom;
	late final DivElement centerDom;
	late final DivElement rightDom;
	late final DivElement alignmentDom;
	late final DivElement justifyDom;
	late final DivElement rowOptionDom;
	late final DivElement listDom;
	late final DivElement listOptionDom;
	late final DivElement separatorDom;
	late final DivElement separatorOptionDom;
	late final DivElement pageScalePercentageDom;
	late final DivElement searchDom;
	late final InputElement searchInputDom;
	late final InputElement replaceInputDom;
	late final DivElement searchCollapseDom;
	late final LabelElement searchResultDom;
	SpanElement? searchCloseDom;
	ButtonElement? replaceButton;
	DivElement? searchArrowLeftDom;
	DivElement? searchArrowRightDom;
	late final DivElement catalogDom;
	late final DivElement catalogMainDom;
	late final DivElement pageModeOptionsDom;
	late final DivElement watermarkOptionDom;
	late final DivElement controlOptionDom;
	late final DivElement dateOptionsDom;
	late final DivElement modeElement;
	late final DivElement fullscreenDom;
	late final DivElement editorOptionDom;
	late final DivElement commentDom;

	final List<EditorComment> _commentData = List<EditorComment>.from(commentList);
	final List<List<TableCellElement>> _tableCellList = <List<TableCellElement>>[];

	bool _isCatalogVisible = true;
	bool _awaitingPainterSecondClick = false;
	Timer? _painterTimer;
	int _tableRowIndex = 0;
	int _tableColIndex = 0;

	late final void Function() _debouncedContentChange;

	Future<void> initialize() async {
		_createEditorInstance();
		_bindGlobalListeners();
		_setupUndoRedoAndFormat();
		_setupFontAndStyleControls();
		_setupTitleAndAlignmentControls();
		_setupListControls();
		_setupSeparatorAndPageBreakControls();
		_setupTableControls();
		_setupImageControl();
		_setupHyperlinkControl();
		_setupWatermarkControl();
		_setupCodeblockControl();
		_setupControlMenu();
		_setupCheckboxRadioLatexControls();
		_setupDateControl();
		_setupBlockControl();
		_setupSearchAndReplace();
		_setupPrintControl();
		_setupCatalogControls();
		_setupPageControls();
		_setupPaperControls();
		_setupFullscreenControl();
		_setupModeControl();
		_setupOptionsDialog();
		commentDom = _requireElement<DivElement>('.comment');

		_setupEditorListeners();

		_debouncedContentChange = app_utils.debounce(() {
			unawaited(_handleContentChange());
		}, const Duration(milliseconds: 200));

		editor.listener.contentChange = _debouncedContentChange;

		await _handleContentChange();
	}

	void _setupHyperlinkControl() {
		final hyperlinkDom = _requireElement<DivElement>('.menu-item__hyperlink');
		hyperlinkDom.onClick.listen((_) {
			final defaultText = command.getRangeText();
			Dialog(
				DialogOptions(
					title: '超链接',
					data: [
						DialogData(
							type: 'text',
							label: '文本',
							name: 'name',
							required: true,
							placeholder: '请输入文本',
							value: defaultText,
						),
						DialogData(
							type: 'text',
							label: '链接',
							name: 'url',
							required: true,
							placeholder: '请输入链接',
						),
					],
					onConfirm: (payload) {
						final name = _findPayloadValue(payload, 'name');
						final url = _findPayloadValue(payload, 'url');
						if (name == null || name.isEmpty || url == null || url.isEmpty) {
							return;
						}
						final valueList = editor_utils
							.splitText(name)
							.map((text) => IElement(value: text, size: 16))
							.toList();
						command.executeHyperlink(
							IElement(
								type: ElementType.hyperlink,
								value: '',
								url: url,
								valueList: valueList,
							),
						);
					},
				),
			);
		});
	}

	void _setupWatermarkControl() {
		final watermarkDom = _requireElement<DivElement>('.menu-item__watermark');
		watermarkOptionDom = _requireElementFrom<DivElement>(watermarkDom, '.options');
		watermarkDom.onClick.listen((_) => watermarkOptionDom.classes.toggle('visible'));
		watermarkOptionDom.onMouseDown.listen((event) {
			final target = event.target;
			if (target is! LIElement) {
				return;
			}
			final menu = target.dataset['menu'];
			watermarkOptionDom.classes.toggle('visible');
			if (menu == 'add') {
				Dialog(
					DialogOptions(
						title: '水印',
						data: [
							DialogData(
								type: 'text',
								label: '内容',
								name: 'data',
								required: true,
								placeholder: '请输入内容',
							),
							DialogData(
								type: 'color',
								label: '颜色',
								name: 'color',
								required: true,
								value: '#AEB5C0',
							),
							DialogData(
								type: 'number',
								label: '字体大小',
								name: 'size',
								required: true,
								value: '120',
							),
							DialogData(
								type: 'number',
								label: '透明度',
								name: 'opacity',
								required: true,
								value: '0.3',
							),
							DialogData(
								type: 'select',
								label: '重复',
								name: 'repeat',
								value: '0',
								required: true,
								options: [
									DialogOptionItem(label: '不重复', value: '0'),
									DialogOptionItem(label: '重复', value: '1'),
								],
							),
							DialogData(
								type: 'number',
								label: '水平间隔',
								name: 'horizontalGap',
								value: '10',
							),
							DialogData(
								type: 'number',
								label: '垂直间隔',
								name: 'verticalGap',
								value: '10',
							),
						],
						onConfirm: (payload) {
						final data = _findPayloadValue(payload, 'data');
						final color = _findPayloadValue(payload, 'color');
						final sizeValue = _findPayloadValue(payload, 'size');
						final opacityValue = _findPayloadValue(payload, 'opacity');
						if (data == null || data.isEmpty ||
								color == null || color.isEmpty ||
								sizeValue == null || sizeValue.isEmpty ||
								opacityValue == null || opacityValue.isEmpty) {
							return;
						}
						final repeatValue = _findPayloadValue(payload, 'repeat');
						final horizontalGapValue = _findPayloadValue(payload, 'horizontalGap');
						final verticalGapValue = _findPayloadValue(payload, 'verticalGap');
						final watermark = IWatermark(
							data: data,
							color: color,
							size: double.tryParse(sizeValue),
							opacity: double.tryParse(opacityValue),
							repeat: repeatValue == '1',
							gap: (repeatValue == '1' &&
									horizontalGapValue != null && horizontalGapValue.isNotEmpty &&
									verticalGapValue != null && verticalGapValue.isNotEmpty)
								? <double>[
									double.tryParse(horizontalGapValue) ?? 0,
									double.tryParse(verticalGapValue) ?? 0,
								]
								: null,
						);
						command.executeAddWatermark(watermark);
					},
				),
			);
			} else {
				command.executeDeleteWatermark();
			}
		});
	}

	void _setupCodeblockControl() {
		final codeblockDom = _requireElement<DivElement>('.menu-item__codeblock');
		codeblockDom.onClick.listen((_) {
			Dialog(
				DialogOptions(
					title: '代码块',
					data: [
						DialogData(
							type: 'textarea',
							name: 'codeblock',
							placeholder: '请输入代码',
							width: 500,
							height: 300,
						),
					],
					onConfirm: (payload) {
						final value = _findPayloadValue(payload, 'codeblock');
						if (value == null || value.trim().isEmpty) {
							return;
						}
						final prism = js_util.getProperty(js_util.globalThis, 'Prism');
						if (prism == null) {
							return;
						}
						final languages = js_util.getProperty(prism, 'languages');
						final jsLanguage = languages != null ? js_util.getProperty(languages, 'javascript') : null;
						final tokenList = js_util.callMethod(prism, 'tokenize', [value, jsLanguage]);
						if (tokenList is! List) {
							return;
						}
						final formatTokens = formatPrismToken(List<dynamic>.from(tokenList));
						final elements = <IElement>[IElement(value: '\\n')];
						for (final token in formatTokens) {
							final parts = editor_utils.splitText(token.content);
							for (final part in parts) {
								final element = IElement(value: part);
								if (token.color != null) {
									element.color = token.color;
								}
								if (token.bold == true) {
									element.bold = true;
								}
								if (token.italic == true) {
									element.italic = true;
								}
								elements.add(element);
							}
						}
						command.executeInsertElementList(elements);
					},
				),
			);
		});
	}

	void _setupControlMenu() {
		final controlDom = _requireElement<DivElement>('.menu-item__control');
		controlOptionDom = _requireElementFrom<DivElement>(controlDom, '.options');
		controlDom.onClick.listen((_) => controlOptionDom.classes.toggle('visible'));
		controlOptionDom.onMouseDown.listen((event) {
			controlOptionDom.classes.toggle('visible');
			final target = event.target;
			if (target is! LIElement) {
				return;
			}
			final controlType = _parseControlType(target.dataset['control']);
			if (controlType == null) {
				return;
			}
			switch (controlType) {
				case ControlType.text:
					Dialog(
						DialogOptions(
							title: '文本控件',
							data: [
								DialogData(
									type: 'text',
									label: '占位符',
									name: 'placeholder',
									required: true,
									placeholder: '请输入占位符',
								),
								DialogData(
									type: 'text',
									label: '默认值',
									name: 'value',
									placeholder: '请输入默认值',
								),
							],
							onConfirm: (payload) {
								final placeholder = _findPayloadValue(payload, 'placeholder');
								if (placeholder == null || placeholder.isEmpty) {
									return;
								}
								final value = _findPayloadValue(payload, 'value') ?? '';
								command.executeInsertControl(
									IElement(
										type: ElementType.control,
										value: '',
										control: IControl(
											type: controlType,
											placeholder: placeholder,
											value: value.isEmpty ? null : [IElement(value: value)],
											valueSets: <IValueSet>[],
											flexDirection: FlexDirection.row,
										),
									),
								);
							},
						),
					);
					break;
				case ControlType.select:
					Dialog(
						DialogOptions(
							title: '列举控件',
							data: [
								DialogData(
									type: 'text',
									label: '占位符',
									name: 'placeholder',
									required: true,
									placeholder: '请输入占位符',
								),
								DialogData(
									type: 'text',
									label: '默认值',
									name: 'code',
									placeholder: '请输入默认值',
								),
								DialogData(
									type: 'textarea',
									label: '值集',
									name: 'valueSets',
									required: true,
									height: 100,
									placeholder: '请输入值集JSON，例：\n[{"value":"有","code":"98175"}]',
								),
							],
							onConfirm: (payload) {
								final placeholder = _findPayloadValue(payload, 'placeholder');
								final valueSetsRaw = _findPayloadValue(payload, 'valueSets');
								if (placeholder == null || placeholder.isEmpty ||
										valueSetsRaw == null || valueSetsRaw.isEmpty) {
									return;
								}
								final valueSets = _parseValueSets(valueSetsRaw);
								if (valueSets == null) {
									return;
								}
								final code = _findPayloadValue(payload, 'code');
								command.executeInsertControl(
									IElement(
										type: ElementType.control,
										value: '',
										control: IControl(
											type: controlType,
											placeholder: placeholder,
											code: code,
											value: null,
											valueSets: valueSets,
											flexDirection: FlexDirection.row,
										),
									),
								);
							},
						),
					);
					break;
				case ControlType.checkbox:
					Dialog(
						DialogOptions(
							title: '复选框控件',
							data: [
								DialogData(
									type: 'text',
									label: '默认值',
									name: 'code',
									placeholder: '请输入默认值，多个值以英文逗号分割',
								),
								DialogData(
									type: 'textarea',
									label: '值集',
									name: 'valueSets',
									required: true,
									height: 100,
									placeholder: '请输入值集JSON，例：\n[{"value":"有","code":"98175"}]',
								),
							],
							onConfirm: (payload) {
								final valueSetsRaw = _findPayloadValue(payload, 'valueSets');
								if (valueSetsRaw == null || valueSetsRaw.isEmpty) {
									return;
								}
								final valueSets = _parseValueSets(valueSetsRaw);
								if (valueSets == null) {
									return;
								}
								final code = _findPayloadValue(payload, 'code');
								command.executeInsertControl(
									IElement(
										type: ElementType.control,
										value: '',
										control: IControl(
											type: controlType,
											code: code,
											value: null,
											valueSets: valueSets,
											flexDirection: FlexDirection.row,
										),
									),
								);
							},
						),
					);
					break;
				case ControlType.radio:
					Dialog(
						DialogOptions(
							title: '单选框控件',
							data: [
								DialogData(
									type: 'text',
									label: '默认值',
									name: 'code',
									placeholder: '请输入默认值',
								),
								DialogData(
									type: 'textarea',
									label: '值集',
									name: 'valueSets',
									required: true,
									height: 100,
									placeholder: '请输入值集JSON，例：\n[{"value":"有","code":"98175"}]',
								),
							],
							onConfirm: (payload) {
								final valueSetsRaw = _findPayloadValue(payload, 'valueSets');
								if (valueSetsRaw == null || valueSetsRaw.isEmpty) {
									return;
								}
								final valueSets = _parseValueSets(valueSetsRaw);
								if (valueSets == null) {
									return;
								}
								final code = _findPayloadValue(payload, 'code');
								command.executeInsertControl(
									IElement(
										type: ElementType.control,
										value: '',
										control: IControl(
											type: controlType,
											code: code,
											value: null,
											valueSets: valueSets,
											flexDirection: FlexDirection.row,
										),
									),
								);
							},
						),
					);
					break;
				case ControlType.date:
					Dialog(
						DialogOptions(
							title: '日期控件',
							data: [
								DialogData(
									type: 'text',
									label: '占位符',
									name: 'placeholder',
									required: true,
									placeholder: '请输入占位符',
								),
								DialogData(
									type: 'text',
									label: '默认值',
									name: 'value',
									placeholder: '请输入默认值',
								),
								DialogData(
									type: 'select',
									label: '日期格式',
									name: 'dateFormat',
									value: 'yyyy-MM-dd hh:mm:ss',
									required: true,
									options: [
										DialogOptionItem(label: 'yyyy-MM-dd hh:mm:ss', value: 'yyyy-MM-dd hh:mm:ss'),
										DialogOptionItem(label: 'yyyy-MM-dd', value: 'yyyy-MM-dd'),
									],
							),
						],
							onConfirm: (payload) {
								final placeholder = _findPayloadValue(payload, 'placeholder');
								if (placeholder == null || placeholder.isEmpty) {
									return;
								}
								final value = _findPayloadValue(payload, 'value') ?? '';
								final dateFormat = _findPayloadValue(payload, 'dateFormat') ?? '';
								command.executeInsertControl(
									IElement(
										type: ElementType.control,
										value: '',
										control: IControl(
											type: controlType,
											placeholder: placeholder,
											dateFormat: dateFormat,
											value: value.isEmpty ? null : [IElement(value: value)],
											valueSets: <IValueSet>[],
											flexDirection: FlexDirection.row,
										),
									),
								);
							},
						),
					);
					break;
				case ControlType.number:
					Dialog(
						DialogOptions(
							title: '数值控件',
							data: [
								DialogData(
									type: 'text',
									label: '占位符',
									name: 'placeholder',
									required: true,
									placeholder: '请输入占位符',
								),
								DialogData(
									type: 'text',
									label: '默认值',
									name: 'value',
									placeholder: '请输入默认值',
								),
							],
							onConfirm: (payload) {
								final placeholder = _findPayloadValue(payload, 'placeholder');
								if (placeholder == null || placeholder.isEmpty) {
									return;
								}
								final value = _findPayloadValue(payload, 'value') ?? '';
								command.executeInsertControl(
									IElement(
										type: ElementType.control,
										value: '',
										control: IControl(
											type: controlType,
											placeholder: placeholder,
											value: value.isEmpty ? null : [IElement(value: value)],
											valueSets: <IValueSet>[],
											flexDirection: FlexDirection.row,
										),
									),
								);
							},
						),
					);
					break;
			}
		});
	}

	void _setupCheckboxRadioLatexControls() {
		final checkboxDom = _requireElement<DivElement>('.menu-item__checkbox');
		checkboxDom.onClick.listen((_) {
			command.executeInsertElementList([
				IElement(
					type: ElementType.checkbox,
					value: '',
					checkbox: ICheckbox(value: false),
				),
			]);
		});

		final radioDom = _requireElement<DivElement>('.menu-item__radio');
		radioDom.onClick.listen((_) {
			command.executeInsertElementList([
				IElement(
					type: ElementType.radio,
					value: '',
					radio: IRadio(value: false),
				),
			]);
		});

		final latexDom = _requireElement<DivElement>('.menu-item__latex');
		latexDom.onClick.listen((_) {
			Dialog(
				DialogOptions(
					title: 'LaTeX',
					data: [
						DialogData(
							type: 'textarea',
							height: 100,
							name: 'value',
							placeholder: '请输入LaTeX文本',
						),
					],
					onConfirm: (payload) {
						final value = _findPayloadValue(payload, 'value');
						if (value == null || value.isEmpty) {
							return;
						}
						command.executeInsertElementList([
							IElement(
								type: ElementType.latex,
								value: value,
							),
						]);
					},
				),
			);
		});
	}

	void _setupDateControl() {
		final dateDom = _requireElement<DivElement>('.menu-item__date');
		dateOptionsDom = _requireElementFrom<DivElement>(dateDom, '.options');
		dateDom.onClick.listen((_) {
			dateOptionsDom.classes.toggle('visible');
			final bodyRect = document.body?.getBoundingClientRect();
			final optionRect = dateOptionsDom.getBoundingClientRect();
			if (bodyRect != null && optionRect.left + optionRect.width > bodyRect.width) {
				dateOptionsDom.style
					..right = '0px'
					..left = 'unset';
			} else {
				dateOptionsDom.style
					..right = 'unset'
					..left = '0px';
			}
			final now = DateTime.now();
			final dateString = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
			final timeString = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
			final dateTimeString = '$dateString $timeString';
			final items = dateOptionsDom.querySelectorAll('li');
			if (items.isNotEmpty) {
				items.first.text = dateString;
				items.last.text = dateTimeString;
			}
		});
		dateOptionsDom.onMouseDown.listen((event) {
			final target = event.target;
			if (target is! LIElement) {
				return;
			}
			final format = target.dataset['format'];
			if (format == null) {
				return;
			}
			dateOptionsDom.classes.toggle('visible');
			command.executeInsertElementList([
				IElement(
					type: ElementType.date,
					value: '',
					dateFormat: format,
					valueList: [IElement(value: target.text?.trim() ?? '')],
				),
			]);
		});
	}

	void _setupBlockControl() {
		final blockDom = _requireElement<DivElement>('.menu-item__block');
		blockDom.onClick.listen((_) {
			Dialog(
				DialogOptions(
					title: '内容块',
					data: [
						DialogData(
							type: 'select',
							label: '类型',
							name: 'type',
							value: 'iframe',
							required: true,
							options: [
								DialogOptionItem(label: '网址', value: 'iframe'),
								DialogOptionItem(label: '视频', value: 'video'),
							],
						),
						DialogData(
							type: 'number',
							label: '宽度',
							name: 'width',
							placeholder: '请输入宽度（默认页面内宽度）',
						),
						DialogData(
							type: 'number',
							label: '高度',
							name: 'height',
							required: true,
							placeholder: '请输入高度',
						),
						DialogData(
							type: 'input',
							label: '地址',
							name: 'src',
							placeholder: '请输入地址',
						),
						DialogData(
							type: 'textarea',
							label: 'HTML',
							height: 100,
							name: 'srcdoc',
							placeholder: '请输入HTML代码（仅网址类型有效）',
						),
					],
					onConfirm: (payload) {
						final typeValue = _findPayloadValue(payload, 'type');
						final heightValue = _findPayloadValue(payload, 'height');
						if (typeValue == null || typeValue.isEmpty ||
								heightValue == null || heightValue.isEmpty) {
							return;
						}
						final blockType = _parseBlockType(typeValue);
						if (blockType == null) {
							return;
						}
						final widthValue = _findPayloadValue(payload, 'width');
						final srcValue = _findPayloadValue(payload, 'src');
						final srcdocValue = _findPayloadValue(payload, 'srcdoc');
						final block = IBlock(type: blockType);
						if (blockType == BlockType.iframe) {
							if ((srcValue == null || srcValue.isEmpty) &&
									(srcdocValue == null || srcdocValue.isEmpty)) {
								return;
							}
							block.iframeBlock = IIFrameBlock(src: srcValue, srcdoc: srcdocValue);
						} else if (blockType == BlockType.video) {
							if (srcValue == null || srcValue.isEmpty) {
								return;
							}
							block.videoBlock = IVideoBlock(src: srcValue);
						}
						final height = double.tryParse(heightValue) ?? 0;
						final element = IElement(
							type: ElementType.block,
							value: '',
							height: height,
							block: block,
						);
						if (widthValue != null && widthValue.isNotEmpty) {
							element.width = double.tryParse(widthValue);
						}
						command.executeInsertElementList([element]);
					},
				),
			);
		});
	}

	void _setupSearchAndReplace() {
		searchDom = _requireElement<DivElement>('.menu-item__search');
		searchDom.title = '搜索与替换(${isApple ? '⌘' : 'Ctrl'}+F)';
		searchCollapseDom = _requireElement<DivElement>('.menu-item__search__collapse');
		searchInputDom = _requireElement<InputElement>('.menu-item__search__collapse__search input');
		replaceInputDom = _requireElement<InputElement>('.menu-item__search__collapse__replace input');
		searchResultDom = _requireElement<LabelElement>('.menu-item__search__collapse .search-result');
		searchCloseDom = searchCollapseDom.querySelector('span') as SpanElement?;
		replaceButton = searchCollapseDom.querySelector('button') as ButtonElement?;
		searchArrowLeftDom = searchCollapseDom.querySelector('.arrow-left') as DivElement?;
		searchArrowRightDom = searchCollapseDom.querySelector('.arrow-right') as DivElement?;

		void updateResult() {
			final info = command.getSearchNavigateInfo();
			if (info is Map) {
				final index = info['index'];
				final count = info['count'];
				searchResultDom.text = (index != null && count != null) ? '$index/$count' : '';
			} else {
				searchResultDom.text = '';
			}
		}

		searchDom.onClick.listen((_) {
			searchCollapseDom.style.display = 'block';
			final bodyRect = document.body?.getBoundingClientRect();
			final searchRect = searchDom.getBoundingClientRect();
			final collapseRect = searchCollapseDom.getBoundingClientRect();
			if (bodyRect != null && searchRect.left + collapseRect.width > bodyRect.width) {
				searchCollapseDom.style
					..right = '0px'
					..left = 'unset';
			} else {
				searchCollapseDom.style
					..right = 'unset'
					..left = 'auto';
			}
			searchInputDom.focus();
		});

		searchCloseDom?.onClick.listen((_) {
			searchCollapseDom.style.display = 'none';
			searchInputDom.value = '';
			replaceInputDom.value = '';
			command.executeSearch(null);
			updateResult();
		});

		searchInputDom.onInput.listen((_) {
			final value = searchInputDom.value;
			command.executeSearch(value != null && value.isNotEmpty ? value : null);
			updateResult();
		});

		searchInputDom.onKeyDown.listen((event) {
			if (event.key == 'Enter') {
				final value = searchInputDom.value;
				command.executeSearch(value != null && value.isNotEmpty ? value : null);
				updateResult();
			}
		});

		replaceButton?.onClick.listen((_) {
			final searchValue = searchInputDom.value ?? '';
			final replaceValue = replaceInputDom.value ?? '';
			if (searchValue.isNotEmpty && searchValue != replaceValue) {
				command.executeReplace(replaceValue);
				updateResult();
			}
		});

		searchArrowLeftDom?.onClick.listen((_) {
			command.executeSearchNavigatePre();
			updateResult();
		});

		searchArrowRightDom?.onClick.listen((_) {
			command.executeSearchNavigateNext();
			updateResult();
		});
	}

	void _setupPrintControl() {
		final printDom = _requireElement<DivElement>('.menu-item__print');
		printDom
			..title = '打印(${isApple ? '⌘' : 'Ctrl'}+P)'
			..onClick.listen((_) => command.executePrint());
	}

	void _setupCatalogControls() {
		catalogDom = _requireElement<DivElement>('.catalog');
		catalogMainDom = _requireElement<DivElement>('.catalog__main');
		final catalogModeDom = _requireElement<DivElement>('.catalog-mode');
		final catalogCloseDom = _requireElement<DivElement>('.catalog__header__close');

		void toggleCatalog() {
			_isCatalogVisible = !_isCatalogVisible;
			if (_isCatalogVisible) {
				catalogDom.style.display = 'block';
				unawaited(_updateCatalog());
			} else {
				catalogDom.style.display = 'none';
			}
		}

		catalogModeDom.onClick.listen((_) => toggleCatalog());
		catalogCloseDom.onClick.listen((_) => toggleCatalog());
	}

	void _setupPageControls() {
		pageScalePercentageDom = _requireElement<DivElement>('.page-scale-percentage');
		pageScalePercentageDom.onClick.listen((_) => command.executePageScaleRecovery());
		_requireElement<DivElement>('.page-scale-minus').onClick.listen((_) => command.executePageScaleMinus());
		_requireElement<DivElement>('.page-scale-add').onClick.listen((_) => command.executePageScaleAdd());

		final pageModeDom = _requireElement<DivElement>('.page-mode');
		pageModeOptionsDom = _requireElementFrom<DivElement>(pageModeDom, '.options');
		pageModeDom.onClick.listen((_) => pageModeOptionsDom.classes.toggle('visible'));
		pageModeOptionsDom.onClick.listen((event) {
			final target = event.target;
			if (target is! LIElement) {
				return;
			}
			final pageMode = _parsePageMode(target.dataset['pageMode']);
			if (pageMode != null) {
				command.executePageMode(pageMode);
			}
		});
	}

	void _setupPaperControls() {
		final paperSizeDom = _requireElement<DivElement>('.paper-size');
		final paperSizeOptions = _requireElementFrom<DivElement>(paperSizeDom, '.options');
		paperSizeDom.onClick.listen((_) => paperSizeOptions.classes.toggle('visible'));
		paperSizeOptions.onClick.listen((event) {
			final target = event.target;
			if (target is! LIElement) {
				return;
			}
			final paperType = target.dataset['paperSize'];
			if (paperType == null) {
				return;
			}
			final parts = paperType.split('*');
			if (parts.length != 2) {
				return;
			}
			final width = double.tryParse(parts.first);
			final height = double.tryParse(parts.last);
			if (width != null && height != null) {
				command.executePaperSize(width, height);
			}
			for (final li in paperSizeOptions.children.whereType<LIElement>()) {
				li.classes.remove('active');
			}
			target.classes.add('active');
		});

		final paperDirectionDom = _requireElement<DivElement>('.paper-direction');
		final paperDirectionOptions = _requireElementFrom<DivElement>(paperDirectionDom, '.options');
		paperDirectionDom.onClick.listen((_) => paperDirectionOptions.classes.toggle('visible'));
		paperDirectionOptions.onClick.listen((event) {
			final target = event.target;
			if (target is! LIElement) {
				return;
			}
			final direction = _parsePaperDirection(target.dataset['paperDirection']);
			if (direction != null) {
				command.executePaperDirection(direction);
			}
			for (final li in paperDirectionOptions.children.whereType<LIElement>()) {
				li.classes.remove('active');
			}
			target.classes.add('active');
		});

		final paperMarginDom = _requireElement<DivElement>('.paper-margin');
		paperMarginDom.onClick.listen((_) {
			final margin = command.getPaperMargin();
			final top = margin.isNotEmpty ? margin[0] : 0;
			final right = margin.length > 1 ? margin[1] : 0;
			final bottom = margin.length > 2 ? margin[2] : 0;
			final left = margin.length > 3 ? margin[3] : 0;
			Dialog(
				DialogOptions(
					title: '页边距',
					data: [
						DialogData(
							type: 'text',
							label: '上边距',
							name: 'top',
							required: true,
							value: '$top',
							placeholder: '请输入上边距',
						),
						DialogData(
							type: 'text',
							label: '下边距',
							name: 'bottom',
							required: true,
							value: '$bottom',
							placeholder: '请输入下边距',
						),
						DialogData(
							type: 'text',
							label: '左边距',
							name: 'left',
							required: true,
							value: '$left',
							placeholder: '请输入左边距',
						),
						DialogData(
							type: 'text',
							label: '右边距',
							name: 'right',
							required: true,
							value: '$right',
							placeholder: '请输入右边距',
						),
					],
					onConfirm: (payload) {
						final topValue = _findPayloadValue(payload, 'top');
						final bottomValue = _findPayloadValue(payload, 'bottom');
						final leftValue = _findPayloadValue(payload, 'left');
						final rightValue = _findPayloadValue(payload, 'right');
						if ([topValue, bottomValue, leftValue, rightValue].any((value) => value?.isEmpty ?? true)) {
							return;
						}
						command.executeSetPaperMargin([
							double.tryParse(topValue!) ?? 0,
							double.tryParse(rightValue!) ?? 0,
							double.tryParse(bottomValue!) ?? 0,
							double.tryParse(leftValue!) ?? 0,
						]);
					},
				),
			);
		});
	}

	void _setupFullscreenControl() {
		fullscreenDom = _requireElement<DivElement>('.fullscreen');
		void toggleFullscreen() {
			if (document.fullscreenElement == null) {
				document.documentElement?.requestFullscreen();
			} else {
				document.exitFullscreen();
			}
		}

		fullscreenDom.onClick.listen((_) => toggleFullscreen());
		window.onKeyDown.listen((event) {
			if (event.key == 'F11') {
				toggleFullscreen();
				event.preventDefault();
			}
		});
		document.onFullscreenChange.listen((_) {
			fullscreenDom.classes.toggle('exist');
		});
	}

	void _setupModeControl() {
		modeElement = _requireElement<DivElement>('.editor-mode');
		final modes = <Map<String, Object>>[
			{'mode': EditorMode.edit, 'name': '编辑模式'},
			{'mode': EditorMode.clean, 'name': '清洁模式'},
			{'mode': EditorMode.readonly, 'name': '只读模式'},
			{'mode': EditorMode.form, 'name': '表单模式'},
			{'mode': EditorMode.print, 'name': '打印模式'},
			{'mode': EditorMode.design, 'name': '设计模式'},
		];
		var index = 0;
		modeElement.onClick.listen((_) {
			index = index >= modes.length - 1 ? 0 : index + 1;
			final entry = modes[index];
			modeElement.text = entry['name'] as String;
			final mode = entry['mode'] as EditorMode;
			command.executeMode(mode);
			final isReadonly = mode == EditorMode.readonly;
			const enableMenu = {'search', 'print'};
			for (final element in document.querySelectorAll('.menu-item>div').whereType<DivElement>()) {
				final menu = element.dataset['menu'];
				final shouldDisable = isReadonly && (menu == null || !enableMenu.contains(menu));
				if (shouldDisable) {
					element.classes.add('disable');
				} else {
					element.classes.remove('disable');
				}
			}
		});
	}

	void _setupOptionsDialog() {
		editorOptionDom = _requireElement<DivElement>('.editor-option');
		editorOptionDom.onClick.listen((_) {
			final currentOptions = command.getOptions();
			final encoder = const JsonEncoder.withIndent('  ');
			final optionSnapshot = _editorOptionSnapshot(currentOptions);
			final optionText = encoder.convert(optionSnapshot);
			Dialog(
				DialogOptions(
					title: '编辑器配置',
					data: [
						DialogData(
							type: 'textarea',
							name: 'option',
							width: 350,
							height: 300,
							required: true,
							value: optionText,
							placeholder: '请输入编辑器配置',
						),
					],
					onConfirm: (payload) {
						final value = _findPayloadValue(payload, 'option');
						if (value == null || value.isEmpty) {
							return;
						}
						try {
							final decoded = jsonDecode(value);
							final updateOption = _parseUpdateOption(decoded);
							if (updateOption != null) {
								command.executeUpdateOptions(updateOption);
							}
						} catch (_) {
							// ignore invalid json
						}
					},
				),
			);
		});
	}

	void _setupEditorListeners() {
		final listener = editor.listener;

		listener.rangeStyleChange = (dynamic payload) {
			if (payload is! Map) {
				return;
			}
			final type = _parseElementType(payload['type']);
			if (type == ElementType.subscript) {
				subscriptDom.classes.add('active');
			} else {
				subscriptDom.classes.remove('active');
			}
			if (type == ElementType.superscript) {
				superscriptDom.classes.add('active');
			} else {
				superscriptDom.classes.remove('active');
			}
			if (type == ElementType.separator) {
				separatorDom.classes.add('active');
			} else {
				separatorDom.classes.remove('active');
			}
			for (final li in separatorOptionDom.querySelectorAll('li').whereType<LIElement>()) {
				li.classes.remove('active');
			}
			if (type == ElementType.separator) {
				final dashArray = payload['dashArray'];
				if (dashArray is List) {
					final dashValue = dashArray.join(',');
					final li = separatorOptionDom.querySelector("[data-separator='$dashValue']") as LIElement?;
					li?.classes.add('active');
				}
			}

			for (final li in fontOptionDom.querySelectorAll('li').whereType<LIElement>()) {
				li.classes.remove('active');
			}
			final font = payload['font'] as String?;
			if (font != null) {
				final currentFont = fontOptionDom.querySelector("[data-family='$font']") as LIElement?;
				if (currentFont != null) {
					fontSelectDom.text = currentFont.text;
					fontSelectDom.style.fontFamily = font;
					currentFont.classes.add('active');
				}
			}

			for (final li in sizeOptionDom.querySelectorAll('li').whereType<LIElement>()) {
				li.classes.remove('active');
			}
			final size = payload['size'];
			if (size != null) {
				final sizeString = '$size';
				final currentSizeDom = sizeOptionDom.querySelector("[data-size='$sizeString']") as LIElement?;
				if (currentSizeDom != null) {
					sizeSelectDom.text = currentSizeDom.text;
					currentSizeDom.classes.add('active');
				} else {
					sizeSelectDom.text = sizeString;
				}
			}

			(payload['bold'] == true ? boldDom.classes.add : boldDom.classes.remove)('active');
			(payload['italic'] == true ? italicDom.classes.add : italicDom.classes.remove)('active');
			(payload['underline'] == true ? underlineDom.classes.add : underlineDom.classes.remove)('active');
			(payload['strikeout'] == true ? strikeoutDom.classes.add : strikeoutDom.classes.remove)('active');

			final color = payload['color'] as String?;
			if (color != null) {
				colorDom.classes.add('active');
				colorControlDom.value = color;
				colorSpanDom.style.backgroundColor = color;
			} else {
				colorDom.classes.remove('active');
				colorControlDom.value = '#000000';
				colorSpanDom.style.backgroundColor = '#000000';
			}

			final highlight = payload['highlight'] as String?;
			if (highlight != null) {
				highlightDom.classes.add('active');
				highlightControlDom.value = highlight;
				highlightSpanDom.style.backgroundColor = highlight;
			} else {
				highlightDom.classes.remove('active');
				highlightControlDom.value = '#ffff00';
				highlightSpanDom.style.backgroundColor = '#ffff00';
			}

			final rowFlex = _parseRowFlex(payload['rowFlex']);
			leftDom.classes.remove('active');
			centerDom.classes.remove('active');
			rightDom.classes.remove('active');
			alignmentDom.classes.remove('active');
			justifyDom.classes.remove('active');
			switch (rowFlex) {
				case RowFlex.right:
					rightDom.classes.add('active');
					break;
				case RowFlex.center:
					centerDom.classes.add('active');
					break;
				case RowFlex.alignment:
					alignmentDom.classes.add('active');
					break;
				case RowFlex.justify:
					justifyDom.classes.add('active');
					break;
				case RowFlex.left:
					leftDom.classes.add('active');
					break;
			}

			for (final li in rowOptionDom.querySelectorAll('li').whereType<LIElement>()) {
				li.classes.remove('active');
			}
			final rowMargin = payload['rowMargin'];
			if (rowMargin != null) {
				final marginString = '$rowMargin';
				final currentMarginDom = rowOptionDom.querySelector("[data-rowmargin='$marginString']") as LIElement?;
				currentMarginDom?.classes.add('active');
			}

			payload['undo'] == true ? undoDom.classes.remove('no-allow') : undoDom.classes.add('no-allow');
			payload['redo'] == true ? redoDom.classes.remove('no-allow') : redoDom.classes.add('no-allow');
			payload['painter'] == true ? painterDom.classes.add('active') : painterDom.classes.remove('active');

			for (final li in titleOptionDom.querySelectorAll('li').whereType<LIElement>()) {
				li.classes.remove('active');
			}
			final levelValue = payload['level'];
			if (levelValue != null) {
				final selector = "[data-level='${levelValue is Enum ? levelValue.name : levelValue}']";
				final current = titleOptionDom.querySelector(selector) as LIElement?;
				if (current != null) {
					titleSelectDom.text = current.text;
					current.classes.add('active');
				}
			} else {
				titleSelectDom.text = '正文';
				(titleOptionDom.querySelector('li') as LIElement?)?.classes.add('active');
			}

			for (final li in listOptionDom.querySelectorAll('li').whereType<LIElement>()) {
				li.classes.remove('active');
			}
			final listTypeValue = payload['listType'];
			final listStyleValue = payload['listStyle'];
			if (listTypeValue != null) {
				listDom.classes.add('active');
				final typeName = listTypeValue is Enum ? listTypeValue.name : '$listTypeValue';
				final styleName = listStyleValue is Enum ? listStyleValue.name : '$listStyleValue';
				final selector = "[data-list-type='$typeName'][data-list-style='$styleName']";
				final listItem = listOptionDom.querySelector(selector) as LIElement?;
				listItem?.classes.add('active');
			} else {
				listDom.classes.remove('active');
			}

			for (final element in commentDom.querySelectorAll('.comment-item').whereType<DivElement>()) {
				element.classes.remove('active');
			}
			final groupIds = payload['groupIds'];
			if (groupIds is List && groupIds.isNotEmpty) {
				final targetId = groupIds.first;
				final activeComment = commentDom.querySelector(".comment-item[data-id='$targetId']") as DivElement?;
				if (activeComment != null) {
					activeComment.classes.add('active');
					app_utils.scrollIntoView(commentDom, activeComment);
				}
			}

			final rangeContext = command.getRangeContext();
			if (rangeContext != null) {
				final rowSpan = document.querySelector('.row-no') as SpanElement?;
				final colSpan = document.querySelector('.col-no') as SpanElement?;
				rowSpan?.text = '${rangeContext.startRowNo + 1}';
				colSpan?.text = '${rangeContext.startColNo + 1}';
			}
		};

		listener.visiblePageNoListChange = (dynamic payload) {
			if (payload is List) {
				final text = payload.map((item) => (item as num) + 1).join('、');
				(document.querySelector('.page-no-list') as SpanElement?)?.text = text;
			}
		};

		listener.pageSizeChange = (dynamic payload) {
			(document.querySelector('.page-size') as SpanElement?)?.text = '$payload';
		};

		listener.intersectionPageNoChange = (dynamic payload) {
			if (payload is num) {
				(document.querySelector('.page-no') as SpanElement?)?.text = '${payload + 1}';
			}
		};

		listener.pageScaleChange = (dynamic payload) {
			if (payload is num) {
				final percentage = (payload * 100).floor();
				pageScalePercentageDom.text = '$percentage%';
			}
		};

		listener.controlChange = (dynamic payload) {
			final state = payload is Map ? payload['state'] : null;
			final isActive = state == ControlState.active || state == 'active';
			const disableMenus = ['table', 'hyperlink', 'separator', 'page-break', 'control'];
			for (final key in disableMenus) {
				final menuDom = document.querySelector('.menu-item__$key') as DivElement?;
				if (menuDom != null) {
					isActive ? menuDom.classes.add('disable') : menuDom.classes.remove('disable');
				}
			}
		};

		listener.pageModeChange = (dynamic payload) {
			if (payload == null) {
				return;
			}
			final modeName = payload is Enum ? payload.name : '$payload';
			for (final li in pageModeOptionsDom.querySelectorAll('li').whereType<LIElement>()) {
				li.classes.remove('active');
			}
			final active = pageModeOptionsDom.querySelector("[data-page-mode='$modeName']") as LIElement?;
			active?.classes.add('active');
		};

		listener.saved = (dynamic payload) {
			window.console.log('elementList: $payload');
		};
	}

	Future<void> _handleContentChange() async {
		final wordCount = await command.getWordCount();
		(document.querySelector('.word-count') as SpanElement?)?.text = '$wordCount';

		if (_isCatalogVisible) {
			app_utils.nextTick(() {
				unawaited(_updateCatalog());
			});
		}

		app_utils.nextTick(() {
			unawaited(_updateComment());
		});
	}

	Future<void> _updateCatalog() async {
		final catalog = await command.getCatalog();
		catalogMainDom.children.clear();
		if (catalog == null) {
			return;
		}
		void appendCatalog(DivElement parent, List<ICatalogItem> entries) {
			for (final entry in entries) {
				final itemDom = DivElement()..classes.add('catalog-item');
				final contentDom = DivElement()..classes.add('catalog-item__content');
				final span = SpanElement()..text = entry.name;
				contentDom.append(span);
				contentDom.onClick.listen((_) => command.executeLocationCatalog(entry.id));
				itemDom.append(contentDom);
				if (entry.subCatalog.isNotEmpty) {
					appendCatalog(itemDom, entry.subCatalog);
				}
				parent.append(itemDom);
			}
		}

		appendCatalog(catalogMainDom, catalog);
	}

	Future<void> _updateComment() async {
		final groupIds = await command.getGroupIds();
		for (final comment in _commentData) {
			final selector = ".comment-item[data-id='${comment.id}']";
			final existing = commentDom.querySelector(selector) as DivElement?;
			if (groupIds.contains(comment.id)) {
				if (existing == null) {
					final commentItem = DivElement()
						..classes.add('comment-item')
						..setAttribute('data-id', comment.id);
					commentItem.onClick.listen((_) => command.executeLocationGroup(comment.id));

					final title = DivElement()..classes.add('comment-item__title');
					title.append(SpanElement()..text = comment.rangeText);
					final close = Element.tag('i');
					close.onClick.listen((event) {
						event.stopPropagation();
						command.executeDeleteGroup(comment.id);
					});
					title.append(close);
					commentItem.append(title);

					final info = DivElement()..classes.add('comment-item__info');
					info
						..append(SpanElement()..text = comment.userName)
						..append(SpanElement()..text = comment.createdDate);
					commentItem.append(info);

					commentItem.append(
						DivElement()
							..classes.add('comment-item__content')
							..text = comment.content,
					);

					commentDom.append(commentItem);
				}
			} else {
				existing?.remove();
			}
		}
	}

	Map<String, dynamic> _editorOptionSnapshot(IEditorOption options) {
		return <String, dynamic>{
			if (options.defaultFont != null) 'defaultFont': options.defaultFont,
			if (options.defaultColor != null) 'defaultColor': options.defaultColor,
			if (options.defaultSize != null) 'defaultSize': options.defaultSize,
			if (options.minSize != null) 'minSize': options.minSize,
			if (options.maxSize != null) 'maxSize': options.maxSize,
			if (options.defaultRowMargin != null) 'defaultRowMargin': options.defaultRowMargin,
			if (options.defaultBasicRowMarginHeight != null) 'defaultBasicRowMarginHeight': options.defaultBasicRowMarginHeight,
			if (options.defaultTabWidth != null) 'defaultTabWidth': options.defaultTabWidth,
			if (options.underlineColor != null) 'underlineColor': options.underlineColor,
			if (options.strikeoutColor != null) 'strikeoutColor': options.strikeoutColor,
			if (options.rangeColor != null) 'rangeColor': options.rangeColor,
			if (options.rangeAlpha != null) 'rangeAlpha': options.rangeAlpha,
			if (options.rangeMinWidth != null) 'rangeMinWidth': options.rangeMinWidth,
			if (options.highlightAlpha != null) 'highlightAlpha': options.highlightAlpha,
			if (options.highlightMarginHeight != null) 'highlightMarginHeight': options.highlightMarginHeight,
			if (options.margins != null) 'margins': List<double>.from(options.margins!),
			if (options.maskMargin != null) 'maskMargin': List<double>.from(options.maskMargin!),
			if (options.renderMode != null) 'renderMode': options.renderMode!.name,
			if (options.wordBreak != null) 'wordBreak': options.wordBreak!.name,
			if (options.pageOuterSelectionDisable != null) 'pageOuterSelectionDisable': options.pageOuterSelectionDisable,
			if (options.defaultHyperlinkColor != null) 'defaultHyperlinkColor': options.defaultHyperlinkColor,
			if (options.letterClass != null) 'letterClass': List<String>.from(options.letterClass!),
			if (options.contextMenuDisableKeys != null) 'contextMenuDisableKeys': List<String>.from(options.contextMenuDisableKeys!),
			if (options.shortcutDisableKeys != null) 'shortcutDisableKeys': List<String>.from(options.shortcutDisableKeys!),
		};
	}

	IUpdateOption? _parseUpdateOption(dynamic value) {
		if (value is! Map) {
			return null;
		}
		final option = IUpdateOption();
		var hasValue = false;

		bool assignString(String key, void Function(String) setter) {
			final raw = value[key];
			if (raw is String && raw.isNotEmpty) {
				setter(raw);
				return true;
			}
			return false;
		}

		bool assignNum(String key, void Function(num) setter) {
			final raw = value[key];
			if (raw is num) {
				setter(raw);
				return true;
			}
			return false;
		}

		hasValue |= assignString('defaultFont', (raw) => option.defaultFont = raw);
		hasValue |= assignString('defaultColor', (raw) => option.defaultColor = raw);
		hasValue |= assignNum('defaultSize', (raw) => option.defaultSize = raw.toInt());
		hasValue |= assignNum('minSize', (raw) => option.minSize = raw.toInt());
		hasValue |= assignNum('maxSize', (raw) => option.maxSize = raw.toInt());
		hasValue |= assignNum('defaultRowMargin', (raw) => option.defaultRowMargin = raw.toDouble());
		hasValue |= assignNum('defaultBasicRowMarginHeight', (raw) => option.defaultBasicRowMarginHeight = raw.toDouble());
		hasValue |= assignNum('defaultTabWidth', (raw) => option.defaultTabWidth = raw.toDouble());
		hasValue |= assignString('underlineColor', (raw) => option.underlineColor = raw);
		hasValue |= assignString('strikeoutColor', (raw) => option.strikeoutColor = raw);
		hasValue |= assignString('rangeColor', (raw) => option.rangeColor = raw);
		hasValue |= assignNum('rangeAlpha', (raw) => option.rangeAlpha = raw.toDouble());
		hasValue |= assignNum('rangeMinWidth', (raw) => option.rangeMinWidth = raw.toDouble());
		hasValue |= assignNum('highlightAlpha', (raw) => option.highlightAlpha = raw.toDouble());
		hasValue |= assignNum('highlightMarginHeight', (raw) => option.highlightMarginHeight = raw.toDouble());

		final margins = _parseDoubleList(value['margins']);
		if (margins != null) {
			option.margins = margins;
			hasValue = true;
		}
		final maskMargin = _parseDoubleList(value['maskMargin']);
		if (maskMargin != null) {
			option.maskMargin = maskMargin;
			hasValue = true;
		}

		final renderMode = _parseRenderMode(value['renderMode']);
		if (renderMode != null) {
			option.renderMode = renderMode;
			hasValue = true;
		}

		final wordBreak = _parseWordBreak(value['wordBreak']);
		if (wordBreak != null) {
			option.wordBreak = wordBreak;
			hasValue = true;
		}

		if (value['pageOuterSelectionDisable'] is bool) {
			option.pageOuterSelectionDisable = value['pageOuterSelectionDisable'] as bool;
			hasValue = true;
		}

		hasValue |= assignString('defaultHyperlinkColor', (raw) => option.defaultHyperlinkColor = raw);

		if (value['letterClass'] is List) {
			option.letterClass = value['letterClass'].cast<String>();
			hasValue = true;
		}
		if (value['contextMenuDisableKeys'] is List) {
			option.contextMenuDisableKeys = value['contextMenuDisableKeys'].cast<String>();
			hasValue = true;
		}
		if (value['shortcutDisableKeys'] is List) {
			option.shortcutDisableKeys = value['shortcutDisableKeys'].cast<String>();
			hasValue = true;
		}

		return hasValue ? option : null;
	}

	ElementType? _parseElementType(dynamic value) {
		if (value == null) {
			return null;
		}
		final name = value is Enum ? value.name : value.toString();
		for (final type in ElementType.values) {
			if (type.name == name) {
				return type;
			}
		}
		return null;
	}

	ControlType? _parseControlType(String? value) {
		if (value == null) {
			return null;
		}
		for (final type in ControlType.values) {
			if (type.name == value) {
				return type;
			}
		}
		return null;
	}

	BlockType? _parseBlockType(String? value) {
		if (value == null) {
			return null;
		}
		for (final type in BlockType.values) {
			if (type.value == value) {
				return type;
			}
		}
		return null;
	}

	PageMode? _parsePageMode(String? value) {
		if (value == null) {
			return null;
		}
		for (final mode in PageMode.values) {
			if (mode.name == value) {
				return mode;
			}
		}
		return null;
	}

	PaperDirection? _parsePaperDirection(String? value) {
		if (value == null) {
			return null;
		}
		for (final direction in PaperDirection.values) {
			if (direction.name == value) {
				return direction;
			}
		}
		return null;
	}

	ListType? _parseListType(String? value) {
		if (value == null) {
			return null;
		}
		for (final type in ListType.values) {
			if (type.name == value || type.value == value) {
				return type;
			}
		}
		return null;
	}

	ListStyle? _parseListStyle(String? value) {
		if (value == null) {
			return null;
		}
		for (final style in ListStyle.values) {
			if (style.name == value || style.value == value) {
				return style;
			}
		}
		return null;
	}

	RowFlex _parseRowFlex(dynamic value) {
		if (value == null) {
			return RowFlex.left;
		}
		final name = value is Enum ? value.name : value.toString();
		for (final flex in RowFlex.values) {
			if (flex.name == name) {
				return flex;
			}
		}
		return RowFlex.left;
	}

	TextDecorationStyle? _parseTextDecorationStyle(String? value) {
		if (value == null) {
			return null;
		}
		for (final style in TextDecorationStyle.values) {
			if (style.value == value) {
				return style;
			}
		}
		return null;
	}

	TitleLevel? _parseTitleLevel(String? value) {
		if (value == null) {
			return null;
		}
		for (final level in TitleLevel.values) {
			if (level.name == value) {
				return level;
			}
		}
		return null;
	}

	RenderMode? _parseRenderMode(dynamic value) {
		if (value == null) {
			return null;
		}
		final name = value is Enum ? value.name : value.toString();
		for (final mode in RenderMode.values) {
			if (mode.name == name) {
				return mode;
			}
		}
		return null;
	}

	WordBreak? _parseWordBreak(dynamic value) {
		if (value == null) {
			return null;
		}
		final name = value is Enum ? value.name : value.toString();
		for (final wordBreak in WordBreak.values) {
			if (wordBreak.name == name) {
				return wordBreak;
			}
		}
		return null;
	}

	List<double>? _parseDoubleList(dynamic value) {
		if (value is List) {
			final result = <double>[];
			for (final entry in value) {
				if (entry is num) {
					result.add(entry.toDouble());
				} else if (entry is String) {
					final parsed = double.tryParse(entry);
					if (parsed != null) {
						result.add(parsed);
					}
				}
			}
			return result;
		}
		return null;
	}

	List<IValueSet>? _parseValueSets(String raw) {
		try {
			final decoded = jsonDecode(raw);
			if (decoded is List) {
				final result = <IValueSet>[];
				for (final item in decoded) {
					if (item is Map) {
						final value = item['value'];
						final code = item['code'];
						if (value is String && code is String) {
							result.add(IValueSet(value: value, code: code));
						}
					}
				}
				return result;
			}
		} catch (_) {
			return null;
		}
		return null;
	}

	String? _findPayloadValue(List<DialogConfirm> payload, String name) {
		for (final entry in payload) {
			if (entry.name == name) {
				return entry.value;
			}
		}
		return null;
	}

	T _requireElement<T extends Element>(String selector) {
		final element = document.querySelector(selector);
		if (element is T) {
			return element;
		}
		throw StateError('Could not find element for selector $selector');
	}

	T _requireElementFrom<T extends Element>(Element parent, String selector) {
		final element = parent.querySelector(selector);
		if (element is T) {
			return element;
		}
		throw StateError('Could not find element for selector $selector within ${parent.runtimeType}');
	}

	void _createEditorInstance() {
		final container = _requireElement<DivElement>('.editor');
		final header = <IElement>[
			IElement(value: '第一人民医院', size: 32, rowFlex: RowFlex.center),
			IElement(value: '\\n门诊病历', size: 18, rowFlex: RowFlex.center),
			IElement(value: '\\n', type: ElementType.separator),
		];
		final footer = <IElement>[
			IElement(value: 'canvas-editor', size: 12),
		];
		editor = Editor(
			container,
			IEditorData(
				header: header,
				main: List<IElement>.from(data),
				footer: footer,
			),
			options,
		);
		js_util.setProperty(js_util.globalThis, 'editor', editor);
	}

	void _bindGlobalListeners() {
		window.addEventListener('click', (event) {
			final visibleDom = document.querySelector('.visible');
			if (visibleDom == null) {
				return;
			}
			final target = event.target;
			if (target is Node && visibleDom.contains(target)) {
				return;
			}
			visibleDom.classes.remove('visible');
		}, true);
	}

	void _setupUndoRedoAndFormat() {
		undoDom = _requireElement<DivElement>('.menu-item__undo');
		undoDom
			..title = '撤销(${isApple ? '⌘' : 'Ctrl'}+Z)'
			..onClick.listen((_) => command.executeUndo());

		redoDom = _requireElement<DivElement>('.menu-item__redo');
		redoDom
			..title = '重做(${isApple ? '⌘' : 'Ctrl'}+Y)'
			..onClick.listen((_) => command.executeRedo());

		painterDom = _requireElement<DivElement>('.menu-item__painter');
		painterDom.onClick.listen((_) {
			if (_awaitingPainterSecondClick) {
				_painterTimer?.cancel();
				_awaitingPainterSecondClick = false;
				return;
			}
			_awaitingPainterSecondClick = true;
			_painterTimer = Timer(const Duration(milliseconds: 200), () {
				_awaitingPainterSecondClick = false;
				command.executePainter(IPainterOption(isDblclick: false));
			});
		});
		painterDom.onDoubleClick.listen((_) {
			_painterTimer?.cancel();
			_awaitingPainterSecondClick = false;
			command.executePainter(IPainterOption(isDblclick: true));
		});

		final formatDom = _requireElement<DivElement>('.menu-item__format');
		formatDom.onClick.listen((_) => command.executeFormat());
	}

	void _setupFontAndStyleControls() {
		final fontDom = _requireElement<DivElement>('.menu-item__font');
		fontSelectDom = _requireElementFrom<DivElement>(fontDom, '.select');
		fontOptionDom = _requireElementFrom<DivElement>(fontDom, '.options');
		fontDom.onClick.listen((_) => fontOptionDom.classes.toggle('visible'));
		fontOptionDom.onClick.listen((event) {
			final target = event.target;
			if (target is! LIElement) {
				return;
			}
			final family = target.dataset['family'];
			if (family == null || family.isEmpty) {
				return;
			}
			command.executeFont(family);
		});

		final sizeDom = _requireElement<DivElement>('.menu-item__size');
		sizeDom.title = '设置字号';
		sizeSelectDom = _requireElementFrom<DivElement>(sizeDom, '.select');
		sizeOptionDom = _requireElementFrom<DivElement>(sizeDom, '.options');
		sizeDom.onClick.listen((_) => sizeOptionDom.classes.toggle('visible'));
		sizeOptionDom.onClick.listen((event) {
			final target = event.target;
			if (target is! LIElement) {
				return;
			}
			final sizeValue = target.dataset['size'];
			final parsed = int.tryParse(sizeValue ?? '');
			if (parsed != null) {
				command.executeSize(parsed);
			}
		});

		final sizeAddDom = _requireElement<DivElement>('.menu-item__size-add');
		sizeAddDom
			..title = '增大字号(${isApple ? '⌘' : 'Ctrl'}+[)'
			..onClick.listen((_) => command.executeSizeAdd());

		final sizeMinusDom = _requireElement<DivElement>('.menu-item__size-minus');
		sizeMinusDom
			..title = '减小字号(${isApple ? '⌘' : 'Ctrl'}+])'
			..onClick.listen((_) => command.executeSizeMinus());

		boldDom = _requireElement<DivElement>('.menu-item__bold');
		boldDom
			..title = '加粗(${isApple ? '⌘' : 'Ctrl'}+B)'
			..onClick.listen((_) => command.executeBold());

		italicDom = _requireElement<DivElement>('.menu-item__italic');
		italicDom
			..title = '斜体(${isApple ? '⌘' : 'Ctrl'}+I)'
			..onClick.listen((_) => command.executeItalic());

		underlineDom = _requireElement<DivElement>('.menu-item__underline');
		underlineDom.title = '下划线(${isApple ? '⌘' : 'Ctrl'}+U)';
		underlineOptionDom = _requireElementFrom<DivElement>(underlineDom, '.options');
		final underlineSelect = _requireElementFrom<SpanElement>(underlineDom, '.select');
		final underlineIcon = _requireElementFrom<Element>(underlineDom, 'i');
		underlineSelect.onClick.listen((event) {
			event.stopPropagation();
			underlineOptionDom.classes.toggle('visible');
		});
		underlineIcon.onClick.listen((event) {
			event.stopPropagation();
			command.executeUnderline();
			underlineOptionDom.classes.remove('visible');
		});
		underlineOptionDom.onMouseDown.listen((event) {
			final target = event.target;
			if (target is! LIElement) {
				return;
			}
			final styleValue = target.dataset['decorationStyle'];
			final style = _parseTextDecorationStyle(styleValue);
			final decoration = style != null ? ITextDecoration(style: style) : null;
			command.executeUnderline(decoration);
			underlineOptionDom.classes.remove('visible');
		});

		strikeoutDom = _requireElement<DivElement>('.menu-item__strikeout');
		strikeoutDom.onClick.listen((_) => command.executeStrikeout());

		superscriptDom = _requireElement<DivElement>('.menu-item__superscript');
		superscriptDom
			..title = '上标(${isApple ? '⌘' : 'Ctrl'}+Shift+,)'
			..onClick.listen((_) => command.executeSuperscript());

		subscriptDom = _requireElement<DivElement>('.menu-item__subscript');
		subscriptDom
			..title = '下标(${isApple ? '⌘' : 'Ctrl'}+Shift+.)'
			..onClick.listen((_) => command.executeSubscript());

		colorControlDom = _requireElement<InputElement>('#color');
		colorControlDom.onInput.listen((_) => command.executeColor(colorControlDom.value));
		colorDom = _requireElement<DivElement>('.menu-item__color');
		colorSpanDom = _requireElementFrom<SpanElement>(colorDom, 'span');
		colorDom.onClick.listen((_) => colorControlDom.click());

		highlightControlDom = _requireElement<InputElement>('#highlight');
		highlightControlDom.onInput.listen((_) => command.executeHighlight(highlightControlDom.value));
		highlightDom = _requireElement<DivElement>('.menu-item__highlight');
		highlightSpanDom = _requireElementFrom<SpanElement>(highlightDom, 'span');
		highlightDom.onClick.listen((_) => highlightControlDom.click());
	}

	void _setupTitleAndAlignmentControls() {
		final titleDom = _requireElement<DivElement>('.menu-item__title');
		titleSelectDom = _requireElementFrom<DivElement>(titleDom, '.select');
		titleOptionDom = _requireElementFrom<DivElement>(titleDom, '.options');
		var index = 0;
		for (final li in titleOptionDom.querySelectorAll('li').whereType<LIElement>()) {
			li.title = 'Ctrl+${isApple ? 'Option' : 'Alt'}+$index';
			index += 1;
		}
		titleDom.onClick.listen((_) => titleOptionDom.classes.toggle('visible'));
		titleOptionDom.onClick.listen((event) {
			final target = event.target;
			if (target is! LIElement) {
				return;
			}
			final levelValue = target.dataset['level'];
			final level = _parseTitleLevel(levelValue);
			command.executeTitle(level);
		});

		leftDom = _requireElement<DivElement>('.menu-item__left');
		leftDom
			..title = '左对齐(${isApple ? '⌘' : 'Ctrl'}+L)'
			..onClick.listen((_) => command.executeRowFlex(RowFlex.left));

		centerDom = _requireElement<DivElement>('.menu-item__center');
		centerDom
			..title = '居中对齐(${isApple ? '⌘' : 'Ctrl'}+E)'
			..onClick.listen((_) => command.executeRowFlex(RowFlex.center));

		rightDom = _requireElement<DivElement>('.menu-item__right');
		rightDom
			..title = '右对齐(${isApple ? '⌘' : 'Ctrl'}+R)'
			..onClick.listen((_) => command.executeRowFlex(RowFlex.right));

		alignmentDom = _requireElement<DivElement>('.menu-item__alignment');
		alignmentDom
			..title = '两端对齐(${isApple ? '⌘' : 'Ctrl'}+J)'
			..onClick.listen((_) => command.executeRowFlex(RowFlex.alignment));

		justifyDom = _requireElement<DivElement>('.menu-item__justify');
		justifyDom
			..title = '分散对齐(${isApple ? '⌘' : 'Ctrl'}+Shift+J)'
			..onClick.listen((_) => command.executeRowFlex(RowFlex.justify));

		final rowMarginDom = _requireElement<DivElement>('.menu-item__row-margin');
		rowOptionDom = _requireElementFrom<DivElement>(rowMarginDom, '.options');
		rowMarginDom.onClick.listen((_) => rowOptionDom.classes.toggle('visible'));
		rowOptionDom.onClick.listen((event) {
			final target = event.target;
			if (target is! LIElement) {
				return;
			}
			final marginValue = double.tryParse(target.dataset['rowmargin'] ?? '');
			if (marginValue != null) {
				command.executeRowMargin(marginValue);
			}
		});
	}

	void _setupListControls() {
		listDom = _requireElement<DivElement>('.menu-item__list');
		listOptionDom = _requireElementFrom<DivElement>(listDom, '.options');
		listDom
			..title = '列表(${isApple ? '⌘' : 'Ctrl'}+Shift+U)'
			..onClick.listen((_) => listOptionDom.classes.toggle('visible'));
		listOptionDom.onClick.listen((event) {
			final target = event.target;
			if (target is! LIElement) {
				return;
			}
			final listType = _parseListType(target.dataset['listType']);
			final listStyle = _parseListStyle(target.dataset['listStyle']);
			command.executeList(listType, listStyle);
		});
	}

	void _setupSeparatorAndPageBreakControls() {
		separatorDom = _requireElement<DivElement>('.menu-item__separator');
		separatorOptionDom = _requireElementFrom<DivElement>(separatorDom, '.options');
		separatorDom.onClick.listen((_) => separatorOptionDom.classes.toggle('visible'));
		separatorOptionDom.onMouseDown.listen((event) {
			final target = event.target;
			if (target is! LIElement) {
				return;
			}
			final dashValue = target.dataset['separator'];
			final dashList = dashValue != null && dashValue.isNotEmpty
					? dashValue.split(',').map((value) => value.trim()).where((value) => value.isNotEmpty).map(int.parse).toList()
					: <int>[];
			final isSolid = dashList.isEmpty || dashList.every((element) => element == 0);
			final payload = isSolid ? <num>[] : dashList.map((value) => value.toDouble()).toList();
			command.executeSeparator(payload);
		});

		final pageBreakDom = _requireElement<DivElement>('.menu-item__page-break');
		pageBreakDom.onClick.listen((_) => command.executePageBreak());
	}

	void _setupTableControls() {
		final tableDom = _requireElement<DivElement>('.menu-item__table');
		final tablePanelContainer = _requireElement<DivElement>('.menu-item__table__collapse');
		final tableClose = _requireElement<DivElement>('.table-close');
		final tableTitle = _requireElement<DivElement>('.table-select');
		final tablePanel = _requireElement<TableElement>('.table-panel');
		tablePanel.children.clear();
		_tableCellList.clear();

		for (var r = 0; r < 10; r += 1) {
			final row = TableRowElement()..classes.add('table-row');
			final cells = <TableCellElement>[];
			for (var c = 0; c < 10; c += 1) {
				final cell = TableCellElement()..classes.add('table-cel');
				row.append(cell);
				cells.add(cell);
			}
			tablePanel.append(row);
			_tableCellList.add(cells);
		}

		void resetTable() {
			for (final cells in _tableCellList) {
				for (final cell in cells) {
					cell.classes.remove('active');
				}
			}
			_tableRowIndex = 0;
			_tableColIndex = 0;
			tableTitle.text = '插入';
			tablePanelContainer.style.display = 'none';
		}

		tableDom.onClick.listen((_) {
			tablePanelContainer.style.display = 'block';
		});

		tablePanel.onMouseMove.listen((event) {
			for (final cells in _tableCellList) {
				for (final cell in cells) {
					cell.classes.remove('active');
				}
			}
			const cellSize = 16;
			const rowMarginTop = 10;
			const cellMarginRight = 6;
			final offset = event.offset;
			_tableColIndex = ((offset.x) / (cellSize + cellMarginRight)).ceil();
			_tableRowIndex = ((offset.y) / (cellSize + rowMarginTop)).ceil();
			if (_tableColIndex < 1) _tableColIndex = 1;
			if (_tableColIndex > 10) _tableColIndex = 10;
			if (_tableRowIndex < 1) _tableRowIndex = 1;
			if (_tableRowIndex > 10) _tableRowIndex = 10;

			for (var r = 0; r < _tableRowIndex; r += 1) {
				for (var c = 0; c < _tableColIndex; c += 1) {
					_tableCellList[r][c].classes.add('active');
				}
			}
			tableTitle.text = '${_tableRowIndex}×${_tableColIndex}';
		});

		tableClose.onClick.listen((_) => resetTable());
		tablePanel.onClick.listen((_) {
			command.executeInsertTable(_tableRowIndex, _tableColIndex);
			resetTable();
		});
	}

	void _setupImageControl() {
		final imageDom = _requireElement<DivElement>('.menu-item__image');
		final imageFileDom = _requireElement<InputElement>('#image');
		imageDom.onClick.listen((_) => imageFileDom.click());
		imageFileDom.onChange.listen((_) {
			final files = imageFileDom.files;
			if (files == null || files.isEmpty) {
				return;
			}
			final file = files.first;
			final reader = FileReader();
			reader.readAsDataUrl(file);
			reader.onLoad.listen((_) {
				final result = reader.result;
				if (result is! String) {
					return;
				}
				final image = ImageElement()..src = result;
				image.onLoad.listen((_) {
					final width = image.width?.toDouble() ?? 0;
					final height = image.height?.toDouble() ?? 0;
					command.executeImage(
						IDrawImagePayload(
							value: result,
							width: width,
							height: height,
						),
					);
					imageFileDom.value = '';
				});
			});
		});
	}
}