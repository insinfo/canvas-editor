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
- Os fluxos de mouse, digitação e navegação foram estabilizados em `mousedown.dart`, `mousemove.dart`, `mouseup.dart`, `click.dart`, `drag.dart`, `input.dart`, `cut.dart`, `backspace.dart`, `delete.dart`, `enter.dart`, `left.dart`, `right.dart`, `home.dart`, `end.dart` e `tab.dart`.
- Os erros de tipo em runtime na navegação de controles foram corrigidos: chamadas que antes passavam `Map<String, dynamic>` agora usam objetos tipados como `IControlInitOption`, `IMoveCursorResult` e `IInitNextControlOption`.
- O cálculo de posição/range ficou mais resiliente: `position.dart`, `range_manager.dart` e o novo helper `mouse_offset.dart` tratam melhor offsets, seleção, contexto de controle e coordenadas vindas do DOM.
- O fluxo HTML -> `IElement` agora também fecha a paridade básica de LaTeX: `lib/src/editor/utils/element.dart` passou a converter conteúdo LaTeX em SVG durante a normalização, preenchendo `width`, `height` e `laTexSVG` como no TypeScript.
- O E2E passou a cobrir inserção de LaTeX no fluxo real do editor: a suíte valida que o elemento inserido recebe `width`, `height` e `laTexSVG` preenchidos durante a normalização.
- O E2E agora cobre operações centrais antes pendentes: copy/paste, undo/redo, colagem de LaTeX via clipboard interno, importação de tabela HTML, inserção de tabela e cenários básicos de controles embutidos já são validados no fluxo real da demo web.
- A toolbar voltou a aplicar fonte e cor sem erro de tipo em runtime: `command_adapt.dart` agora usa `IRangeElementStyle` nos estilos padrão de range, e o E2E passou a cobrir explicitamente essa regressão.
- A shell Dart passou a preservar a seleção ao abrir os pickers nativos de cor e realce, evitando que a toolbar perca o range antes do `change/input` do navegador.
- O repaint rápido do editor voltou a refletir mudanças de estilo sem recomputar todo o layout: `draw.dart` agora sincroniza os `IRowElement` em cache antes de `render(isCompute: false)`, corrigindo o caso em que a cor só aparecia depois de outro comando como `bold`.
- O fluxo de impressão foi realinhado com o TypeScript original em `print.dart`, removendo o cast inválido de `Window` em iframes cross-frame e restaurando a montagem do documento de impressão por `iframe` oculto.
- A impressão voltou a funcionar no navegador sem `TypeError`: `print.dart` passou a chamar `contentWindow`, `document`, `focus()` e `print()` via JS interop no iframe real.
- A configuração de regras do modo `print` avançou mais uma etapa rumo ao upstream TypeScript: `IPrintModeRule`, `option.dart`, `draw.dart` e `control.dart` agora portam `backgroundDisabled` e `filterEmptyControl`, permitindo suprimir o fundo da página e manter ou remover placeholders de controles vazios durante a renderização de impressão.
- O pacote de APIs públicas do `Command` avançou mais uma etapa: o Dart agora expõe `executeHideCursor`, `executeDeleteArea`, `executeJumpControl`, `executeComputeElementListHeight` e `getRemainingContentHeight`, reduzindo a defasagem frente ao upstream TypeScript.
- A lacuna básica de graffiti deixou de ser ausência total: `interface/graffiti.dart`, `utils/option.dart`, `draw/graffiti/graffiti.dart`, `draw.dart`, `command_adapt.dart` e `command.dart` agora suportam `EditorMode.graffiti`, persistência/renderização de `graffiti` por página e a API pública `executeClearGraffiti`.
- A renderização opcional de marcadores de espaço em branco deixou de ser lacuna: `interface/white_space.dart`, `dataset/constant/white_space.dart`, `utils/option.dart`, `draw/particle/white_space_particle.dart` e `draw.dart` agora portam `whiteSpace.disabled/color/radius` e desenham o ponto visual para caracteres `\s`, como no TypeScript.
- `label` deixou de ser lacuna no núcleo Dart: `interface/label.dart`, `dataset/constant/label.dart`, `interface/element.dart`, `utils/option.dart`, `draw/particle/label_particle.dart`, `position.dart` e `mousedown.dart` agora portam `ElementType.label`, estilo do label, cálculo de métricas, render com fundo arredondado e o evento `labelMousedown`.
- O mock padrão da demo Dart agora inclui uma tabela de exemplo, aproximando o documento inicial da shell web do material de referência do TypeScript e exercitando melhor o renderer de tabela fora do caso vazio.
- A serialização pública do editor deixou de corromper o estado vivo ao ler dados: `draw.dart` voltou a compactar o payload de `getValue()` sobre cópias, como no upstream, evitando mutações acidentais em títulos, controles e tabelas durante inspeção/teste.
- A paridade básica de imagem avançou mais uma etapa: `interface/element.dart`, `utils/option.dart`, `image_particle.dart`, `draw.dart`, `command_adapt.dart` e `command.dart` agora expõem, persistem e renderizam `imgCrop` e `imgCaption`, incluindo opções padrão de legenda e as APIs públicas `executeSetImageCrop` e `executeSetImageCaption`.
- A mudança de display de imagem via menu de contexto avançou mais uma etapa: `command_adapt.dart` voltou a inicializar `imgFloatPosition` corretamente ao trocar para `surround`/`floatTop`/`floatBottom`, fechando a divergência local do port em relação ao TypeScript.
- Os controles visuais de edição de tabela da shell web deixaram de depender do vazio: `web/styles.css` agora inclui as regras de `TableTool` portadas do TypeScript, restaurando barras de linha/coluna, botões rápidos de adição, seletor da tabela, guias de resize e áreas de arraste.
- O seed inicial da demo deixou de exibir `\\n` literal no cabeçalho: `lib/src/editor.dart` agora usa quebras de linha reais no documento de exemplo.
- O E2E deixou de ser apenas um smoke test de canvas vazio: `test/e2e/editor_smoke_test.dart` agora sobe a shell real, inicializa o editor completo e valida boot, digitação, backspace, setas, expansão de seleção e `Enter`.
- O E2E agora cobre também crop e legenda de imagem no fluxo real, validando serialização de `imgCrop`/`imgCaption` e mudanças visíveis na exportação da página após `executeSetImageCrop` e `executeSetImageCaption`.
- O E2E agora cobre também a base de graffiti: a suíte valida serialização de `graffiti`, alteração visível na exportação em `EditorMode.graffiti` e limpeza do estado via `executeClearGraffiti`.
- O E2E agora cobre também `whiteSpace`: a suíte liga/desliga os marcadores de espaço via bridge de teste e valida a alteração visual no `getImage()` sem alterar o conteúdo serializado.
- O E2E agora cobre também `label`, validando serialização de `type: label`/`labelId` e o disparo de `labelMousedown` após clique real no canvas.
- A navegação por teclado ficou mais próxima do upstream TypeScript: `keydown/index.dart`, `home.dart` e `end.dart` agora tratam `Home`, `End` e o atalho equivalente `Cmd+Left/Right` no macOS, e o E2E cobre o salto para início/fim da linha com inserção real de texto.
- O E2E agora cobre também a troca de `imgDisplay` pelo menu de contexto da imagem, validando no browser real a submenu `Ajuste do texto`, a transição para `surround`, a criação de `imgFloatPosition` e o retorno para `inline`.
- O E2E agora cobre também expansão de seleção por `Shift+End` e drag-selection real com mouse no canvas, reduzindo a lacuna prática da shell em navegação e seleção básica.
- A shell web voltou a expor a camada visual rica do previewer/resizer de imagem: `web/styles.css` agora inclui as classes do previewer e do resizer, `web/assets/images/` ganhou os ícones faltantes e o E2E passou a validar a abertura do previewer, zoom, rotação e navegação entre imagens no overlay real.
- O previewer de imagem ganhou uma primeira UX concreta de crop interativo no lado Dart: `previewer.dart` agora expõe modo de recorte com seleção por arrasto e ações `Recortar`/`Aplicar`/`Cancelar`, e o E2E valida o fluxo real no DOM conferindo a serialização de `imgCrop` e a mudança visível na exportação da página.
- A UX de crop do previewer deixou de exigir recriação da seleção a cada ajuste: a seleção existente agora pode ser movida e redimensionada por handles no overlay, e o E2E cobre explicitamente o fluxo criar -> mover -> redimensionar -> aplicar no DOM real.
- O E2E agora cobre também menu de contexto mais profundo de tabela no DOM, validando submenus reais para inserir linha abaixo, aplicar alinhamento vertical e trocar a borda da tabela para `empty`.
- O E2E agora cobre também merge/cancel merge e bordas de célula no menu de contexto da tabela, validando no DOM real a seleção cruzada, a mesclagem/desmesclagem e a aplicação de borda superior/diagonal principal na célula.
- O E2E agora cobre também split vertical/horizontal e exclusão da tabela inteira pelo menu de contexto, e o runtime Dart foi corrigido para que o split realmente reduza `colspan`/`rowspan` da célula original em vez de só inserir estrutura extra inconsistente.
- O E2E agora cobre também interações reais adicionais do previewer/resizer de imagem, validando zoom por wheel, pan por drag no previewer e resize por arrasto do handle no resizer.
- A infraestrutura compartilhada do E2E foi extraída para `test/e2e/support/editor_e2e_support.dart`, e a suíte passou a ficar repartida fisicamente por domínio em `test/e2e/editor_e2e_shell.dart`, `test/e2e/editor_e2e_keyboard.dart`, `test/e2e/editor_e2e_image.dart`, `test/e2e/editor_e2e_table.dart`, `test/e2e/editor_e2e_latex_clipboard.dart`, `test/e2e/editor_e2e_annotations.dart`, `test/e2e/editor_e2e_controls.dart` e `test/e2e/editor_e2e_toolbar.dart`, mantendo `test/e2e/editor_e2e_misc.dart` apenas como agregador leve e `test/e2e/editor_smoke_test.dart` como orquestrador único.
- A suíte E2E completa permaneceu verde após os dois avanços mais recentes, fechando 37 testes no fluxo real da demo web com cobertura adicional para crop interativo editável e regras de `print`.
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
- `mock.dart` foi refeito para servir um documento de demonstração em português, com controles embutidos, comentários, hyperlink, lista, assinatura, data e agora também uma tabela de exemplo carregada por padrão.

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
- `home.dart` e `end.dart` foram portados do upstream para fechar a navegação por início/fim de linha, inclusive com expansão por `Shift` e alias de `Cmd+Left/Right` no dispatcher.
- `range_manager.dart` ganhou tratamento mais defensivo para coordenadas e seleção.
- O E2E passou a inserir controles `text` e `checkbox` por comando, verificando placeholder, valor e estrutura básica serializada no documento resultante.

