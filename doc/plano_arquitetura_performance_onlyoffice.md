# Plano de Arquitetura e Performance baseado no OnlyOffice

Data original: 2026-07-09. Estado atualizado em **2026-07-15**.

Objetivo: reduzir travamentos do TR e transformar os monolitos
`lib/src/editor/core/draw/draw.dart` e `lib/src/editor.dart` em módulos
extensíveis, testáveis e rápidos. A fonte de verdade comparativa é
`D:\EuroOfficeNative\DocumentServer\sdkjs\word`.

## Estado de execução da grande refatoração

| Frente | Estado em 2026-07-15 | Evidência/limite atual |
|---|---|---|
| 3.1 Núcleo de documento | ✅ concluído como base | `DocumentModel`, `DocumentIndex`, `DocumentMutation`, `DocumentReplayDelta`, `DocumentTransaction` e locators estáveis por região/caminho de tabela |
| 3.2 Histórico por deltas | ✅ hot paths + retenção limitada | digitação/Enter/Delete/Backspace coalescidos; checkpoint forward-only; 10.000 splices → 1 operação de checkpoint + 4 callbacks com janela ≈4; snapshots ficam para fronteiras absolutas/fallbacks |
| 3.3 Layout incremental | 🔶 parcial funcional | `LayoutInvalidation`/`LayoutRequest`, `LayoutScheduler`, `PageRowIndex`, fast paragraph e fast splice estrutural; **falta** `LayoutEngine` extraído, EndInfo genérico e reflow regional de fragmentos de tabela |
| 3.4 Renderização por página | ✅ hot path; 🔶 extração incompleta | `DirtyPageQueue`, `PageCanvasManager`, repaint parcial de rows/página e posição limitada à página afetada; **faltam** `PagePainter` e `ViewportPager` extraídos |
| 3.5 Comandos por domínio | ⬜ pendente | `CommandAdapt` ainda não foi dividido em serviços; comandos legados restantes ainda precisam adotar transaction/invalidation tipada |
| 3.6 Shell extensível | ⬜ pendente | `EditorApp`/`editor.dart` ainda precisam ser separados nos controllers propostos |
| P5 workers auxiliares | ⬜ pendente | `WorkerManager` continua fake/main thread; unzip/parse, word count, catálogo e spellcheck são os candidatos corretos |

### Checklist consolidado

- [x] Modelo canônico e índices incrementais.
- [x] Locator estável para main, seis variantes de header/footer e células de
  tabelas arbitrariamente aninhadas.
- [x] Changes reversíveis com faixa/impacto, coalescência e checkpoint de
  histórico limitado, inclusive branch e mistura com snapshot.
- [x] Splice de seleção sem `removeAt` repetido, fast reflow de Enter/Delete,
  posição por página e repaint parcial por faixa de rows.
- [x] Scheduler fatiado/cancelável, canvases virtualizados e dirty-page queue.
- [x] Bench reproduzível do TR, guarda de convergência e validação: analyzer
  limpo, **61 testes de núcleo** e **40 testes Word** verdes.
- [ ] **Reflow regional de tabela paginada:** reconstruir a tabela canônica,
  recalcular a partir do fragmento afetado e parar somente quando fronteira,
  altura de página e carry state convergirem.
- [ ] **Workers auxiliares reais**, sem mover o layout editável da main thread.
- [ ] **Extrações restantes:** LayoutEngine/caches, PagePainter/Viewport,
  CommandAdapt por domínio e controllers de EditorApp.

### Métricas finais do TR real (release)

| Medida | Resultado |
|---|---:|
| Abertura do TR | **2.338,1 ms** |
| Primeiro foco/seleção | **37,4 ms**, snapshots profundos **2→2** |
| Enter + texto, 5 pares | **61,2 ms/par**; amostras 76/65/66/48/51 ms (~30,6 ms/evento CDP) |
| Escopo das 10 mutações | **10 fast layouts, 0 full**, 5 repaints parciais, 142 páginas reutilizadas, posições de 1 página |
| Delete multiparágrafo | **1.081 elementos em 48 ms** (31–48 ms nas rodadas validadas) |
| Full explícito / segundo full | **3.351,3 / 3.454,7 ms** |

Após cinco ciclos Enter+texto, o fast path publicou 122.713 elementos, 1.727
rows e 144 páginas. O primeiro full convergiu para 122.717/1.731/143 e o
segundo full repetiu exatamente essa geometria. Não existe acúmulo de
merge-back/split; a diferença do primeiro full demonstra a pendência real:
reparticionar regionalmente fragmentos de tabela no próprio fast path.

