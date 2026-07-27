/// Camada fina do editor sobre `package:web` (substitui `dart:html`).
///
/// Plano e racional: `doc/plano_migracao_dart_html_package_web.md`.
///
/// Regras:
/// - NÃO recria o dart:html — só complementa o que o `web 1.1.1` não traz
///   (event streams de Document/Window/FileReader, setters String do canvas,
///   manipulação de `children`, RAF, Blob/File, casts seguros).
/// - Tudo aqui é `package:web` puro (compatível com dart2js e dart2wasm).
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:math' show Point;
import 'dart:typed_data';

import 'package:web/web.dart';

export 'dart:js_interop';
export 'dart:js_interop_unsafe';
export 'dart:math' show Point, Rectangle;

export 'package:web/web.dart';

// ─────────────────────────────────────────────────────────────────────────
// Eventos que os helpers do package:web não cobrem
// ─────────────────────────────────────────────────────────────────────────

/// Streams de eventos no [Document] (o package:web só traz custom events).
extension DocumentCompatEvents on Document {
  Stream<MouseEvent> get onMouseMove =>
      EventStreamProviders.mouseMoveEvent.forTarget(this);
  Stream<MouseEvent> get onMouseUp =>
      EventStreamProviders.mouseUpEvent.forTarget(this);
  Stream<MouseEvent> get onMouseDown =>
      EventStreamProviders.mouseDownEvent.forTarget(this);
  Stream<MouseEvent> get onClick =>
      EventStreamProviders.clickEvent.forTarget(this);
  Stream<KeyboardEvent> get onKeyDown =>
      EventStreamProviders.keyDownEvent.forTarget(this);
  Stream<KeyboardEvent> get onKeyUp =>
      EventStreamProviders.keyUpEvent.forTarget(this);
  Stream<Event> get onSelectionChange =>
      const EventStreamProvider<Event>('selectionchange').forTarget(this);
  Stream<Event> get onFullscreenChange =>
      const EventStreamProvider<Event>('fullscreenchange').forTarget(this);
  Stream<ClipboardEvent> get onPaste =>
      EventStreamProviders.pasteEvent.forTarget(this);
  Stream<ClipboardEvent> get onCopy =>
      EventStreamProviders.copyEvent.forTarget(this);
  Stream<MouseEvent> get onContextMenu =>
      EventStreamProviders.contextMenuEvent.forTarget(this);
  Stream<Event> get onScroll =>
      EventStreamProviders.scrollEvent.forTarget(this);
  Stream<MouseEvent> get onMouseLeave =>
      const EventStreamProvider<MouseEvent>('mouseleave').forTarget(this);
}

/// Streams de eventos no [Window] além dos WindowEventGetters do package:web
/// (que só tem onKeyDown/onKeyPress/onLoad/onMessage/onPopState/onTouchMove).
extension WindowCompatEvents on Window {
  Stream<Event> get onResize =>
      const EventStreamProvider<Event>('resize').forTarget(this);
  Stream<Event> get onScroll =>
      EventStreamProviders.scrollEvent.forTarget(this);
  Stream<MouseEvent> get onMouseMove =>
      EventStreamProviders.mouseMoveEvent.forTarget(this);
  Stream<MouseEvent> get onMouseUp =>
      EventStreamProviders.mouseUpEvent.forTarget(this);
  Stream<MouseEvent> get onMouseDown =>
      EventStreamProviders.mouseDownEvent.forTarget(this);
  Stream<MouseEvent> get onClick =>
      EventStreamProviders.clickEvent.forTarget(this);
  Stream<KeyboardEvent> get onKeyUp =>
      EventStreamProviders.keyUpEvent.forTarget(this);
  Stream<Event> get onBlur => EventStreamProviders.blurEvent.forTarget(this);
  Stream<Event> get onFocus => EventStreamProviders.focusEvent.forTarget(this);
  Stream<Event> get afterPrint =>
      const EventStreamProvider<Event>('afterprint').forTarget(this);
  Stream<MouseEvent> get onMouseOver =>
      const EventStreamProvider<MouseEvent>('mouseover').forTarget(this);
}

/// `FileReader.onLoad`/`onError` (o package:web só traz onLoadEnd).
extension FileReaderCompatEvents on FileReader {
  Stream<ProgressEvent> get onLoad =>
      const EventStreamProvider<ProgressEvent>('load').forTarget(this);
  Stream<ProgressEvent> get onError =>
      const EventStreamProvider<ProgressEvent>('error').forTarget(this);
}

