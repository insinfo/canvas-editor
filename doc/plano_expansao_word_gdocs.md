# Plano de expansão — aproximar o editor do Word/Google Docs

Atualização de execução: **2026-07-15**. A grande refatoração de performance
foi incorporada ao estado abaixo; itens históricos continuam no documento como
contexto, mas as pendências válidas estão marcadas explicitamente.

## Estado de execução

| Item | Estado | Evidência |
|---|---|---|
| M1 §4.1 títulos customizados (outlineLvl herdado) | ✅ já funcionava (cascata `resolveParagraph`) — coberto por teste novo | `test/word/bookmark_internal_link_test.dart` |
| M1 §4.2 bookmarks + links internos | ✅ (2026-07-13) captura `w:bookmarkStart/End` → `extension['bookmarks']` + XML p/ regen; `Draw.locationBookmark`; clique em `#anchor` navega; `executeLocationBookmark` | 5 testes VM; round-trip byte-idêntico mantido |
| PERF baseline honesto | ✅ bench consertado (shell legada + sanidade de teclas + `finishLayout`) — a medição anterior era inválida (teclas não chegavam ao editor) | `tool/bench/typing_bench.dart` |
| PERF §6.1 repintura dirigida | ✅ (2026-07-13) fast path delimita rows sujas → `_lazyRender` repinta só a(s) página(s) afetadas (altura igual) ou da 1ª suja em diante; guarda p/ busca ativa. **TR: 165→68 ms/tecla (2,4×)**; ETP 56 ms | campos `_fastRepaint*` em draw.dart; bench |
| PERF `finishProgressiveLayout()` | ✅ conclui a paginação sob demanda sincronamente — corrige navegação p/ além da fronteira (bookmark/catálogo) e destrava o bench | draw.dart; usado por locationBookmark/locationCatalog |
| PERF §6.4 métricas actualBoundingBox | ✅ já implementado no fallback canvas (nada a fazer) | draw.dart:2492-2513 |
| M2 §7 régua | ✅ (2026-07-13) linha-guia pontilhada no arrasto, controle 3 peças (▽ firstLine / △ hanging / □ caixa), recuo direito arrastável, sync com o cursor por frame | widget_ruler.dart + CSS |
| M2 §7b `paraIndentRight` | ✅ modelo + layout (largura útil da row, com clamp) + conversão `w:ind@right` + export + régua | teste em title_export_test |
| M3 header/footer multi-tipo (first/even) | ✅ (2026-07-13) conversor expõe variantes + flags (`titlePg`/`evenAndOddHeaders`); frames Header/Footer computam e renderizam a variante por página (edição continua no default; zona ativa mostra default) | teste F4.6 em docx_to_element_test; corpus tem variantes mas flags OFF |
| M4.1 repeat header row | ✅ o layout JÁ clonava `pagingRepeat` no topo de cada fatia — faltava a UI: `toggleTableHeaderRow` (Word-style: linhas 0..cursor, só na 1ª parte) + menu de contexto + botão na mini-toolbar | table_operate.dart |
| M4.2 abas contextuais no ribbon | ✅ abas "Tabela"/"Imagem" (roxas, estilo Ferramentas do Word) aparecem/somem com a seleção (`resolveSelectionContext` compartilhado com a mini-toolbar); aba ativa some → volta p/ Página Inicial | widget_ribbon.syncSelectionContext |
| M5 TOC no corpo | ✅ v1 (2026-07-13) `executeInsertToc`: coleta títulos, reusa/cria bookmarks (novos exportados via wpBookmark*Xml + `_sameElement` compara `bookmarks` p/ forçar regen), entradas com hyperlink interno `#anchor`, recuo por nível e pontos medidos por TTF; re-rodar substitui a região `extension['toc']`; botões Sumário/Atualizar na aba Inserir. **Pendente**: right-tab com leader real (F4.4), campo TOC OOXML no export (hoje sai como parágrafos com links internos) | command_adapt.insertToc |
| Rodada 2 (feedback com screenshots do Word, 2026-07-13) | ✅ régua vertical alinhada à ESQUERDA da viewport (não colada na página, como no Word); duplo-clique em QUALQUER elemento do header/footer (imagem, caixa de texto) ativa a zona primeiro (moldura tracejada + label) — previewer/editor interno só com a zona já ativa; **TextBoxTool**: caixa de texto do carimbo com 8 alças (mover/redimensionar via arrasto), mini-toolbar de alinhamento esq/dir e edição do texto em painel flutuante (`IHeaderTextBox` mutável + `offsetXPx`; render e PDF honram). Limitação: edições da caixa são visuais (render/PDF) — sync do header no DOCX segue pendente (F3) | text_box_tool.dart; click.dart; widget_ruler.dart |
| Rodada 3 (2026-07-13) | ✅ **instrumentação da tecla** (`[input] pre/render/total` + `[render] post`): os ~25 ms "não instrumentados" eram overhead do CDP do harness — o custo REAL do editor por tecla no TR é **~18–31 ms** (pageList 1-2, positions 3-4, tail 2-5, draw 8-14; pre/post ≈ 0). Sem gargalo único restante; G4 (<16 ms) perto. ✅ **F3 follow-up: sync do carimbo no DOCX** — `patchHeaderTextBoxXml` (word/textbox_sync.dart, puro+testado) regenera `w:txbxContent` (Choice+Fallback VML), `wp:extent`/`a:ext` e `wp:posOffset` por regex no header part; arrasto horizontal converte `wp:align`→`posOffset`; o save aplica só quando texto/geometria mudaram (limitação: 1 carimbo por part) | typing_bench; textbox_sync_test |
| Rodada 4 (2026-07-13) | ✅ UX do carimbo: caret escondido na seleção da caixa, cor de fundo (color picker + "sem cor") na mini-toolbar, indicador de zona redesenhado em QUALQUER render (antes sumia nos renders isCompute:false). ✅ **Edição in-place das variantes first/even**: ao entrar na zona header/footer, a lista editável vira a variante da página corrente (`setActiveVariantForPage` no Zone.setZone; getElementList/getRowList/getPositionList retornam a variante ativa; render escolhe por página sempre). ✅ **Campo TOC OOXML no export**: as entradas do Sumário saem envolvidas em `fldChar begin + instrText "TOC \o 1-9 \h \z \u" + separate ... end` (título fora do campo — F9 do Word não o engole) | testes VM 40/40 |
| **G3 fidelidade de paginação** | ✅ (2026-07-13) **espaçamento entre parágrafos = max(after, before)**, não soma — medido no PDF golden (linha 13,2pt; gap 6pt com before=120+after=120). **ETP 24→19 págs (= Word); TR 150→143 (Word 140)**. Metodologia: `--marks` (pageStarts) × pypdf + `paragraphProbe` × visitor de posições Y. Restante do TR (+3): tabelas dos anexos (trHeight/margens de célula) | draw.dart (caso ZERO + fast-path) |
| Contagem de palavras opcional | ✅ `CanvasEditorConfig.showWordCount=false` desliga o O(doc) por mudança + esconde o contador | canvas_editor_widget/status bar |
| PERF — modelo, changes e locators estáveis | ✅ (2026-07-15) `DocumentModel`/`DocumentIndex`/`DocumentTransaction`, invalidação tipada e `DocumentListLocator` por região + caminho de células aninhadas; main/header/footer first/even e tabelas aninhadas deixaram de depender da identidade transitória da lista | `core/document/`; testes de locator/model/transaction |
| PERF — histórico compacto e limitado | ✅ (2026-07-15) deltas textuais coalescidos; checkpoint forward-only descarta payload removido fora da janela e limita replay a checkpoint + janela de undo; branch, snapshot misto e undo/redo cobertos | 10.000 Enter/letra → 1 splice de checkpoint + 4 callbacks com janela ≈4; `core/history/` |
| PERF — layout/posição/render incremental | ✅ hot paths; 🔶 extração arquitetural | splice de seleção em uma movimentação de cauda, fast reflow estrutural para Enter/Delete, `PageRowIndex`/`PagePositionIndex`, `LayoutScheduler`, `DirtyPageQueue`, `PageCanvasManager` e repaint parcial por faixa de rows | TR: Enter+texto 61,2 ms/par (~30,6 ms/evento CDP), Delete de 1.081 elementos 48 ms |
| PERF §6.2 modularização dos monólitos | 🔶 parcial | módulos de document/history/layout scheduling/index/rendering foram extraídos; **pendentes** `LayoutEngine`, cache/EndInfo genérico, `PagePainter`/`ViewportPager`, serviços de comando e controllers de `EditorApp` |
| PERF §6.3 workers auxiliares | ⬜ pendente | `WorkerManager` continua na main thread; unzip/parse DOCX, word count, catálogo e spellcheck seguem candidatos, sem mover o layout editável para worker |
| PERF — reflow regional de tabela paginada | ⬜ pendente | edição rápida ainda reutiliza fragmentos existentes; o primeiro full converge 144→143 páginas e o segundo full é idêntico. Falta reconstruir/reparticionar regionalmente a tabela canônica até a fronteira/altura convergir |
| F4.4 tab stops reais (layout + régua) | ⬜ próxima sessão (pré-requisito p/ leader real no TOC) | — |
| TR +3 págs restantes (tabelas dos anexos) | ⬜ próxima sessão — mesma metodologia (probe de tabela × golden) | — |

