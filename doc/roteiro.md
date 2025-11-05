# Roteiro de Tradução
port from C:\MyDartProjects\canvas-editor-port\typescript\src to C:\MyDartProjects\canvas-editor-port\lib

## Estado Atual
- Infra de boot do editor estabilizada: `Draw` expõe container, escala, `getI18n()` e `destroy()`, permitindo que `Editor` inicialize menus, atalhos e limpeza sem acessar APIs ausentes.
- Eventos de canvas seguram execuções enquanto `RangeManager`, `Position` e partículas não estiverem disponíveis, evitando exceções durante o fluxo de port.
- `Draw` oferece modo impressão, `setPaperSize`, `setPaperDirection`, `setPaperMargin`, `setPageScale` e `setPagePixelRatio` com atualização automática de métricas, além de reemissão para listener/event bus.
- Renderização portada: `drawRow`, `_drawPage`, `_drawFloat`, `_lazyRender` e `_immediateRender` seguem o pipeline TypeScript, cobrindo highlight/underline/strikeout, listas, tabelas, floats e placeholder.
- Cursor sincronizado: `setCursor` reposiciona caret em tabelas e imagens, delega `Previewer.updateResizer` e respeita stack do `HistoryManager` para undo/redo inicial.
- Infra interativa reativada: `CanvasEvent`, `Cursor`, `GlobalEvent`, `ScrollObserver`, `SelectionObserver` e `MouseObserver` passam a ser instanciados pelo `Draw`, junto do par `TableTool`/`TableOperate`, garantindo render de ferramentas e eventos globais.
- Histórico restaurado: `submitHistory` grava snapshots completos (zona, página, cabeçalho/rodapé, range) no `HistoryManager`, habilitando undo/redo real.
- Limpeza de UI: `clearSideEffect` reseta previewer, table tool, popup de hyperlink e date picker, evitando resíduos após troca de modo.
- `Editor` e `main.dart` compilam; a demo Flutter continua funcional com o núcleo atual.
- `dart analyze` permanece sem erros (76 avisos de estilo/imports conhecidos).
- Testes E2E ainda não foram executados após as últimas portas (`dart test` continua recomendado).

## Progresso Recente
- Porta do pipeline de rendering (`drawRow`, `_drawPage`, `_drawFloat`, `_lazyRender`, `_immediateRender`) com suporte a highlight, underline, strikeout, tabelas e floats.
- Implementação de `setCursor` espelhando o TypeScript (contexto de tabela, imagem direta, `Previewer.updateResizer`, reposição de caret durante `render`).
- Ajustes no fluxo de `render`: reaproveitamento de `curIndex`, submissão condicional de histórico e reativação pós-render para controles, range e table tool.
- Porte do pipeline de eventos globais: `CanvasEvent.register`, `GlobalEvent.register`, observadores de scroll/seleção/mouse e criação automática de `TableTool`/`TableOperate`.
- Instanciação do `DateParticle` e integração do `clearDatePicker` via `clearSideEffect`.
- Reimplementação de `submitHistory` com clones de posição e range, sincronizando cabeçalho/rodapé e a lista principal antes de renderizar.
- Execução de `dart analyze` para validar ausência de erros (apenas avisos já catalogados).

## Próximas Ações
- Finalizar seleção e navegação: validar integração de arrasto/teclado (`CursorAgent`, `SelectionObserver`, `RangeManager`), cobrindo `moveCursorToVisible` e sincronização de range.
- Refinar ferramentas de tabela: completar cenários de redimensionamento/merge no `TableOperate`, validar callbacks de renderização e garantir observadores removem eventos ao destruir.
- Portar rotinas restantes de `Draw` (observers complementares, integração com comandos/worker além dos cenários básicos).
- Integrar controles dependentes de `_tableTool`/`tableOperate` e revisar comandos que ainda não acionam `submitHistory`.
- Portar rotinas restantes de `Draw` (cursor blinking, observers complementares, integração com comandos/worker).
- Mapear e atualizar a contagem de arquivos/funções pendentes comparando com o código TypeScript restante.
- Rodar `dart analyze` e `dart test test/e2e/editor_smoke_test.dart` após estabilizar os itens acima.

## Rastreamento de Arquivos
0.83  editor/core/draw/Draw.ts               → lib/src/editor/core/draw/draw.dart (renderização, history, cleanup)
0.51  editor/interface/Common.ts             → lib/src/editor/interface/common.dart
0.61  editor/core/worker/WorkerManager.ts    → lib/src/editor/core/worker/worker_manager.dart
0.66  editor/core/contextmenu/menus/imageMenus.ts    → lib/src/editor/core/contextmenu/menus/image_menus.dart
0.67  editor/core/contextmenu/menus/tableMenus.ts    → lib/src/editor/core/contextmenu/menus/table_menus.dart
0.71  editor/core/plugin/Plugin.ts           → lib/src/editor/core/plugin/plugin.dart
0.73  editor/core/contextmenu/menus/globalMenus.ts   → lib/src/editor/core/contextmenu/menus/global_menus.dart
0.75  editor/core/observer/MouseObserver.ts  → lib/src/editor/core/observer/mouse_observer.dart
0.75  editor/core/register/Register.ts       → lib/src/editor/core/register/register.dart
0.76  editor/core/contextmenu/menus/hyperlinkMenus.ts → lib/src/editor/core/contextmenu/menus/hyperlink_menus.dart
0.79  editor/core/worker/works/group.ts      → lib/src/editor/core/worker/works/group.dart
