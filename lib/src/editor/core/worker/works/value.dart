import '../../../interface/draw.dart';
import '../../../interface/editor.dart';
import '../../../interface/element.dart';
import '../../../utils/element.dart';

List<IElement> _cloneElementList(List<IElement>? source) {
	if (source == null) {
		return <IElement>[];
	}
	return List<IElement>.from(source);
}

/// Returns a zipped editor payload following the same semantics as the
/// original worker implementation.
IEditorData computeZippedValue(
	IEditorData data,
	IGetValueOption? options,
) {
	final List<String> extraPickAttrs = options?.extraPickAttrs ?? const <String>[];
	final ZipElementListOption commonOption = ZipElementListOption(
		extraPickAttrs: extraPickAttrs,
		isClone: false,
	);
	final ZipElementListOption mainOption = commonOption.copyWith(
		isClassifyArea: true,
	);
	final List<IElement> header = zipElementList(
		_cloneElementList(data.header),
		options: commonOption,
	);
	final List<IElement> main = zipElementList(
		_cloneElementList(data.main),
		options: mainOption,
	);
	final List<IElement> footer = zipElementList(
		_cloneElementList(data.footer),
		options: commonOption,
	);
	return IEditorData(
		header: header,
		main: main,
		footer: footer,
	);
}
