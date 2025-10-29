import 'dart:html';

import '../../editor/dataset/constant/editor.dart';
import '../../editor/dataset/enum/editor.dart';

class DialogOptionItem {
	DialogOptionItem({required this.label, required this.value});

	final String label;
	final String value;
}

class DialogData {
	DialogData({
		required this.type,
		required this.name,
		this.label,
		this.value,
		this.options,
		this.placeholder,
		this.width,
		this.height,
		this.required,
	});

	final String type;
	final String name;
	final String? label;
	final String? value;
	final List<DialogOptionItem>? options;
	final String? placeholder;
	final num? width;
	final num? height;
	final bool? required;
}

class DialogConfirm {
	DialogConfirm({required this.name, required this.value});

	final String name;
	final String value;
}

class DialogOptions {
	DialogOptions({
		required this.title,
		required this.data,
		this.onClose,
		this.onCancel,
		this.onConfirm,
	});

	final String title;
	final List<DialogData> data;
	final void Function()? onClose;
	final void Function()? onCancel;
	final void Function(List<DialogConfirm>)? onConfirm;
}

class Dialog {
	Dialog(this._options) {
		_render();
	}

	final DialogOptions _options;
	final List<dynamic> _inputs = <dynamic>[];

	DivElement? _mask;
	DivElement? _container;

	void _render() {
		final body = document.body;
		if (body == null) {
			return;
		}

		final mask = DivElement()
			..classes.add('dialog-mask')
			..setAttribute(editorComponent, EditorComponent.component.name);
		body.append(mask);

		final container = DivElement()
			..classes.add('dialog-container')
			..setAttribute(editorComponent, EditorComponent.component.name);

		final dialog = DivElement()..classes.add('dialog');
		container.append(dialog);

		final titleContainer = DivElement()..classes.add('dialog-title');
		final titleSpan = SpanElement()..text = _options.title;
		final closeIcon = Element.tag('i');
		closeIcon.onClick.listen((_) {
			_options.onClose?.call();
			_dispose();
		});
		titleContainer
			..append(titleSpan)
			..append(closeIcon);
		dialog.append(titleContainer);

		final optionContainer = DivElement()..classes.add('dialog-option');
		for (final data in _options.data) {
			final optionItem = DivElement()..classes.add('dialog-option__item');

			if (data.label != null) {
				final label = SpanElement()
					..text = data.label!
					..classes.toggle('dialog-option__item--require', data.required);
				optionItem.append(label);
			}

			Element input;
			if (data.type == 'select') {
				final select = SelectElement();
				for (final option in data.options ?? const <DialogOptionItem>[]) {
					select.children.add(OptionElement(data: option.label, value: option.value));
				}
				input = select;
			} else if (data.type == 'textarea') {
				input = TextAreaElement()
					..placeholder = data.placeholder ?? '';
			} else {
				input = InputElement()
					..type = data.type
					..placeholder = data.placeholder ?? '';
			}

			input
				..attributes['name'] = data.name
				..attributes['value'] = data.value ?? '';

			if (input is SelectElement) {
				input.value = data.value ?? input.value;
			} else if (input is InputElement) {
				input.value = data.value ?? '';
			} else if (input is TextAreaElement) {
				input.value = data.value ?? '';
			}

			if (data.width != null) {
				input.style.width = '${data.width}px';
			}
			if (data.height != null) {
				input.style.height = '${data.height}px';
			}

			optionItem.append(input);
			optionContainer.append(optionItem);
			_inputs.add(input);
		}
		dialog.append(optionContainer);

		final menuContainer = DivElement()..classes.add('dialog-menu');

		final cancelButton = ButtonElement()
			..classes.add('dialog-menu__cancel')
			..text = '取消'
			..type = 'button';
		cancelButton.onClick.listen((_) {
			_options.onCancel?.call();
			_dispose();
		});
		menuContainer.append(cancelButton);

		final confirmButton = ButtonElement()
			..text = '确定'
			..type = 'submit';
		confirmButton.onClick.listen((_) {
			if (_options.onConfirm != null) {
						final payload = _inputs.map<DialogConfirm>((dynamic element) {
																									if (element is InputElement) {
																										final String? name = element.name;
																										final String? value = element.value;
																										return DialogConfirm(name: name ?? '', value: value ?? '');
							}
							if (element is TextAreaElement) {
																										final String? name = element.name;
																										final String? value = element.value;
																										return DialogConfirm(name: name ?? '', value: value ?? '');
							}
							if (element is SelectElement) {
																										final String? name = element.name;
																										final String? value = element.value;
																										return DialogConfirm(name: name ?? '', value: value ?? '');
							}
							return DialogConfirm(name: '', value: '');
						}).toList(growable: false);
				_options.onConfirm!(payload);
			}
			_dispose();
		});
		menuContainer.append(confirmButton);
		dialog.append(menuContainer);

		body.append(container);
		_mask = mask;
		_container = container;
	}

	void _dispose() {
		_mask?.remove();
		_container?.remove();
		_inputs.clear();
	}
}