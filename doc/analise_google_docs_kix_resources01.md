# Análise de engenharia reversa — `resources/01` (Google Docs / "Kix")

> **O que é `resources/01`:** uma captura completa ("Salvar página como → Página da Web completa")
> de um documento aberto no **Google Docs**, build `pt_BR` / `docs_2026`. São ~36 MB, 228 arquivos.
> O objetivo desta análise é entender **como o editor real funciona por dentro** — em especial o
> **modelo de renderização em canvas** e a **paginação sob demanda / estimada** — para embasar as
> decisões de arquitetura e performance do nosso port em Dart (`canvas-editor-port`).
>
> Documento gerado a partir de investigação direta do código minificado, do CSS (`KixCss`) e do
> HTML-shell (`edit.html`). Cada afirmação abaixo cita a evidência exata em que se baseia. Quando algo
> é **inferência de arquitetura** (e não string literal encontrada), isso está marcado como tal.

---

## 0. Sumário executivo (TL;DR)

O Google Docs (codinome interno **"Kix"**) **não renderiza texto em HTML/DOM**. Ele:

1. Monta um **shell de aplicação** em HTML (barra de ferramentas, menus, réguas) com um contêiner
   **vazio** `<div class="kix-appview-editor">`.
2. Em runtime, o JavaScript constrói uma **árvore de "views" em DOM apenas para geometria e
   interação** (páginas, seções, cabeçalho/rodapé, tabelas…) — **sem texto dentro**.
3. Sobre cada página, desenha um **`<canvas>` por página** (`kix-canvas-tile-content`,
   `pointer-events:none`) onde o texto, réguas de layout e gráficos são **pintados com a API 2D**
   (`fillText`, `measureText`, `drawImage`).
4. A digitação entra por um **elemento de entrada escondido** (`docs-texteventtarget…`), o cursor e a
   seleção são desenhados como **overlays de DOM** (`kix-current-user-cursor-caret`, `kix-selection`),
   e o **hit-testing do mouse é feito em JS contra o modelo**, não pelo browser.
5. O documento é dividido em **setores** (`kix-sector-view`). Só os setores/páginas **próximos da
   viewport** têm seus tiles de canvas efetivamente **pintados** — detectados por
   **`IntersectionObserver`** e pintados **fatiado em `requestAnimationFrame`**. É isto que o usuário
   chamou de "paginação sob demanda / estimada".

Os nomes de CSS/DOM confirmam integralmente essa arquitetura: `kix-appview-editor`,
`kix-canvas-tile-content`, `kix-sector-view`, `kix-page-paginated`, `kix-stacked-tile-page-shadow`,
`canvas-first-page`.

---

## 1. Estrutura do pacote capturado

| Item | Valor |
|---|---|
| Tamanho total | ~36 MB, 228 arquivos (216 extraídos — ver §1.1) |
| Origem | `docs.google.com/document/d/1bKI5PHXZzDyJd94nsbNSdSo9ewzrS1Cv4cVDnRS33vw` |
| Locale / build | `pt_BR`, `kdocs.client_js_prod_integrated…es5.O`, `docs_2026` |
| HTML-shell | `document/d/…/edit.html` — **6,6 MB** |
| CSS do editor | `static/document/client/css/1976262941-v3-KixCss_ltr.css` — **3,9 MB** |

### 1.1. Sobre o `.zip` e os 12 arquivos que não extraíram

O `resources/01.zip` tem **228 arquivos**; foram extraídos **216**. Os **12 que faltam falharam por
caminho longo demais** no Windows (limite de ~260 caracteres). Verifiquei um por um: **todos são
irrelevantes** para o editor — são bundles de dois widgets da barra de conta do Google:

- **`SocialPeopleHovercardUi`** (cartão de contato que aparece ao passar o mouse sobre um colaborador);
- **`OneGoogleWidgetUi` / `accountmenuview`** (o menu da conta no canto superior direito).

Nenhum arquivo do editor foi perdido. Todos os artefatos que importam — `edit.html`, `KixCss`,
`mkix_core`, `mkix_app`, `mkix_tertiary` — extraíram normalmente. **Não é preciso reprocessar o zip.**

