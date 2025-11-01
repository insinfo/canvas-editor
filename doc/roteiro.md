# Roteiro de Tradução
port from C:\MyDartProjects\canvas-editor-port\typescript\src to C:\MyDartProjects\canvas-editor-port\lib

## Estado Atual
- Infra de boot do editor estabilizada: `Draw` agora expõe container, escala, `getI18n()` e `destroy()`, permitindo que `Editor` inicialize menus, atalhos e limpeza sem acessar APIs ausentes.
- Eventos de canvas seguram execuções enquanto `RangeManager`, `Position` e partículas não estiverem disponíveis, evitando exceções durante o fluxo de port.
- `Editor` e `main.dart` compilam; a aplicação demo roda com o núcleo atual enquanto o restante das partículas ainda é traduzido.
- `dart analyze` retorna 39 avisos (principalmente imports redundantes e formatação) e nenhum erro — sinal de que as pendências são funcionalidade, não compilação.

## Progresso Recente
- Porta `core/draw/particle/separator_particle.dart`, habilitando traçado de linhas com suporte a dash e espessura escalonada.
- Porta `core/draw/particle/radio_particle.dart`, cobrindo interação e desenho de radios alinhados verticalmente conforme opções do editor.
- Porta `core/draw/particle/checkbox_particle.dart`, habilitando alternância visual e interação com `ListParticle` via `Draw.getCheckboxParticle()`.
- Porta `core/draw/particle/list_particle.dart`, incluindo cálculo de largura por estilo, renderização de marcadores/checkbox e `Draw.spliceElementList` para manipular listas.
- Porta `core/draw/particle/hyperlink_particle.dart`, com popup DOM reutilizável, abertura em nova aba e fallback da cor padrão de hyperlink.
- Porta `core/draw/particle/page_break_particle.dart`, renderizando texto traduzível com linhas tracejadas alinhadas às margens escalonadas.
- Porta `core/draw/particle/subscript_particle.dart`, mantendo o deslocamento vertical relativo à altura da métrica da linha.
- Porta `core/draw/particle/superscript_particle.dart`, espelhando o deslocamento superior com reutilização do estilo do elemento.
- Porta `core/draw/particle/table/table_particle.dart`, garantindo geometria, seleção e desenho de células.
- Porta `core/draw/particle/table/table_tool.dart`, espelhando o UI DOM para seleção/redimensionamento com compatibilidade de eventos.
- Porta `core/draw/particle/table/table_operate.dart`, cobrindo inserção/remoção de linhas e colunas, mesclagem/divisão e ajustes de estilo.
- Porta `core/draw/particle/previewer/previewer.dart`, habilitando redimensionamento via handles DOM, pré-visualização com zoom/rotação e download direto da imagem.
- Porta `core/draw/particle/image_particle.dart`, lidando com cache, fallback SVG e espelhando o DOM flutuante para arrastar imagens flutuantes.
- Porta `plugins/copy/index.dart`, adicionando override seguro de `executeCopy` para inserir textos de copyright antes de delegar ao fluxo padrão.
- Porta `plugins/markdown/index.dart`, habilitando conversão básica de Markdown em `IElement` antes de inserir no documento pelo novo hook de comando.
- Porta `utils/print.dart`, recriando o fluxo de impressão em iframe com cálculo automático de `@page` conforme dimensões configuradas.
- Porta `core/draw/frame/margin.dart`, gerando indicadores de margem escalonados com fallback de cor e suporte a `PageMode.continuity`.
- Porta `core/draw/richtext/abstract_rich_text.dart`, expondo buffer reutilizável para desenhos contínuos de decoração.
- Porta `core/draw/richtext/underline.dart`, incluindo estilos contínuos/dashed/dotted/double/wavy ajustados pela escala do editor.
- Porta `core/draw/richtext/highlight.dart`, aplicando preenchimento translúcido com alpha configurável.
- Porta `core/draw/richtext/strikeout.dart`, desenhando linha central escalonada com fallback seguro de cor.
- Porta `core/draw/frame/page_number.dart`, formatando numeradores com suporte a plantilla `{pageNo}/{pageCount}` e algarismos chineses.
- Porta `core/draw/frame/watermark.dart`, cobrindo modos texto/imagem com cache, repetição em padrão e reload seguro.
- Porta `core/draw/particle/latex/utils/la_tex_utils.dart`, espelhando tokenização, parser, planejamento geométrico e exportação em polilinhas/SVG/PDF.
- Porta `core/draw/particle/latex/la_tex_particle.dart`, carregando SVG gerado e cacheando imagens para renderizar fórmulas com o mesmo fluxo de imagens.
- Porta `core/draw/particle/date/date_picker.dart`, replicando o popup DOM, alternância data/hora e callbacks de envio com formatação localizável.
- Porta `core/draw/particle/date/date_particle.dart`, sincronizando `DatePicker` com o documento ao inserir formatos localizados e reposicionar o range.
- Porta `core/draw/particle/latex/utils/hershey.dart`, compilando fontes vetoriais Hershey em cache para cálculo rápido de bounding boxes na renderização LaTeX.

## Indicadores de Qualidade
- `dart analyze` (2024-xx-xx) → 58 avisos: imports redundantes em `main.dart`/`mock.dart`, preferências de estilo (`prefer_final_fields`, `prefer_is_empty`) e interpolações supérfluas — sem erros.
- Nenhum teste E2E executado após as alterações recentes; rodar `dart test` continua recomendado depois das próximas portas críticas.

## Inventário "TODO: Translate" (43 arquivos)
- Desafios maiores concentram-se no subsistema `draw` (frames, partículas, controles e interações), seguidos por workers/observers/actuator.
- Agrupamento por área: Draw-Frame (8), Draw-Particle (16), Draw-Control (9), Draw-Interactive (3), Draw-RichText (0), ContextMenu (3), Actuator (2), Event (3), Worker (5), Observer (2), Zone (2), Utils (1), Plugins (0), History (1), I18n (1).

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
lib/src/editor/core/draw/frame/badge.dart
lib/src/editor/core/draw/frame/footer.dart
lib/src/editor/core/draw/frame/header.dart
lib/src/editor/core/draw/frame/line_number.dart
lib/src/editor/core/draw/frame/page_border.dart
lib/src/editor/core/draw/frame/placeholder.dart
lib/src/editor/core/draw/interactive/area.dart
lib/src/editor/core/draw/interactive/group.dart
lib/src/editor/core/draw/interactive/search.dart
lib/src/editor/core/draw/particle/block/block_particle.dart
lib/src/editor/core/draw/particle/block/modules/base_block.dart
lib/src/editor/core/draw/particle/block/modules/i_frame_block.dart
lib/src/editor/core/draw/particle/block/modules/video_block.dart
lib/src/editor/core/draw/particle/latex/utils/symbols.dart
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
```

## Próximas Ações
- Priorizar o fechamento do pipeline de renderização: portar `draw/particle` essenciais (list, table, hyperlink) e `draw/frame/*` para destravar exibição completa.
- Implementar observadores (`mouse`/`selection`) e `history_manager` para permitir edição real com undo/redo.
- Portar `worker_manager` + tarefas (`catalog`, `group`, `value`, `word_count`) antes de habilitar funcionalidades assíncronas da UI.
- Consolidar utilitários restantes (`utils/index.dart`) e iniciar `draw/frame/*` para expor cabeçalho/rodapé/badge no rendering.
- Encerrar a etapa com limpeza de imports e execução de `dart analyze` + smoke tests (`dart test test/e2e/editor_smoke_test.dart`).