### 7. Eventos, seleção e mouse
- `mousedown.dart`, `mousemove.dart` e `mouseup.dart` foram alterados para reduzir flicker de seleção, melhorar cálculo de offset e evitar inconsistências em arrasto/seleção.
- `mouse_offset.dart` foi adicionado para padronizar a leitura de coordenadas do ponteiro.
- `click.dart`, `drag.dart`, `input.dart`, `cut.dart`, `backspace.dart`, `delete.dart` e `enter.dart` foram revisados no fluxo de edição.

### 8. Partículas e componentes auxiliares
- `date_picker.dart` recebeu correções funcionais importantes de visibilidade e alternância entre calendário e lista de tempo.
- `image_particle.dart` foi ajustado no tratamento de imagens/data URL e o previewer de imagem segue funcional no port Dart.
- `command_adapt.dart` foi ajustado no caminho de `changeImageDisplay()` para ler `coordinate['leftTop']` como mapa Dart real, restaurando a inicialização de `imgFloatPosition` que o upstream já fazia no TypeScript.
- `draw/graffiti/graffiti.dart` foi adicionado com a base funcional do modo graffiti: armazenamento de traços por página, renderização sobre o canvas ativo, limpeza via comando e poda de páginas inválidas após recomputar o documento.
- `label_particle.dart` foi adicionado para espelhar o upstream: o elemento `label` agora desenha fundo arredondado, padding configurável e texto com cor própria em cima das métricas ajustadas no layout.
- `white_space_particle.dart` foi adicionado para espelhar o upstream: quando `whiteSpace.disabled != true`, o draw desenha um ponto centralizado em caracteres de espaço em branco usando cor e raio configuráveis.
- A partícula de imagem agora também aplica crop em canvas, desenha legenda com fallback configurável de fonte/cor/tamanho/topo e substitui `{imageNo}` com base na ordem real das imagens no documento, como no TypeScript.
- O previewer e o resizer de imagem já não dependem mais de estilos ausentes na shell Dart: os seletores `.ce-image-previewer`, `.ce-resizer-selection`, handles, size view e ícones de zoom/rotate/download/navegação voltaram a ter contraparte visual no `web/styles.css`.
- `element.dart` passou a usar `LaTexParticle.convertLaTextToSVG()` no fluxo de normalização, fechando a lacuna que ainda existia ao importar/transformar conteúdo HTML com elementos LaTeX.
- `hyperlink_particle.dart` e módulos de bloco/frame/interativos também tiveram ajustes para acompanhar a nova shell e o pipeline do draw.
- `dialog.dart` e `signature.dart` foram reestruturados e traduzidos, mantendo a funcionalidade em cima da UI web portada.