/// `onDoubleClick` tipado como [MouseEvent] (o helper do package:web declara
/// `Event`); `dblclick` é um MouseEvent na prática.
extension ElementCompatEvents on Element {
  Stream<MouseEvent> get onDblClick =>
      const EventStreamProvider<MouseEvent>('dblclick').forTarget(this);
}

// ─────────────────────────────────────────────────────────────────────────
// Canvas
// ─────────────────────────────────────────────────────────────────────────

extension CanvasCtxCompat on CanvasRenderingContext2D {
  /// `fillStyle` recebendo cor CSS (no IDL o tipo é `JSAny`:
  /// String|CanvasGradient|CanvasPattern).
  set fillColor(String value) => fillStyle = value.toJS;
  String get fillColor {
    final JSAny current = fillStyle;
    return current.isA<JSString>() ? (current as JSString).toDart : '';
  }

  set strokeColor(String value) => strokeStyle = value.toJS;
  String get strokeColor {
    final JSAny current = strokeStyle;
    return current.isA<JSString>() ? (current as JSString).toDart : '';
  }

  /// `setLineDash` com lista Dart.
  void setDash(List<num> dashes) => setLineDash(
      <JSNumber>[for (final num d in dashes) d.toDouble().toJS].toJS);
}

// ─────────────────────────────────────────────────────────────────────────
// Elementos / coleções
// ─────────────────────────────────────────────────────────────────────────

extension NodeCompat on Node {
  /// Anexa todos os nós, na ordem (substitui `children.addAll`).
  void appendAll(Iterable<Node> nodes) {
    for (final Node node in nodes) {
      appendChild(node);
    }
  }

  /// Remove todos os filhos (substitui `children.clear()`).
  void clearChildren() {
    while (firstChild != null) {
      removeChild(firstChild!);
    }
  }
}

extension ElementCompat on Element {
  /// Filhos-Elemento materializados (a `children` do IDL é uma HTMLCollection
  /// viva sem operações de List).
  List<Element> get childElements =>
      <Element>[for (int i = 0; i < children.length; i++) children.item(i)!];

  /// `style` também quando o tipo estático é [Element] (querySelector).
  /// Em runtime todo elemento com estilo inline responde a `.style`.
  CSSStyleDeclaration get style => (this as HTMLElement).style;

  /// `dataset` quando o tipo estático é [Element].
  DOMStringMap get dataset => (this as HTMLElement).dataset;

  /// Estilo COMPUTADO (no dart:html era método do próprio elemento).
  CSSStyleDeclaration getComputedStyle() => window.getComputedStyle(this);

  /// Delegações de HTMLElement úteis com tipo estático [Element].
  int get offsetTop => (this as HTMLElement).offsetTop;
  int get offsetLeft => (this as HTMLElement).offsetLeft;
  int get offsetWidth => (this as HTMLElement).offsetWidth;
  int get offsetHeight => (this as HTMLElement).offsetHeight;
  Element? get offsetParent => (this as HTMLElement).offsetParent;

  /// `appendText` do dart:html.
  void appendText(String value) => appendChild(Text(value));
  set innerText(String value) => (this as HTMLElement).innerText = value;
  String get innerText => (this as HTMLElement).innerText;

  /// `outerHTML` como String (JSAny no IDL por TrustedTypes).
  String get outerHtml {
    final JSAny current = outerHTML;
    return current.isA<JSString>() ? (current as JSString).toDart : '';
  }

  /// `innerHTML` como String (no IDL é JSAny por causa de TrustedTypes).
  String get innerHtml {
    final JSAny current = innerHTML;
    return current.isA<JSString>() ? (current as JSString).toDart : '';
  }

  set innerHtml(String value) => innerHTML = value.toJS;

  /// `title` (tooltip) com tipo estático [Element].
  String get title => (this as HTMLElement).title;
  set title(String value) => (this as HTMLElement).title = value;

  /// `nodes` do dart:html (filhos incluindo nós de texto), materializado.
  List<Node> get nodes =>
      <Node>[for (int i = 0; i < childNodes.length; i++) childNodes.item(i)!];
}

/// `event.dataTransfer?.types.contains('Files')` do dart:html.
bool dataTransferHasFiles(DataTransfer? dataTransfer) {
  if (dataTransfer == null) return false;
  final JSArray<JSString> types = dataTransfer.types;
  for (int i = 0; i < types.length; i++) {
    if (types[i].toDart == 'Files') return true;
  }
  return false;
}

extension NodeCompatMembers on Node {
  /// `parent` do dart:html (= parentElement).
  Element? get parent => parentElement;