### 1.2. Bundles JavaScript (code-splitting do Kix)

Todos em `_/docs/_/js/kdocs.client_js_prod_integrated.pt_BR…/` (extensão `.html` é só como o
"salvar página" nomeou; o conteúdo é JS minificado ES5, uma única linha gigante):

| Bundle | Tamanho | Papel (inferido pelo conteúdo) |
|---|---|---|
| `mkix_tertiary` | **7,6 MB** | Menus, diálogos, features "terciárias" (add-ons, smart canvas, exportação…) |
| `mkix_core` | **3,5 MB** | **Núcleo:** modelo do documento, layout, motor de renderização em canvas, seleção |
| `mkix_app` | **3,2 MB** | Camada de aplicação: paginação, integração de UI, réguas, modos página/sem-página |
| `mkix_docos` | **1,35 MB** | Comentários ("docos") |
| `mkix_nestedsketchycore` | 357 KB | Desenho/objetos (sketchy) |
| `mkix_pre_tertiary_deps` | 105 KB | Dependências pré-terciárias |
| `mkix_companion`, `mkix_explore`, `mkix_add_ons`, `mkix_approvals`, `mkix_meet`, `mkix_voice`… | pequenos | Features laterais |

O código está minificado com **símbolos remapeados** (`_.AFb`, `WOb`, `pRe`, `this.vu`…), mas
**strings literais e nomes de classe CSS são preservados** — é por isso que a análise abaixo se apoia
neles.

---

## 2. O shell HTML: por que o corpo do documento está vazio

Em `edit.html`, a região do editor é literalmente:

```html
<div class="kix-appview-editor-container">
  <div class="kix-appview-editor"></div>   <!-- VAZIO -->
</div>
<div id="kix-vertical-ruler-container">…</div>
…
<div id="docs-texteventtargetbrailleoffsetcalculator"></div>
```

Fatos verificados no `edit.html`:

- **`<canvas>` no HTML salvo: 0 ocorrências.**
- **`kix-page` no HTML salvo: 0 ocorrências.**
- O `kix-appview-editor` está **vazio**.

**Conclusão:** o corpo do documento (páginas, texto, canvas) **não existe no HTML** — é **inteiramente
construído por JavaScript em runtime**. Por isso "Salvar página como" captura o cromo do app mas
**não captura o documento**: os `<canvas>` são criados e pintados depois, e o "save" tira o snapshot do
HTML inicial. O que sobrou de "kix-*" no `edit.html` são só referências em configuração/CSS, quase
todas com contagem 1.

O elemento `docs-texteventtargetbrailleoffsetcalculator` já denuncia o modelo de entrada: **um alvo de
teclado escondido** (inclusive com suporte a **braille**), típico de editores que renderizam em canvas
e não usam `contenteditable`.

---

## 3. Renderização: canvas por página, não DOM de texto

### 3.1. Evidência de que o texto é pintado em `<canvas>`

No `mkix_core`:

```js
_.Qba="2d";
_.AFb=function(a){return a.getContext(_.Qba)};   // getContext("2d")
```

APIs de canvas 2D em uso (contagem em `mkix_core` + `mkix_app`):

| API | Ocorrências | Uso |
|---|---|---|
| `measureText` | 5 | Medição de largura/altura de glifos |
| `fillText` | 2 | Pintura de texto |
| `drawImage` | 13 | Imagens, tiles, sprites |
| `createLinearGradient` | 1 | Gradientes |
| `devicePixelRatio` | 9 | Escalonamento **HiDPI/Retina** do canvas |

Medição de métricas de fonte com precisão de glifo (não só largura):

```js
this.W = createImageBitmap && this.H.measureText("a").actualBoundingBoxAscent != null;
…
a.H.font = k.zR.font;
var q = a.H.measureText(k.zR.text);
k.Fyb = Math.ceil(q.actualBoundingBox…);   // altura real do glifo (ascent/descent)
```

Ou seja, o Kix usa `actualBoundingBoxAscent/Descent` do `measureText` para obter **métricas reais de
tipografia** — e faz *feature detection* disso.

### 3.2. O tile de canvas é um overlay não-interativo