## 1. Evidências do DocumentServer

### 1.1 Recálculo não começa pelo caminho global

Em `sdkjs/word/Editor/Document.js`, `private_Recalculate` consulta o histórico
de mudanças e tenta fast paths antes do recálculo regular:

- `History.GetNonRecalculatedChanges()`;
- `private_RecalculateFastRunRange(arrChanges)`;
- `private_RecalculateFastParagraph(arrChanges)`.

O fast run-range recalcula o run/parágrafo afetado, chama
`DrawingDocument.OnRecalculatePage(nPageIndex, ...)` e encerra o ciclo com
`OnEndRecalculate(false, true)`. Isso é o padrão que devemos copiar: comandos
geram changes com intervalo afetado; o layout decide o menor escopo seguro.

### 1.2 Formatação distingue relayout de repaint

Em `sdkjs/word/Editor/DocumentContent.js`, `AddToParagraph(ParaTextPr)` usa
`TextPr.Check_NeedRecalc()`. Se a propriedade altera métrica, chama
`Recalculate()`. Se não altera métrica, chama apenas `ReDraw(StartPage, EndPage)`.

Aplicação local concluída nos hot paths de formatação:

- `bold/font/size/italic/superscript/subscript`: tenta relayout local;
- `underline/strikeout/color/highlight`: repaint-only quando possível;
- undo/redo dessas ações usa delta local em vez de snapshot global.

### 1.3 Recálculo longo é fatiado e cancelável

O DocumentServer mantém estado em `FullRecalc` e continua o cálculo por timer:

- `ContinueRecalculationLoopTimer`;
- `IsContinueRecalculateOnTimer`;
- `Layout.GetCalculateTimeLimit()` retorna o orçamento de cálculo.

O `LayoutScheduler` extraído já aplica orçamento, versão/cancelamento e
continuação fatiada nos caminhos progressivos. Permanece pendente generalizar o
fallback para todos os comandos legados que ainda não geram uma invalidação
tipada nem passam pelo scheduler.

### 1.4 Desenho é por página recalculada

`DrawingDocument.OnStartRecalculate`, `OnRecalculatePage(index, pageObject)` e
`OnEndRecalculate` separam cálculo de layout do desenho de página. O editor não
redesenha tudo como reação padrão. Essa separação já ganhou `DirtyPageQueue`,
`PageCanvasManager` e repaint parcial por página/faixa de rows; ainda falta
extrair `PagePainter` e `ViewportPager` do monolito.

### 1.5 Undo/redo é replay de changes

`History.js` desfaz/refaz cada item chamando `Data.Undo()`, `Data.Redo()` e
`Data.CheckNeedRecalculate()`. O modelo evita clonar o documento inteiro como
operação normal. O caminho comum local já usa deltas, transações, locators
estáveis e checkpoint/restorer limitado; snapshots profundos ficam nos
fallbacks explícitos. Ainda é necessário fechar as mutações legadas que não
passam pela API tipada.

## 2. Diagnóstico dos monolitos atuais

### `draw.dart`

Hoje concentra responsabilidades que no OnlyOffice são separadas:

- modelo de documento: main/header/footer, setValue, insert/delete;
- layout: `computeRowList`, paginação, posições, table paging;
- renderização: canvases, lazy render, drawPage/drawRow, pixel ratio;
- interação: cursor, range, observers, scroll, selection;
- serviços de domínio: tabela, imagem, hiperlink, busca, controle, histórico;
- scheduler progressivo e invalidação.

Isso torna qualquer melhoria perigosa: uma operação de formatação pode acionar
layout, histórico, DOM e canvas no mesmo método.

### `editor.dart`

Hoje mistura shell de UI, toolbar, dialogs, DOCX open/save, autosave,
search/replace, paper controls, fullscreen, opções, e persistência. Isso dificulta
plugins e testes, porque a UI web sabe demais sobre comandos e sobre DOCX.

## 3. Arquitetura alvo

### 3.1 Núcleo de documento

**Estado: ✅ base entregue; 🔶 migração de legados em andamento.**

Novo pacote interno sugerido: `lib/src/editor/core/document/`.

- `DocumentModel`: dono de main/header/footer/graffiti.
- `DocumentMutation`: interface para changes.
- `DocumentIndex`: índices auxiliares por `id`, `tableId`, `pagingId`,
  parágrafo e página.