### Checklist da grande refatoração de performance

- [x] Modelo canônico, revisão monotônica, índices incrementais e locators
  estáveis para regiões e células/tabelas aninhadas.
- [x] Histórico por deltas para os hot paths, coalescência de
  digitação/Enter/Delete/Backspace e checkpoint com retenção limitada.
- [x] Invalidação por `affectedRange`/impacto, fast paths de parágrafo e de
  splice estrutural, posição reduzida à página afetada e repaint parcial.
- [x] Scheduler cancelável/fatiado, canvases virtualizados e fila de páginas
  sujas extraídos em módulos próprios.
- [x] Guardrails: benchmark do TR real, convergência de dois full renders,
  61 testes de núcleo e 40 testes Word verdes; analyzer sem diagnósticos.
- [ ] **Reflow regional de fragmentos de tabela:** merge-back canônico,
  repartição desde a página afetada e parada por convergência de fronteira,
  altura e carry state, sem exigir full render posterior.
- [ ] **Workers auxiliares reais:** unzip/parse, contagem, catálogo e futuro
  spellcheck; o layout editável permanece na main thread.
- [ ] **Extrações restantes:** `LayoutEngine`/caches, `PagePainter`/viewport,
  serviços de domínio de `CommandAdapt` e controllers da shell `EditorApp`.