No `KixCss`:

```css
.kix-canvas-tile-content { position: absolute; pointer-events: none; left: 0; top: 0; }
```

**`pointer-events:none`** é a chave: o canvas **não recebe cliques**. Ele é uma **camada de pintura**
sobreposta à página; os eventos de mouse atravessam para o DOM/alvo de entrada por baixo, e o
**hit-testing (posição do clique → offset no texto) é resolvido em JavaScript contra o modelo**.

### 3.3. É o renderizador NOVO (canvas), não o antigo (DOM)

O Kix clássico (pré-2021) renderizava texto em DOM, com classes como `kix-lineview`,
`kix-wordhtmlgenerator-word-node`, `kix-paragraphrenderer`. Procurei todas: **0 ocorrências** nos
bundles. Já `kix-canvas-tile-content` **existe**. Isso confirma que esta captura é do **renderizador
baseado em canvas** (tile por página).

---

## 4. A árvore de "views" em DOM (geometria + interação)

Sob o canvas existe uma árvore de DOM que **não contém texto** — serve para posicionamento, rolagem,
regiões clicáveis e overlays. Foram extraídas **237 classes `kix-*` distintas** do `mkix_core`. As
estruturais:

```
kix-appview
└─ kix-appview-editor            (viewport de rolagem — overflow-y:auto)
   └─ kix-scroll-view
      └─ kix-sector-view         ← documento fatiado em SETORES (virtualização)
         └─ kix-page  /  kix-page-background     (uma "folha")
            └─ kix-canvas-tile-content            (o <canvas> pintado, pointer-events:none)
```

Views de conteúdo estrutural (todas em DOM, só geometria):
`kix-body-view`, `kix-header-footer-view`, `kix-footnote-view`, `kix-table-view`, `kix-cell-view`,
`kix-column`, `kix-autogen-region-view`, `kix-block-field-view`.

Scroller: `kix-domviewscroller-inner`, `kix-domviewscroller-fade`.

Overlays desenhados **acima** do canvas (em DOM, para poder animar/piscar sem repintar o canvas):
`kix-selection`, `kix-current-user-cursor-caret`, e a família `kix-overlay-range-*`
(`kix-overlay-range-table`, `-cell`, `-block-field`, `-ai-field`, `-autogen-region`).

Geometria de página confirmada no `KixCss`:

```css
.kix-page          { cursor: text; overflow: hidden; position: relative; white-space: normal; }
.kix-page-paginated{ margin: 0; margin-bottom: 3pt; box-shadow: none !important; }
.kix-page-paginated-box-shadow { box-shadow: 0 1px 3px 1px rgba(…,.15); }
.kix-stacked-tile-page-shadow  { position: absolute; width:100%; height:100%; box-shadow: … }
.kix-page-canvas-compact-mode  { border-top: 1px dotted var(--gm3-sys-color-outline-variant); }
.kix-page-canvas-compact-mode.canvas-first-page { border-top: none; }
.canvas-first-page { border-top: none; }
.canvas-left-border / .canvas-right-border { box-shadow: ±1px 0 0 0 …; }  /* bordas da folha */
```

O termo **"stacked tile"** (`kix-stacked-tile-page-shadow`) confirma o modelo de **tiles empilhados**:
uma pilha de folhas, cada uma com seu tile de canvas absoluto por cima.

---

## 5. Paginação sob demanda / "estimada" — o ponto central

Não existe uma string literal `"estimate"` para paginação (o único `estimat` no código é
`navigator.storage.estimate`, sobre cota de disco — irrelevante). O mecanismo real, evidenciado, é a
combinação **setor + observador de interseção + pintura fatiada em rAF**:

### 5.1. Setores (virtualização do documento)

`kix-sector-view` divide o documento em **setores**. Um documento de 150 páginas não é um único bloco:
é uma sequência de setores, e a árvore de views só materializa/pinta o que é necessário perto da tela.

### 5.2. Detecção de visibilidade por viewport

`IntersectionObserver` aparece **19×** nos bundles. Trecho do `mkix_core`:

```js
this.H = new IntersectionObserver(function(g){ … });
```

