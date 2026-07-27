import '../dataset/enum/editor.dart';
import '../dataset/enum/title.dart';

/// Aparência de um nível de título (equivalente a "Modificar Estilo" do Word).
/// Campos nulos caem no padrão do editor.
class ITitleStyle {
	String? font;
	int? size;
	String? color;
	bool? bold;
	bool? italic;

	ITitleStyle({this.font, this.size, this.color, this.bold, this.italic});

	ITitleStyle clone() => ITitleStyle(
				font: font,
				size: size,
				color: color,
				bold: bold,
				italic: italic,
			);
}

class ITitleOption {
	double? defaultFirstSize;
	double? defaultSecondSize;
	double? defaultThirdSize;
	double? defaultFourthSize;
	double? defaultFifthSize;
	double? defaultSixthSize;

	/// Customização por nível (Título 1..6) definida pelo usuário. Vence os
	/// padrões ao aplicar o título e ao reaplicar o estilo no documento.
	Map<TitleLevel, ITitleStyle>? styles;

	ITitleOption({
		this.defaultFirstSize,
		this.defaultSecondSize,
		this.defaultThirdSize,
		this.defaultFourthSize,
		this.defaultFifthSize,
		this.defaultSixthSize,
		this.styles,
	});
}

class ITitle {
	bool? deletable;
	bool? disabled;
	String? conceptId;

	ITitle({this.deletable, this.disabled, this.conceptId});
}

class IGetTitleValueOption {
	String conceptId;

	IGetTitleValueOption({required this.conceptId});
}

class ITitleValueItem<TElement> extends ITitle {
	String? value;
	List<TElement> elementList;
	EditorZone zone;

	ITitleValueItem({
		bool? deletable,
		bool? disabled,
		String? conceptId,
		this.value,
		required this.elementList,
		required this.zone,
	}) : super(
					deletable: deletable,
					disabled: disabled,
					conceptId: conceptId,
				);
}