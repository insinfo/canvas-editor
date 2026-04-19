import 'editor/dataset/enum/common.dart';
import 'editor/dataset/enum/control.dart';
import 'editor/dataset/enum/element.dart';
import 'editor/dataset/enum/list.dart';
import 'editor/dataset/enum/title.dart';
import 'editor/interface/editor.dart';
import 'editor/interface/element.dart';
import 'editor/interface/page_number.dart';
import 'editor/interface/placeholder.dart';
import 'editor/interface/table/td.dart';
import 'editor/interface/zone.dart';

IElement _sectionTitle(String value) {
	return IElement(
		value: '',
		type: ElementType.title,
		level: TitleLevel.first,
		valueList: [
			IElement(value: value, size: 18),
		],
	);
}

IElement _sampleTable() {
	List<IElement> cellText(String value) => <IElement>[
			IElement(value: value, size: 16),
			IElement(value: '.', size: 16),
		];

	return IElement(
		value: '',
		type: ElementType.table,
		colgroup: <IColgroup>[
			IColgroup(width: 180),
			IColgroup(width: 80),
			IColgroup(width: 130),
			IColgroup(width: 130),
		],
		trList: <ITr>[
			ITr(
				height: 40,
				tdList: <ITd>[
					ITd(colspan: 1, rowspan: 2, value: cellText('1')),
					ITd(colspan: 1, rowspan: 1, value: cellText('2')),
					ITd(colspan: 2, rowspan: 1, value: cellText('3')),
				],
			),
			ITr(
				height: 40,
				tdList: <ITd>[
					ITd(colspan: 1, rowspan: 1, value: cellText('4')),
					ITd(colspan: 1, rowspan: 1, value: cellText('5')),
					ITd(colspan: 1, rowspan: 1, value: cellText('6')),
				],
			),
			ITr(
				height: 40,
				tdList: <ITd>[
					ITd(colspan: 1, rowspan: 1, value: cellText('7')),
					ITd(colspan: 1, rowspan: 1, value: cellText('8')),
					ITd(colspan: 1, rowspan: 1, value: cellText('9')),
					ITd(colspan: 1, rowspan: 1, value: <IElement>[
						IElement(value: '1', size: 16),
						IElement(value: '0', size: 16),
						IElement(value: '.', size: 16),
					]),
				],
			),
		],
	);
}

