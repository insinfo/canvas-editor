# Roteiro de Tradução
port from C:\MyDartProjects\canvas-editor-port\typescript\src to C:\MyDartProjects\canvas-editor-port\lib

## Estado Atual
- Infra de boot do editor estabilizada: `Draw` agora expõe container, escala, `getI18n()` e `destroy()`, permitindo que `Editor` inicialize menus, atalhos e limpeza sem acessar APIs ausentes.
- Eventos de canvas seguram execuções enquanto `RangeManager`, `Position` e partículas não estiverem disponíveis, evitando exceções durante o fluxo de port.
- `Editor` e `main.dart` compilam; a aplicação demo roda com o núcleo atual enquanto o restante das partículas ainda é traduzido.
- `dart analyze` retorna 39 avisos (principalmente imports redundantes e formatação) e nenhum erro — sinal de que as pendências são funcionalidade, não compilação.

## Progresso Recente
- Reescrita do esqueleto de `core/draw/draw.dart`, com criação de páginas, escala dinâmica, painter style e pontos de injeção para módulos futuros.
- Harden em `core/event/canvas_event.dart`, evitando chamadas em módulos ainda vazios.
- Revisão do fluxo de inicialização em `editor/index.dart`, liberando a cadeia `Editor -> Draw -> ContextMenu/Shortcut`.

## Indicadores de Qualidade
- `dart analyze` (2024-xx-xx) → 39 avisos: 4 imports não usados em `editor/index.dart`, cadeia de imports redundantes em `main.dart`/`mock.dart`, preferências de estilo (`prefer_final_fields`, `prefer_is_empty`) e interpolações supérfluas.
- Nenhum teste E2E executado após as alterações recentes; rodar `dart test` continua recomendado depois das próximas portas críticas.

## Inventário "TODO: Translate" (74 arquivos)
- Desafios maiores concentram-se no subsistema `draw` (frames, partículas, controles e interações), seguidos por workers/observers/actuator.
- Agrupamento por área: Draw-Frame (10), Draw-Particle (25), Draw-Control (9), Draw-Interactive (3), Draw-RichText (4), ContextMenu (3), Actuator (2), Event (3), Worker (5), Observer (2), Zone (2), Utils (2), Plugins (2), History (1), I18n (1).

```text
lib/src/editor/core/actuator/actuator.dart
lib/src/editor/core/actuator/handlers/position_context_change.dart
lib/src/editor/core/contextmenu/context_menu.dart
lib/src/editor/core/contextmenu/menus/image_menus.dart
lib/src/editor/core/contextmenu/menus/table_menus.dart
lib/src/editor/core/draw/control/checkbox/checkbox_control.dart
lib/src/editor/core/draw/control/control.dart
lib/src/editor/core/draw/control/date/date_control.dart
lib/src/editor/core/draw/control/interactive/control_search.dart
lib/src/editor/core/draw/control/number/number_control.dart
lib/src/editor/core/draw/control/radio/radio_control.dart
lib/src/editor/core/draw/control/richtext/border.dart
lib/src/editor/core/draw/control/select/select_control.dart
lib/src/editor/core/draw/control/text/text_control.dart
lib/src/editor/core/draw/frame/background.dart
lib/src/editor/core/draw/frame/badge.dart
lib/src/editor/core/draw/frame/footer.dart
lib/src/editor/core/draw/frame/header.dart
lib/src/editor/core/draw/frame/line_number.dart
lib/src/editor/core/draw/frame/margin.dart
lib/src/editor/core/draw/frame/page_border.dart
lib/src/editor/core/draw/frame/page_number.dart
lib/src/editor/core/draw/frame/placeholder.dart
lib/src/editor/core/draw/frame/watermark.dart
lib/src/editor/core/draw/interactive/area.dart
lib/src/editor/core/draw/interactive/group.dart
lib/src/editor/core/draw/interactive/search.dart
lib/src/editor/core/draw/particle/block/block_particle.dart
lib/src/editor/core/draw/particle/block/modules/base_block.dart
lib/src/editor/core/draw/particle/block/modules/i_frame_block.dart
lib/src/editor/core/draw/particle/block/modules/video_block.dart
lib/src/editor/core/draw/particle/checkbox_particle.dart
lib/src/editor/core/draw/particle/date/date_particle.dart
lib/src/editor/core/draw/particle/date/date_picker.dart
lib/src/editor/core/draw/particle/hyperlink_particle.dart
lib/src/editor/core/draw/particle/image_particle.dart
lib/src/editor/core/draw/particle/latex/la_tex_particle.dart
lib/src/editor/core/draw/particle/latex/utils/hershey.dart
lib/src/editor/core/draw/particle/latex/utils/la_tex_utils.dart
lib/src/editor/core/draw/particle/latex/utils/symbols.dart
lib/src/editor/core/draw/particle/line_break_particle.dart
lib/src/editor/core/draw/particle/list_particle.dart
lib/src/editor/core/draw/particle/page_break_particle.dart
lib/src/editor/core/draw/particle/previewer/previewer.dart
lib/src/editor/core/draw/particle/radio_particle.dart
lib/src/editor/core/draw/particle/separator_particle.dart
lib/src/editor/core/draw/particle/subscript_particle.dart
lib/src/editor/core/draw/particle/superscript_particle.dart
lib/src/editor/core/draw/particle/table/table_operate.dart
lib/src/editor/core/draw/particle/table/table_particle.dart
lib/src/editor/core/draw/particle/table/table_tool.dart
lib/src/editor/core/draw/particle/text_particle.dart
lib/src/editor/core/draw/richtext/abstract_rich_text.dart
lib/src/editor/core/draw/richtext/highlight.dart
lib/src/editor/core/draw/richtext/strikeout.dart
lib/src/editor/core/draw/richtext/underline.dart
lib/src/editor/core/event/global_event.dart
lib/src/editor/core/event/handlers/input.dart
lib/src/editor/core/event/handlers/keydown/enter.dart
lib/src/editor/core/history/history_manager.dart
lib/src/editor/core/i18n/i18n.dart
lib/src/editor/core/observer/mouse_observer.dart
lib/src/editor/core/observer/selection_observer.dart
lib/src/editor/core/worker/worker_manager.dart
lib/src/editor/core/worker/works/catalog.dart
lib/src/editor/core/worker/works/group.dart
lib/src/editor/core/worker/works/value.dart
lib/src/editor/core/worker/works/word_count.dart
lib/src/editor/core/zone/zone.dart
lib/src/editor/core/zone/zone_tip.dart
lib/src/editor/utils/index.dart
lib/src/editor/utils/print.dart
lib/src/plugins/copy/index.dart
lib/src/plugins/markdown/index.dart
```

## Próximas Ações
- Priorizar o fechamento do pipeline de renderização: portar `draw/particle` essenciais (text, list, table, hyperlink) e `draw/frame/*` para destravar exibição completa.
- Implementar observadores (`mouse`/`selection`) e `history_manager` para permitir edição real com undo/redo.
- Portar `worker_manager` + tarefas (`catalog`, `group`, `value`, `word_count`) antes de habilitar funcionalidades assíncronas da UI.
- Migrar os plugins `copy` e `markdown` assim que o núcleo estiver funcional, garantindo paridade com a versão TypeScript.
- Encerrar a etapa com limpeza de imports e execução de `dart analyze` + smoke tests (`dart test test/e2e/editor_smoke_test.dart`).
