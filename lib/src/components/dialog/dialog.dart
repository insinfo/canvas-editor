import 'package:canvas_text_editor/src/dom/dom.dart';

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

  HTMLDivElement? _mask;
  HTMLDivElement? _container;

  void _render() {
    final body = document.body;
    if (body == null) {
      return;
    }

    final mask = HTMLDivElement()
      ..classList.add('dialog-mask')
      ..setAttribute(editorComponent, EditorComponent.component.name);
    body.append(mask);

    final container = HTMLDivElement()
      ..classList.add('dialog-container')
      ..setAttribute(editorComponent, EditorComponent.component.name);

    final dialog = HTMLDivElement()..classList.add('dialog');
    container.append(dialog);

    final titleContainer = HTMLDivElement()..classList.add('dialog-title');
    final titleSpan = HTMLSpanElement()..text = _options.title;
    final closeIcon = document.createElement('i');
    closeIcon.onClick.listen((_) {
      _options.onClose?.call();
      _dispose();
    });
    titleContainer
      ..append(titleSpan)
      ..append(closeIcon);
    dialog.append(titleContainer);

    final optionContainer = HTMLDivElement()..classList.add('dialog-option');
    for (final data in _options.data) {
      final optionItem = HTMLDivElement()..classList.add('dialog-option__item');

      if (data.label != null) {
        final label = HTMLSpanElement()
          ..text = data.label!
          ..classList.toggle('dialog-option__item--require', data.required ?? false);
        optionItem.append(label);
      }

      Element input;
      if (data.type == 'select') {
        final select = HTMLSelectElement();
        for (final option in data.options ?? const <DialogOptionItem>[]) {
          // append direto: o glue `children` do package:web materializa uma
          // List MORTA — add() nela não anexa nada e o select ficava vazio.
          select.append(
              HTMLOptionElement()..text = option.label..value = option.value);
        }
        input = select;
      } else if (data.type == 'textarea') {
        input = HTMLTextAreaElement()..placeholder = data.placeholder ?? '';
      } else {
        input = HTMLInputElement()
          ..type = data.type
          ..placeholder = data.placeholder ?? '';
      }

      input
        ..attributes['name'] = data.name
        ..attributes['value'] = data.value ?? '';

      if (jsIsHTMLSelectElement(input)) {
        final HTMLSelectElement select = input as HTMLSelectElement;
        select.value = data.value ?? select.value;
      } else if (jsIsHTMLInputElement(input)) {
        (input as HTMLInputElement).value = data.value ?? '';
      } else if (jsIsHTMLTextAreaElement(input)) {
        (input as HTMLTextAreaElement).value = data.value ?? '';
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

    final menuContainer = HTMLDivElement()..classList.add('dialog-menu');

    final cancelButton = HTMLButtonElement()
      ..classList.add('dialog-menu__cancel')
      ..text = 'Cancelar'
      ..type = 'button';
    cancelButton.onClick.listen((_) {
      _options.onCancel?.call();
      _dispose();
    });
    menuContainer.append(cancelButton);

    final confirmButton = HTMLButtonElement()
      ..text = 'Confirmar'
      ..type = 'submit';
    confirmButton.onClick.listen((_) {
      if (_options.onConfirm != null) {
        final payload = _inputs.map<DialogConfirm>((dynamic element) {
          if (jsIsHTMLInputElement(element)) {
            final HTMLInputElement input = element as HTMLInputElement;
            return DialogConfirm(name: input.name, value: input.value);
          }
          if (jsIsHTMLTextAreaElement(element)) {
            final HTMLTextAreaElement area = element as HTMLTextAreaElement;
            return DialogConfirm(name: area.name, value: area.value);
          }
          if (jsIsHTMLSelectElement(element)) {
            final HTMLSelectElement select = element as HTMLSelectElement;
            return DialogConfirm(name: select.name, value: select.value);
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
