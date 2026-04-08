# Roteiro de Tradução
port from C:\MyDartProjects\canvas-editor-port\typescript\src to C:\MyDartProjects\canvas-editor-port\lib

continuar portando o que falta de C:\MyDartProjects\canvas-editor-port\typescript para dart C:\MyDartProjects\canvas-editor-port\lib\src e testando e atualizando o roteiro

## Estado Atual
- A demo web do editor agora tem casca própria em Dart: `lib/src/editor.dart` concentra o bootstrap da aplicação, `web/main.dart` inicializa com fallback seguro para DOM pronto e `lib/src/main.dart` foi removido do fluxo antigo.
- A interface da demo foi portada para o lado Dart/web com toolbar, rodapé, catálogo, busca/substituição, controles, paginação, modo de página, papel, tela cheia, comentários e caixas de diálogo em `web/index.html`, `web/styles.css`, `web/assets/images/*` e `web/favicon.png`.
- O núcleo de renderização em `lib/src/editor/core/draw/draw.dart` foi ampliado e reorganizado para ficar muito mais próximo do pipeline do TypeScript: `_drawPage`, `_drawFloat`, `_lazyRender`, `_immediateRender`, `render()`, `setCursor()` e sincronização de canvases/páginas seguem o fluxo principal do editor original.
- A renderização deixou de piscar no uso normal: a atualização de métricas/canvas passou a evitar reset de `width`/`height` quando nada mudou, o que eliminou a limpeza completa do canvas a cada tecla.
- O cursor visual voltou a funcionar de forma estável: `cursor.dart` e `cursor_agent.dart` já estavam no caminho certo, e a folha `web/styles.css` passou a incluir `.ce-inputarea`, `.ce-cursor`, animação de blink e regras faltantes do port web.
- O popup de data deixou de vazar no documento: `date_picker.dart` agora nasce oculto e alterna `display` explicitamente; além disso a CSS do date picker foi portada para a stylesheet carregada pela demo.
- O conteúdo visível da demo foi localizado para português: `mock.dart`, `i18n.dart`, `option.dart`, `web/index.html`, `dialog.dart` e `signature.dart` deixaram de depender de textos em chinês no fluxo principal.
- A locale padrão do editor passou para `ptBR`, com mapa de traduções correspondente e mock de demonstração em português.
- O tooltip de zona e o menu de contexto foram alinhados com a demo web: `zone_tip.dart`, `context_menu.dart` e `web/styles.css` agora tratam posicionamento fixo, visibilidade e estilo corretos.
- O sistema de controle embutido ficou mais robusto: `control.dart` já possui `initControl()`, `ensureActiveControl()`, reativação e destruição mais previsíveis, além de integração melhor com render e range.
- Os fluxos de mouse, digitação e navegação foram estabilizados em `mousedown.dart`, `mousemove.dart`, `mouseup.dart`, `click.dart`, `drag.dart`, `input.dart`, `cut.dart`, `backspace.dart`, `delete.dart`, `enter.dart`, `left.dart`, `right.dart` e `tab.dart`.
- Os erros de tipo em runtime na navegação de controles foram corrigidos: chamadas que antes passavam `Map<String, dynamic>` agora usam objetos tipados como `IControlInitOption`, `IMoveCursorResult` e `IInitNextControlOption`.
- O cálculo de posição/range ficou mais resiliente: `position.dart`, `range_manager.dart` e o novo helper `mouse_offset.dart` tratam melhor offsets, seleção, contexto de controle e coordenadas vindas do DOM.
- O E2E deixou de ser apenas um smoke test de canvas vazio: `test/e2e/editor_smoke_test.dart` agora sobe a shell real, inicializa o editor completo e valida boot, digitação, backspace, setas, expansão de seleção e `Enter`.
- `.gitignore` foi atualizado para ignorar artefatos locais adicionais, incluindo `build/`.

