# Análise de performance dos 4 editores de referência — insights para o port

Data: 2026-07-13. Consolida a engenharia reversa de **Google Docs (Kix)**, **Word
Online (WordEditorDS)** e **OnlyOffice/EuroOffice DocumentServer**, cruzando com o
estado atual do nosso port em Dart+canvas, para extrair um roteiro de otimização
priorizado. Complementa (não substitui):

- [analise_google_docs_kix_resources01.md](analise_google_docs_kix_resources01.md) — Kix a fundo (`resources/01`).
- [plano_arquitetura_performance_onlyoffice.md](plano_arquitetura_performance_onlyoffice.md) — OnlyOffice `sdkjs/word`.
- [plano_otimizacao_performance.md](plano_otimizacao_performance.md) — nosso plano de perf.

Fontes desta rodada: `resources/01` (Kix), `resources/word.example` (Word Online,
`word.cloud.microsoft`), `D:\EuroOfficeNative\DocumentServer` (OnlyOffice — AGPL, só
referência conceitual).

---

## 0. TL;DR — as 3 grandes escolhas de arquitetura

| | Superfície de texto | Seleção/caret | Medição | Proofing/word-count |
|---|---|---|---|---|
| **Google Docs (Kix)** | **canvas** (`fillText` por página) | overlay DOM (`kix-selection`) | canvas (`measureText`) | Web Workers |
| **Word Online** | **DOM/HTML** (`.TextRun`, contentEditable) | **nativa do browser** | canvas oculto (`measureText().width`, `GlyphCache`) | **AugLoop** (worker dedicado) |
| **OnlyOffice** | **canvas** (mesmo motor C++ compilado p/ JS) | overlay próprio | HarfBuzz/métricas próprias | worker de hash; spell próprio |
| **Nosso port** | **canvas** (como Kix/OnlyOffice) | overlay/canvas | canvas + TTF (`ce_fonts`) | main thread (fake worker) |

**Achado central:** existem **dois paradigmas opostos** e ambos funcionam:
1. **Canvas-first** (Kix, OnlyOffice, nós): controle total, mas *tudo* — pintura,
   medição, seleção, hit-test — é responsabilidade nossa; performance exige
   virtualização agressiva + invalidação incremental.
2. **DOM-first** (Word Online): delega pintura de texto, seleção nativa, caret e
   quebra de linha ao browser; o canvas só mede. Mais leve para o desenvolvedor,
   menos controle de fidelidade pixel-perfeita.

Escolhemos canvas-first (a decisão certa para fidelidade DOCX/PDF). Então os insights
úteis vêm de **como Kix e OnlyOffice sustentam 150+ páginas em canvas** — e de um
truque de medição que o Word valida.

**Consenso dos 3 (crítico):** **layout/paginação roda na MAIN THREAD** nos três. Nenhum
usa Web Worker para layout. O anti-jank vem de virtualização + fatiamento + invalidação
incremental, não de threads. Isso já está documentado e é o caminho que seguimos.

---

## 1. O que cada um faz que nós (ainda) não fazemos

### 1.1 Word Online — cache de métricas de glifo (`GlyphCache`)
- Evidência: `GlyphCache`=11, `FontMetrics`=1; um canvas oculto reutilizado para
  `measureText(x).width` com cache. `fillText`=0 (texto é DOM).
- **Nós:** já temos `TextParticle.cacheMeasureText` (por `texto+fonte`) e o `ce_fonts`
  (métrica TTF determinística). ✅ em paridade. **Ação:** confirmar que o cache não é
  invalidado por engano em cada render (medir hit-rate) e que o `_scaleWidthCache` do
  batch não recomeça a cada tecla.

### 1.2 Word Online — faixa de páginas ativa com fidelidade variável
- Evidência: `ViewportActivePageRangeAdjustmentCalculator`, `VirtualizationWindow`,
  `FidelityView` × `FullDocumentRendering`, `isAllContentInViewportRendered`,
  `ViewportAprDirtyState`. IntersectionObserver só 2× (o Word calcula a faixa, não
  observa interseção).
- **Nós:** temos lazy canvas por `IntersectionObserver` (só páginas visíveis vivas) +
  layout progressivo fatiado. ✅ conceito adotado. **Falta:** o nível de *fidelidade
  variável* — páginas distantes poderiam ser desenhadas em resolução menor ou como
  placeholder cinza (já temos placeholder dormente; falta o "low-fidelity paint").

### 1.3 OnlyOffice — invalidação incremental guiada por changes (`Get_RecalcData`)
- Evidência: `IClientPaginationLayoutInvalidator` (Word), `RecalcInfo`/`Get_RecalcData`/
  `CheckNeedRecalculate` (OnlyOffice). O recálculo deriva do histórico QUAIS parágrafos
  mudaram e recomputa só o mínimo (fast run-range → fast paragraph → regular).
- **Nós:** temos o fast path de parágrafo (`_tryFastParagraphLayout`) e a repintura
  dirigida por página, mas o escopo ainda é decidido por **flags ad-hoc por comando**,
  não por um `RecalcData` derivado das mutações. **Este é o maior salto pendente**
  (§6.1 do plano_expansao) — ver §3.

