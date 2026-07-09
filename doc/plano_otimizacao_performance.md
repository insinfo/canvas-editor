# Plano de Otimização de Performance — digitação e abertura de DOCX
webdev serve --auto=refresh -- --delete-conflicting-outputs
Data: 2026-07-07. Antecipa itens da **Fase 5 (G4)** do
[roteiro_editor_profissional.md](roteiro_editor_profissional.md), motivado por dois sintomas
reportados com o ETP (19 págs no Word / ~30 no editor, 10.319 palavras) e o TR (140 págs):

1. **Digitação**: ~1 s de latência por tecla.
2. **Abertura de DOCX**: travada longa (freeze da aba) ao abrir
   `resources/PGCTIC1_-_TR_-_SISTEMA_GESTAO_PUBLICA__Recuperação_Automática_.docx`,
   sem nenhum feedback visual durante o carregamento.

## 1. Diagnóstico (causas, por ordem de impacto)

### C1 — Servir via `webdev serve` (DDC, JS de desenvolvimento)
O fluxo de teste atual roda o app com DDC (dartdevc), que gera JS sem otimização
(despacho dinâmico `dsend`, sem inlining). Em loops quentes o DDC costuma ficar **5–20×**
mais lento que `dart compile js -O2`. Qualquer medição de performance só vale em build release.

### C2 — Chamadas DOM de fonte por elemento no `computeRowList`
A cada tecla o `render()` recomputa o layout do documento inteiro
([draw.dart](../lib/src/editor/core/draw/draw.dart) `computeRowList`). Para **cada elemento de
texto** (dezenas de milhares no ETP):

