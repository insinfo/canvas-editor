# Plano de migração: `dart:html` → `package:web ^1.1.1`

Data: 2026-07-27 · Status: **em execução**

## 1. Por quê

- `dart:html` está **deprecado** e não é suportado na compilação para
  **WebAssembly** (dart2wasm). `package:web` é a solução de interop de longo
  prazo do Dart, baseada em `dart:js_interop` (extension types de custo zero
  sobre os objetos JS reais, gerados do Web IDL).
- O pacote já declara `web: ^1.1.1` no pubspec; a migração remove o último
  bloqueio para Wasm e nos tira da API congelada do SDK.
- Referências: guia oficial (dart.dev/interop/js-interop/package-web),
  CHANGELOG do `web` (constructores por tag desde 0.5.1, operadores `[]` em
  1.1.0, `JSImmutableListWrapper` em 1.1.0), exemplo `url_launcher_web`.

## 2. Inventário (medido em 2026-07-27)

- **117 arquivos** com `import 'dart:html'` (91 em `lib/`, resto em
  `example/`, `example2/`, `test/`, `tool/`).
- Superfície de API usada (nº de ocorrências):
  `.classes.` 403 · `window.` 351 · `document.` 359 · `js_util` 331 ·
  `.append(` 258 · `querySelector` 189 · `DivElement(` 169 · `.onClick` 154 ·
  `MouseEvent` 143 · `context2D` 96 · `SpanElement(` 63 ·
  `getBoundingClientRect` 61 · `.dataset[` 59 · `.children.` 55 ·
  `fillStyle` 42 / `strokeStyle` 34 · `measureText` 34 · `is/as XxxElement`
  (testes de tipo) 105 · `Rectangle<num>` 27 · `requestAnimationFrame` 16 ·
  observers (Mutation/Intersection) 6 · `FileReader` 11 · `Blob(` 14 ·
  `Url.` 28.
- `js_util` concentra-se em: paste.dart (21), click.dart (19),
  global_event.dart (18), utils/index.dart (14), clipboard.dart (10),
  print.dart (8), prism.dart (7), i_frame_block.dart (6), editor.dart (6),
  canvas_editor_widget.dart (5) e no suporte E2E.

## 3. O que o `web 1.1.1` já dá de graça (verificado no pub cache)

| Precisamos de | `web 1.1.1` oferece |
|---|---|
| `DivElement()` etc. | **Construtor por tag**: `HTMLDivElement()`, `HTMLSpanElement()`, … (desde 0.5.1) |
| `el.onClick.listen` | `ElementEventGetters` (onClick, onMouseDown/Move/Up, onKeyDown/Up, onPaste, onScroll, onWheel, onDrop, onDragOver, onBlur, onFocus, onDoubleClick, …) |
| `dataset['x']` | `DOMStringMap` tem `operator []`/`[]=` (1.1.0) |
| `el.style.left = '2px'` | Propriedades CSS como getters/setters String em `CSSStyleDeclaration` |
| `canvas.context2D` | `HTMLCanvasElementGlue.context2D` |
| `.text` | `Node.text` (deprecado em 1.1.1 → usar `textContent`) |
| iteração de coleções | `JSImmutableListWrapper` (1.1.0) |
| `EventStreamProvider` | exportado; base p/ getters que faltam |

## 4. O que NÃO vem pronto (nossa camada `lib/src/dom/dom.dart`)

Biblioteca interna que **re-exporta** `package:web/web.dart` +
`dart:js_interop` e adiciona apenas o que falta (sem recriar o dart:html):

1. **Eventos em `Document`/`Window`/`FileReader`** que os helpers não têm:
   `document.onMouseMove/onMouseUp/onMouseDown/onKeyDown/onClick/
   onSelectionChange`, `window.onResize/onScroll/onMouseUp/onMouseMove`,
   `FileReader.onLoad` — via `EventStreamProviders.xxx.forTarget(this)`.
2. **Canvas**: `fillStyle`/`strokeStyle` são `JSAny` no IDL → setters
   `fillColor`/`strokeColor` (String) e `setDash(List<num>)` para
   `setLineDash(JSArray)`. Sed: `fillStyle =` → `fillColor =` etc.
3. **`children`**: no IDL é `HTMLCollection` viva (sem add/clear) → helpers
   `appendAll(Iterable<Node>)`, `clearChildren()`, `childElements`
   (`List<Element>` materializada). Sed: `.children.addAll(` →
   `.appendAll(`, `.children.clear()` → `.clearChildren()`,
   `.children.add(` → `.append(`.
4. **`requestAnimationFrame`**: exige `JSFunction` → helper top-level
   `raf(void Function(num))`. Sed: `window.requestAnimationFrame(` → `raf(`.
5. **Arquivos/Blob/URL**: `blobFromBytes(Uint8List, {String type})`,
   `filesOf(FileList?)`, leitura de `FileReader.result` (JSAny → String/
   ByteBuffer). `Url.createObjectUrl` → `URL.createObjectURL` (sed).