### 1.4 Word Online — proofing/word-count fora do thread de edição (AugLoop)
- Evidência: bundle `wordeditords.augloop.js` dedicado, `Worker`=68 refs,
  `Annotation`=212; erros de ortografia são **decorações CSS no DOM**
  (`.SpellingErrorV2`), não repintura.
- **Nós:** o `WorkerManager` é FAKE (`Future(cb)` na main thread) e a contagem de
  palavras é O(doc) na main thread (agora **desligável** por
  `CanvasEditorConfig.showWordCount=false`). **Ação:** mover word-count/catalog para
  isolate real (§6.3).

### 1.5 Kix — separar geometria (barata, do doc inteiro) de pintura (cara, só viewport)
- Já é o nosso princípio (altura total estimada + pintura fatiada). ✅

---

## 2. O que já copiamos e está validado pelos 3

| Técnica | Kix | Word | OnlyOffice | Nós |
|---|---|---|---|---|
| Layout na main thread | ✅ | ✅ | ✅ | ✅ |
| Virtualização por viewport | setores+IO | active page range | página recalculada | lazy canvas + IO |
| Pintura fatiada (rAF/timer) | rAF 37× | rAF 23 + rIC 11 | timer loop | rAF + Timer progressivo |
| Cache de medição de texto | ✅ | GlyphCache | HarfBuzz | cacheMeasureText + TTF |
| Recálculo incremental | — | dirty state | Get_RecalcData | fast path parcial |
| Caret/seleção sem repintar tile | overlay | nativo | overlay | **verificar** |

---

## 3. Roteiro priorizado de performance (para o nosso port)

Ordenado por **impacto na queixa real** (digitar/selecionar/negritar num doc de 140
páginas) × custo:

1. **[feito nesta rodada] Throttle da seleção por arrasto a 1 render/frame (rAF).**
   O `mousemove` disparava `render()` a cada pixel; agora coalesce por frame. É a
   causa direta do "selecionar é lento". (Word delega isso ao browser; nós coalescemos.)

2. **[feito] Contagem de palavras desligável** (`showWordCount=false`) — remove um
   O(doc) por mudança. Próximo: movê-la para isolate (item 6).

3. **Recálculo guiado por changes (§6.1) — o maior salto restante.** Migrar o histórico
   para deltas com `affectedRange`/`needsLayout`/`needsRepaintOnly` e o `render()`
   decidir o escopo a partir das mutações (como `Get_RecalcData`/`ClientPaginationLayout
   Invalidator`). Distinguir **relayout × repaint**: negrito/itálico mudam métrica
   (relayout do parágrafo), mas cor/sublinhado/realce são **repaint-only** — hoje alguns
   ainda relayoutam. Isso ataca "negritar é lento".

4. **Fidelidade variável de página distante (Word `FidelityView`).** Páginas muito longe
   do viewport: placeholder cinza com altura conhecida (já temos o canvas dormente;
   falta suprimir o *paint* completo quando > N telas de distância).

5. **Cache de métrica: medir hit-rate e evitar reset por render.** Confirmar que
   `cacheMeasureText`/`_scaleWidthCache` sobrevivem entre teclas (o Word nunca re-mede o
   mesmo glifo).

6. **Isolate real para tarefas auxiliares (§6.3):** word-count, catálogo, e o parse
   SAX do DOCX na abertura (ainda bloqueia ~1,6s no TR). Padrão dos 3: worker só para o
   que NÃO toca o layout.

7. **Modularizar `draw.dart` (§6.2)** para o recálculo por changes ser implementável sem
   risco: DocumentModel / LayoutEngine (cursor de continuação como serviço) /
   PageRenderer (fila de páginas sujas) / Viewport.

---

## 4. O caminho que os 3 NÃO tomam (evitar)

- **Worker de layout no browser:** nenhum dos 3 faz. O layout toca o modelo a cada
  edição; serializar para worker ida/volta custaria mais que o ganho. (OnlyOffice tem
  layout headless em processo C++ nativo, mas isso é para conversão server-side, não
  edição interativa.)
- **Re-medir glifos a cada render:** todos cacheiam.
- **Repintar o documento inteiro por edição:** todos invalidam incrementalmente.

---

## 5. Metodologia de medição (para continuar)

O que funcionou nesta rodada para achar gargalos e divergências de fidelidade:
- **Instrumentação por fase** (`Draw.debugRenderTiming`): `[input] pre/render/total`,
  `[render] computeRowList/PageList/PositionList/tail/draw/post`.
- **Bench honesto em release** (`tool/bench/typing_bench.dart`) — DDC mascara tudo.
- **Fidelidade página a página:** `--marks` (primeiro texto de cada página) × `pypdf`
  do PDF do Word para achar ONDE a paginação diverge; `paragraphProbe` (rows/alturas de
  um parágrafo) × `visitor` de posições Y do golden para isolar A regra (ex.: descoberta
  de que o espaçamento entre parágrafos é `max(after,before)`, não soma).

Regra de ouro: **medir só em release** (`dart run tool/serve_web.dart`).