- `DocumentTransaction`: agrupa changes de um comando.

Regra: comando não altera `IElement` diretamente fora de uma transaction.
`DocumentModel`, `DocumentIndex`, locators, mutações e transações já existem; a
regra ainda precisa se tornar universal para os comandos antigos.

### 3.2 Histórico por deltas

**Estado: ✅ caminho comum entregue; 🔶 changes de domínio restantes.**

Expandir `lib/src/editor/core/history/`:

- `changes/insert_elements_change.dart`;
- `changes/style_elements_change.dart`;
- `changes/delete_range_change.dart`;
- `changes/table_change.dart`;
- `changes/option_change.dart`.

Cada change deve expor:

- `apply()`;
- `revert()`;
- `affectedRange`;
- `needsLayout`;
- `needsRepaintOnly`;
- `canMergeWith(next)`.

Meta: eliminar `submitHistory` com clone profundo como caminho comum. Snapshot
global fica só para `setValue`, importação, recovery e fallback de segurança.
Essa meta foi atingida nos hot paths: no cenário de 10 mil pares Enter/texto, a
janela ativa ficou em aproximadamente quatro callbacks mais um checkpoint de
splice, sem retenção do payload removido. Permanecem changes tipados específicos
para comandos legados e de tabela.

### 3.3 Layout incremental

**Estado: 🔶 base e hot paths entregues; engine/cache genéricos pendentes.**

Novo pacote interno sugerido: `lib/src/editor/core/layout/`.

- `LayoutEngine`: função pura de layout de parágrafo/tabela.
- `LayoutCache`: rows por bloco, page spans e end info.
- `ParagraphLocator`: encontra fronteiras de parágrafo sem varrer tudo.
- `TableLayoutCache`: cache de partes de tabela paginada.
- `LayoutScheduler`: orçamento de 10 ms, versão/cancelamento, fila dirty.
- `LayoutInvalidation`: converte changes em escopo mínimo.

Fast paths necessários:

- [x] run-range e parágrafo local para os comandos comuns;
- [x] splice estrutural rápido para Enter/Delete, com índice de rows/páginas;
- [x] full sliced com orçamento, versão e cancelamento;
- [ ] `EndInfo`/`LayoutCache` genérico para todos os blocos;
- [ ] table segment que reconstrói e reparticiona regionalmente fragmentos até
  altura/fronteira convergir;
- [ ] `LayoutEngine` puro extraído de `draw.dart`.

### 3.4 Renderização por página suja

**Estado: ✅ hot path entregue; 🔶 extrações finais pendentes.**

Novo pacote interno sugerido: `lib/src/editor/core/rendering/`.

- `PageCanvasManager`: cria, dorme e acorda canvases;
- `DirtyPageQueue`: agenda repaint por página;
- `PagePainter`: desenha uma página a partir de rows/positions;
- `ViewportPager`: visibilidade e scroll sem medir todos os canvases.

Regra: repaint-only nunca chama `computeRowList`.
`PageCanvasManager`, `DirtyPageQueue`, repaint parcial e posição limitada à
página afetada já atendem essa regra nos caminhos medidos. `PagePainter` e
`ViewportPager` ainda precisam ser extraídos e os caminhos legados, unificados.

### 3.5 Comandos por domínio

**Estado: ⬜ pendente.**

Separar `CommandAdapt` em serviços:

- `RichTextCommandService`;
- `ClipboardCommandService`;
- `TableCommandService`;
- `ImageCommandService`;
- `DocumentCommandService`;
- `NavigationCommandService`.

Cada serviço cria transactions; nenhum chama `draw.render()` diretamente. Ele
retorna uma intenção de atualização (`LayoutRequest`/`RepaintRequest`) para o
scheduler.

### 3.6 Shell web extensível

**Estado: ⬜ pendente.**

Extrair `EditorApp` em `lib/src/app/` ou `lib/src/editor_app/`:

- `DocxController`: open/save/export;
- `ToolbarController`: botões e estados;
- `SearchController`;
- `PageControlsController`;
- `DialogController`;
- `AutosaveController`;
- `StatusBarController`.

`editor.dart` vira apenas composição: cria controllers, injeta `Editor` e
registra lifecycle. Isso torna plugins e testes mais simples.

## 4. Estado e próximas otimizações prioritárias

### P0 - Guardrails

**Estado: ✅ entregue e ativo.**