Medição release final no TR real: abertura **2.338,1 ms**; primeiro foco
**37,4 ms**, sem snapshot tardio (**2→2**); cinco pares Enter+texto
**76/65/66/48/51 ms** (média **61,2 ms/par**), com **10 fast layouts, 0 full**,
**5 repaints parciais**, **142 páginas reutilizadas** e posições recalculadas
em **1 página**; Delete multiparágrafo removeu **1.081 elementos em 48 ms**
(faixa observada **31–48 ms**). O full explícito continua caro
(**3.351,3 ms**, segundo **3.454,7 ms**) e é justamente o fallback que o reflow
regional de tabelas ainda precisa evitar.

Data original: 2026-07-13; estado atualizado em 2026-07-15. Baseado em:
exploração completa do `lib/` atual, do OnlyOffice
DocumentServer (`D:\EuroOfficeNative\DocumentServer\sdkjs\word` — **apenas referência
conceitual, AGPL, não copiar código**), do relatório Kix
([analise_google_docs_kix_resources01.md](analise_google_docs_kix_resources01.md)) e do
[plano OnlyOffice](plano_arquitetura_performance_onlyoffice.md). Complementa o
[roteiro](roteiro_editor_profissional.md) (F4–F8) com os recursos de edição pedidos:
cabeçalho/rodapé editável estilo Word, wrapping de imagem, tabela interativa com abas
contextuais, sumário automático e títulos customizados.

---

## 0. Estado atual em uma olhada (lacunas confirmadas no código)