### 9. Testes e suporte de execução
- `test/e2e/editor_smoke_test.dart` agora sobe uma cópia da pasta `web`, compila `main.dart` temporário e expõe helpers JS para inspecionar conteúdo e range do editor durante o teste.
- O E2E passou a validar comportamento real do editor em vez de um canvas de placeholder.
- A suíte E2E agora também verifica inserção de LaTeX com geração de metadados SVG, cobrindo `laTexSVG`, `width` e `height` no documento resultante.
- A suíte E2E agora cobre copy/paste e undo/redo de seleção textual, colagem de LaTeX via clipboard interno do editor, importação de tabela HTML, inserção programática de tabela e cenários básicos de controles embutidos.
- A suíte E2E passou a validar também que a shell real sobe com uma tabela pré-carregada no mock da demo, cobrindo um caso de renderização de tabela fora do fluxo artificial de documento vazio.
- A suíte E2E agora também verifica que, ao focar uma célula da tabela carregada na demo, os overlays do `TableTool` aparecem no DOM com linhas, colunas, botões rápidos e seletor visíveis.
- A suíte E2E agora cobre também as mutações públicas simples de tabela em um caso sem merge: inserir linha no topo/rodapé, inserir coluna à esquerda/direita e remover uma linha/coluna via `Command`, confirmando que o fluxo básico desses controles já responde como no upstream.
- A suíte E2E agora cobre também a inserção de uma nova tabela em documento já preenchido, ancorando a seleção antes de `Observações finais` no mock e verificando que a tabela pré-existente e os controles já carregados permanecem intactos.
- A suíte E2E também valida aplicação de fonte e cor sobre seleção textual, protegendo o fluxo da toolbar contra regressões de tipagem em runtime.
- A suíte E2E agora também cobre o caminho da própria toolbar de cor, inclusive o cenário em que o picker nativo faz o editor perder foco antes da aplicação da cor.
- A suíte E2E agora também cobre `Home` e `End`, validando no navegador real o salto para o início/fim da linha pela própria pilha de teclado do editor antes da inserção de texto.
- A suíte E2E agora também cobre `Shift+End`, preservando a expansão de seleção até o fim da linha no caminho real de teclado.
- A suíte E2E agora também cobre drag-selection real com mouse sobre texto no canvas, verificando atualização de range sem depender apenas de helpers programáticos.
- A suíte E2E passou a cobrir também as APIs públicas recém-expostas para cursor, cálculo utilitário de altura, navegação programática entre controles e exclusão segura de área inexistente.
- A suíte E2E agora cobre também a nova paridade básica de imagem, inserindo uma imagem SVG determinística, aplicando `executeSetImageCrop` e `executeSetImageCaption`, verificando a serialização dos campos e confirmando alteração no output exportado da página.
- A suíte E2E agora cobre também o menu de contexto específico de imagem no caso de `textWrap`, confirmando a mutação de `imgDisplay` e `imgFloatPosition` no fluxo real da shell.
- A suíte E2E agora cobre também a camada visual do previewer/resizer de imagem na shell web, garantindo a presença do overlay fixo, além de zoom, rotação e navegação real entre imagens no previewer.
- A suíte E2E agora cobre também wheel-zoom, pan por drag e resize por handle no fluxo real do previewer/resizer, verificando mutação visual do overlay e atualização de `width`/`height` da imagem serializada.
- A suíte E2E agora cobre também menu de contexto de tabela no DOM com submenus reais, confirmando inserção de linha abaixo, `verticalAlign: middle` na célula e troca de `borderType` para `empty`.
- A suíte E2E agora cobre também merge/cancel merge e bordas de célula no menu de contexto da tabela, confirmando `colspan` após mesclagem, restauração após cancelar merge e aplicação de `borderTypes`/`slashTypes` na célula.
- A suíte E2E agora cobre também split vertical/horizontal e exclusão de tabela inteira pelo menu de contexto, confirmando a redução real de `colspan`/`rowspan` no split e a remoção completa do elemento `table` no delete.
- A suíte E2E agora cobre também a nova base de graffiti em modo dedicado: injeta um traço determinístico no browser, confirma a serialização em `data.graffiti`, valida a diferença visual no `getImage()` e garante a limpeza por `executeClearGraffiti`.
- A suíte E2E agora cobre também a paridade básica de `whiteSpace`, ativando e desativando o marcador visual sobre texto com espaço e confirmando a mudança do bitmap exportado.
- A suíte E2E agora cobre também a paridade básica de `label`, verificando serialização e o evento `labelMousedown` no fluxo real do canvas.
- `pubspec.yaml` mantém as dependências necessárias para esse fluxo de E2E com `puppeteer`, `shelf` e `shelf_static`.
- `.github/copilot-instructions.md` foi adicionada para registrar convenções operacionais do repositório durante o port.