  /// `Node.remove()` do dart:html (o IDL só tem em Element/CharacterData).
  void remove() => parentNode?.removeChild(this);
}

extension NamedNodeMapCompat on NamedNodeMap {
  /// Iteração nome→valor como o Map de atributos do dart:html.
  void forEach(void Function(String name, String value) action) {
    for (int i = 0; i < length; i++) {
      final Attr attr = item(i)!;
      action(attr.name, attr.value);
    }
  }

  void operator []=(String name, String value) {
    final Attr attr = document.createAttribute(name);
    attr.value = value;
    setNamedItem(attr);
  }
}

/// `console.log` com qualquer valor Dart (no IDL o parâmetro é JSAny?).
void consoleLog(Object? message) => console.log(message?.toString().toJS);
void consoleWarn(Object? message) => console.warn(message?.toString().toJS);
void consoleError(Object? message) => console.error(message?.toString().toJS);

/// `text` do dart:html em [Element]: declarado num tipo MAIS ESPECÍFICO que o
/// `NodeGlue.text` (setter deprecado em Node) para vencer a resolução de
/// extensão sem ambiguidade.
extension ElementTextCompat on Element {
  String get text => textContent ?? '';
  set text(String? value) => textContent = value;
}

extension MouseEventCompat on MouseEvent {
  /// Posição relativa ao alvo, como o `offset` do dart:html.
  Point<num> get offset => Point<num>(offsetX, offsetY);

  /// `dataTransfer` em handlers tipados como MouseEvent (drag/drop).
  DataTransfer? get dataTransfer =>
      isA<DragEvent>() ? (this as DragEvent).dataTransfer : null;
}

extension WindowCompatMembers on Window {
  /// Future que resolve no próximo frame (dart:html `window.animationFrame`).
  Future<num> get animationFrame {
    final Completer<num> completer = Completer<num>.sync();
    raf(completer.complete);
    return completer.future;
  }
}

extension NodeListCompat on NodeList {
  /// Materializa como lista de elementos (ignora nós não-Element).
  List<Element> toElements() => <Element>[
        for (int i = 0; i < length; i++)
          if (item(i).isA<Element>()) item(i)! as Element
      ];

  List<Node> toList() => <Node>[for (int i = 0; i < length; i++) item(i)!];

  void forEach(void Function(Node node) action) {
    for (int i = 0; i < length; i++) {
      action(item(i)!);
    }
  }

  Node get first => item(0)!;
  Node get last => item(length - 1)!;
  bool get isEmpty => length == 0;
  bool get isNotEmpty => length > 0;
  Node operator [](int index) => item(index)!;
}

extension HTMLCollectionCompat on HTMLCollection {
  List<Element> toElements() =>
      <Element>[for (int i = 0; i < length; i++) item(i)!];
}

extension TouchListCompat on TouchList {
  bool get isEmpty => length == 0;
  bool get isNotEmpty => length > 0;
  Touch get first => item(0)!;
}

extension DOMTokenListCompatList on DOMTokenList {
  List<String> toList() =>
      <String>[for (int i = 0; i < length; i++) item(i)!];
}

extension FileListCompat on FileList {
  File get first => item(0)!;
  bool get isEmpty => length == 0;
  bool get isNotEmpty => length > 0;
}

extension HTMLOptionsCollectionCompat on HTMLOptionsCollection {
  /// Iteração/consulta das opções de um select (dart:html expunha List).
  List<HTMLOptionElement> toList() => <HTMLOptionElement>[
        for (int i = 0; i < length; i++)
          if (item(i).isA<HTMLOptionElement>()) item(i)! as HTMLOptionElement
      ];

  bool any(bool Function(HTMLOptionElement option) test) =>
      toList().any(test);
}

extension DOMTokenListCompat on DOMTokenList {
  void addAll(Iterable<String> tokens) {
    for (final String token in tokens) {
      add(token);
    }
  }

  void removeAll(Iterable<String> tokens) {
    for (final String token in tokens) {
      remove(token);
    }
  }
}

/// Lista materializada de uma [NodeList] (querySelectorAll).
List<Element> elementsOfNodeList(NodeList list) => <Element>[
      for (int i = 0; i < list.length; i++)
        if (list.item(i).isA<Element>()) list.item(i)! as Element
    ];

/// Lista materializada de uma [FileList] (`input.files`).
List<File> filesOf(FileList? list) => <File>[
      if (list != null)
        for (int i = 0; i < list.length; i++) list.item(i)!
    ];