É assim que o Kix sabe **quais páginas/setores entraram na viewport** para então agendar a pintura dos
tiles — em vez de pintar as 150 folhas de uma vez.

### 5.3. Pintura fatiada em frames

`requestAnimationFrame` aparece **37×**. A pintura dos tiles é **distribuída ao longo de vários
frames** (rAF), de modo que a rolagem não trava enquanto muitos tiles precisam ser desenhados.

### 5.4. O laço que monta as folhas paginadas

Trecho do `mkix_core` (o loop sobre a lista de folhas `this.vu`):

```js
// para cada folha c da lista this.vu:
_.cI(c.Ea(), "kix-page-paginated");            // marca como página paginada
_.fI(c.Ea(), Era, a === 0);                    // Era = "canvas-first-page" só na 1ª folha
pRe(c, this.H);                                // pRe: alterna "kix-page-canvas-compact-mode"
```

`this.vu` é o **array de folhas (tiles)**; cada uma tem um elemento DOM (`.Ea()`) que recebe as classes
`kix-page-paginated` / `canvas-first-page` / `kix-page-canvas-compact-mode`.

### 5.5. O que é "estimada"

> **Inferência de arquitetura** (coerente com as evidências acima e com o comportamento observável do
> produto): o Kix calcula o **layout/quebra de páginas** de todo o documento — por isso a **contagem de
> páginas e a altura total são exatas** (a barra de rolagem não "pula"). Porém a **pintura** de cada
> tile é **preguiçosa**: páginas longe da viewport ficam como caixas `kix-page-background` de **altura
> já conhecida**, e só ganham o desenho do canvas quando o `IntersectionObserver` avisa que se
> aproximaram. "Estimada" aqui = **a geometria/altura é reservada antecipadamente** (para o scroll ser
> estável) enquanto **o conteúdo pintado é adiado** ("sob demanda").

`kix-splash-screen-page` e `kix-default-page` reforçam que existe um estado de **página-placeholder**
antes do conteúdo real ser pintado.

### 5.6. Modo Paginado × Sem-página (Pageless)

O Kix tem os dois modos, e a paginação é opcional:

- `kix-toggle-paginated-view` / `kix-toggle-pageless-format`
- `kix-pageless-text-width-narrow | medium | wide | full`
- `kix-page-paginated`, `kix-paginated-features-hidden-dialog`, `kix-pageless-features-hidden-dialog`

No modo *pageless* não há folhas; o texto flui em largura contínua (daí `text-width-*`).

---

## 6. Entrada, cursor e seleção

- **Entrada de teclado/IME/braille:** o elemento escondido `docs-texteventtarget…` (visto no
  `edit.html`) captura as teclas. Como o canvas é `pointer-events:none`, **nada é `contenteditable`**.
- **Cursor:** `kix-current-user-cursor-caret` — um elemento DOM que pisca por cima do canvas (não
  precisa repintar o tile a cada piscada).
- **Seleção:** `kix-selection` + `kix-overlay-range-*` — retângulos de seleção desenhados como overlay.
- **Hit-testing:** clique → JS converte coordenada em offset no modelo (o canvas não ajuda, pois é
  inerte). Isso exige que o layout mantenha, por página, as caixas de cada linha/glifo — caro, e é onde
  entra o cache (veja §8).

---

## 7. Outros achados de arquitetura

- **Web Workers:** `postMessage`/`Worker` aparecem 28× (core), 28× (app), 44× (tertiary) — trabalho
  pesado (ex.: verificação ortográfica, sincronização, sugestões) é **offloaded** para workers.
- **HiDPI:** `devicePixelRatio` (9×) — o canvas é escalado pela densidade da tela para texto nítido.
- **Design system GM3:** o CSS usa tokens `--gm3-sys-color-*` (Material 3).
- **Fontes:** o pacote traz dezenas de `.woff2` (Roboto, Google Sans, EB Garamond, Lora, Merriweather,
  Montserrat, etc.) e `document/font/getmetadata` — o Kix busca **metadados de fonte** do servidor
  para layout consistente independentemente das fontes locais.
- **237 classes `kix-*`** cobrindo: bubbles/popovers contextuais (`kix-bubble-*`), smart canvas,
  chapters, cover image, spellcheck, citações, etc.