## Mudanças Consolidadas Desta Rodada

### 1. Shell web portada e ativada
- `lib/src/editor.dart` virou a contraparte prática da antiga demo DOM/Vite do TypeScript no lado Dart.
- `web/index.html` foi expandido de uma página mínima com `<canvas>` para a estrutura completa da demo, incluindo menus, painéis, rodapé e áreas auxiliares.
- `web/styles.css` saiu de vazio para uma folha grande com a base visual da demo, incluindo toolbar, catálogo, diálogos, assinatura, menu de contexto, cursor, date picker e layout geral.
- `web/assets/images/*` e `web/favicon.png` foram adicionados para suportar a iconografia da UI portada.
- `web/main.dart` passou a inicializar o app corretamente tanto quando o DOM já está pronto quanto quando ainda está carregando.

### 2. Bootstrap e demo reorganizados
- O código antigo de bootstrap concentrado em `lib/src/main.dart` foi removido.
- O bootstrap real foi extraído e reorganizado em `lib/src/editor.dart`, deixando a aplicação web mais modular e mais alinhada com a demo TypeScript.
- `mock.dart` foi refeito para servir um documento de demonstração em português, com controles embutidos, comentários, hyperlink, lista, assinatura e data.

### 3. Localização para português
- `lib/src/editor/core/i18n/i18n.dart` recebeu `ptBR` e fallback coerente com a nova demo.
- `lib/src/editor/utils/option.dart` passou a usar `ptBR` como locale padrão.
- `lib/src/components/dialog/dialog.dart` e `lib/src/components/signature/signature.dart` foram traduzidos para português na UI visível.
- `web/index.html` teve rótulos, títulos e menus da shell traduzidos para português.
- `lib/src/mock.dart` também passou a refletir esse idioma no conteúdo inicial, comentários e placeholders.

### 4. Correções visuais e de UX
- O cursor voltou a aparecer e piscar corretamente com a adição da CSS faltante da demo original.
- O flicker ao digitar deixou de acontecer por causa da correção em `draw.dart` que evita reset desnecessário de canvas.
- O `ce-time-wrap` não aparece mais como números soltos no final da página porque o date picker agora nasce escondido e tem a CSS correspondente carregada.
- O `ce-zone-tip` deixou de seguir o mouse de forma errada e passou a usar posicionamento mais apropriado.
- O menu de contexto recebeu estilo e estrutura para funcionar de forma consistente com a shell web.

### 5. Renderização e pipeline principal
- `lib/src/editor/core/draw/draw.dart` recebeu a maior consolidação do port nesta rodada: renderização imediata/lazy, desenho por página, floats, placeholder, busca, áreas, watermark, line number, page number e sincronização com observadores ficaram mais próximos do TypeScript.
- `background.dart`, `watermark.dart`, `line_number.dart`, `page_number.dart`, `search.dart` e arquivos correlatos foram ajustados para integrar com o novo pipeline.
- A lógica de primeira renderização, envio de histórico, eventos de `contentChange`, `pageSizeChange` e atualização de UI passou a acontecer num fluxo mais coerente.

### 6. Controles embutidos, posição e navegação
- `control.dart` agora expõe e usa `initControl()` de forma explícita, eliminando a antiga pendência registrada no roteiro anterior.
- Os controles `text`, `select`, `checkbox`, `radio`, `date` e `number` foram revisitados junto com o ciclo de highlight/awake/destroy.
- `position.dart` foi ajustado para usar tipos corretos ao mover o cursor dentro de controles.
- `left.dart`, `right.dart` e `tab.dart` passaram a usar `IInitNextControlOption` em vez de mapas soltos.
- `range_manager.dart` ganhou tratamento mais defensivo para coordenadas e seleção.