// ─────────────────────────────────────────────────────────────────────────
// Casts seguros (extension types apagam para JSObject: `is Element` é
// sempre-verdadeiro — o teste correto é isA<T>())
// ─────────────────────────────────────────────────────────────────────────

/// Teste de tipo JS a partir de valores `dynamic`/`Object?` (o `is` de Dart
/// entre tipos interop compara só o apagamento p/ JSObject e mente).
///
/// O `isA<T>()` do js_interop NÃO aceita variável de tipo (erro do CFE no
/// dart2js) — por isso os probes são monomórficos, um por tipo usado.
// ignore: invalid_runtime_check_with_js_interop_types
bool _isJSValue(Object? value) => value is JSAny;

bool jsIsJSAny(Object? value) => _isJSValue(value);

bool jsIsJSObject(Object? value) =>
    _isJSValue(value) && (value as JSAny).isA<JSObject>();

bool jsIsElement(Object? value) =>
    _isJSValue(value) && (value as JSAny).isA<Element>();

bool jsIsHTMLDivElement(Object? value) =>
    _isJSValue(value) && (value as JSAny).isA<HTMLDivElement>();

bool jsIsHTMLInputElement(Object? value) =>
    _isJSValue(value) && (value as JSAny).isA<HTMLInputElement>();

bool jsIsHTMLTextAreaElement(Object? value) =>
    _isJSValue(value) && (value as JSAny).isA<HTMLTextAreaElement>();

bool jsIsHTMLSelectElement(Object? value) =>
    _isJSValue(value) && (value as JSAny).isA<HTMLSelectElement>();

bool jsIsEvent(Object? value) =>
    _isJSValue(value) && (value as JSAny).isA<Event>();

bool jsIsMouseEvent(Object? value) =>
    _isJSValue(value) && (value as JSAny).isA<MouseEvent>();

bool jsIsKeyboardEvent(Object? value) =>
    _isJSValue(value) && (value as JSAny).isA<KeyboardEvent>();

Element? asElement(JSAny? target) =>
    target != null && target.isA<Element>() ? target as Element : null;

HTMLElement? asHtmlElement(JSAny? target) =>
    target != null && target.isA<HTMLElement>() ? target as HTMLElement : null;

HTMLCanvasElement? asCanvasElement(JSAny? target) =>
    target != null && target.isA<HTMLCanvasElement>()
        ? target as HTMLCanvasElement
        : null;

HTMLInputElement? asInputElement(JSAny? target) =>
    target != null && target.isA<HTMLInputElement>()
        ? target as HTMLInputElement
        : null;

// ─────────────────────────────────────────────────────────────────────────
// Janela / agendamento
// ─────────────────────────────────────────────────────────────────────────

/// `window.requestAnimationFrame` com callback Dart
/// (substitui `window.requestAnimationFrame((_) => ...)`).
int raf(void Function(num highResTime) callback) =>
    window.requestAnimationFrame(((double t) => callback(t)).toJS);

// ─────────────────────────────────────────────────────────────────────────
// Blob / arquivos / dados
// ─────────────────────────────────────────────────────────────────────────

Blob blobFromBytes(Uint8List bytes, {String type = ''}) => Blob(
      <JSAny>[bytes.toJS].toJS,
      BlobPropertyBag(type: type),
    );

/// Resultado de um [FileReader] como bytes (após readAsArrayBuffer).
Uint8List? readerResultAsBytes(FileReader reader) {
  final JSAny? result = reader.result;
  if (result == null || !result.isA<JSArrayBuffer>()) return null;
  return (result as JSArrayBuffer).toDart.asUint8List();
}

/// Resultado de um [FileReader] como String (após readAsDataURL/readAsText).
String? readerResultAsString(FileReader reader) {
  final JSAny? result = reader.result;
  if (result == null || !result.isA<JSString>()) return null;
  return (result as JSString).toDart;
}

/// Leitura segura de `data-*` (evita `undefined` atravessando como String
/// pelo operator[] do DOMStringMap).
String? dataAttr(Element element, String name) {
  final String kebab = name.replaceAllMapped(
      RegExp('[A-Z]'), (Match m) => '-${m[0]!.toLowerCase()}');
  return element.getAttribute('data-$kebab');
}

/// LEITURA de `data-*` sempre por aqui: o `dataset['x']` do package:web
/// declara String não-nulo e deixa `undefined` estourar no cast do dart2js
/// quando o atributo falta. Escrita via `dataset['x'] = v` continua ok.
extension ElementDataAttr on Element {
  String? data(String name) => dataAttr(this, name);
}