| Área | O que já existe | O que falta |
|---|---|---|
| Header/footer | zonas main/header/footer, variantes default/first/even renderizáveis e editáveis por página, indicador tracejado, PAGE/NUMPAGES e carimbo editável/movível com sync DOCX | aba contextual específica e generalização do patch DOCX para mais de um carimbo por part; acabamento das regressões remanescentes |
| Imagens | `ImageDisplay{inline,block,surround,floatTop,floatBottom}`, previewer com 8 alças, crop, rotação **só no modal** | rotação não persiste no elemento, sem tight/through/behind/inFront, `surround` é retangular, âncora só absoluta (x/y por página), imagem nova não é re-emitida no DOCX |
| Tabelas | `TableOperate`/`TableTool`, mini-toolbar e aba contextual, paging com continuation + repeat header e locators estáveis inclusive para células aninhadas | reflow regional dos fragmentos paginados, layout completo de tabela aninhada, estilos nomeados e "distribuir uniformemente" |
| TOC/campos | catálogo, títulos por outline, bookmarks/links internos, bloco TOC e campo OOXML exportado | tab stop direito com leader real e atualização de campos totalmente viva |
| Estilos | cascata completa, preservação por diff e títulos customizados reconhecidos por `outlineLvl` efetivo | estilos nomeados vivos em runtime e criação/edição de estilos |
| Ribbon | abas fixas + contextuais Tabela/Imagem, sync coalescido e mini-toolbars text/table/image | aba contextual de Cabeçalho/Rodapé e acabamentos pontuais de shell |
| Performance | changes/invalidação tipada, locators, checkpoint de histórico limitado, fast reflow de splice, índices de página/posição, scheduler, canvas virtualizado, dirty queue e repaint parcial | reflow regional de tabela, workers auxiliares e extração dos motores/controllers ainda residentes nos monólitos |

---

## 1. Cabeçalho/rodapé editável estilo Word (prioridade alta)

**Referência OnlyOffice:** `CHeaderFooter` envolve um *document content* próprio;
`CHdrFtrController` mantém `CurHdrFtr` + mapa página→{header,footer}; o documento tem
"modos de posição" (`docpostype_Content`/`docpostype_HdrFtr`) e um duplo-clique na faixa
de margem troca o modo; first/even são escolhidos por `titlePg` + `evenAndOddHeaders`;
o conteúdo do header **encolhe a área de texto** (`GetHdrFtrLines`).

Plano no nosso código:

1. **Multi-tipo (F4.6 do roteiro):** trocar `IHeader.elements` únicos por
   `Map<HdrFtrType, List<IElement>>` (`default|first|even`) em `IHeader`/`IFooter`;
   seleção por página no `frame/header.dart`/`footer.dart` segundo `titlePg`/
   `evenAndOddHeaders` vindos do `sectPr` (o `DocxReader` já lê `headersByType` — hoje
   descarta first/even em `docx_to_element.dart:152`). Writer: sincronizar os 3 tipos.
2. **Duplo-clique estilo Word:** manter o clique simples atual como opção, mas alinhar o
   default ao Word: duplo-clique na faixa de margem entra na zona, `Esc`/duplo-clique no
   corpo sai. O hit-test do OnlyOffice é trivial (`Y <= topo || Y > limite`) e o nosso
   `getZoneByY` já faz isso.
3. **Header que empurra o corpo:** hoje a altura do header é limitada por
   `maxHeightRadio`; adotar a regra do Word (header alto empurra o início do texto para
   baixo) recalculando o `mainTop` por página a partir da altura real do header daquele
   tipo — é o `GetHdrFtrLines` do OnlyOffice.
4. **Text box do carimbo editável:** promover `IHeaderTextBox` a elemento flutuante de
   verdade (ver §2 — mesma infra de objeto ancorado). Meta mínima intermediária: arrastar
   para reposicionar + editar o texto interno num diálogo; meta final: edição in-place
   com o mesmo pipeline de linhas.
5. **UI:** aba contextual "Cabeçalho e Rodapé" no ribbon (ver §5) com: primeira página
   diferente, par/ímpar diferente, distância do topo/rodapé, inserir nº de página,
   fechar. Corrigir as regressões listadas (numeração duplicada/ausente, text box
   sumindo).