### 7. Eventos, seleção e mouse
- `mousedown.dart`, `mousemove.dart` e `mouseup.dart` foram alterados para reduzir flicker de seleção, melhorar cálculo de offset e evitar inconsistências em arrasto/seleção.
- `mouse_offset.dart` foi adicionado para padronizar a leitura de coordenadas do ponteiro.
- `click.dart`, `drag.dart`, `input.dart`, `cut.dart`, `backspace.dart`, `delete.dart` e `enter.dart` foram revisados no fluxo de edição.

### 8. Partículas e componentes auxiliares
- `date_picker.dart` recebeu correções funcionais importantes de visibilidade e alternância entre calendário e lista de tempo.
- `image_particle.dart` foi ajustado no tratamento de imagens/data URL.
- `hyperlink_particle.dart` e módulos de bloco/frame/interativos também tiveram ajustes para acompanhar a nova shell e o pipeline do draw.
- `dialog.dart` e `signature.dart` foram reestruturados e traduzidos, mantendo a funcionalidade em cima da UI web portada.

### 9. Testes e suporte de execução
- `test/e2e/editor_smoke_test.dart` agora sobe uma cópia da pasta `web`, compila `main.dart` temporário e expõe helpers JS para inspecionar conteúdo e range do editor durante o teste.
- O E2E passou a validar comportamento real do editor em vez de um canvas de placeholder.
- `pubspec.yaml` mantém as dependências necessárias para esse fluxo de E2E com `puppeteer`, `shelf` e `shelf_static`.
- `.github/copilot-instructions.md` foi adicionada para registrar convenções operacionais do repositório durante o port.

## Pendências Atuais Confirmadas
- `lib/src/editor/utils/element.dart`: a conversão de conteúdo LaTeX para SVG no fluxo HTML -> `IElement` ainda não foi portada; o comentário continua registrando essa lacuna.
- Ainda faltam validações mais profundas de paridade em cenários avançados de tabela, controles embutidos complexos e fluxos longos de edição contínua.
- O E2E melhorou bastante, mas ainda não cobre copy/paste, undo/redo, drag-selection real com mouse, contexto de tabela, date picker interativo e menu de contexto ponta a ponta.
- O port funcional da demo web está bem mais próximo do TypeScript, mas ainda há espaço para acabamento fino de comportamento visual, atalhos e estados ativos da toolbar.

## Reclassificação das Pendências Antigas
- `main.ts`: na prática, a lacuna foi fechada pelo conjunto `lib/src/editor.dart` + `web/index.html` + `web/main.dart` + `web/styles.css`; não existe uma cópia literal 1:1, mas agora existe uma contraparte funcional da demo web no lado Dart.
- `editor/core/draw/control/Control.ts`: a pendência antiga sobre `initControl()` não se aplica mais, porque o método já existe e participa do fluxo atual.
- `vite-env.d.ts` e `editor/types/index.d.ts`: continuam sem contraparte formal, mas são itens de tipagem/barrel do projeto TypeScript e não bloqueiam a demo funcional em Dart.

## Próximas Ações
- Portar a conversão LaTeX -> SVG em `lib/src/editor/utils/element.dart`.
- Expandir o E2E para cobrir copy/paste, undo/redo, seleção com mouse, controles e menu de contexto.
- Validar cenários avançados de tabela e controle embutido após a estabilização da shell web.
- Rodar uma rodada maior de validação manual da demo web agora que cursor, date picker, contexto e renderização principal estão mais estáveis.

## Leitura Rápida
- A demo web em Dart deixou de ser um bootstrap mínimo e passou a reproduzir a experiência principal da demo TypeScript com shell completa, assets, CSS e interações básicas reais.
- O maior avanço desta rodada foi deixar o editor utilizável no navegador sem o flicker constante e sem os artefatos visuais do date picker.
- O maior risco remanescente está em paridade fina de comportamentos avançados, não mais na ausência da casca da aplicação.
- Para edição básica de texto, o projeto está significativamente mais perto da versão original do que o roteiro anterior indicava.