## Pendências Atuais Confirmadas
- A seleção/edição de imagem ainda não está em paridade total com o original. O Dart já expõe `executeSetImageCrop` e `executeSetImageCaption`, persiste `imgCrop`/`imgCaption`, renderiza ambos no canvas, cobre `imgDisplay` no menu de contexto e agora também valida zoom/rotação/navegação no previewer; o que segue pendente é o acabamento fino da edição visual ponta a ponta, sobretudo resize/drag/crop totalmente interativos e outros fluxos completos de manipulação.
- O previewer de imagem e a opção `imagePreviewerDisabled` já existem no Dart, e a shell agora também cobre wheel-zoom, pan e resize reais além da mera abertura; o que continua pendente é a experiência completa de edição rica por seleção, com validações mais profundas de interação visual ponta a ponta.
- O crop de imagem já tem fluxo visual interativo na shell Dart, com criação, movimentação e redimensionamento da seleção no previewer; o que segue pendente nessa frente é consolidar o acabamento visual e reduzir a sobreposição entre o fluxo antigo de aplicação do crop e o novo fluxo editável.
- A leitura ampliada do upstream TypeScript e dos artefatos de referência em docs/example/cypress/features segue sem apontar uma UI dedicada de crop equivalente ao previewer/resizer; daqui em diante, os ajustes restantes dessa frente tendem a ser acabamento de UX e consolidação do port Dart, não apenas “portar um overlay já pronto”.
- A lacuna explícita de API pública em torno de graffiti foi fechada: `executeClearGraffiti` agora existe no Dart junto com `EditorMode.graffiti` e persistência básica do estado. Vale ainda revisar o upstream para descobrir se sobrou alguma API menor recente fora do radar atual.
- O modo graffiti agora tem base funcional no Dart, com dados por página, renderização no canvas, limpeza por comando e guarda básica nos handlers de mouse. O que segue pendente é acabamento de UX, integração visual mais rica na shell e validação interativa mais profunda do gesto real com mouse.
- `label` já possui contraparte funcional no Dart para renderização básica, serialização e evento de clique; se sobrar algo nessa área, passa a ser acabamento fino ou APIs periféricas do upstream, não mais a ausência do bloco principal.
- Na parte de tabela, o fluxo básico já está coberto no shell Dart para renderização inicial, foco com overlays, mutações públicas simples em tabela sem merge, contexto de tabela com submenus reais e inserção programática de nova tabela sobre documento preenchido.
- Ainda faltam validações mais profundas de paridade em cenários avançados de tabela, como fluxos longos de edição contínua após combinações de merge/split e eventuais cenários de edição mais densos com spans maiores.
- O E2E melhorou bastante, mas ainda não cobre date picker interativo, menu de contexto ponta a ponta em áreas mais amplas e alguns acabamentos mais profundos da edição visual de imagem; no caso de graffiti, a cobertura atual fecha serialização/render/clear, mas ainda falta validação mais profunda do gesto interativo real de desenho.
- A criação/edição rica de áreas ainda precisa de validação funcional mais profunda na shell web; nesta rodada a API pública de exclusão foi portada e coberta apenas no caminho seguro de no-op para área inexistente.
- O port funcional da demo web está bem mais próximo do TypeScript, mas ainda há espaço para acabamento fino de comportamento visual e estados ativos da toolbar.