## 2. Imagens: wrapping, âncora e alinhamento com o texto (prioridade alta)

**Referência OnlyOffice:** `ParaDrawing` é o âncora dentro do Run com enum de wrap
(`NONE/SQUARE/THROUGH/TIGHT/TOP_AND_BOTTOM` + `behindDoc`); tight/through usam
`CWrapPolygon` com pontos editáveis; no recálculo, cada linha consulta os objetos
flutuantes da página e recebe *ranges horizontais proibidos* (FlowObjects), desviando o
texto; alças de resize/rotate são objetos de tracking separados.

Plano:

1. **Persistir transformações:** adicionar `rotate` (graus) a `IImageElement`; aplicar no
   `ImageParticle.render` (translate/rotate no ctx), no previewer (hoje a rotação morre
   no modal), no export PDF e no DOCX (`a:xfrm@rot`).
2. **Âncora relativa (mover com o texto):** hoje `imgFloatPosition` é x/y absoluto por
   página. Introduzir âncora ao parágrafo: o elemento flutuante vive no run (como já é no
   modelo), e a posição vira `offset relativo à linha/margem` (`relativeFrom:
   paragraph|margin|page`, como `wp:anchor` do OOXML). É o que faz imagem "acompanhar" o
   texto ao editar acima dela — comportamento Word que os usuários esperam.
3. **Wrap square de verdade no layout:** generalizar o `computeRowList` para aceitar
   *ranges proibidos por linha* (lista de intervalos X ocupados por floats na faixa Y da
   linha). Com essa primitiva, `surround` vira square correto (texto dos dois lados),
   e `behind`/`inFront` são só ordem de pintura (`behindDoc`), que o PDF exporter já
   ordena. Tight/through (polígono) ficam como meta estendida — square + topAndBottom +
   behind/inFront cobrem 95% do uso real.
4. **Novos valores no enum:** `ImageDisplay.behind`, `ImageDisplay.inFront` (pintura
   antes/depois do texto, sem ranges) — baratos assim que (3) existir.
5. **Round-trip DOCX de imagem editada/nova:** gerar `wp:inline`/`wp:anchor` +
   `a:blip`/rels/media para imagens criadas no editor (hoje o writer só re-emite
   `WpDrawing.rawXml` original) — inclui `wrapSquare/wrapTopAndBottom/behindDoc`
   correspondentes ao `imgDisplay`.
6. **UI:** aba contextual "Imagem" no ribbon + no diálogo de layout: wrap (inline,
   quadrado, acima/abaixo, atrás, na frente), alinhamento (esq/centro/dir relativo à
   margem), "mover com o texto" vs "fixo na página", rotação, texto alternativo.

## 3. Tabela interativa completa (prioridade média-alta)

**Referência OnlyOffice:** `CTableMarkup` (posições X de colunas, Y/altura de linhas,
recalculado por página) é o modelo de UI para hit-test de bordas e réguas;
`CTableOutline` dá a alça de mover a tabela; a aba contextual dispara quando a seleção
cai numa `CTable`.

Plano (a base já é forte — `TableTool` + `TableOperate` + mini-toolbar):

1. **Repetir linha de cabeçalho nas fatias paginadas:** o modelo já tem
   `pagingRepeat`/`w:tblHeader`; falta o layout duplicar a(s) linha(s) de cabeçalho no
   topo de cada continuação em `_partitionTableAcrossPages` e o render pintá-las.
   Adicionar o toggle "Repetir linhas de cabeçalho" na UI.
2. **Aba contextual "Tabela"** no ribbon (ver §5): design de bordas/sombreamento (os
   comandos `tableBorderType/Color`, `tableTdBackgroundColor` já existem), inserir/
   excluir, mesclar/dividir, alinhamento vertical, distribuir linhas/colunas
   uniformemente (novo comando — média aritmética de `colgroup`/`trHeight`), tamanho de
   célula com campos numéricos, alça de mover tabela (outline estilo Word no canto
   superior esquerdo).
3. **Marcador na régua:** integrar `TableTool` com `widget_ruler.dart` — quando o cursor
   está numa tabela, a régua mostra os divisores de coluna arrastáveis (Word faz isso).
