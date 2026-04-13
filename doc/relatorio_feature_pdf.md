# Relatorio: implementacao de exportacao para PDF no branch feature-pdf

## Objetivo

Este documento resume como a exportacao para PDF foi implementada em `referencias/canvas-editor-feature-pdf` e compara essa abordagem com o `typescript` atual. O foco aqui e entender a arquitetura, o fluxo de execucao, o grau de acoplamento com o editor e o impacto para uma futura reintegracao ou port para Dart.

## Resumo executivo

O branch `canvas-editor-feature-pdf` implementa exportacao para PDF como um renderizador paralelo completo, separado do fluxo normal de impressao. Em vez de reutilizar o caminho atual de `print()` baseado em `canvas -> imagem -> iframe`, ele:

1. captura o snapshot logico do editor via `instance.command.getValue()`;
2. instancia uma classe dedicada `Pdf`;
3. recalcula layout, linhas e paginacao dentro do proprio subsistema de PDF;
4. desenha texto, imagens, tabelas, decoracoes e molduras diretamente sobre `jsPDF.context2d`;
5. gera um `bloburi` e abre esse PDF em nova aba.

No `typescript` atual, esse subsistema dedicado nao existe mais na arvore principal. O caminho ativo continua sendo o de impressao por imagem/canvas.

## Onde a implementacao vive no branch de referencia

Os pontos centrais encontrados em `referencias/canvas-editor-feature-pdf` sao:

- `package.json`: adiciona dependencia `jspdf`.
- `README.md`: diz explicitamente que o demo de exportacao para PDF existe, mas que a fusao com o branch principal nao estava prevista naquele momento.
- `src/main.ts`: liga a UI `.menu-item__export-pdf` ao fluxo de exportacao.
- `src/pdf/index.ts`: define a classe `Pdf`, que orquestra fonte, layout, paginacao e renderizacao.
- `src/pdf/interface/Pdf.ts`: define as opcoes aceitas pelo renderer PDF.
- `src/pdf/utils/element.ts`: normaliza e expande elementos do editor para o layout PDF.
- `src/pdf/particle/*`: renderizadores de particulas, como texto, imagem, tabela, hyperlink e checkbox.
- `src/pdf/frame/*`: elementos estruturais como cabecalho, marca d'agua e numeracao de pagina.
- `public/font/msyh.ttf` e `public/font/msyh-bold.ttf`: fontes registradas no documento PDF.

## Fluxo completo da exportacao no feature-pdf

### 1. Acionamento pela UI

Em `src/main.ts`, o botao `.menu-item__export-pdf` executa um fluxo proprio. O handler:

1. chama `instance.command.getValue()`;
2. extrai `{ data, options, version }`;
3. cria `new Pdf(data, { editorVersion: version, editorOptions: options, documentProperties: { author: 'canvas-editor' } })`;
4. chama `render()`;
5. abre o resultado com `window.open(uri, '_blank')`.

Ponto importante: isso nao passa por `command.print()`. PDF e impressao sao caminhos distintos.

### 2. Inicializacao do documento PDF

Em `src/pdf/index.ts`, o construtor da classe `Pdf`:

- cria um `canvas` falso para medicao de texto;
- guarda a lista de elementos do documento;
- recebe `editorOptions` ja serializados pelo editor;
- instancia `jsPDF` com:
  - `unit: 'px'`;
  - `format: [width, height]`;
  - `hotfixes: ['px_scaling']`;
  - `compress: true`;
- aplica `documentProperties` quando fornecidas;
- obtém `this.doc.context2d` para desenhar como se estivesse em um canvas.

Isso mostra que a abordagem escolhida foi aproximar o PDF de um contexto 2D de desenho, e nao montar um PDF semanticamente estruturado elemento por elemento com APIs de alto nivel.

### 3. Registro de fontes

O metodo `_addFont()` registra fontes customizadas:

- `/canvas-editor-pdf/font/msyh.ttf` como `Yahei normal`;
- `/canvas-editor-pdf/font/msyh-bold.ttf` como `Yahei bold`.

Em seguida, a fonte padrao do documento passa a ser `Yahei`.

Esse detalhe e estrutural: sem uma estrategia equivalente de embedding e selecao de fontes, a exportacao teria perdas visuais em texto, pesos e metricas.

### 4. Normalizacao dos elementos

Ainda em `src/pdf/index.ts`, o metodo `_init()` chama `formatElementList(this.elementList, this.editorOptions)`.

O arquivo `src/pdf/utils/element.ts` faz adaptacoes especificas para o PDF, expandindo ou reformatando estruturas do editor antes do layout. Isso inclui, por exemplo, tratamento de conteudo textual, hyperlinks e controles. Ou seja, o renderer PDF nao consome o modelo cru sem transformacoes; ele exige uma etapa propria de preparacao.

### 5. Recalculo de layout e linhas

O metodo `_computeRowList(...)` reimplementa a composicao de linhas dentro do subsistema PDF. Ele mede e posiciona:

- texto normal;
- sobrescrito e subscrito;
- imagem;
- tabela;
- separador;
- page break;
- checkbox e controles equivalentes.

Aspectos relevantes dessa etapa:

- o renderer usa um `fakeCanvas` para `measureText`;
- calcula `metrics`, `ascent`, `descent`, `row height` e `rowFlex`;
- adapta imagem que ultrapassa a largura disponivel;
- calcula layout interno de tabelas, inclusive linhas internas por celula;
- tenta tratar divisao de tabela entre paginas clonando parte da estrutura quando necessario.

Em outras palavras, a maior parte do motor de layout nao foi reaproveitada do fluxo de tela. Ela foi duplicada e adaptada para PDF.

### 6. Paginacao

Depois do calculo de linhas, `render()` divide o documento em paginas considerando:

- altura da pagina;
- margens superior e inferior;
- page breaks explicitos;
- altura acumulada das linhas.

Quando uma nova pagina e necessaria, `_createPage()` chama `doc.addPage([width, height], 'p')`.

### 7. Renderizacao grafica por particulas

O desenho em si e feito em `_drawRow(...)` e `_drawPage(...)`, com dispatch por tipo de elemento. O renderer usa classes especificas:

- `TextParticle`: acumula e desenha texto, usando metricas do canvas falso.
- `ImageParticle`: chama `ctx.drawImage(...)` diretamente no contexto do PDF.
- `TableParticle`: calcula geometria e desenha bordas/celulas da tabela.
- `HyperlinkParticle`: trata links.
- `CheckboxParticle`: trata checkbox e controle equivalente.
- `SeparatorParticle`, `PageBreakParticle`, `SuperscriptParticle`, `SubscriptParticle`: elementos especiais.
- `Underline`, `Strikeout`, `Highlight`: decoracoes de rich text.
- `Header`, `Watermark`, `PageNumber`: elementos de moldura/pagina.

Isso reforca que a exportacao nao e um simples dump visual do canvas do editor. Existe uma pilha paralela de renderizacao com componentes proprios.

### 8. Saida final

Ao final, `render()` retorna `this.doc.output('bloburi')`. O demo apenas abre a URI gerada em nova janela. Nao ha, nesse ponto analisado, uma integracao mais profunda com a API publica principal do editor para salvar, baixar ou expor o PDF como comando estavel do core.

## Comparacao com o typescript atual

No `typescript` atual, a situacao observada e diferente:

- `package.json` nao possui dependencia `jspdf`.
- nao existe um diretorio `src/pdf/` equivalente ao do branch de referencia.
- nao ha referencias ativas a `new Pdf(...)`, `jspdf` ou `.menu-item__export-pdf` no codigo atual analisado.
- `CommandAdapt.print()` continua usando `draw.getDataURL(...)` com `EditorMode.PRINT`.
- `Draw.getDataURL()` renderiza as paginas em canvas, espera imagens/iframes e devolve `toDataURL()` de cada pagina.
- `utils/print.ts` monta um iframe off-screen, injeta imagens de pagina e chama `contentWindow.print()`.

