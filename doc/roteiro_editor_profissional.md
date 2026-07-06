# Roteiro — Editor Profissional compatível com Word (DOCX) + Exportação PDF

> **Objetivo:** transformar o editor de `lib/` em um editor profissional de alto desempenho,
> capaz de **abrir e salvar os DOCX de `resources/` sem bugs e sem perda** (os arquivos devem
> continuar abrindo perfeitamente no Microsoft Word), com **shell de interface no estilo Word**
> e **exportação PDF fiel** — tudo em **Dart puro 3.6.2, sem dependências externas** nos packages.
>
> Este roteiro consolida e supersede o plano de `doc/roteiro2.md` (MVP de tradução) e complementa
> `doc/roteiro.md` (tracker do port TS→Dart, que continua valendo para paridade com o upstream).
> A análise de PDF em `doc/relatorio_feature_pdf.md` está incorporada na Fase 7.

---

## 0. Estado de execução

| Fase | Estado | Evidência |
|---|---|---|
| F0 fundações | ✅ concluída (2026-07-05) | 6 packages em `packages/` (pubspecs puros, `analysis_options` compartilhado); `tool/docx_inventory.dart` com `--verify` batendo com a seção 2.2; CI local `tool/ci.dart` |
| F1 ce_xml/ce_zip/ce_opc | ✅ concluída (2026-07-05) | `ce_zip`: re-zip **byte-idêntico ao arquivo inteiro** nos 2 DOCX (14 testes); `ce_xml`: SAX 4,45 MB em **92 ms** (orçamento 500 ms), DOM round-trip estável (16 testes); `ce_opc`: rels/content-types dos 2 DOCX, targets 100% resolvidos (15 testes). Falta só a validação manual no Word (checklist G2) |
| F2 reader | ✅ concluída (2026-07-05) | `ce_docx`: modelo WordprocessingML tipado + `DocxReader` + cascata de estilos + numeração multinível (18 testes; inventário do modelo = seção 2.2); conversor `lib/src/word/docx_to_element.dart` (11 testes VM: tabelas com merges, imagens base64, hyperlinks, títulos, marcadores de numeração, geometria da página do `sectPr`); UI: botão "Abrir DOCX" + drag-drop na shell (`menu-item__docx`), E2E dedicado em `test/e2e/editor_e2e_docx.dart`. Limitações registradas p/ F4: numeração como marcador textual inline, campos com resultado em cache, carimbo preservado sem render, só header/footer default |
| F3 writer | ⬜ próxima | — |
| F4–F8 | ⬜ | — |

CI local: `dart run tool/ci.dart` (packages + raiz + inventário; `--e2e` opcional).

---

## 1. Metas mensuráveis (Definition of Done global)

| # | Meta | Critério de aceite |
|---|------|--------------------|
| G1 | Abrir os 2 DOCX de `resources/` | ETP (19 págs) e TR (140 págs, 4,45 MB de `document.xml`) abrem, renderizam com estilos, numeração multinível, tabelas com merges/bordas/sombreamento, cabeçalhos/rodapés com `PAGE`/`NUMPAGES` |
| G2 | Round-trip sem corrupção | abrir → salvar → o Word abre **sem diálogo de recuperação/repair**, com formatação preservada; partes não editadas preservadas byte a byte |
| G3 | Fidelidade de paginação | mesmo conteúdo por página que o Word (tolerância: ±1 quebra de página no TR), com widow/orphan control e `keepNext`/`keepLines` |
| G4 | Desempenho | abrir o TR em < 3 s; digitação com frame < 16 ms; scroll fluido nas 140 páginas; memória estável |
| G5 | Shell estilo Word | ribbon com abas, régua, barra de status com página/palavras/zoom, painel de estilos e navegação |
| G6 | PDF fiel | exportação com **texto vetorial** (selecionável), fontes TTF embutidas com subsetting, paginação idêntica à tela, imagens e tabelas corretas |
| G7 | Dart puro | `packages/*` com **zero dependências de pub** no runtime (apenas `dart:` core); código copiado/adaptado das bibliotecas locais é permitido |

---

## 2. Diagnóstico do estado atual (resumo das explorações)

### 2.1 O editor (`lib/`)
- ~231 arquivos, ~50,8 mil linhas. Port do canvas-editor TS: modelo `IElement`
  ([element.dart](../lib/src/editor/interface/element.dart)), pipeline `Draw.computeRowList()`
  → `_computePageList()` ([draw.dart](../lib/src/editor/core/draw/draw.dart)), partículas por tipo,
  frames (header/footer/watermark/pageNumber), zonas header/main/footer, medição via
  `ctx.measureText()` com cache ([text_particle.dart](../lib/src/editor/core/draw/particle/text_particle.dart)).
- Página padrão 794×1123 px (A4 @96dpi), margens em px nas options ([option.dart](../lib/src/editor/utils/option.dart)).
- Import/export hoje: JSON (`getValue`/`setValue`), HTML (paste/`getHTML`), texto, PNG por página, print via imagens, Markdown.
- **Não existe nada de DOCX/PDF/ZIP/XML em `lib/`.** Runtime depende só de `dart:html` (+`package:web` declarado mas não usado).
- **Lacunas estruturais para Word:** sem estilos nomeados (só estilo inline por elemento), sem numeração
  multinível OOXML, sem seções (`sectPr`), sem múltiplos headers/footers por tipo, sem campos
  (`PAGE`/`NUMPAGES`), sem tab stops, sem bordas por célula completas, sem shading de parágrafo,
  sem footnotes/comments (não exigidos pelo corpus), sem hifenização.

### 2.2 O alvo de compatibilidade (inventário real dos DOCX de `resources/`)

Os dois documentos vêm do mesmo template corporativo (Prefeitura de Rio das Ostras). Números exatos:

| Feature OOXML | ETP | TR | Suporte hoje no editor |
|---|---:|---:|---|
| Tabelas / linhas / células | 3 / 18 / 82 | 22 / 1.642 / 3.650 | parcial (sem estilo de tabela, bordas por célula limitadas) |
| `gridSpan` (merge horizontal) | 1 | 1.670 | ✔ (`colspan`) |
| `vMerge` (merge vertical) | 4 | 14 | ✔ (`rowspan`) |
| `tcBorders` (borda por célula) | 0 | 3.158 | parcial (`borderTypes` simples) |
| `w:shd` (sombreamento par./célula) | 123 | 1.496 | parcial (highlight de run) |
| Estilos referenciados (`pStyle`/`rStyle`/`tblStyle`) | 458/0/2 | 1.524/26/15 | ✘ inexistente |
| Catálogo de estilos (`styles.xml`) | 158 | 181 | ✘ |
| Numeração multinível (`1.`, `1.1.`, … 9 níveis) | 40 abstractNum | 13 abstractNum | ✘ (só ul/ol simples) |
| `numPr` aplicados no corpo | 208 | 29 | ✘ |
| Seções / `pgSz`+`pgMar` | 1 seção A4 | 1 seção A4 | parcial (global, não por seção) |
| Headers/footers (tipos default/first/even) | 2+2 | 3+3 | parcial (1 header + 1 footer) |
| Campos `PAGE`/`NUMPAGES` no rodapé | ✔ | ✔ | ✘ (pageNumber próprio, não campo) |
| Text box do carimbo no header (`mc:AlternateContent` DrawingML+VML) | ✔ | ✔ | ✘ |
| Imagens (JPG/PNG, inline) | 4 (headers) | 5 (4 headers + 1 corpo) | ✔ inline |
| Hyperlinks externos | 0 | 3 | ✔ |
| Bookmarks | 0 | 12 | ✘ (preservar) |
| `w:ins` órfãos (revisões) | 0 | 0 | n/a — medição do `tool/docx_inventory` (2026-07-05) corrigiu a estimativa anterior (2/14): o corpus não tem revisões; passthrough D1 continua valendo como robustez geral |
| Tab stops (`w:tab` defs) | 33 | 713 | ✘ |
| `w:br` | 0 | 108 | ✔ |
| Justificação `both` | 1 | 1.428 | verificar paridade do `justify` |
| `autoHyphenation` | ✔ | ✔ | ✘ (opcional, Fase 4.9) |
| Fontes | Ecofont_Spranq_eco_Sans 12pt (Normal), Times New Roman (default) | idem | fallback do browser |
| Footnotes/endnotes/comments/equações/floating images/OLE | **0 em ambos** | **0** | não exigido pelo corpus |

**Conclusão:** o esforço pesado é **estilos nomeados + numeração multinível + tabelas ricas
(bordas por célula, shading) + headers/footers multi-tipo com campos + preservação round-trip**.
Nada de equações, notas ou objetos flutuantes é necessário para o corpus (ficam como metas estendidas).

### 2.3 Referências disponíveis (`referencias/`)
- **feature-pdf** (TS): export PDF via jsPDF com **texto vetorial** e fontes TTF registradas;
  pipeline paralelo de layout (re-layout próprio). Arquivos-chave: `src/pdf/index.ts`,
  `src/pdf/particle/TextParticle.ts`. Lição: texto como operadores PDF reais, não raster.
- **feature-svg** (TS): prova que o renderer pode ser abstraído — `CanvasPath2SvgPath` converte
  chamadas de path canvas em `<path d>`; medição continua via canvas. Base da decisão D3.
- **poc-table-paging** (TS): algoritmo completo de **quebra de tabela entre páginas**
  (split de `tr`/`td` com `pagingId`/`pagingRepeat` para repetir header row) em
  `src/editor/core/draw/Draw.ts` L1536–1720. Portar na Fase 4.7.
- **plugin-main** (TS): plugin docx upstream é **lossy** (export via lib `docx`, import via
  `mammoth`→HTML). **Não serve** como base — confirma a necessidade de um conversor OOXML próprio.
- **feature-CRDT** (TS): Yjs com sync ingênuo de documento inteiro. Fora de escopo deste roteiro.

### 2.4 Bibliotecas locais (o que copiar para `packages/`)

| Origem | O que copiar | Estado de pureza |
|---|---|---|
| `C:\MyDartProjects\docx_dart` (port do python-docx) | `lib/src/internal/archive/**` (**ZIP próprio com deflate/inflate/crc32, sem deps**); `lib/src/opc/**` (OPC: package, rels, content types); `lib/src/oxml/**` (modelo OOXML + `xmlchemy`) | ZIP é puro; OPC/OXML dependem de `package:xml` → **substituir pelo nosso parser (Fase 1)** |
| `C:\MyDartProjects\jsPDF` (port Dart) | **Projeto inteiro é Dart puro (zero deps de runtime)**: `lib/src/libs/zlib*.dart`, `lib/src/libs/ttffont.dart` (parser TTF + embedding), `fast_png.dart`, `bmp_decoder.dart`, `pdf_document.dart`, módulos `addimage/png_support/jpeg_support/split_text_to_size/standard_fonts_metrics` | ✔ puro — base do `ce_pdf` |
| `C:\MyDartProjects\pdfbox_dart` (port PDFBox) | `lib/src/fontbox/ttf/**` — em especial **`ttf_subsetter.dart`** (subsetting p/ embedding) e tabelas cmap/glyf/hmtx/OS2/kern | tem deps (`pointycastle`, `archive`, git) → copiar só os arquivos de fonte e desacoplar |
| `C:\MyDartProjects\itext` (port iText7, `dpdf`) | referência de arquitetura: `kernel/pdf/**` (writer), `io/font/**` (`true_type_font_subsetter.dart`), `layout/**` (engine de layout real) | quase autocontido; usar como 2ª fonte/validação cruzada |
| `C:\MyDartProjects\pdf.js` (port Dart) | referência de leitura/validação de PDF e decodificação de fontes (CFF, glyf) | quase puro; usar nos testes do `ce_pdf` |
| `C:\MyDartProjects\dart_quill` | `lib/src/dependencies/dart_quill_delta/**` (modelo Delta) — **opcional**, só se formalizarmos deltas p/ histórico/colaboração | vendorável |
| `D:\EuroOfficeNative` (fork ONLYOFFICE, C++/JS) | **apenas referência conceitual** de semântica OOXML e layout (`core/OOXML`, `sdkjs/word`). **AGPL v3 — não derivar código** | ✘ não copiar |

---

## 3. Decisões de arquitetura

### D1 — DOCX é o formato principal; preservação é a estratégia de round-trip
O editor passa a tratar `.docx` como formato de persistência de primeira classe. Para garantir G2:

- **Passthrough no nível de parte (ZIP):** partes que o editor não edita (`theme1.xml`, `fontTable.xml`,
  `webSettings.xml`, `customXml/*`, `docProps/*`, media não alterada) são **preservadas byte a byte**
  e recopiadas no save. Só `document.xml` (e headers/footers/styles/numbering *se editados*) são regenerados.
- **Passthrough inline no `document.xml`:** nós que o modelo não entende (ex.: `mc:AlternateContent`
  do carimbo, `w:bookmarkStart/End`, `w:ins`, `w:proofErr`) são capturados como **XML bruto anexado
  à posição** (elemento `preservedXml` no modelo) e re-emitidos no mesmo lugar no save. Regra de ouro:
  **"o que não entendemos, preservamos; nunca descartamos silenciosamente."**
- `rsid*` podem ser descartados na regravação de parágrafos editados (o Word tolera), mas mantidos
  nos parágrafos intocados via passthrough de parágrafo (hash do XML original por parágrafo: se o
  parágrafo não mudou no modelo, re-emite o XML original byte a byte).

### D2 — Modelo interno estendido (não um segundo modelo)
Estender o `IElement`/opções existentes em vez de criar um modelo paralelo, adicionando:
`styleId` (parágrafo/run/tabela), `numId`+`ilvl`, `tabs` (stops), sombreamento de parágrafo/célula,
`tcBorders` completos, seção (`ISection` com `pgSz`/`pgMar`/refs de header-footer), campos
(`fieldType: page|numPages|…`), `bookmarks`, `preservedXml`. Um novo **catálogo de estilos**
(`StyleSheet`: docDefaults → basedOn chain → estilo → formatação direta, com a ordem de aplicação
do Word) e um **catálogo de numeração** (`NumberingModel`: abstractNum/num, `lvlText` `%1.%2.`,
formatos decimal/lowerLetter/lowerRoman/bullet, restart) viram serviços do core consultados pelo
layout. O JSON nativo (`getValue`) é versionado (v2) e continua sendo o formato de
debug/testes/histórico — é o "formato intermediário" permitido, sem inventar um container novo.

### D3 — Abstração do contexto de desenho (uma engine, três saídas)
Criar interface própria `RenderContext` (fillText, fillRect, drawImage, path ops, clip, transform,
métricas) e fazer `Draw` + partículas desenharem **somente** através dela:
- `CanvasRenderContext` (tela, envolve `CanvasRenderingContext2D`);
- `PdfRenderContext` (Fase 7, emite content streams via `ce_pdf` — texto vetorial por construção);
- (opcional) `SvgRenderContext` (o feature-svg upstream prova o conceito com `CanvasPath2SvgPath`).

Assim o PDF **reusa o layout real** (`computeRowList`/`pageRowList`) em vez de re-implementar
paginação como o feature-pdf fez em TS — elimina a classe inteira de bugs "PDF diferente da tela".

### D4 — Métricas de fonte determinísticas (TTF primeiro, measureText como fallback)
Para G3 e G6, a medição de texto passa a vir de **métricas TTF** (`ce_fonts`: hmtx/kern/cmap) para
as fontes que o app embarca ou que o usuário carregar; `ctx.measureText` fica como fallback para
fontes do sistema. Benefícios: layout idêntico tela↔PDF↔navegadores; larguras estáveis para
justificação. Fontes embarcadas (licença livre): **Liberation Serif/Sans** (métricas compatíveis com
Times New Roman/Arial). Tabela de substituição: `Times New Roman→Liberation Serif`,
`Ecofont_Spranq_eco_Sans→(TTF do usuário se fornecida; senão Liberation Sans)` — com aviso de
substituição no abrir.

### D5 — Monorepo de packages Dart puro

```
packages/
  ce_xml/     # parser/serializer XML 1.0 namespace-aware, SAX streaming + DOM leve (novo, ~1.5-2k linhas)
  ce_zip/     # ZIP/deflate/inflate/crc32 — copiado de docx_dart lib/src/internal/archive (já sem deps)
  ce_opc/     # Open Packaging Conventions: [Content_Types].xml, _rels, partes — adaptado de docx_dart/opc sobre ce_xml
  ce_docx/    # WordprocessingML tipado: reader + writer + preservação (adaptado de docx_dart/oxml sobre ce_xml)
  ce_fonts/   # parser TTF + métricas + subsetting — jsPDF port (ttffont.dart) + pdfbox_dart (ttf_subsetter)
  ce_pdf/     # gerador PDF — núcleo do jsPDF port (pdf_document, zlib, png/jpeg) + PdfRenderContext
```
Regras: cada package com `pubspec.yaml` **sem `dependencies`** (só `dev_dependencies` para testes);
`ce_opc`→`ce_xml`+`ce_zip`; `ce_docx`→`ce_opc`; `ce_pdf`→`ce_fonts`. O app (`lib/`) referencia por
`path:`. O conversor DOCX↔IElement fica em `lib/src/word/` (conhece os dois lados).

### D6 — `ce_xml` próprio em vez de `package:xml`
`docx_dart` depende de `package:xml` — proibido pela regra G7. Escrever parser próprio é viável e
até desejável para desempenho: OOXML é XML bem-comportado (sem DTD externo). Requisitos: namespaces,
atributos, texto, CDATA, comentários, PIs, entidades predefinidas + referências numéricas,
**modo streaming (SAX)** para o `document.xml` de 4,45 MB + DOM leve para partes pequenas, e um
serializer com controle exato de escape (fidelidade de output).

### D7 — Fidelidade de paginação: reproduzir as regras do Word que importam
Itens que mudam quebra de página e **precisam** entrar no layout: `w:spacing`
(before/after/line/lineRule auto|atLeast|exact), `w:ind` (left/right/firstLine/hanging),
`widowControl` (default ligado no Word), `keepNext`, `keepLines`, `pageBreakBefore`, linha base por
fonte (ascent/descent do TTF), altura de linha do Word (~1.15 do em em single spacing conforme
métricas hhea/OS2), tabela: `cantSplit`, header row repeat, células com altura mínima `trHeight`.
Meta realista: G3 (±1 quebra no TR), não pixel-perfection — hifenização e kerning do Word nunca
serão bit a bit idênticos.

### D8 — Desempenho como requisito de arquitetura (não otimização posterior)
Ver Fase 5: parsing streaming, interning de estilos, layout incremental por faixa suja,
virtualização de páginas (só páginas visíveis têm canvas vivo), cache de medição por
(fonte,tamanho,string), scheduling em chunks (`requestIdleCallback`/microtasks) para não travar
digitação durante reflow do TR.

---

## 4. Fases do roteiro

> Cada fase termina com critérios de aceite verificáveis e testes automatizados novos.
> Ordem de dependência: F0 → F1 → F2 → F3 (round-trip) em paralelo com F4 (layout) → F5 → F6 → F7 → F8.

### Fase 0 — Fundações do monorepo e harness de testes (pequena)
1. Criar os 6 packages em `packages/` com pubspecs puros, `analysis_options` compartilhado.
2. Harness de golden tests: `tool/` com runner que compara `getImage()` página a página contra
   goldens (já existe base E2E com puppeteer/shelf — estender).
3. **Ferramenta `tool/docx_inventory.dart`**: dado um .docx, emite o inventário de features (como o
   da seção 2.2) — vira o "medidor de compatibilidade" usado em todas as fases.
4. CI local (script) rodando `dart analyze` + testes unitários dos packages + E2E.

**Aceite:** `dart test` verde nos packages vazios; inventário roda nos 2 DOCX e bate com a seção 2.2.

### Fase 1 — `ce_xml`, `ce_zip`, `ce_opc` (fundação OOXML)
1. `ce_zip`: copiar `docx_dart/lib/src/internal/archive/**`; testes: abrir os 2 DOCX, listar as
   29/32 partes (medição real), extrair e **re-zipar byte-fiel** (partes intocadas idênticas via hash).
2. `ce_xml`: implementar SAX + DOM leve + serializer (D6). Testes: parse do `document.xml` de
   4,45 MB < 500 ms; round-trip well-formed; namespaces `w:`, `wp:`, `mc:`, `v:`, `r:` corretos.
3. `ce_opc`: content types, relationships, resolução de partes (adaptado de `docx_dart/opc`).
   Testes: enumerar rels dos 2 DOCX (incl. os 3 hyperlinks externos do TR e as imagens de header).

**Aceite:** abrir DOCX → tocar nada → salvar → arquivo abre no Word sem repair e hash das partes
originais preservado (primeiro marco de G2, ainda sem edição).

### Fase 2 — `ce_docx` reader → modelo do editor (abrir com fidelidade)
1. Modelo WordprocessingML tipado (adaptar `docx_dart/oxml` para `ce_xml`): document, body,
   parágrafo (`pPr` completo), run (`rPr`), tabela (`tblPr`/`trPr`/`tcPr`, grid), seção (`sectPr`),
   styles.xml (docDefaults, 158–181 estilos, basedOn/link), numbering.xml (abstractNum/num, lvlText),
   headers/footers (+ tipos default/first/even), settings (defaultTabStop, autoHyphenation,
   evenAndOddHeaders/titlePg ausentes ⇒ só default ativo), campos `fldChar`/`instrText`, media.
2. Resolvedor de formatação efetiva (cascata do Word): docDefaults → estilo de tabela → estilo de
   parágrafo (cadeia basedOn) → estilo de caractere → formatação direta. Converter twips/half-points
   → unidades do editor (px @96dpi: 1 twip = 1/15 px; 11906×16838 twips = 794×1123 px ✔ bate com o default atual).
3. Conversor `lib/src/word/docx_to_element.dart`: WordprocessingML → `IElement[]` estendido (D2),
   incl. mapeamento `Nivel 01`/`Nível N` → títulos com nível + numeração; `gridSpan/vMerge` →
   `colspan/rowspan`; text box do carimbo → `preservedXml` + render placeholder (Fase 4.8).
4. UI de abrir arquivo (input file / drag-drop) na shell.

**Aceite:** ETP e TR abrem e renderizam legíveis (mesmo antes da paridade fina de layout);
`tool/docx_inventory` sobre o modelo carregado reporta 100% dos itens da seção 2.2 mapeados ou
preservados; zero exceções nos 2 arquivos.

### Fase 3 — `ce_docx` writer → salvar DOCX round-trip (G2 completo)
1. Serializer WordprocessingML: modelo → `document.xml` (+ headers/footers/styles/numbering quando
   editados), com passthrough inline (D1) e passthrough por parágrafo intocado (hash).
2. Reescrita do pacote OPC: partes novas/alteradas + cópia byte a byte das intocadas; media de
   imagens novas (PNG/JPEG) com content types e rels corretos.
3. UI salvar/salvar como (download do .docx).
4. **Suíte de round-trip:** (a) abrir→salvar sem edição: XML canônico equivalente, Word abre sem
   repair; (b) abrir→editar 1 parágrafo→salvar: só o parágrafo muda no XML; (c) validador estrutural
   próprio (well-formed, rels consistentes, content types completos, refs de estilo/num existentes);
   (d) checklist manual de abertura no Word 2016+ e LibreOffice para os 2 arquivos.

**Aceite:** G2 integral nos 2 DOCX, incluindo após edições de texto, estilo, tabela e imagem.

### Fase 4 — Motor de layout/render em paridade com o Word (G1 + G3)
Cada item = modelo (se faltar) + layout + render + comando/UI + E2E:
1. **Estilos nomeados**: aplicar/limpar estilo de parágrafo e caractere; galeria de estilos na UI;
   re-render quando estilo muda (afeta os 1.524 `pStyle` do TR).
2. **Numeração multinível**: contadores por `numId` com herança e restart; formatos decimal,
   lowerLetter, lowerRoman, bullet (Symbol/Wingdings→fallback Unicode •/○/■); `lvlText` `%1.%2.%3.`
   até 9 níveis; alinhamento/indent por nível (`w:ind` do lvl).
3. **Parágrafo Word-completo**: spacing before/after/line (auto/atLeast/exact), indents
   (firstLine/hanging), justificação `both` real (distribuir espaço nos gaps), shading de parágrafo,
   bordas de parágrafo, `widowControl`/`keepNext`/`keepLines`/`pageBreakBefore` na paginação (D7).
4. **Tab stops**: left/center/right/decimal com leaders; `defaultTabStop` 708 twips; os 713 tab defs do TR.
5. **Tabelas ricas**: `tcBorders` por célula (lados, estilos single/none, cor, largura — 3.158 no TR),
   shading por célula (1.496 `w:shd`), larguras de coluna do `tblGrid` + `tcW` (dxa/pct/auto),
   `tblStyle` (Grid Table Light), alinhamento vertical, `trHeight`, células mescladas já existentes.
6. **Seções + headers/footers multi-tipo**: `ISection` com geometria própria (margens do ETP:
   1418/1134 twips = 94.5/75.6 px ≠ default atual → geometria tem que vir do arquivo); tipos
   default/first/even (nos 2 DOCX só default ativo — implementar seleção correta segundo
   `titlePg`/`evenAndOddHeaders`); distância header/footer (426/454 e 567/230 twips).
7. **Campos**: `PAGE` e `NUMPAGES` renderizados no rodapé ("Página X | Y") e atualizados na
   paginação; arquitetura extensível para futuros (DATE, TOC…). Portar também o **table paging** do
   POC (`referencias/canvas-editor-poc-table-paging`, split de `tr` com repeat header) — o TR tem
   tabelas de centenas de linhas que cruzam dezenas de páginas.
8. **Carimbo do header** (text box `mc:AlternateContent`): render mínimo fiel — desenhar o shape
   (retângulo + texto multi-linha) a partir do DrawingML/VML preservado; edição do texto interno é
   meta estendida, preservação no save é obrigatória (D1).
9. **Hifenização automática pt-BR** (opcional para G3 fino): algoritmo de Liang + padrões pt
   (licença livre, embutir como dados Dart); liga/desliga por `autoHyphenation`.
10. **Fontes/métricas TTF** (D4): `ce_fonts` medindo hmtx/kern; carregar Liberation embutidas +
    upload de TTF do usuário; troca do measureText nos caminhos de layout.

**Aceite:** G1 e G3 nos 2 DOCX (comparação visual página a página vs. Word: goldens de referência
gerados a partir de screenshots/PDF do Word guardados em `test/goldens/word/`); suíte E2E cobrindo
cada item; TR renderiza as 140 páginas sem erro.

### Fase 5 — Desempenho e escala (G4)
1. Benchmarks (`tool/bench/`): abrir ETP/TR, digitar 100 chars no meio do TR, reflow de tabela
   gigante, scroll 140 páginas — medidos no CI local com orçamentos.
2. Parsing: SAX streaming direto → modelo (sem DOM intermediário para `document.xml`), interning de
   strings de estilo/fonte, pooling de objetos de métrica.
3. Layout incremental: invalidação por faixa (parágrafo/tabela sujos) em vez de `computeRowList`
   global; cache de linhas por parágrafo com hash de conteúdo+formatação; reuso do row cache já
   existente no repaint rápido.
4. Virtualização: canvas só para páginas no viewport ±2 (hoje `_lazyRender` já observa — estender
   para destruir/recriar canvases fora do viewport e manter memória plana nas 140 págs).
5. Digitação: caminho rápido de edição intra-parágrafo (re-layout só do parágrafo + shift das
   páginas seguintes se a altura mudou); debounce de recomputações de campo `NUMPAGES`.
6. dart2js: eliminar `dynamic` quente nos loops de layout, listas tipadas, evitar closures em hot
   paths; medir com o profile do Chrome. (Explorar `dart compile wasm` como spike, sem compromisso.)

**Aceite:** orçamentos G4 verdes nos benchmarks; sem regressão na suíte E2E.

### Fase 6 — Shell de interface estilo Word (G5)
Evoluir `web/index.html` + `styles.css` + `lib/src/editor.dart` (a shell já tem toolbar, catálogo,
busca, comentários, paginação — reorganizar no padrão Word/Fluent):
1. **Ribbon** com abas: Arquivo (abrir/salvar DOCX, exportar PDF, imprimir), Página Inicial
   (clipboard, fonte, parágrafo, estilos com galeria), Inserir (tabela, imagem, link, quebra de
   página, header/footer, símbolo), Layout (margens, tamanho, orientação, colunas*, hifenização),
   Referências* (mínimo: navegação por títulos), Revisão (busca/substituição, contagem), Exibir
   (zoom, régua, modo página/contínuo). *itens sem backend ficam ocultos.
2. **Régua horizontal** com indents e tab stops arrastáveis (integra Fase 4.4) + régua vertical.
3. **Barra de status**: página X de Y, palavras (já existe), idioma, zoom slider, modos de exibição.
4. **Painéis**: Estilos (aplicar/inspecionar), Navegação (mapa de títulos — evoluir catálogo atual).
5. Diálogos: Fonte, Parágrafo, Tabela (bordas/sombreamento), Configurar Página — todos mapeando os
   novos recursos da Fase 4.
6. Atalhos Word (Ctrl+B/I/U, Ctrl+E/L/R/J, Ctrl+Enter quebra de página, F12 salvar como…).

**Aceite:** checklist visual comparativa com o Word (screenshots lado a lado); E2E de ribbon
(aplicar estilo, mudar margem, inserir quebra) verde.

### Fase 7 — Exportação PDF fiel (G6)
Conforme `doc/relatorio_feature_pdf.md`, mas usando D3 (contexto abstrato) em vez do pipeline
paralelo do TS:
1. `ce_pdf`: núcleo do jsPDF-Dart (documento, páginas, content streams, zlib próprio, PNG/JPEG);
   revisar/limpar API pública mínima.
2. `ce_fonts` + subsetting: embutir **subset** das TTF usadas (glifos referenciados) — base
   `ttf_subsetter.dart` do pdfbox_dart, validação cruzada com o `true_type_font_subsetter` do itext;
   suporte a fontes Unicode (cmap → CIDs, ToUnicode p/ copiar-colar do PDF).
3. `PdfRenderContext` implementando `RenderContext`: fillText→operadores Tj/TJ (texto vetorial),
   paths→operadores de path, drawImage→XObjects; transformações e clipping.
4. Comando `exportPdf()`: itera `pageRowList` real do `Draw` (mesma paginação da tela por
   construção), desenha cada página no `PdfRenderContext`, inclui headers/footers/campos resolvidos,
   watermark, imagens; metadados (title/author de `docProps`).
5. Testes: (a) abrir o PDF gerado com o port do pdf.js e validar estrutura + extração de texto;
   (b) comparação visual raster PDF↔`getImage()` por página (tolerância de anti-aliasing);
   (c) tamanho: TR em PDF < ~10 MB com subsetting; (d) abrir em Acrobat/Chrome/SumatraPDF.

**Aceite:** G6 nos 2 DOCX; texto selecionável/pesquisável; paginação idêntica à tela.

### Fase 8 — Robustez, corpus e regressão contínua
1. Ampliar o corpus: gerar variações no Word (documento com even/first headers ativos, floating
   images, footnotes, multi-seção, landscape) e definir comportamento (suportar ou preservar+avisar).
2. Fuzzing leve: mutações de XML/ZIP nos DOCX → o reader nunca lança exceção não tratada; erros
   viram diagnóstico amigável ("parte X inválida").
3. Relatório de fidelidade no abrir: lista do que foi substituído (fontes) ou apenas preservado
   (text box, revisões) — transparência para o usuário.
4. Documentação: `doc/arquitetura_word.md` (modelo, cascata de estilos, passthrough) e atualização
   contínua deste roteiro com estado por fase.

---

## 5. Estratégia de testes (transversal)

| Camada | Ferramenta | O que valida |
|---|---|---|
| Unit (packages) | `dart test` puro | ZIP round-trip byte-fiel, XML parse/serialize, cascata de estilos, contadores de numeração, subsetting TTF, operadores PDF |
| Conversão | fixtures dos 2 DOCX + sintéticos | DOCX→modelo→DOCX com XML canônico equivalente; inventário 100% mapeado/preservado |
| E2E (browser) | puppeteer+shelf (já existente) | abrir/editar/salvar na shell real, ribbon, régua, export PDF |
| Golden visual | `getImage()` + rasters de referência | paridade página a página tela↔Word (referência) e tela↔PDF |
| Benchmarks | `tool/bench/` | orçamentos G4 (abrir TR < 3 s, frame < 16 ms) |
| Validação externa (manual, por marco) | Word 2016+, LibreOffice, Acrobat | sem repair dialog, formatação ok, PDF ok |

---

## 6. Riscos e mitigação

| Risco | Impacto | Mitigação |
|---|---|---|
| Fontes originais indisponíveis (Ecofont, Times New Roman é licenciada) | métricas ≠ Word → paginação desvia | Liberation (métricas compatíveis TNR) embutida; upload de TTF do usuário; relatório de substituição |
| Divergência measureText vs TTF | layout instável entre browsers | D4: TTF como fonte primária de métricas |
| Regenerar `document.xml` corromper algo sutil | Word mostra repair | D1: passthrough por parte + por parágrafo intocado + validador estrutural + suíte round-trip |
| Custo do parser XML próprio | atraso na F1 | escopo restrito a XML 1.0 sem DTD; SAX primeiro; corpus real como teste desde o dia 1 |
| Desempenho do TR (1.642 trs, 3.650 tds) | editor inutilizável | F5 é fase própria com orçamentos; layout incremental desde F4 (não deixar para o fim) |
| AGPL do EuroOffice | contaminação de licença | somente leitura conceitual; nenhuma cópia de código |
| Table paging complexo (POC upstream) | quebra de tabela errada no TR | portar o algoritmo já validado do POC + E2E dedicado com tabelas de 100+ linhas |
| Escopo do ribbon crescer demais | F6 vira buraco | itens sem backend ficam ocultos; checklist fechado por aba |

---

## 7. Sequência executiva (visão de dependências)

```
F0 fundações ──► F1 ce_xml/ce_zip/ce_opc ──► F2 reader ──► F3 writer (G2)
                                                 │
                                                 ▼
                              F4 layout Word-parity (G1, G3) ──► F5 performance (G4)
                                                 │                      │
                                                 ▼                      ▼
                                        F6 shell Word (G5)      F7 PDF (G6)
                                                 └──────────┬───────────┘
                                                            ▼
                                                     F8 robustez/corpus
```

Esforço relativo estimado: F0 ▪ | F1 ▪▪ | F2 ▪▪▪ | F3 ▪▪▪ | F4 ▪▪▪▪▪ (a maior) | F5 ▪▪▪ | F6 ▪▪▪ | F7 ▪▪▪ | F8 ▪▪.

**Primeiros passos concretos (próxima sessão)** — F0, F1 e F2 concluídas em 2026-07-05 (ver
seção 0); próxima é a **Fase 3 (writer `ce_docx` → round-trip G2)**:
1. F3.1: serializer WordprocessingML (modelo → `document.xml`) com passthrough inline (D1) e
   passthrough por parágrafo intocado (hash do XML original — o campo `sourceXml` de
   `WpParagraph` já está previsto no modelo).
2. F3.2: reescrita OPC — já coberta pelo `ce_zip`/`ce_opc` (partes intocadas byte a byte);
   falta media de imagens novas + content types/rels.
3. F3.3: UI salvar/salvar como (download do .docx) + F3.4: suíte de round-trip.
4. Em paralelo, itens F4 com maior retorno visual: motor de numeração real (substituir o
   marcador textual inline do conversor F2), campos PAGE/NUMPAGES dinâmicos, tcBorders por
   célula no render.
5. Validação manual pendente da F1/F2: abrir no Word o output de `OpcPackage.save()`
   (build/roundtrip/) — deve abrir sem repair (output byte-idêntico, testes garantem).
