import '../enum/element.dart';

const List<String> editorElementStyleAttr = <String>[
	'bold',
	'color',
	'highlight',
	'font',
	'size',
	'italic',
	'underline',
	'strikeout',
	'textDecoration',
];

const List<String> editorRowAttr = <String>[
	'rowFlex',
	'rowMargin',
];

const List<String> editorElementCopyAttr = <String>[
	'type',
	'font',
	'size',
	'bold',
	'color',
	'italic',
	'highlight',
	'underline',
	'strikeout',
	'rowFlex',
	'url',
	'areaId',
	'hyperlinkId',
	'dateId',
	'dateFormat',
	'groupIds',
	'rowMargin',
	'textDecoration',
];

const List<String> editorElementZipAttr = <String>[
	'type',
	'font',
	'size',
	'bold',
	'color',
	'italic',
	'highlight',
	'underline',
	'strikeout',
	'rowFlex',
	'rowMargin',
	'dashArray',
	'trList',
	'tableToolDisabled',
	'borderType',
	'borderColor',
	'translateX',
	'width',
	'height',
	'url',
	'colgroup',
	'valueList',
	'control',
	'checkbox',
	'radio',
	'dateFormat',
	'block',
	'level',
	'title',
	'listType',
	'listStyle',
	'listWrap',
	'groupIds',
	'conceptId',
	'imgDisplay',
	'imgFloatPosition',
	'imgToolDisabled',
	'textDecoration',
	'extension',
	'externalId',
	'areaId',
	'area',
	'hide',
];

const List<String> tableTdZipAttr = <String>[
	'conceptId',
	'extension',
	'externalId',
	'verticalAlign',
	'backgroundColor',
	'borderTypes',
	'slashTypes',
	'disabled',
	'deletable',
];

const List<String> tableContextAttr = <String>[
	'tdId',
	'trId',
	'tableId',
];

const List<String> titleContextAttr = <String>[
	'level',
	'titleId',
	'title',
];

const List<String> listContextAttr = <String>[
	'listId',
	'listType',
	'listStyle',
];

const List<String> controlContextAttr = <String>[
	'control',
	'controlId',
	'controlComponent',
];

const List<String> controlStyleAttr = <String>[
	'font',
	'size',
	'bold',
	'highlight',
	'italic',
	'strikeout',
];

const List<String> areaContextAttr = <String>[
	'areaId',
	'area',
];

const List<String> editorElementContextAttr = <String>[
	...tableContextAttr,
	...titleContextAttr,
	...listContextAttr,
	...areaContextAttr,
];

const List<ElementType> textlikeElementType = <ElementType>[
	ElementType.text,
	ElementType.hyperlink,
	ElementType.subscript,
	ElementType.superscript,
	ElementType.control,
	ElementType.date,
];

const List<ElementType> imageElementType = <ElementType>[
	ElementType.image,
	ElementType.latex,
];

const List<ElementType> blockElementType = <ElementType>[
	ElementType.block,
	ElementType.pageBreak,
	ElementType.separator,
	ElementType.table,
];

const List<String> inlineNodeName = <String>[
	'HR',
	'TABLE',
	'UL',
	'OL',
];

const List<ElementType> virtualElementType = <ElementType>[
	ElementType.title,
	ElementType.list,
];