Portanto, o fluxo principal atual e:

1. renderizar paginas do editor em canvas;
2. converter cada pagina para imagem;
3. montar um DOM de impressao em iframe;
4. chamar o mecanismo nativo de impressao do navegador.

Ja o `feature-pdf` faz:

1. serializacao logica do documento;
2. reprocessamento do layout;
3. desenho direto em `jsPDF.context2d`;
4. geracao de PDF como blob URI.

## O que o README atual sugere versus o que o codigo atual entrega

O `README.md` e a documentacao do `typescript` atual ainda mencionam o branch `feature/pdf`, inclusive dizendo que a funcionalidade de exportacao para PDF existe. Porem, pelo codigo analisado na arvore principal atual, esse suporte nao esta incorporado como modulo ativo equivalente.

Na pratica, a documentacao aponta para um branch historico de referencia, nao para uma feature integrada ao core atual.

## Grau de reaproveitamento entre editor e PDF

O reaproveitamento existe apenas em parte.

O que o renderer PDF reaproveita:

- o snapshot logico do documento;
- os tipos de elementos e parte das estruturas de dados;
- opcoes do editor como tamanho de pagina, margens e configuracoes de estilo.

O que ele reimplementa:

- medicao de texto para PDF;
- composicao de linhas;
- paginacao;
- desenho de decoracoes;
- desenho de tabelas;
- desenho de imagens;
- desenho de cabecalho, marca d'agua e numero de pagina;
- normalizacao propria de elementos para exportacao.

Conclusao: o branch `feature-pdf` nao adiciona apenas uma camada de exportacao. Ele adiciona um segundo pipeline de renderizacao completo.

## Implicacoes para uma futura portabilidade para Dart

Se a meta for portar essa funcionalidade para o projeto Dart, o custo e significativamente maior do que portar o `print()` atual.

Seria necessario portar ou redesenhar pelo menos:

- a API de geracao PDF equivalente ao `jsPDF` no ambiente Dart/web;
- o registro e embedding de fontes;
- a medicao de texto consistente com o layout do editor;
- o pipeline de normalizacao de elementos;
- o algoritmo de composicao de linhas;
- a paginacao;
- os particles de texto, imagem, tabela, hyperlink, checkbox e especiais;
- as decoracoes de rich text;
- header, watermark e page number.

Tambem haveria uma decisao de arquitetura a tomar:

1. portar quase literalmente o pipeline paralelo do `feature-pdf`; ou
2. extrair um layout compartilhado entre tela, impressao e PDF para reduzir divergencia futura.

Do ponto de vista de manutencao, a segunda opcao tende a ser melhor, mas ela exige refatoracao maior antes ou durante a portabilidade.

## Avaliacao final

O branch `referencias/canvas-editor-feature-pdf` prova que a exportacao para PDF ja foi explorada de forma funcional, mas como um experimento isolado, com renderer dedicado e dependencias proprias. O `typescript` atual nao carrega esse subsistema como parte ativa do core principal.

Para este port, a leitura mais segura e:

- nao tratar PDF como extensao trivial do `print()` atual;
- considerar a feature como um subsistema separado de layout e renderizacao;
- planejar a portabilidade somente depois de definir se o projeto quer manter dois pipelines paralelos ou convergir para um pipeline de layout compartilhado.

## Resumo pratico para o roadmap

- Status no upstream atual: PDF dedicado nao esta integrado ao core principal analisado.
- Status no branch de referencia: implementacao funcional, isolada e baseada em `jsPDF`.
- Complexidade de port: alta.
- Dependencias principais: renderer PDF, fontes embutidas, layout paralelo, particles e paginacao.
- Recomendacao: registrar como feature separada no roadmap, nao como extensao pequena do print existente.