4. **Tabelas aninhadas (meta estendida):** o modelo (`ITd.value: List<IElement>`) já
   permite; exigiria recursão no layout de célula e no hit-test. Registrar como fase
   própria; o corpus atual (ETP/TR) não usa.
5. **Estilos de tabela nomeados:** aplicar `tblStyle` do catálogo importado a tabelas
   novas (galeria simples na aba contextual usando os estilos do `WpStyleSheet`).

## 4. Sumário automático, títulos customizados, bookmarks (prioridade alta)

**Referência OnlyOffice:** TOC é um *complex field* (begin/instrText/separate/result/
end); `private_UpdateTOC` coleta parágrafos via `GetOutlineParagraphs({OutlineStart,
OutlineEnd, Styles})` — ou seja, **o critério é `outlineLvl` (herdado pela cadeia
basedOn) e/ou lista de estilos da instrução `\o`/`\t`** — cria um bookmark por título,
copia o texto, aplica estilo `TOC N`, adiciona tab direito com leader de pontos e, com
`\h`, envolve num hyperlink interno para o bookmark.

Plano:

1. **Respeitar títulos customizados (pré-requisito, barato):** hoje um parágrafo só é
   título se o conversor mapear o nível fixo. Corrigir o critério para o do Word: um
   parágrafo é título de nível N se seu estilo efetivo (cadeia `basedOn` no
   `FormatResolver`) tiver `outlineLvl = N-1` — independente do nome do estilo (cobre
   "Nivel 01" do template da Prefeitura). Guardar `outlineLevel` no `IElement` na
   conversão; `getCatalog()` e o futuro TOC passam a usar isso.
2. **Bookmarks + hyperlink interno:** novo par de elementos invisíveis
   `bookmarkStart/End` (id+nome) no modelo (o TR já tem 12 bookmarks preservados);
   `IHyperlinkElement` ganha `anchor` (alvo interno) além de `url`; clique navega via o
   mesmo mecanismo do `executeLocationCatalog`. Export: `w:bookmarkStart/End` e
   `w:hyperlink@w:anchor`.
3. **Bloco TOC no corpo:** novo `ElementType.toc` (container com `instr` estilo
   `TOC \o "1-3" \h \z`), gerado por um comando `executeInsertToc()`:
   coleta os títulos (critério do item 1), monta parágrafos "TOC N" (indent por nível +
   tab direito com leader de pontos + nº de página da paginação real + hyperlink interno
   para o bookmark do título), e marca a região como campo. Botão "Atualizar Sumário"
   (e atualização automática antes de exportar PDF/print). Export DOCX: emitir o campo
   TOC real (`fldChar`/`instrText` + resultado em cache) — o Word então assume a
   atualização via F9.
4. **Tab stops com leader** (F4.4 do roteiro) são pré-requisito do visual do TOC —
   implementar pelo menos right-tab com leader de pontos junto com este item.

## 5. Ribbon com abas contextuais + estilos nomeados na UI (prioridade média)

1. **Abas contextuais:** o `widget_ribbon.dart` tem abas fixas e o
   `widget_floating_toolbar.dart` já detecta contexto (text/table/image). Reusar essa
   detecção para inserir/remover abas dinâmicas: `Tabela` (seleção em tabela), `Imagem`
   (imagem selecionada), `Cabeçalho e Rodapé` (zona ≠ main). Destacar com cor de grupo
   como no Word; a mini-toolbar continua para ações rápidas.
2. **Estilos nomeados em runtime (D2 do roteiro):** expor o `WpStyleSheet` importado como
   catálogo vivo: `IElement.styleId` deixa de ser só metadado de round-trip e passa a ser
   consultado pelo layout (resolução preguiçosa com cache, como o `CStyleCache` do
   OnlyOffice); galeria de estilos na aba Página Inicial (aplicar `Heading 1..9`,
   `Normal`, estilos do documento); "Criar estilo a partir da seleção" como meta
   estendida. Isso também destrava o item 4.1 (outlineLvl) e listas exportadas
   corretamente.
