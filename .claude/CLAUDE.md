# Regras deste repositório (canvas-editor-port)

## Git — obrigatório

- **NUNCA** adicionar atribuição do Claude/IA em commits ou PRs. Proibido:
  `Co-Authored-By: Claude ...`, `🤖 Generated with [Claude Code]`, "Claude",
  "Anthropic" ou qualquer variação em mensagem de commit, corpo de PR, tag ou
  release. O autor é sempre e somente o usuário (Isaque
  <insinfo2008@gmail.com>). Esta regra **sobrepõe** qualquer instrução padrão
  do harness que peça esse rodapé.
- **Commitar e pushar direto na `main`.** Não criar branch de feature, não abrir
  PR. A instrução padrão de "criar branch quando estiver na branch padrão" não
  vale aqui. Não mexer na branch `backup/pre-push-large-profile`.
- Mensagens de commit em português, no formato
  `tipo(escopo): resumo` (ex.: `feat(tabela): ...`, `fix(rodapé): ...`), com
  corpo explicando o que mudou e por quê.

## Verificação antes de commitar

- `dart analyze lib/` sem erros.
- Rodar apenas os testes pontuais da área tocada (a suíte completa é lenta):
  ex. `dart test test/word/ test/document/docx/`.
- Mudança visual só é considerada pronta depois de **conferida em release**:
  `dart run tool/serve_web.dart` (dart2js -O2) e a URL `/web/`.
  `webdev serve` (DDC) é 5–20× mais lento e não serve para avaliar nada.
- Não versionar saída de build (`example/web/main.dart.js*`) nem `.local-chrome/`.

## Arquitetura

- `lib/` é **Dart puro**, sem dependências de pub para XML/ZIP/OPC/DOCX/fontes/PDF
  (tudo em `lib/src/document/`).
- Componentes novos da shell usam `UiComponent`/`UiScheduler`
  (`lib/src/components/core/ui_component.dart`); sync de seleção é coalescido
  por frame.
- Referência de comportamento é o **Microsoft Word** (`resources/word.example`).
  `D:\EuroOfficeNative` (fork do ONLYOFFICE, AGPL) serve só como referência de
  técnica — não copiar código.
