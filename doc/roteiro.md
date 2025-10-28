# Roteiro de Tradução (Atualizado em 28/10/2025)
port from C:\MyDartProjects\canvas-editor-port\typescript\src to C:\MyDartProjects\canvas-editor-port\lib
## Estado Atual
- Fundamentos concluídos: enums centrais, grande parte das interfaces e constantes de elementos migradas para Dart.
- Infra de atalhos portada: utilitários `ua.dart` e `hotkey.dart`, dados de atalhos e classe `Shortcut` já operando.
- Conjuntos de dados recentes: `ElementStyleKey`, `TableOrder`, configurações de título, watermark e listas espelham o TypeScript; defaults de background, badge, checkbox, control, cursor, header/footer, group e regras de modo do editor já disponíveis em Dart.
- Interfaces específicas (área, controle, evento, título, watermark, etc.) adaptadas para classes Dart com construtores nomeados.
- `dart analyze` executado com avisos herdados apenas sobre convenções de nomes; nenhum erro funcional introduzido.

## Métricas de Progresso
- Port geral: 129 de 218 arquivos TypeScript migrados (~59% concluído, ~41% restante).
- Constantes em `lib/src/editor/dataset/constant`: 27 de 27 migradas (100% concluído, 0% restante).
- Arquivos ainda sem implementação efetiva: 89 (lista detalhada em "Pendências de Tradução").
- *Total recalculado para 218 arquivos após mapear os handlers recém-incluídos na fila.*

## Pendências de Tradução
Total pendente: 85 arquivos

### components (2 arquivos)
- `lib/src/components/dialog/dialog.dart`
- `lib/src/components/signature/signature.dart`

### editor (83 arquivos)
- `lib/src/editor/core/actuator/actuator.dart`
- `lib/src/editor/core/actuator/handlers/position_context_change.dart`
- `lib/src/editor/core/contextmenu/context_menu.dart`
- `lib/src/editor/core/contextmenu/menus/control_menus.dart`
- `lib/src/editor/core/contextmenu/menus/global_menus.dart`
- `lib/src/editor/core/contextmenu/menus/hyperlink_menus.dart`
- `lib/src/editor/core/contextmenu/menus/image_menus.dart`
- `lib/src/editor/core/contextmenu/menus/table_menus.dart`
- `lib/src/editor/core/draw/control/checkbox/checkbox_control.dart`
- `lib/src/editor/core/draw/control/control.dart`
- `lib/src/editor/core/draw/control/date/date_control.dart`
- `lib/src/editor/core/draw/control/interactive/control_search.dart`
- `lib/src/editor/core/draw/control/number/number_control.dart`
- `lib/src/editor/core/draw/control/radio/radio_control.dart`
- `lib/src/editor/core/draw/control/richtext/border.dart`
- `lib/src/editor/core/draw/control/select/select_control.dart`
- `lib/src/editor/core/draw/control/text/text_control.dart`
- `lib/src/editor/core/draw/draw.dart`
- `lib/src/editor/core/draw/frame/background.dart`
- `lib/src/editor/core/draw/frame/badge.dart`
- `lib/src/editor/core/draw/frame/footer.dart`
- `lib/src/editor/core/draw/frame/header.dart`
- `lib/src/editor/core/draw/frame/line_number.dart`
- `lib/src/editor/core/draw/frame/margin.dart`
- `lib/src/editor/core/draw/frame/page_border.dart`
- `lib/src/editor/core/draw/frame/page_number.dart`
- `lib/src/editor/core/draw/frame/placeholder.dart`
- `lib/src/editor/core/draw/frame/watermark.dart`
- `lib/src/editor/core/draw/interactive/area.dart`
- `lib/src/editor/core/draw/interactive/group.dart`
- `lib/src/editor/core/draw/interactive/search.dart`
- `lib/src/editor/core/draw/particle/block/block_particle.dart`
- `lib/src/editor/core/draw/particle/block/modules/base_block.dart`
- `lib/src/editor/core/draw/particle/block/modules/i_frame_block.dart`
- `lib/src/editor/core/draw/particle/block/modules/video_block.dart`
- `lib/src/editor/core/draw/particle/checkbox_particle.dart`
- `lib/src/editor/core/draw/particle/date/date_particle.dart`
- `lib/src/editor/core/draw/particle/hyperlink_particle.dart`
- `lib/src/editor/core/draw/particle/image_particle.dart`
- `lib/src/editor/core/draw/particle/latex/la_tex_particle.dart`
- `lib/src/editor/core/draw/particle/latex/utils/hershey.dart`
- `lib/src/editor/core/draw/particle/latex/utils/la_tex_utils.dart`
- `lib/src/editor/core/draw/particle/latex/utils/symbols.dart`
- `lib/src/editor/core/draw/particle/line_break_particle.dart`
- `lib/src/editor/core/draw/particle/list_particle.dart`
- `lib/src/editor/core/draw/particle/page_break_particle.dart`
- `lib/src/editor/core/draw/particle/previewer/previewer.dart`
- `lib/src/editor/core/draw/particle/radio_particle.dart`
- `lib/src/editor/core/draw/particle/separator_particle.dart`
- `lib/src/editor/core/draw/particle/subscript_particle.dart`
- `lib/src/editor/core/draw/particle/superscript_particle.dart`
- `lib/src/editor/core/draw/particle/table/table_operate.dart`
- `lib/src/editor/core/draw/particle/table/table_particle.dart`
- `lib/src/editor/core/draw/particle/table/table_tool.dart`
- `lib/src/editor/core/draw/particle/text_particle.dart`
- `lib/src/editor/core/draw/richtext/abstract_rich_text.dart`
- `lib/src/editor/core/draw/richtext/highlight.dart`
- `lib/src/editor/core/draw/richtext/strikeout.dart`
- `lib/src/editor/core/draw/richtext/underline.dart`
- `lib/src/editor/core/event/canvas_event.dart`
- `lib/src/editor/core/event/eventbus/event_bus.dart`
- `lib/src/editor/core/event/global_event.dart`
- `lib/src/editor/core/history/history_manager.dart`
- `lib/src/editor/core/i18n/i18n.dart`
- `lib/src/editor/core/listener/listener.dart`
- `lib/src/editor/core/observer/mouse_observer.dart`
- `lib/src/editor/core/observer/selection_observer.dart`
- `lib/src/editor/core/override/override.dart`
- `lib/src/editor/core/plugin/plugin.dart`
- `lib/src/editor/core/register/register.dart`
- `lib/src/editor/core/worker/worker_manager.dart`
- `lib/src/editor/core/worker/works/catalog.dart`
- `lib/src/editor/core/worker/works/group.dart`
- `lib/src/editor/core/worker/works/value.dart`
- `lib/src/editor/core/worker/works/word_count.dart`
- `lib/src/editor/core/zone/zone.dart`
- `lib/src/editor/core/zone/zone_tip.dart`
- `lib/src/editor/index.dart`
- `lib/src/editor/utils/print.dart`

### main (1 arquivos)
- `lib/src/main.dart`

### mock (1 arquivos)
- `lib/src/mock.dart`

### plugins (2 arquivos)
- `lib/src/plugins/copy/index.dart`
- `lib/src/plugins/markdown/index.dart`

## Próximas Entregas (Curto Prazo)
- Portar `lib/src/editor/core/event/canvas_event.dart`, consolidando a malha de eventos de mouse/teclado para preparar os handlers restantes.
- Completar a tradução de `utils/element.ts` para Dart e validar integração com os novos helpers (`deepClone*`, `splitText`).
- Revisar `Command.ts` para remover proxies dinâmicos remanescentes e amarrar os comandos ao adaptador Dart agora completo.
- Revisar utilitários de `option` para garantir cobertura de testes e preparar cenários de atualização dinâmica.

## Marcos Intermediários
- **Core de comandos:** após `CommandAdapt`, validar chamadas dos atalhos convertendo callbacks dinâmicos em implementações reais.
- **Gerenciamento de seleção:** concluir `RangeManager`, `Position` e observadores relacionados antes de avançar para desenho.
- **Desenho e tabela:** migrar `Draw`, partículas de tabela e utilitários após concluir constantes/enum de tabela.
- **UI auxiliar:** portar componentes de diálogo, assinatura e menus após estabilizar a base core.

## Rotina de Trabalho Recomendada
- Antes de cada bloco: revisar o equivalente TypeScript em `typescript/src/...` e mapear dependências.
- Durante a tradução: replicar a assinatura original, adicionando comentários curtos apenas onde o fluxo não for óbvio.
- Após cada arquivo: executar `dart format <arquivo>` e `dart analyze` (ou por pasta) para garantir consistência.
- Registrar progresso neste roteiro sempre que um módulo relevante for concluído ou uma prioridade mudar.

## Conclusões Recentes
- Portados os handlers `click.dart`, `mousedown.dart`, `mousemove.dart`, `mouseup.dart`, `copy.dart`, `cut.dart` e `drag.dart`, espelhando segmentação por palavra, cache de seleção, arraste/cópia/recorte/posicionamento com suporte a tabelas e integrações com previewer, partículas e controles.
- Portado o handler `keydown/backspace.dart`, cobrindo remoção de elementos ocultos, seleção em tabela e sincronização com controles ativos.
- Portado o handler `keydown/enter.dart`, garantindo quebra de linha com formatação de contexto, preservação seletiva de estilos e interação correta com controles e listas.
- Portado o handler `keydown/delete.dart`, espelhando remoção direta, tabelas, controles embutidos e elementos ocultos antes de reposicionar o cursor.
- Portado o dispatcher `keydown/index.dart`, garantindo disparo de backspace/delete/enter em Dart e migrando os atalhos globais de undo/redo/copy/cut/select/save/esc.
- Portado o handler `keydown/right.dart`, replicando avanço por palavra, salto entre controles no modo formulário e movimentação entre células de tabela.
- Portado o handler `keydown/updown.dart`, assegurando navegação vertical com suporte a seleção estendida e transições de tabela com realinhamento do cursor visível.
- Portado o handler `keydown/tab.dart`, habilitando navegação entre controles no modo formulário e inserção de tabulações com preservação de estilo.
- Portado o handler `keydown/left.dart`, espelhando navegação por palavra, integração com controles em modo formulário e salto entre células de tabela.
- Portado o handler `drop.dart`, alinhando `DataTransfer` para texto/imagem com overrides personalizados antes de acionar `pasteImage`.
- Adicionado `scripts/port_diff.py` para mapear automaticamente arquivos TypeScript sem tradução efetiva e gerar listas em JSON/Markdown.
- Iniciado o pipeline E2E com `test/e2e/editor_smoke_test.dart`, compilando um harness mínimo para Chrome via Puppeteer e garantindo que o canvas seja servido pela aplicação.
- Portados os handlers `composition` e `mouseleave`, espelhando a lógica TypeScript para IME/input e bloqueio de seleção fora do canvas.
- O smoke test agora baixa o Chromium via `downloadChrome` e executa headless com `--no-sandbox`, evitando falhas de ambiente.
- Portados `RangeManager` e `Position`, garantindo paridade no cálculo de seleção, contexto de cursor e ajustes de elementos flutuantes/tablados em relação ao TypeScript.
- Adicionada `Command` com proxies para `CommandAdapt`, disponibilizando os comandos Dart em `lib/src/editor/core/command/command.dart` enquanto o adaptador completo segue em tradução.
- Portado `utils/clipboard.dart`, garantindo leitura/gravação estruturada no clipboard (localStorage e API nativa), além da serialização completa de `IElement` e controles aninhados.
- Portado `formatElementContext` com `FormatElementContextOption` e `_overwriteElementAttributes`, garantindo cópia de contexto (tabela, área, linha e título) respeitando permissões do modo design.
- Portados `splitListElement`, `groupElementListByRowFlex`, `convertElementToDom` e `createDomFromElementList`, habilitando geração/copiar de DOM com suporte a tabelas, listas, blocos de vídeo/iframe e controles alinhados por rowFlex.
- Portado `zipElementList`, incluindo helpers de clone profundo (tabelas, controles, áreas) e compressão de títulos/listas/hiperlinks, com `_assignElementAttributes`, `_applyControlStyleFromElement` e `_copyTdZipAttributes` espelhando o comportamento TypeScript.
- Adicionados `isSameElementExceptValue` e `pickElementAttr`, incluindo helpers de acesso/clone de atributos para preparar a migração de `zipElementList` e demais rotinas de compactação.
- `formatElementList` agora cobre Título, Lista, Área, Tabela, Hyperlink, Data e rotinas de Controle (prefixo/placeholder/checkbox/radio/select), além de normalizar strings longas e quebras de linha com `_cloneElement`/`unzipElementList`.
- Implementado `_cloneElement` e `unzipElementList` em Dart para preparar a expansão da tradução (ainda faltam os demais utilitários complexos desse módulo).
- Mapas de estilo e tipo de lista (`list.dart`) disponíveis para lógica de rich text.
- Inclusão dos enums `MouseEventButton`, `ElementStyleKey`, `TableOrder` e outros suportes de shortcuts.
- Ajustes contínuos nas interfaces para refletir tipos opcionais e coleções específicas do Dart.
- Iniciada tradução de `CommandAdapt` com comandos globais e formatação básica em `lib/src/editor/core/command/command_adapt.dart`; métodos restantes serão migrados gradualmente.
- Ampliada tradução de `CommandAdapt` cobrindo título, listas, ajustes de linha e operações básicas de tabela, mantendo helpers utilitários para mapeamento de tamanho de heading.
- Estendidos os comandos de `CommandAdapt` para hyperlink, separador, watermark, inserção de imagens e fluxo de busca/impressão; adicionados `insertElementList`, `appendElementList` e stubs auxiliares (`printImageBase64`, `pasteByApi`) para preparar integrações pendentes.
- Portados os blocos finais de `CommandAdapt` para controles/títulos/áreas: `locationControl`, `insertControl`, `getPositionContextByEvent`, `focus`, `insertTitle`, e rotinas de localização e atualização de áreas já espelham o TypeScript.
- Validada a paridade de `CommandAdapt`: 134 métodos expostos no TypeScript agora têm equivalentes em Dart (`getRange` renomeado para alinhar com a API e comparações automatizadas confirmam cobertura completa).
- Atualizado `Command` para depender diretamente de `CommandAdapt` tipado, removendo `dynamic` e alinhando os retornos (`getValue`, `getValueAsync`, `getHTML`, `getText`, `getAreaValue`, `getPaperMargin`) com as interfaces Dart.