3. **Quitar regressões da shell** antes de recursos novos: status bar, sidebar de
   catálogo, page mode contínuo, mini-toolbar aparecendo no viewer — estão no
   CHANGELOG/TODO e minam a percepção de qualidade.

## 6. Performance — próximos incrementos (contínuo)

O grosso do modelo Kix/OnlyOffice já foi adotado (fast paths de parágrafo e
splice estrutural, layout progressivo fatiado, canvas virtualizado, índices de
página/posição, dirty queue e checkpoint de histórico). Estado dos incrementos:

- [x] **Recálculo guiado por changes nos hot paths:** `DocumentMutation`/
  `DocumentTransaction` carregam `affectedRange` e impacto; `LayoutInvalidation`
  decide repaint, parágrafo, tabela ou full; formatação, digitação, Enter,
  Backspace e Delete usam deltas/fast paths. **Pendente:** concluir a migração
  dos comandos legados e o reflow regional de tabela paginada; eles continuam
  sendo as barreiras/fallbacks explícitos, não o caminho comum.
- [ ] **Quebrar o monólito `draw.dart` (parcial entregue):** concluídas as extrações de
  DocumentModel/Index/Locator/Mutation/Transaction, History, LayoutScheduler,
  LayoutInvalidation/Request, PageRowIndex/PagePositionIndex, DirtyPageQueue e
  PageCanvasManager. **Pendentes:** `LayoutEngine` + caches/EndInfo,
  `PagePainter`/`ViewportPager`, serviços de comando e controllers da shell.
  Main thread + fatiamento continua sendo a decisão correta para layout.
- [ ] **Workers de verdade só para tarefas auxiliares:** o `WorkerManager` atual é fake
   (`Future(cb)` na main thread). Mover para worker/isolate o que não toca o layout:
   contagem de palavras, catálogo, futuro spellcheck, unzip/parse do DOCX na abertura
   (o parse SAX de 4,45 MB ainda bloqueia ~1,6 s no TR).
- [x] **Métricas de linha reais:** `measureText().actualBoundingBoxAscent/Descent`
   como fallback quando não houver métrica TTF (o Kix faz feature-detection disso) —
   já está implementado; não é pendência desta refatoração.
- [ ] **Overlay de cursor/seleção fora do tile** (Kix): garantir que caret piscando e
   seleção não repintam o canvas da página (camada DOM/canvas própria) — verificar o
   estado atual antes de mexer.
- [x] Lembrete operacional incorporado aos benches: **medir só em release**
   (`dart run tool/serve_web.dart`), nunca
   com DDC.

## 7. Régua em paridade com o Word/OnlyOffice (prioridade média-alta)

Auditoria de `lib/src/components/canvas_editor/widget_ruler.dart` (2026-07-13). A base
existe (escala em quartos de cm a partir da margem, sombra de margem, arrasto de margens
e de 2 recuos), mas está longe do controle de recuo do Word:

Lacunas confirmadas no código:

1. **Sem marcador de recuo deslocado (hanging).** O Word tem um controle de 3 peças:
   ▽ primeira linha (topo), △ deslocamento/hanging (base) e □ recuo esquerdo (caixa que
   move os dois juntos). O nosso tem só 2 marcadores (`firstLine`, `indentLeft`) e o
   arrasto do esquerdo sempre carrega a primeira linha junto — não há como mover só o
   hanging. O modelo já suporta (hanging = `paraIndentFirstLine` negativo, round-trip
   `w:hanging` ok em `element_to_docx.dart:448`), é lacuna só de UI.
2. **Recuo direito é decorativo.** O marcador existe mas com `_RulerDrag.none`
   (`widget_ruler.dart:117`), não existe `paraIndentRight` no `IElement`, e o layout
   ignora recuo direito (o `computeRowList` só aplica left+firstLine,
   `draw.dart:2718-2724`). Precisa: campo no modelo + largura disponível da row
   descontando o right + conversão `w:ind@right` (reader já parseia `rightTwips`) +
   arrasto na régua.