## Reclassificação das Pendências Antigas
- `main.ts`: na prática, a lacuna foi fechada pelo conjunto `lib/src/editor.dart` + `web/index.html` + `web/main.dart` + `web/styles.css`; não existe uma cópia literal 1:1, mas agora existe uma contraparte funcional da demo web no lado Dart.
- `editor/core/draw/control/Control.ts`: a pendência antiga sobre `initControl()` não se aplica mais, porque o método já existe e participa do fluxo atual.
- Recursos que já não devem mais aparecer como pendência genérica: previewer de imagem básico, `imagePreviewerDisabled`, `imgCrop`, `imgCaption`, base de `graffiti` com `executeClearGraffiti`, `tableSelectAll`, `titleId`, separador com `lineWidth`/cor e suporte básico de checkbox/radio já têm contraparte funcional no Dart.
- `whiteSpace` também já não deve mais aparecer como ausência genérica: a configuração e a renderização do marcador visual já existem no núcleo Dart.
- `label` também já não deve mais aparecer como ausência genérica: `ElementType.label`, render, métricas e evento básico de clique agora existem no núcleo Dart.
- `vite-env.d.ts` e `editor/types/index.d.ts`: continuam sem contraparte formal, mas são itens de tipagem/barrel do projeto TypeScript e não bloqueiam a demo funcional em Dart.