---

## 8. Comparação com o nosso port (`canvas-editor-port`) e recomendações

Nosso editor é um port do **canvas-editor** (JS) para Dart, também baseado em canvas. Os aprendizados do
Kix validam a direção das otimizações recentes (ver commits `perf(scroll)`, `perf(typing)`) e apontam o
próximo patamar.

| Aspecto | Google Docs (Kix) | Nosso port (hoje) | Recomendação |
|---|---|---|---|
| Superfície de pintura | **1 canvas/tile por página**, absoluto, `pointer-events:none` | canvas por página (draw.dart) | Manter; garantir tile por página desacoplado da geometria |
| Virtualização | **`kix-sector-view` + `IntersectionObserver`**: só pinta perto da viewport | "desenho fatiado em rAF" + "paginação sob demanda/estimada" (já iniciado) | **Adotar detecção de viewport explícita** para decidir *quais* páginas pintar, não só *quando* |
| Altura das páginas | **Layout total calculado ⇒ altura exata**; pintura adiada | cache de posições por página (commit recente) | Reservar altura de todas as páginas cedo (scroll estável), pintar só as visíveis |
| Agendamento | **`requestAnimationFrame` fatiado** | rAF fatiado (implementado) | ✔️ alinhado; medir orçamento por frame (~8–12 ms) |
| Métricas de fonte | `measureText().actualBoundingBoxAscent/Descent` | verificar uso atual | Usar `actualBoundingBox*` p/ ascent/descent reais (melhora fidelidade de linha) |
| Cursor/seleção | **overlay** separado (não repinta o tile) | verificar | Desenhar caret/seleção em camada própria — piscar sem repintar a página |
| HiDPI | `devicePixelRatio` no canvas | verificar | Escalar backing store por DPR |
| Entrada | alvo escondido, sem `contenteditable`; hit-test em JS | — | Manter modelo próprio de hit-testing por página |
| Trabalho pesado | Web Workers | — | Considerar isolates/worker p/ layout de documentos grandes |

**Princípio central a levar do Kix:** *separe **geometria** (barata, calculada para o documento inteiro
para dar altura/quebra exatas) de **pintura** (cara, feita só para o que está na viewport, fatiada em
rAF).* É exatamente a ideia de "paginação sob demanda / estimada" — e é o que sustenta 150+ páginas sem
travar.

---

## 8.1. Onde roda o layout/paginação: main thread × workers (Kix × EuroOffice/OnlyOffice)

Pergunta frequente: *o cálculo de layout e paginação acontece em Web Workers ou na main thread?* A
resposta, com evidência dos dois lados, é: **nos dois, o layout/paginação interativo roda na MAIN
THREAD do browser.** Nenhum dos dois faz *offload* do reflow para Web Worker.

### Google Docs (Kix) — evidência

- **`new Worker(` = 0** em todos os bundles (`mkix_core/app/tertiary`). Não existe *nenhum* Web Worker
  dedicado — muito menos de layout.
- Os únicos workers são:
  - **`SharedWorker` → `eventbusworker.js`** — barramento de eventos para **colaboração em tempo real /
    comunicação entre abas** (roteamento de mensagens), não layout.
  - **`ServiceWorker`** — cache **offline** (`docs_offline_iframe_api`).
- O `postMessage` carrega mensagens de **colaboração/offline** ("Pouco espaço em disco", status
  on-line), não dados de layout.
- `measureText`/`getContext("2d")` e o loop de folhas (`this.vu`) estão em `mkix_core`, que roda na
  main thread. `OffscreenCanvas` (3×) é usado como **superfície de medição/pintura** (também válida na
  main thread), com *feature detection* — não como prova de worker de layout.
- **Conclusão:** layout e paginação = **main thread**, com anti-jank via virtualização por setor +
  `IntersectionObserver` + pintura fatiada em `requestAnimationFrame`.

### EuroOffice / OnlyOffice DocumentServer (`sdkjs`) — evidência

Inspeção de `build-native/out/sdkjs/word/sdk-all.js` (19,5 MB, **não minificado**):

