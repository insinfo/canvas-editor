# Plano de Arquitetura e Performance baseado no OnlyOffice

Data: 2026-07-09.

Objetivo: reduzir travamentos do TR e transformar os monolitos
`lib/src/editor/core/draw/draw.dart` e `lib/src/editor.dart` em módulos
extensíveis, testáveis e rápidos. A fonte de verdade comparativa é
`D:\EuroOfficeNative\DocumentServer\sdkjs\word`.

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

Aplicação local já iniciada:

- `bold/font/size/italic/superscript/subscript`: tenta relayout local;
- `underline/strikeout/color/highlight`: repaint-only quando possível;
- undo/redo dessas ações usa delta local em vez de snapshot global.

### 1.3 Recálculo longo é fatiado e cancelável

O DocumentServer mantém estado em `FullRecalc` e continua o cálculo por timer:

- `ContinueRecalculationLoopTimer`;
- `IsContinueRecalculateOnTimer`;
- `Layout.GetCalculateTimeLimit()` retorna o orçamento de cálculo.

O nosso layout progressivo já segue essa direção, mas ainda falta transformar
o cursor de continuação em serviço isolado e reutilizável para qualquer comando
que não puder usar fast path.

### 1.4 Desenho é por página recalculada

`DrawingDocument.OnStartRecalculate`, `OnRecalculatePage(index, pageObject)` e
`OnEndRecalculate` separam cálculo de layout do desenho de página. O editor não
redesenha tudo como reação padrão. Nossa arquitetura precisa ter uma fila de
páginas sujas explícita.

### 1.5 Undo/redo é replay de changes

`History.js` desfaz/refaz cada item chamando `Data.Undo()`, `Data.Redo()` e
`Data.CheckNeedRecalculate()`. O modelo evita clonar o documento inteiro como
operação normal. O trabalho local já começou com deltas de inserção, estilo e
remoção de tabela; o próximo passo é tornar isso a única API pública de mutação.

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

Novo pacote interno sugerido: `lib/src/editor/core/document/`.

- `DocumentModel`: dono de main/header/footer/graffiti.
- `DocumentMutation`: interface para changes.
- `DocumentIndex`: índices auxiliares por `id`, `tableId`, `pagingId`,
  parágrafo e página.
- `DocumentTransaction`: agrupa changes de um comando.

Regra: comando não altera `IElement` diretamente fora de uma transaction.

### 3.2 Histórico por deltas

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

### 3.3 Layout incremental

Novo pacote interno sugerido: `lib/src/editor/core/layout/`.

- `LayoutEngine`: função pura de layout de parágrafo/tabela.
- `LayoutCache`: rows por bloco, page spans e end info.
- `ParagraphLocator`: encontra fronteiras de parágrafo sem varrer tudo.
- `TableLayoutCache`: cache de partes de tabela paginada.
- `LayoutScheduler`: orçamento de 10 ms, versão/cancelamento, fila dirty.
- `LayoutInvalidation`: converte changes em escopo mínimo.

Fast paths necessários:

- run-range: mudança dentro de uma linha/run;
- paragraph: recomputa o parágrafo e para quando o `EndInfo` converge;
- table segment: recalcula só a tabela/partes afetadas;
- full sliced: fallback em timer para mudanças estruturais grandes.

### 3.4 Renderização por página suja

Novo pacote interno sugerido: `lib/src/editor/core/rendering/`.

- `PageCanvasManager`: cria, dorme e acorda canvases;
- `DirtyPageQueue`: agenda repaint por página;
- `PagePainter`: desenha uma página a partir de rows/positions;
- `ViewportPager`: visibilidade e scroll sem medir todos os canvases.

Regra: repaint-only nunca chama `computeRowList`.

### 3.5 Comandos por domínio

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

## 4. Próximas otimizações prioritárias

### P0 - Guardrails

- Manter `tool/bench/command_latency_bench.dart` e `tool/bench/typing_bench.dart`
  como gates manuais antes de grandes refactors.
- Adicionar orçamento explícito: nenhum comando comum no TR deve passar de
  100 ms; comandos estruturais grandes devem fatiar UI antes de 50 ms.

### P1 - Dirty pages reais

- Transformar `_renderSelectionMutation` e deltas em `DirtyPageQueue`.
- Para repaint-only, redesenhar somente páginas afetadas pela seleção.
- Evitar `_syncPageCanvases` quando page count não mudou.

### P2 - Positions incrementais

- `computePositionList` ainda pode virar gargalo para TR.
- Criar `PositionCache` por row/page e recalcular somente a partir da primeira
  row suja.

### P3 - Paragraph EndInfo

- Guardar, por parágrafo, estado de saída: pageNo, y, row count, altura final,
  list state e table carry state.
- Após edição, recomputar parágrafos seguintes só até o EndInfo convergir.

### P4 - Tabelas

- Cachear table paging por `tableId` + hash leve de rows/colgroup.
- Deleção de linha/coluna deve virar `TableChange`, não render global.
- Partes de tabela (`pagingId`) precisam de índice para remoção/restauração sem
  varrer o documento inteiro.

### P5 - Worker onde faz sentido

- Worker para unzip/parse DOCX: bytes entram, bytes/XML saem via transferable.
- Não mover layout editável inteiro para worker enquanto o modelo for mutável
  na main thread; OnlyOffice não faz isso para layout de editor.

### P6 - Extração do monolito

Ordem segura:

1. Extrair `PageCanvasManager` e `DirtyPageQueue` de `draw.dart`.
2. Extrair `LayoutScheduler` mantendo `computeRowList` no lugar.
3. Extrair `HistoryChange` e migrar comandos um a um.
4. Extrair `LayoutEngine` puro com testes de row/page.
5. Quebrar `EditorApp` em controllers de UI.

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