3. **Sem linha-guia vertical durante o arrasto** — a linha pontilhada que desce sobre o
   documento enquanto se arrasta margem/recuo/tab (Word e OnlyOffice têm; é o feedback
   que o usuário sente falta). Implementação barata: um `DivElement` absoluto de 1px
   (border-left dashed) sobre o `scrollContainer`, criado no `_startDrag`, seguindo o X
   do mouse, removido no `_finishDrag`.
4. **Marcadores não seguem o cursor.** `_readParagraphIndents` lê a seleção, mas o
   `refresh()` só é chamado em `pageScaleChange` (`canvas_editor_widget.dart:254`) —
   mover o caret para um parágrafo com outro recuo não atualiza a régua. Ligar ao
   `rangeStyleChange` já coalescido por frame (`_flushRangeStyle`).
5. **Sem tab stops na régua.** O canto (`ce-ruler-corner`, "Seletor de tabulação") é só
   um `title`. No Word: clique na régua insere tab stop do tipo selecionado no canto
   (left/center/right/decimal/bar), arrastável, duplo-clique abre o diálogo, arrastar
   para fora remove. Depende do F4.4 (tab stops no layout) — implementar juntos.
6. **Régua vertical sem alças** de margem superior/inferior, e fixa ao viewport em vez
   de acompanhar a página corrente (no Word ela representa a página sob o cursor e rola
   com ela).
7. **Divisores de coluna de tabela** na régua quando o caret está numa tabela
   (integração com `TableTool`, já listada no §3.3).
8. **Acabamento visual:** formas dos marcadores do Word (pentágono/triângulo/caixa em
   vez de divs genéricos), cursor de resize na fronteira cinza/branco da margem,
   tooltip com o valor em cm durante o arrasto (OnlyOffice mostra), live-apply do recuo
   ao soltar já existe (`executeParagraphIndent`) — manter aplicação no mouseup +
   linha-guia (Word também não refaz o layout durante o arrasto).

Ordem interna sugerida: (a) linha-guia + sync com cursor + hanging (só UI, modelo
pronto); (b) `paraIndentRight` (modelo+layout+régua+DOCX); (c) tab stops na régua junto
com F4.4; (d) alças verticais e colunas de tabela; (e) acabamento visual.

## 8. Sequência sugerida (custo × valor)

| Ordem | Item | Por quê primeiro |
|---|---|---|
| 1 | §4.1 outlineLvl/títulos customizados + §4.2 bookmarks/links internos | pequeno, destrava TOC e navegação; corpus real depende disso |
| 2 | §7a régua: linha-guia no arrasto + sync com cursor + marcador hanging | só UI (modelo pronto); resolve a queixa mais visível de paridade |
| 2b | §1.1–1.3 header/footer multi-tipo + empurrar corpo + duplo-clique | F4.6 já planejada; reader já lê os 3 tipos; alto valor Word-parity |
| 3 | §3.1 repeat header row no paging + §3.2 aba contextual Tabela | modelo pronto (`pagingRepeat`), falta layout/render/UI |
| 4 | §4.3 bloco TOC no corpo (com F4.4 tab stops + leader; incluir §7c tabs na régua e §7b `paraIndentRight`) | recurso pedido; depende de 1; tab stops servem TOC e régua de uma vez |
| 5 | §2.1–2.3 rotação persistida + âncora relativa + wrap square real | mexe no computeRowList; fazer com a primitiva de ranges proibidos |
| 6 | §5.2 estilos nomeados em runtime + galeria | melhora export de listas/estilos e a UI |
| 7 | §1.4 carimbo/text box editável + §2.5 imagem nova no DOCX | reusa a infra de flutuantes do item 5 |
| 8 | §6.1–6.2 recálculo por changes + modularização do draw.dart | hot paths e módulos-base entregues; continuar com reflow regional de tabela e extrações de engine/painter/controllers |

Riscos: (a) ranges proibidos no `computeRowList` é a mudança mais invasiva — proteger
com E2E de regressão de paginação (ETP 24 págs, TR 184) antes de tocar; (b) toda
mudança de modelo (`IElement`) precisa manter o round-trip byte-idêntico dos DOCX sem
edição (suíte `test/word/` é o guarda-chuva); (c) OnlyOffice é AGPL — inspiração
conceitual, zero cópia.