- O motor de layout/paginação é a família **`prototype.Recalculate*`** — **métodos síncronos no modelo
  do documento** (`Recalculate`, `RecalculateAll`, `RecalculateAllAtOnce`, `RecalculateContent`,
  `RecalculatePageCountUpdate`, `RecalculateFromStart`, `RecalculateCurPos`…). Recalculação
  **incremental** guiada por *dirty flags* (`RecalcInfo`, `CheckNeedRecalculate`, `IsNeedRecalculate`,
  `Is_OnRecalculate`). Tudo **main thread**.
- **`new Worker(` = 1** — e **não é layout**: carrega `common/hash/hash/engine.js` (wasm), o **motor de
  hash/assinatura de mudanças** para co-edição. `OffscreenCanvas` = 0. `postMessage` = 15 (worker de
  hash + comunicação com o iframe da API host).
- A verificação ortográfica tem motor próprio (`common/spell/spell/spell.js`), separada do layout.
- **Diferença arquitetural importante:** além do editor no browser, o EuroOffice/OnlyOffice tem um
  **núcleo nativo em C++** (`build-native/core-x2t/x2t.exe`) e o `sdkjs` hospedado em **V8**, com
  **HarfBuzz** (shaping), **ICU**, **Hunspell**, **Hyphen**. Esse núcleo roda o **mesmo tipo de layout
  headless num PROCESSO nativo separado** (no servidor) para **conversão de arquivos (docx↔pdf) e
  render**. Isso é **paralelismo de processo** (outro processo do SO), **não** thread/worker do browser.

### Resumo comparativo

| | Layout/paginação interativo | Workers do browser | Motor extra fora da aba |
|---|---|---|---|
| **Google Docs (Kix)** | **Main thread** (setores + IntersectionObserver + rAF) | SharedWorker (colab) + ServiceWorker (offline). **0** worker de layout | Layout server-side proprietário (não visível na captura) |
| **EuroOffice/OnlyOffice** | **Main thread** (`Recalculate*` incremental) | **1** worker = hash/crypto (co-edição). **0** worker de layout | **Processo nativo C++/V8** (`x2t.exe`, HarfBuzz/ICU) p/ conversão e PDF |
| **Nosso port (Dart→Web)** | Main thread (canvas) | — | — (considerar **isolate** p/ layout de docs grandes) |

**Implicação para o nosso port:** seguir o layout na main thread é o padrão da indústria e está OK —
desde que se copie o anti-jank (virtualização por viewport + pintura fatiada em rAF + recálculo
incremental por *dirty flags*, como o `RecalcInfo` do OnlyOffice). Se algum dia o layout de documentos
muito grandes ainda travar, o caminho não é "worker de layout" (nem Kix nem OnlyOffice fazem isso no
browser), e sim **isolate/worker para tarefas auxiliares** (ex.: parsing de DOCX, hash, ortografia) ou
um **processo/serviço nativo** para conversão — como o `x2t` do OnlyOffice.

---

## 9. Como reproduzir a investigação

Os comandos abaixo (Git Bash, dentro de `resources/01`) reproduzem as principais evidências:

```bash
export LC_ALL=C
D='docs.google.com/_/docs/_/js/kdocs.client_js_prod_integrated.pt_BR.2kQYI1l44bc.es5.O/amQAACHAAw/d0/wt0/rsAGWKN8mF_GmiOHF_8NLhP79qAmIseU1LDA'
CSS='docs.google.com/static/document/client/css/1976262941-v3-KixCss_ltr.css'
EDIT='docs.google.com/document/d/1bKI5PHXZzDyJd94nsbNSdSo9ewzrS1Cv4cVDnRS33vw/edit.html'

# 1) shell vazio + sem canvas no HTML salvo
grep -c '<canvas' "$EDIT"; grep -c 'kix-page' "$EDIT"
grep -oE 'kix-appview-editor[^>]*>.{0,80}' "$EDIT"

# 2) vocabulário DOM do renderizador canvas
grep -oE '="kix-[a-z0-9-]+"' "$D/mkix_core.html" | sed 's/="//;s/"//' | sort -u | grep -E 'tile|sector|page|view|selection|caret'

# 3) APIs de canvas + métricas
grep -oE '.{40}measureText.{40}' "$D/mkix_core.html"
grep -oE 'getContext\([^)]*\)' "$D/mkix_core.html"

# 4) on-demand: IntersectionObserver + rAF
grep -oE 'new IntersectionObserver' "$D/mkix_core.html" | wc -l
grep -oE 'requestAnimationFrame' "$D/mkix_core.html" "$D/mkix_app.html" | wc -l

# 5) CSS do tile
grep -oE '\.kix-canvas-tile-content[^{]*\{[^}]*\}' "$CSS"
```