- `getElementFont(element, scale)` é chamado **2×** (linhas ~1806 e ~1839), montando string;
- `ctx.font = fontStyle` — chamada de interop/DOM **sempre**, mesmo quando a fonte não mudou;
- `TextParticle.measureText` monta a cache key com `ctx.font` — **getter DOM** que serializa
  a fonte de volta ([text_particle.dart](../lib/src/editor/core/draw/particle/text_particle.dart#L94));
- no modo `wordBreak: breakWord`: `RegExp('[A-Za-z]')` recriado por elemento, concat de strings
  por par de elementos, e `measureWord`/`measurePunctuationWidth` repetem o padrão acima.

Resultado: 3–6 chamadas de interop DOM × ~60k elementos = centenas de milhares de chamadas
por tecla. É o custo dominante mesmo em release.

### C3 — Churn de alocação no `computePositionList`
Cada posição aloca `Map<String, List<double>>` + 4 `List<double>`
([position.dart](../lib/src/editor/core/position/position.dart#L188)) = **5 alocações por
elemento por render**, sendo que os 4 cantos são deriváveis de `x`, `y`, `metrics.width`,
`lineHeight`. ~300k alocações/tecla só de coordenadas → pressão de GC.

### C4 — Abertura de DOCX faz 4 renders completos + trabalho síncrono sem yield
`_openDocxBytes` ([editor.dart](../lib/src/editor.dart#L2445)) encadeia
`executePaperSize` → `executeSetPaperMargin` → `executeSetValue` → `executeForceUpdate`,
e **cada um dispara um `render()` completo** (layout do documento inteiro + posições +
snapshot de histórico com clone profundo). Tudo síncrono a partir do `FileReader.onLoad`:
o browser não pinta nada (nem um spinner) até o fim → percepção de travada.

### C5 — Snapshot de histórico clona o documento inteiro a cada tecla
`submitHistory` ([draw.dart](../lib/src/editor/core/draw/draw.dart#L1159)) clona main +
header + footer elemento a elemento a cada render com `isSubmitHistory`. É o design herdado do
canvas-editor TS; custo O(n) com ~60 campos por elemento. Secundário frente a C2/C3, mas
mensurável em documentos grandes.

### C6 — Arquitetura: relayout global por tecla (herdado do original)
Mesmo com C2–C5 resolvidos, o custo por tecla continua O(documento). A solução definitiva é o
**layout incremental** (F5.3/F5.5 do roteiro): invalidação por parágrafo + shift das páginas
seguintes. Fica tem que fazer (mudança arquitetural é vital);
este plano reduz a constante para caber no orçamento com folga.

## 2. Ações deste plano

| # | Ação | Ataca | Risco |
|---|------|-------|-------|
| A1 | Build/serve release: `tool/serve_web.dart` (compila `dart compile js -O2` e serve `web/` em :8080 com shelf_static) + documentação de que `webdev serve` (DDC) é só para depurar | C1 | baixo |
| A2 | `TextParticle`: cache do último `ctx.font` setado (só reatribui quando muda) e cache key com a string de fonte conhecida (sem getter DOM); `measureText`/`measureWord`/`measurePunctuationWidth` recebem a fonte explícita; em cache hit, **zero** chamadas DOM | C2 | baixo |
| A3 | `computeRowList`: calcular `getElementFont` 1× por elemento; hoistar `RegExp` do wordBreak; eliminar concat por par | C2 | baixo |
| A4 | `IElementPosition.coordinate` lazy: guardar `x`/`y` (largura/altura já existem em `metrics`/`lineHeight`) e materializar o `Map` só quando lido (getter com cache; setter continua aceitando override). 55 usos em 20 arquivos, todos leitura | C3 | médio |
| A5 | Abertura DOCX em **1 render**: aplicar paper size/margens/options direto no `Draw` sem render intermediário e fechar com um único `forceUpdate`; snapshot de histórico único | C4 | baixo |
| A6 | Spinner de carregamento: overlay `.ce-loading-overlay` (CSS em `styles.css`), exibido antes do parse com *yield* (2× rAF) para o browser pintar; `try/finally` garante remoção; usado em abrir e salvar DOCX | C4 (percepção) | baixo |
| A7 | Benchmark reproduzível `tool/bench/typing_bench.dart` no molde do harness E2E (dart2js -O2 + puppeteer + shelf): mede (a) tempo de abertura com os 2 DOCX reais de `resources/`, (b) latência média de digitação com o documento aberto (teclas reais via CDP no meio do doc, com orçamento de tempo e auto-dismiss de dialogs). Baseline antes / depois neste doc | valida tudo | baixo |

Não incluídos (ficam para F5 do roteiro): layout incremental (C6), snapshot de histórico
copy-on-write (C5 além do que A5 já poupa), tipagem de campos `dynamic` quentes (F5.6),
virtualização de canvases (F5.4), TTF/métricas determinísticas (F4.10).

## 3. Fidelidade de renderização do TR

Os problemas de fidelidade visual do TR (tabelas de centenas de linhas cruzando páginas,
tcBorders por célula, shading, numeração real) **não são bugs de performance** — são os itens
F4.2–F4.5/F4.7 (table paging do POC) já mapeados no roteiro. Este plano não os resolve;
a travada e a ausência de feedback sim. O que a otimização muda na renderização é neutra por
construção (mesmo resultado, menos trabalho), validado pela suíte E2E existente.

## 4. Orçamentos (critério de aceite deste plano)

| Métrica | Antes (baseline) | Meta |
|---------|------------------|------|
| Digitação no ETP aberto (média por tecla, release -O2) | medir | < 50 ms (meta G4: < 16 ms fica p/ layout incremental) |
| Abertura ETP (parse+convert+render, release) | medir | < 2 s |
| Abertura TR (140 págs, release) | medir | < 3 s (G4) |
| Feedback visual ao abrir | inexistente | spinner visível < 200 ms após seleção do arquivo |

## 5. Ações P1/P2 — incremental estilo OnlyOffice (adicionadas em execução)

Investigado o mecanismo do ONLYOFFICE D:\EuroOfficeNative\DocumentServer DocumentServer (`sdkjs/word/Editor/`:
`Document.js` `private_Recalculate`/`Recalculate_Page`, `Paragraph_Recalculate.js`
`Recalculate_FastWholeParagraph`, `History.js` com undo por deltas): lá cada
parágrafo cacheia `Lines`/`Pages` + um `EndInfo` de saída; a edição marca o
parágrafo sujo via os changes do histórico; dois fast paths (run-range e
parágrafo-inteiro) evitam relayout global quando o `EndInfo` converge; o
recálculo longo roda fatiado em `setTimeout` (10 ms de orçamento); o undo é
replay de deltas, sem clone do documento. Adaptações implementadas aqui:

| # | Ação | Mecanismo |
|---|------|-----------|
| P1 | Snapshot de histórico **adiado por rajada** (`Draw.submitHistory(defer)`, debounce 300 ms; flush em `HistoryManager.undo/redo`, cancel em `recovery` e em submits imediatos) | elimina o clone O(documento) por tecla; undo passa a agrupar a rajada digitada, como no Word |
| P2 | **Fast path de parágrafo** (`Draw._tryFastParagraphLayout`, acionado por `IDrawOption.fastLayoutIndex` em input/backspace/delete) | recomputa só as rows do parágrafo do cursor (rows quebram em ZERO ⇒ fronteiras exatas), renumera `startIndex`/`rowIndex` das seguintes e reparticiona páginas; guardas (zona ≠ main, tabela, floats/surround, lista/área/controle/paging, rowFlex misto, fronteiras desalinhadas) caem para o relayout completo |

Não portados (próximos passos F5.3/F5.5): `EndInfo` por elemento com corte por
convergência, fast path intra-linha (run-range), recálculo fatiado por orçamento
de tempo, histórico por deltas reversíveis (base para colaboração).

## 6. Resultados

Benchmark `dart run tool/bench/typing_bench.dart` (release dart2js -O2, Chrome
headless, DOCX reais; baseline medido em worktree do HEAD `3fb7377`).

| Métrica | Baseline | Depois | Ganho |
|---------|----------|--------|-------|
| Digitação ETP (ms/tecla) | 338,8 | **39,3** | **8,6×** |
| Digitação TR (ms/tecla) | congela (1 tecla > 3 min, renderer chega a morrer) | **281,0** | inutilizável → usável |
| Abertura ETP (ms) | 1 746 | **1 129** | −35% |
| Abertura TR (ms) | 16 795 | **10 656** | −37% (meta < 3 s fica p/ F5.2/F5.3) |
| Feedback ao abrir | nenhum (tela congelada) | spinner overlay imediato | — |

Digitação no ETP (~30 págs) já fica abaixo do orçamento de 50 ms deste plano;
os 281 ms do TR são dominados pelo `computePositionList`/paginação O(documento)
restantes — resolvidos pela continuação da F5 (posições incrementais e
recálculo fatiado). Em DDC (`webdev serve`) os números são ~5-20× piores:
avalie desempenho SEMPRE com `dart run tool/serve_web.dart`.


Resumo — otimização concluída e validada
 relayoutar o documento inteiro por tecla é o problema. Medido em build release, o código antigo gastava 339 ms/tecla no ETP e no TR (140 págs) uma única tecla não completava em 3 minutos (o renderer chegava a morrer). Em DDC (webdev serve), multiplique por 5–20× — daí o ~1 s/tecla que você via.

Como o DocumentServer (OnlyOffice) resolve
Investiguei o sdkjs/word/Editor/ do D:\EuroOfficeNative\DocumentServer (mecanismo documentado na §5 de plano_otimizacao_performance.md): cada parágrafo cacheia suas linhas/páginas + um EndInfo (estado de saída); a edição marca só o parágrafo sujo; um fast path recalcula o parágrafo e para se o EndInfo convergir (Recalculate_FastWholeParagraph); recálculos longos rodam fatiados em setTimeout (10 ms); e o undo é replay de deltas, sem clone do documento. — apliquei o mecanismo:

Fast path de parágrafo (draw.dart _tryFastParagraphLayout): digitação/backspace/delete recomputam só as rows do parágrafo do cursor e reusam todas as outras (rows quebram em ZERO, então as fronteiras são exatas); guardas (tabela, lista, floats, controles, zona ≠ main…) caem para o relayout completo com segurança.
Undo agrupado por rajada (history_manager.dart): o snapshot (clone O(documento) por tecla!) agora é adiado com debounce de 300 ms — undo desfaz a palavra digitada, como no Word; flush garantido antes de undo/redo.
Além das ações A1–A6 já aplicadas: medição de texto sem interop DOM por elemento, coordinate lazy (−5 alocações/elemento/render), abertura DOCX em 1 render (era 4) e spinner .ce-loading-overlay ao abrir/salvar.
Resultados (release -O2, DOCX reais, tool/bench/typing_bench.dart)
Métrica	Antes	Depois
Digitação ETP	339 ms/tecla	39 ms/tecla (8,6×)
Digitação TR	congelava (>3 min/tecla)	281 ms/tecla
Abrir ETP	1,75 s	1,13 s
Abrir TR	16,8 s	10,7 s
Validação: suite E2E completa 39/39 verde (inclui abrir ETP/TR, undo/redo, tabelas) + 20 testes VM de round-trip. Roteiro atualizado (F5 parcial) e memória do projeto também.

Para você testar

dart run tool/serve_web.dart        # compila -O2 e serve em http://127.0.0.1:8080
Importante: não avalie desempenho com webdev serve — é DDC, sem otimização. O web/main.dart.js já está compilado com tudo.

Próximos passos (registrados no roteiro F5)
Os 281 ms do TR ainda são dominados pelo computePositionList/paginação O(documento) — a continuação é posições incrementais + convergência por EndInfo + recálculo fatiado em timer (F5.3/F5.5) e histórico por deltas. E o TR paginar em 82 págs (Word: 140) é o gap de fidelidade de spacing (F4.3), não de performance — é o próximo item natural do roteiro para a sua queixa de "respeitar os dados do arquivo".

## 7. Continuação arquitetural

A análise mais detalhada do DocumentServer/OnlyOffice e o plano de extração dos
monolitos `draw.dart` e `editor.dart` foram separados em
[plano_arquitetura_performance_onlyoffice.md](plano_arquitetura_performance_onlyoffice.md).
Esse plano registra os padrões de produção observados no OnlyOffice
(`History` por deltas, `TextPr.Check_NeedRecalc`, fast run-range/paragraph,
`FullRecalc` fatiado e repaint por página) e a ordem segura para migrar o editor
para módulos de documento, layout, renderização, histórico e controllers de UI.

Confirmei o bug do espaçamento e ele muda meu conselho. Preciso te passar o que encontrei antes de gastar dias no Web Worker.

Olhei suas capturas com atenção e diagnostiquei bugs de fidelidade concretos e corrigíveis:

"u s o p o r p r a z o" nas células — é a justificação (jc="both") distribuindo espaço entre cada caractere em vez de entre palavras (draw.dart:2260). O Word só espaça nos espaços. Correção pontual.
Cabeçalho sobrepondo o corpo (pág. 4) — a altura reservada do header/zona está errada, o texto do corpo sobe demais.
Linhas de tabela gigantes e vazias (pág. 7-8) — altura de linha/rowspan mal calculada (provavelmente relacionado às células-continuação do meu table paging).
Textos flutuantes ("l4.133/2021", "que deverão compor a solução") — são os text boxes/carimbos (mc:AlternateContent) hoje posicionados errado.


Deixei os dois estudos rodando e vou sintetizar o plano quando terminarem. Enquanto isso, um resumo honesto de onde estamos:

Você tem razão e eu fui pessimista demais. pdf.js, Google Docs e OnlyOffice provam que web worker para renderização de documento é o caminho certo — e a chave que eu estava subestimando é exatamente o que o pdf.js resolve: não se serializa objetos gordos. O worker calcula e devolve uma lista compacta de comandos de desenho (texto com x/y/fonte/cor, bordas como coordenadas de linha) em typed arrays transferíveis (custo ~zero, sem cópia), transmitida por página sob demanda — não os 514k objetos IElement/IRow de uma vez. É isso que torna a serialização barata.

O que está em andamento:

✅ Correção da justificação já commitada e no build (2362330) — atualize o 127.0.0.1:8080 e o "u s o p o r p r a z o" das células deve virar "uso por prazo" (espaço entre palavras, como o Word).
🔍 Clonei o pdf.js em docx_rendering/referencias/pdf.js e disparei dois estudos a fundo: (1) pdf.js — protocolo do worker, transferables, streaming por página, divisão worker-calcula-comandos / main-desenha; (2) OnlyOffice — se o layout do editor de texto deles usa web worker ou recálculo fatiado na main thread (isso decide a melhor arquitetura para nós).
Quando os estudos voltarem, trago um plano concreto de web worker para o editor: o que roda no worker (parse + layout + paginação, tudo já em Dart puro e sem canvas graças ao ce_fonts), o formato compacto/transferível que volta por página, e como a main thread só executa os comandos de desenho. Aí implemento em incrementos verificáveis por você na tela.

Os dois estudos voltaram e dão um veredito claro e baseado em evidência:

pdf.js (visualizador read-only): usa web worker + lista de comandos compacta + transferables + streaming. Perfeito — para read-only.
OnlyOffice (editor de texto editável, igual ao nosso): NÃO usa web worker para o layout. Usa recálculo fatiado na main thread com yield — um laço que calcula uma página por vez, cede o thread a cada ~10 ms (ou 50 páginas), retoma de um cursor de estado (FullRecalc), mantém as 2 primeiras páginas síncronas (viewport instantâneo) e é versionado/cancelável (uma edição durante a paginação descarta o laço antigo). Web worker deles só aparece em spellcheck e hash de senha. Fontes/PDF são WASM, mas síncrono na main thread.
A conclusão que os dados entregam: para um editor editável, o layout toca o modelo do documento a cada tecla — mandá-lo para um worker exigiria serializar o modelo de ida e volta a cada edição, o que é pior. Por isso o OnlyOffice, um editor industrial maduro, deliberadamente mantém o layout na main thread e o fatia. O web worker do pdf.js funciona porque PDF é read-only (nunca edita).

Então o caminho comprovado e de menor risco para "abrir/rolar sem travar" no nosso caso é o modelo OnlyOffice: layout fatiado na main thread — que é exatamente a barra "estimada/instável" que você observou no Word e aprovou. Você estava certo que a resposta estava nesses projetos; a evidência só apontou o mecanismo certo (fatiar, não worker) para o caso editável.

Vou registrar essa decisão de arquitetura na memória e começar a implementar o modelo OnlyOffice.

aí você está certíssimo, e é exatamente o padrão do OnlyOffice (zlib em WASM) e do pdf.js (transferem o ArrayBuffer do arquivo): descompressão é o caso perfeito para worker — tarefa isolada, entra bytes comprimidos e sai bytes descomprimidos, ambos como transferable (zero-copy), sem serializar o modelo. Não tem o problema do layout (que toca o modelo a cada tecla).

Só quero te dar o número real para priorizar: no TR (476 KB comprimido → 4,45 MB de XML), a descompressão + parse leva ~247 ms; o congelamento grande da abertura é o layout (2,3s). Então:

Layout fatiado na main thread = ganho grande (os 2,3s) → fazer primeiro.
Worker de descompressão = ganho menor hoje (~247ms), mas você tem razão que escala com o tamanho — um DOCX de 10-20 MB pode levar 1-2s só para descomprimir. E é muito mais simples que o worker de layout (bytes↔bytes, sem serializar 514k elementos). Ótimo candidato como próximo passo, depois do layout fatiado.
Então o plano combinado fica: (1) layout fatiado agora, (2) worker de descompressão depois para arquivos grandes. Vou seguir com o layout fatiado — começando pela peça retomável do computeRowList.

esta travando mesmo em -O3 esta travando na digitação e na rolagem tem momento que não rola e congela ai depois rola com o documento TR ou seja esta uma merda a esperiencia do usuario esta muito longe do word do google docs pode ser a minha maquina travando ou problema de falta de memoria da minha maquina ? o onlyoffice demorar muito mais tempo para abrir o arquivo mais deposi que abre da para digitar perfeitamente sem engasgos se freesers estranhos ou seja tem algum bugs na implementação   o  D:\EuroOfficeNative\DocumentServer esta demorando muito mais para caerrgar o arquivo mais depois que carrega fica otimo sem travamentos analize o o codigo e replique as tomizações D:\EuroOfficeNative\DocumentServer> 