6. **Casts seguros**: `asHtmlElement(EventTarget?)`, `asElement(...)` — em
   extension types `is Element` é sempre-verdadeiro (erasure p/ JSObject);
   o teste correto é `.isA<HTMLElement>()`. **Todos os 105 `is/as
   XxxElement` serão auditados um a um.**
7. **`Rectangle<num>`** → `DOMRect` (mesmos getters, double) — sed + ajuste
   de `.toDouble()` redundantes.
8. **`MouseEvent.client.x`** → `clientX` (a extensão `client` existe mas está
   deprecada) — sed.

## 5. Substituição do `dart:js_util` (331 usos)

`dart:js_util` → `dart:js_interop` / `dart:js_interop_unsafe`:

| Antes | Depois |
|---|---|
| `js_util.getProperty(o, 'x')` | `o.getProperty('x'.toJS)` |
| `js_util.setProperty(o, 'x', v)` | `o.setProperty('x'.toJS, v)` |
| `js_util.callMethod(o, 'm', [a])` | `o.callMethod('m'.toJS, a)` |
| `js_util.allowInterop(f)` | `f.toJS` |
| `js_util.jsify/dartify` | `.jsify()` / `.dartify()` |
| `js_util.newObject()` | `JSObject()` |

Zonas: `dart:html` amarrava callbacks à Zone corrente; `package:web` não.
O editor não usa zone-locals em handlers → sem impacto (registrado aqui
para futura referência).

## 6. Estratégia de execução

O grafo de dependências de `lib/` é um único componente conexo que troca
tipos DOM entre camadas (Draw → widgets → shell), então **misturar os dois
mundos dentro de `lib/` deixaria o analyze vermelho nas costuras**. A
execução é:

- **Etapa A — `lib/` inteiro em um passo mecanizado** (burn-down):
  1. criar `lib/src/dom/dom.dart` (camada acima);
  2. trocar todo `import 'dart:html';` por
     `import 'package:canvas_text_editor/src/dom/dom.dart';`
  3. aplicar renomes de tipos (tabela do `renames.md` do pacote:
     `DivElement`→`HTMLDivElement`, `HtmlElement`→`HTMLElement`,
     `CssStyleDeclaration`→`CSSStyleDeclaration`, …) + seds da seção 4;
  4. construtores com parâmetros do dart:html (`InputElement(type:)`,
     `CanvasElement(width:, height:)`, `AnchorElement(href:)`,
     `OptionElement(data:, value:)`) → cascatas;
  5. `dart analyze` e corrigir por PADRÃO de erro (não por arquivo) até
     **zero**; os 105 testes de tipo são auditados aqui;
  6. `js_util` → `js_interop` nos 10 arquivos de `lib/`;
  7. dart2js do example + smoke visual (puppeteer): abrir ETP, digitar,
     rodapé, régua, tabela, imprimir. → **commit**.
- **Etapa B — `example/web/main.dart` + `tool/`** (benchs/screenshot têm
  código de browser embutido?) → migrar/ajustar → commit.
- **Etapa C — testes**: `page_canvas_manager_test` (plataforma chrome),
  `test/e2e/support` + fixture legacy → commit.
- **Etapa D — encerramento**: grep `dart:html` == 0 no pacote raiz,
  CHANGELOG, remoção de deprecations internas (`.text` → `textContent`).

**Fora do escopo**: `example2/` é AngularDart 8 (framework preso a
`dart:html`, pubspec próprio — não bloqueia o pacote raiz nem o Wasm).
Fica como está, documentado aqui.

## 7. Verificação

- `dart analyze` zero em cada etapa/commit.
- Suites VM (`test/word`, `test/document/docx`) — não tocam DOM, guardam o
  round-trip (77 testes).
- dart2js `-O2` do example a cada etapa; **smoke visual** com puppeteer nos
  fluxos: abrir DOCX, digitar (bench de tecla), régua/tab stops, tabela
  (alças + galeria), imagem (wrap/arrasto), rodapé (nº de página), zoom,
  imprimir (iframe), salvar DOCX byte-idêntico.
- Bench A/B alternado (lição registrada: a máquina deriva; comparar pares
  alternados e os contadores de layout).

## 8. Riscos e mitigação

| Risco | Mitigação |
|---|---|
| `is Element` sempre-verdadeiro em extension types | auditoria dos 105 sites → `.isA<T>()` |
| `undefined` atravessando como `String` (`dataset`, `result`) | helpers com `has`/`isA` antes de ler |
| Callbacks JS sem conversão (`A value of type ... JSFunction?`) | erro de compilação — burn-down cobre |
| Eventos que os helpers não cobrem | extensões próprias via `EventStreamProviders` |
| Regressão visual sutil (canvas) | smoke puppeteer + goldens de screenshot existentes |
| Perf (interop zero-cost, mas conversões `.toJS` em loop) | manter conversões fora dos loops quentes; bench A/B |

## 9. Rollback

Tag `backup/pre-web-migration` criada antes da Etapa A. Cada etapa é um
commit isolado na main; reverter = `git revert` do intervalo.