---

## 10. Ressalvas de honestidade

- O código é **minificado e com símbolos remapeados**; nomes de método reais são desconhecidos. As
  conclusões se apoiam em **strings preservadas** (classes CSS, constantes) e no **CSS**, que são
  confiáveis, mais **inferência de arquitetura** onde indicado (§5.5).
- Esta é uma **captura estática** de uma sessão; não observei o runtime pintando. As afirmações sobre
  *quando* cada tile é pintado são deduzidas de `IntersectionObserver` + `rAF` + `sector-view`, não de
  um trace de execução.
- Números de ocorrência (`measureText`=5, `IntersectionObserver`=19, etc.) refletem **este** conjunto de
  bundles nesta versão (`docs_2026`, build `2kQYI1l44bc`); outra versão pode diferir.
```

*(Investigação e relatório: análise direta de `resources/01`, 2026-07-09.)*

Resposta: nos dois, o layout/paginação roda na main thread — nenhum deles faz layout em Web Worker
Verifiquei no código real dos dois lados (não de memória).

Google Docs (resources/01, Kix)
new Worker( = 0 em todos os bundles. Não existe nenhum Web Worker dedicado — muito menos de layout.
Os únicos workers são:
SharedWorker → eventbusworker.js = barramento de eventos de colaboração em tempo real / entre abas;
ServiceWorker = offline.
O layout (measureText, loop de folhas this.vu) está no mkix_core, que roda na main thread. O anti-travamento vem de setores + IntersectionObserver + pintura fatiada em requestAnimationFrame, não de threads.
EuroOffice / OnlyOffice DocumentServer (sdkjs/word/sdk-all.js, não-minificado)
Layout/paginação = família prototype.Recalculate* (27× Recalculate + RecalculateAll, RecalculatePageCountUpdate, RecalculateFromStart…) — métodos síncronos no modelo, main thread, com recálculo incremental por dirty flags (RecalcInfo, CheckNeedRecalculate).
new Worker( = 1 — e não é layout: carrega common/hash/hash/engine.js (wasm), o motor de hash/assinatura de mudanças para co-edição. OffscreenCanvas = 0.
Diferença importante: o OnlyOffice tem ainda um núcleo nativo C++ (x2t.exe) + sdkjs em V8 + HarfBuzz/ICU/Hunspell que roda o mesmo tipo de layout headless, num processo do SO separado — para conversão docx↔pdf e render no servidor. Isso é paralelismo de processo, não worker do browser.
Em uma frase
Layout interativo	Worker de layout?	Motor extra
Kix	Main thread	Não (0 workers)	Server-side proprietário
OnlyOffice	Main thread (Recalculate*)	Não (o 1 worker é hash)	Processo nativo C++/V8 p/ conversão
Para o seu port: manter o layout na main thread é o padrão da indústria — desde que copie o anti-jank (virtualização por viewport + rAF fatiado + recálculo incremental por dirty flags). Se docs enormes ainda travarem, o caminho não é "worker de layout" (nenhum dos dois faz isso), e sim isolate para tarefas auxiliares (parse de DOCX, hash, ortografia) ou um serviço nativo para conversão, como o x2t.

 Google Docs e EuroOffice/OnlyOffice fazem layout e paginação na main thread nos dois casos. Nenhum usa Web Worker para layout — os workers que existem são para colaboração/offline (Kix) e hash de co-edição (OnlyOffice). O diferencial do OnlyOffice é o motor nativo C++/V8 rodando o mesmo layout headless em outro processo, só para conversão e PDF.