## Próximas Ações
- Priorizar o acabamento da paridade de imagem: portar o fluxo visual de seleção/edição rica da imagem na shell Dart, agora em cima da base já portada de `imgCrop`, `imgCaption` e seus comandos públicos.
- Revisar o upstream para identificar a próxima lacuna real de API pública recente do `Command`/`CommandAdapt`, agora que `executeClearGraffiti` também já possui contraparte.
- A próxima etapa de imagem deixou de ser “ter previewer/resizer visível” e passou a ser aprofundar a edição interativa restante: resize, drag/pan mais profundo, crop realmente visual e validações ponta a ponta desses fluxos.
- Expandir o E2E para cobrir menu de contexto em áreas mais profundas que ainda faltam, como split vertical/horizontal e exclusão de tabela inteira, além de outros fluxos interativos que ainda dependem mais do DOM.
- Continuar a investigação de crop no upstream só se houver outra superfície concreta fora do núcleo já lido; na ausência disso, tratar crop interativo como feature nova de UX no lado Dart, não como port direto já especificado.
- Cobrir preview e importação HTML mais rica de LaTeX, para garantir que a mesma integridade de `laTexSVG`, dimensões e renderização continue válida fora da inserção direta e da colagem interna.
- Validar cenários avançados de tabela e controles embutidos complexos após a estabilização da shell web.
- Rodar uma rodada maior de validação manual da demo web agora que cursor, date picker, contexto e renderização principal estão mais estáveis.
- Voltar ao comparativo com o upstream TypeScript e atacar a próxima lacuna pequena fora de tabela/imagem.
- Consolidar os testes antigos de crop para evitar sobreposição entre o fluxo antigo de aplicação e o novo fluxo editável.

## Leitura Rápida
- A demo web em Dart deixou de ser um bootstrap mínimo e passou a reproduzir a experiência principal da demo TypeScript com shell completa, assets, CSS e interações básicas reais.
- O maior avanço desta rodada foi deixar o editor utilizável no navegador sem o flicker constante e sem os artefatos visuais do date picker.
- O maior risco remanescente está em paridade fina de comportamentos avançados, não mais na ausência da casca da aplicação.
- Para edição básica de texto, o projeto está significativamente mais perto da versão original do que o roteiro anterior indicava.