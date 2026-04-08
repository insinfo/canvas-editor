# Project Guidelines

## Editing Safety
- Antes de editar qualquer arquivo grande, arquivo recém-formatado ou arquivo que acabou de mudar, releia o trecho exato atual antes de montar o patch.
- Se um patch falhar por contexto incompatível, não reutilize o diff antigo. Releia o arquivo e reaplique em blocos menores e precisos.
- Em arquivos extensos, prefira patches pequenos e localizados, um arquivo por vez, em vez de um patch grande com muito contexto ou muitos arquivos de uma só vez.
- Evite diffs gigantes com caminhos longos espalhados por muitos arquivos na mesma operação; divida a edição em passos menores e independentes.
- Não assuma que o conteúdo ainda é o mesmo após `dart format`, `dart fix` ou mudanças do usuário.
- Ao corrigir erros de runtime ligados a seletores DOM, confira o tipo real do elemento no HTML atual antes de usar `_requireElement<T>()`.

## Workspace Conventions

- Não rode `dart format` automaticamente. Só formate arquivos Dart quando o usuário pedir explicitamente.
- Depois de editar arquivos Dart, valide os arquivos alterados com análise focada.