List<IElement> _mockElementList() {
	return <IElement>[
		_sectionTitle('Queixa principal:'),
		IElement(value: '\nFebre há três dias, tosse seca há cinco dias e sensação de cansaço '),
		IElement(
			value: '',
			type: ElementType.control,
			control: IControl(
				conceptId: '1',
				type: ControlType.text,
				value: null,
				placeholder: 'com observações adicionais',
				prefix: '(',
				postfix: ')',
				valueSets: [],
				flexDirection: FlexDirection.row,
			),
		),
		IElement(value: '.\n'),

		_sectionTitle('História atual:'),
		IElement(
			value:
				'\nPaciente atendido após piora do quadro gripal iniciado em domicílio. Refere edema facial leve pela manhã, redução discreta do volume urinário e astenia progressiva, sem relato de lesões cutâneas ou dispneia.\n',
		),

		_sectionTitle('Antecedentes:'),
		IElement(value: '\nHistórico de hipertensão arterial sistêmica e diabetes mellitus tipo 2. Há acompanhamento prévio por '),
		IElement(value: 'doença infecciosa', color: '#FF0000'),
		IElement(value: ' em investigação, com necessidade de revisão clínica complementar.\n'),

		_sectionTitle('Histórico epidemiológico:'),
		IElement(value: '\nNega contato conhecido com casos confirmados recentes. Consultar o '),
		IElement(
			value: '',
			type: ElementType.hyperlink,
			valueList: [
				IElement(value: 'protocolo institucional para síndrome gripal', size: 16),
			],
			url: 'https://hufe.club/canvas-editor',
		),
		IElement(value: ' para atualização da conduta.\n'),

		_sectionTitle('Exame físico:'),
		IElement(value: '\nTemperatura de 39,5 °C, frequência cardíaca de 80 bpm, frequência respiratória de 20 irpm e pressão arterial de 120/80 mmHg.\n'),

		_sectionTitle('Exames complementares:'),
		IElement(value: '\nHemograma de 10/06/2020 com '),
		IElement(
			value: 'hematócrito',
			highlight: '#F2F27F',
			groupIds: ['1'],
			size: 16,
		),
		IElement(value: ' discretamente reduzido (36,5%) e monócitos absolutos aumentados. Saturação periférica preservada durante a avaliação.\n'),

		IElement(
			value: '',
			type: ElementType.list,
			listType: ListType.ordered,
			valueList: [
				IElement(value: 'Reavaliar pressão arterial\nControlar glicemia capilar\nMonitorar diurese\nRegistrar sinais de alarme'),
			],
		),
		IElement(value: '\n'),

		_sectionTitle('Conduta inicial:'),
		IElement(value: '\nSolicitar nova coleta laboratorial em 24 horas, manter hidratação, orientar retorno imediato em caso de piora clínica e registrar concordância com o plano terapêutico.\n'),

		IElement(value: 'Concorda com as orientações acima: '),
		IElement(
			value: '',
			type: ElementType.control,
			control: IControl(
				conceptId: '3',
				type: ControlType.checkbox,
				code: '98175',
				value: null,
				valueSets: [
					IValueSet(value: 'Sim', code: '98175'),
					IValueSet(value: 'Não', code: '98176'),
				],
				flexDirection: FlexDirection.row,
			),
		),
		IElement(value: '\n'),

		IElement(value: 'Classificação de risco: '),
		IElement(
			value: '',
			type: ElementType.control,
			control: IControl(
				conceptId: '2',
				type: ControlType.select,
				value: null,
				placeholder: 'selecionar',
				prefix: '[',
				postfix: ']',
				valueSets: [
					IValueSet(value: 'Baixo', code: '98175'),
					IValueSet(value: 'Moderado', code: '98176'),
					IValueSet(value: 'Alto', code: '98177'),
				],
				flexDirection: FlexDirection.row,
			),
		),
		IElement(value: '\n'),

		IElement(value: 'Assinatura do paciente: '),
		IElement(
			value: '',
			type: ElementType.control,
			control: IControl(
				conceptId: '4',
				type: ControlType.text,
				value: null,
				placeholder: '',
				prefix: '\u200c',
				postfix: '\u200c',
				minWidth: 160,
				underline: true,
				valueSets: [],
				flexDirection: FlexDirection.row,
			),
		),
		IElement(value: '\n'),

		IElement(value: 'Data da assinatura: '),
		IElement(
			value: '',
			type: ElementType.control,
			control: IControl(
				conceptId: '5',
				type: ControlType.date,
				value: [IElement(value: '2026-04-08 09:30:00')],
				placeholder: 'selecionar data',
				valueSets: [],
				flexDirection: FlexDirection.row,
			),
		),
		IElement(value: '\n'),

		_sampleTable(),
		IElement(value: '\n'),

		IElement(value: 'Observações finais: '),
		IElement(
			value: '',
			type: ElementType.control,
			control: IControl(
				conceptId: '6',
				type: ControlType.text,
				value: null,
				placeholder: 'registrar observações complementares',
				preText: '(',
				postText: ')',
				valueSets: [],
				flexDirection: FlexDirection.row,
			),
		),
	];
}

final List<IElement> data = List<IElement>.unmodifiable(_mockElementList());

class EditorComment {
	final String id;
	final String content;
	final String userName;
	final String rangeText;
	final String createdDate;

	const EditorComment({
		required this.id,
		required this.content,
		required this.userName,
		required this.rangeText,
		required this.createdDate,
	});
}

const List<EditorComment> commentList = [
	EditorComment(
		id: '1',
		content: 'Hematócrito (HCT) corresponde à fração do volume sanguíneo ocupada pelas hemácias e ajuda a interpretar a relação entre componentes celulares e plasma.',
		userName: 'Hufe',
		rangeText: 'hematócrito',
		createdDate: '2023-08-20 23:10:55',
	),
];

final IEditorOption options = IEditorOption(
	locale: 'ptBR',
	margins: [100, 120, 100, 120],
	// Marca d'agua desativada ate a revisao final da shell web da demo.
	//watermark: IWatermark(data: '', size: 120),
	pageNumber: IPageNumber(format: 'Página {pageNo} de {pageCount}'),
	placeholder: IPlaceholder(data: 'Digite o conteúdo principal'),
	zone: IZoneOption(tipDisabled: true),
	maskMargin: [60, 0, 30, 0],
);