- Manter `tool/bench/command_latency_bench.dart` e `tool/bench/typing_bench.dart`
  como gates manuais antes de grandes refactors.
- O `command_latency_bench` deve continuar medindo matriz fast path vs fallback:
  formatação de texto, inserção inline, backspace e comandos estruturais de
  tabela. Isso evita esconder regressões por medir só o caso feliz.
- Adicionar orçamento explícito: nenhum comando comum no TR deve passar de
  100 ms; comandos estruturais grandes devem fatiar UI antes de 50 ms.

Os testes de editor/Word e os benches de latência cobrem os caminhos críticos.
No TR real, Enter+texto ficou em 61,2 ms por par e Delete de 1.081 elementos em
48 ms; o full explícito de 3,35 s continua sendo fallback medido, não o caminho
comum.

### P1 - Dirty pages reais

**Estado: ✅ hot paths entregues; 🔶 unificação de legados pendente.**

- [x] `DirtyPageQueue` extraído para `core/rendering/`; scroll enfileira páginas
  e o drain respeita orçamento de frame.
- [x] `_renderSelectionMutation` e os deltas comuns produzem repaint parcial.
- [x] Repaint-only redesenha somente páginas/faixas afetadas pela seleção.
- [x] Hot paths preservam canvases quando a contagem de páginas não muda.
- [ ] Funil único para os caminhos legados e extração de `PagePainter`/viewport.

### P2 - Positions incrementais

**Estado: 🔶 hot path entregue; cache genérico pendente.**

- [x] `PagePositionIndex` limita a atualização medida à página afetada.
- [x] No Enter+texto do TR, 142 páginas foram reutilizadas e as posições foram
  recalculadas para uma página.
- [ ] Extrair um `PositionCache` genérico por row/page e fazê-lo cobrir todos os
  caminhos de layout, inclusive tabelas.

### P3 - Paragraph EndInfo

**Estado: 🔶 fast paragraph/splice entregue; convergência genérica pendente.**

- [x] Parágrafo e splice estrutural comuns encerram o trabalho em escopo local.
- [ ] Guardar, por parágrafo, estado de saída genérico: pageNo, y, row count,
  altura final, list state e table carry state.
- [ ] Recomputar blocos seguintes apenas até esse `EndInfo` convergir, inclusive
  na presença de tabela paginada.

### P4 - Tabelas

**Estado: 🔶 locators/índices entregues; reflow regional pendente.**

- [x] `tableId`/`pagingId` e locators estáveis cobrem fragmentos, células
  aninhadas e regiões de header/footer sem varredura global no hot path.
- [ ] Cachear table paging por `tableId` + hash leve de rows/colgroup.
- [ ] Deleção de linha/coluna deve virar `TableChange`, não render global.
- [ ] Reconstruir e reparticionar somente o segmento regional afetado, parando
  quando altura/fronteira e carry state convergirem.

### P5 - Worker onde faz sentido

**Estado: ⬜ pendente.**

- Worker para unzip/parse DOCX: bytes entram, bytes/XML saem via transferable.
- Não mover layout editável inteiro para worker enquanto o modelo for mutável
  na main thread; OnlyOffice não faz isso para layout de editor.

### P6 - Extração do monolito

**Estado: 🔶 parcial.**

Ordem segura:

1. [x] Extrair `PageCanvasManager` e `DirtyPageQueue` de `draw.dart`.
2. [x] Extrair `LayoutScheduler` mantendo `computeRowList` no lugar.
3. [x] Extrair a base de `HistoryChange` e migrar os hot paths.
4. [ ] Extrair `LayoutEngine`/caches e `PagePainter`/viewport com testes de
   row/page.
5. [ ] Separar `CommandAdapt` em serviços de domínio.
6. [ ] Quebrar `EditorApp` em controllers de UI.

## 5. Regras de arquitetura daqui para frente

- Novo comando deve declarar se é `repaintOnly`, `localLayout`, `tableLayout`
  ou `fullLayout`.
- Novo comando não pode chamar `draw.render()` global diretamente sem justificar.
- Histórico novo deve ser delta; snapshot global é fallback explícito.
- Layout longo deve ser cancelável por versão e fatiado por tempo.
- Canvas deve ser acordado por viewport/dirty page, não por contagem total de
  páginas.
- `draw.dart` não deve receber novos domínios; novos recursos entram por
  serviços e controllers.
Header/caixa de texto editável:
