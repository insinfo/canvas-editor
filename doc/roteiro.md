Roteiro de Tradução: TypeScript para Dart

Este roteiro deve ser atualizado para cada etapa concluida 

Cinco fases principais para organizar a migração.

Fase 1: Fundamentos e Tipos (Tradução de Interfaces, Enums e Constantes)

Comece pelos arquivos que não têm dependências de implementação, apenas definições. Isso estabelece a base do seu projeto em Dart.
Enums: Arquivos que contêm enum (ex: editor/dataset/enum/*). Em Dart, a sintaxe é muito similar.
Constantes: Arquivos que exportam const (ex: editor/dataset/constant/*). Dart também possui constantes, então a tradução é direta.
Interfaces: O Dart não possui interfaces como o TypeScript. Você deverá traduzir as interfaces (.ts contendo export interface) para classes Dart. Propriedades opcionais (label?: string) podem ser tratadas como propriedades anuláveis (String? label).

Exemplo de IDialogData (de components/dialog/Dialog.ts):

os arquivos typescript estão em C:\MyDartProjects\canvas-editor-port\typescript\src

os arquivos dart estão em 
c:\MyDartProjects\canvas-editor-port\lib\src



Dart
class DialogData {
  String type;
  String? label;
  String name;
  String? value;
  List<Map<String, String>>? options;
  String? placeholder;
  int? width;
  int? height;
  bool? required;

  DialogData({
    required this.type,
    this.label,
    required this.name,
    this.value,
    this.options,
    this.placeholder,
    this.width,
    this.height,
    this.required,
  });
}

Fase 2: Utilitários e Lógica Central
Traduza os módulos que contêm lógica de negócio pura e funções utilitárias. Eles dependem apenas da Fase 1.
Arquivos de Utilitários: Funções que manipulam dados, fazem cálculos ou outras tarefas genéricas (geralmente em pastas utils).
Lógica Central (Core): Classes como HistoryManager, RangeManager, Position e EventBus. Elas formam o núcleo do editor, mas ainda não manipulam a interface do usuário diretamente.
Fase 3: Componentes de UI e Manipulação do DOM
Esta é a fase mais complexa, pois envolve a tradução da manipulação direta do DOM para a biblioteca dart:html.
Ordem de Tradução: Comece com componentes mais simples e independentes, como Dialog.ts e Signature.ts.
Manipulação do DOM: Onde você usa document.createElement, element.classList.add, element.append, você usará as classes e métodos correspondentes do dart:html.
Exemplo de _render em Dialog.ts (tradução parcial):
code
TypeScript
// TypeScript
const mask = document.createElement('div');
mask.classList.add('dialog-mask');
document.body.append(mask);
code
Dart
// Dart (usando import 'dart:html' as html;)
final mask = html.DivElement()
  ..classes.add('dialog-mask');
## Roteiro de tradução: TypeScript → Dart

> Este roteiro deve ser atualizado a cada etapa concluída.

Dividi o processo em cinco fases para organizar a migração. A seguir descrevo cada fase com recomendações e exemplos.

### Fase 1 — Fundamentos e tipos

Comece pelos arquivos que não têm dependências de implementação — apenas definições. Isso estabelece a base do projeto em Dart.

- Enums: traduza arquivos que contêm enums (ex.: `src/editor/dataset/enum/*`). A sintaxe do Dart é bem similar.
- Constantes: traduza arquivos que exportam `const` (ex.: `src/editor/dataset/constant/*`). Dart tem suporte a constantes e a tradução é direta.
- Interfaces: o Dart não possui `interface` exatamente como o TypeScript. Converta `export interface` em classes Dart. Propriedades opcionais como `label?: string` viram propriedades anuláveis (`String? label`).

Exemplo (IDialogData em TypeScript → Dart):

```dart
class DialogData {
  String type;
  String? label;
  String name;
  String? value;
  List<Map<String, String>>? options;
  String? placeholder;
  int? width;
  int? height;
  bool? required;

  DialogData({
   required this.type,
   this.label,
   required this.name,
   this.value,
   this.options,
   this.placeholder,
   this.width,
   this.height,
   this.required,
  });
}
```

### Fase 2 — Utilitários e lógica central

Traduza módulos com lógica de negócio pura e funções utilitárias. Eles dependem apenas da Fase 1.

- Utilitários: funções que manipulam dados, fazem cálculos ou tarefas genéricas (normalmente em `utils/`).
- Lógica central (core): classes como `HistoryManager`, `RangeManager`, `Position`, `EventBus`. Elas formam o núcleo do editor e tendem a não manipular a UI diretamente.

### Fase 3 — Componentes de UI e manipulação do DOM

Esta fase é a mais complexa: você traduzirá manipulação direta do DOM para `dart:html`.

- Ordem de tradução recomendada: componentes simples e independentes primeiro (ex.: `Dialog.ts`, `Signature.ts`).
- Manipulação do DOM: substitua `document.createElement`, `element.classList.add`, `element.append` por APIs equivalentes do `dart:html`.

Exemplo de tradução parcial de `_render` em `Dialog.ts`:

```ts
// TypeScript
const mask = document.createElement('div');
mask.classList.add('dialog-mask');
document.body.append(mask);
```

```dart
// Dart (usar: import 'dart:html' as html;)
final mask = html.DivElement()..classes.add('dialog-mask');
html.document.body?.append(mask);
```

Observação: arquivos CSS não precisam ser traduzidos — podem ser referenciados em `web/index.html` do projeto Dart.

### Fase 4 — Orquestradores principais

Com componentes e lógica central traduzidos, foque nas classes que os conectam:

- `Draw.ts`: gerencia a renderização no canvas e depende de vários módulos.
- `CommandAdapt.ts`, `Command.ts`: definem ações do usuário e ligam a UI aos serviços principais.
- `ContextMenu.ts`, `Shortcut.ts`: lidam com interações como menus de contexto e atalhos.

### Fase 5 — Ponto de entrada e integração final

Última etapa: criar o ponto de entrada da aplicação em Dart.

- Traduza `main.ts` ou `index.ts` (arquivo que inicializa o editor).
- Crie `web/main.dart` como ponto de entrada do app web em Dart — ele deve inicializar a classe principal do editor.

## Primeiros arquivos recomendados (ordem sugerida)

Abaixo estão os 10 primeiros arquivos a traduzir, com justificativa breve para cada um:

1. `src/editor/dataset/enum/Editor.ts`
  - **Status:** Concluído.
  - Define enums essenciais (ex.: `EditorMode`, `PageMode`, `EditorZone`) usados amplamente.
2. `src/editor/dataset/enum/Element.ts`
  - **Status:** Concluído.
  - Contém `ElementType`, usado para identificar tipos de conteúdo (texto, imagem, tabela, etc.).
3. `src/editor/dataset/enum/Common.ts`
  - **Status:** Concluído.
  - Enums genéricos (ex.: `ImageDisplay`, `LocationPosition`) usados por várias funcionalidades.
4. `src/editor/dataset/constant/Common.ts`
  - **Status:** Concluído.
  - Constantes globais (ex.: `ZERO`, `WRAP`) usadas na manipulação de texto.
5. `src/editor/interface/Common.ts`
  - **Status:** Concluído.
  - Tipos/interfaces genéricos (ex.: `IPadding`) — converta para classes/typedefs em Dart.
6. `src/editor/interface/Element.ts`
  - **Status:** Concluído.
  - Define `IElement`, a estrutura de dados central do editor; convertê-la para `class Element` em Dart é essencial.
7. `src/editor/interface/Editor.ts`
  - **Status:** Concluído.
  - Define `IEditorData` e `IEditorOption`, representando o documento e opções do editor.
8. `src/editor/interface/Row.ts`
  - **Status:** Concluído.
  - Estrutura de linhas (`IRow`) — importante antes de traduzir a lógica de renderização.
9. `src/editor/interface/Position.ts`
  - **Status:** Concluído.
  - Define estruturas para rastrear posições de cursor e elementos (`IElementPosition`, `IPositionContext`).
10. `src/editor/dataset/enum/Row.ts`
  - **Status:** Concluído.
  - Define `RowFlex` (alinhamento de linha), usado em `IElementStyle` dentro de `Element.ts`.

---



Próximos 20 Arquivos para Tradução
Fase 2a: Concluindo Estruturas de Dados e Constantes
Construindo sobre a base já criada, vamos finalizar todas as definições de dados.
src/editor/interface/Control.ts
Motivo: Define a estrutura IControl, que é complexa e fundamental para a funcionalidade de formulários. Será usada por muitos elementos.
src/editor/dataset/enum/Control.ts
- **Status:** Concluído.
Motivo: Contém os enums (ControlType, ControlComponent) que são dependências diretas da interface IControl.
src/editor/interface/table/Colgroup.ts
Motivo: Estrutura simples que define as colunas da tabela.
src/editor/interface/table/Td.ts
Motivo: Define a célula da tabela (ITd), que é a unidade básica de uma tabela.
src/editor/interface/table/Tr.ts
Motivo: Define a linha da tabela (ITr), que depende da ITd.
src/editor/interface/table/Table.ts
Motivo: Define as opções de configuração para tabelas.
src/editor/dataset/enum/table/Table.ts
Motivo: Enums relacionados a tabelas, como TableBorder.
src/editor/dataset/constant/Table.ts
Motivo: Constantes de configuração padrão para tabelas.
src/editor/interface/Title.ts
Motivo: Define a estrutura dos elementos de título.
src/editor/dataset/enum/Title.ts
Motivo: Enumeração TitleLevel usada na interface ITitle.
src/editor/dataset/constant/Title.ts
Motivo: Constantes de configuração para os títulos (tamanhos padrão, etc.).
src/editor/dataset/enum/List.ts
Motivo: Enumerações para os tipos de lista (ListType, ListStyle), usadas na interface IElement.
Fase 2b: Utilitários e Lógica Central Abstrata
Com todas as estruturas de dados definidas, podemos traduzir as funções que operam sobre elas e as classes de serviço principais.
src/editor/utils/index.ts
Motivo: Contém funções utilitárias genéricas como debounce, getUUID, deepClone, que serão necessárias em toda a aplicação.
src/editor/utils/element.ts
Motivo: Um arquivo de utilitários crucial que contém lógica para manipular listas de elementos (formatElementList, zipElementList). Depende fortemente da classe Element que você já terá criado.
src/editor/core/event/eventbus/EventBus.ts
Motivo: É um módulo autônomo e fundamental para a comunicação entre diferentes partes do editor. Não tem dependências complexas.
src/editor/core/i18n/I18n.ts
Motivo: Gerencia a internacionalização. É uma classe de serviço independente que será consumida por componentes de UI.
src/editor/core/history/HistoryManager.ts
Motivo: Implementa a lógica de desfazer/refazer. Sua lógica é abstrata e não depende da UI, tornando-a ideal para ser traduzida nesta fase.
Fase 2c: Implementando a Lógica de Posição e Seleção
Agora, com as estruturas de dados e utilitários prontos, podemos traduzir as classes que gerenciam o estado do cursor e da seleção.
src/editor/core/position/Position.ts
Motivo: Esta classe implementa a lógica de cálculo de posição dos elementos, que é uma dependência direta para o gerenciamento de seleção (RangeManager) e para a classe principal de renderização (Draw).
src/editor/core/range/RangeManager.ts
Motivo: Gerencia a seleção do usuário (IRange). Depende diretamente de Position.ts e das estruturas de dados principais. É o próximo passo lógico após a tradução da lógica de posicionamento.
src/editor/core/worker/works/wordCount.ts
Motivo: Este é um script de web worker isolado. Sua lógica para contagem de palavras opera diretamente sobre a lista de elementos e não tem outras dependências complexas. É uma parte independente que pode ser traduzida em paralelo ou nesta fase.