# Roteiro de Tradução (Atualizado em 26/10/2025)
port from C:\MyDartProjects\canvas-editor-port\typescript\src to C:\MyDartProjects\canvas-editor-port\lib
## Estado Atual
- Fundamentos concluídos: enums centrais, grande parte das interfaces e constantes de elementos migradas para Dart.
- Infra de atalhos portada: utilitários `ua.dart` e `hotkey.dart`, dados de atalhos e classe `Shortcut` já operando.
- Conjuntos de dados recentes: `ElementStyleKey`, `TableOrder`, configurações de título, watermark e listas espelham o TypeScript; defaults de background, badge, checkbox, control, cursor, header/footer, group e regras de modo do editor já disponíveis em Dart.
- Interfaces específicas (área, controle, evento, título, watermark, etc.) adaptadas para classes Dart com construtores nomeados.
- `dart analyze` executado com avisos herdados apenas sobre convenções de nomes; nenhum erro funcional introduzido.

## Métricas de Progresso
- Port geral: 107 de 220 arquivos TypeScript migrados (~49% concluído, ~51% restante).
- Constantes em `lib/src/editor/dataset/constant`: 27 de 27 migradas (100% concluído, 0% restante).

## Próximas Entregas (Curto Prazo)
- Completar a tradução de `utils/element.ts` para Dart e validar integração com os novos helpers (`deepClone*`, `splitText`).
- Migrar `Command.ts` e `CommandAdapt.ts` para ligar atalhos/comandos às operações reais.
- Iniciar a migração de `RangeManager` e `Position` após utilitários fundamentais estarem prontos.
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
- `formatElementList` parcialmente migrado (suporte para Título, Lista, Área, Tabela, Hyperlink e Data) reaproveitando `_cloneElement` e `unzipElementList`.
- Implementado `_cloneElement` e `unzipElementList` em Dart para preparar a expansão da tradução (ainda faltam os demais utilitários complexos desse módulo).
- Mapas de estilo e tipo de lista (`list.dart`) disponíveis para lógica de rich text.
- Inclusão dos enums `MouseEventButton`, `ElementStyleKey`, `TableOrder` e outros suportes de shortcuts.
- Ajustes contínuos nas interfaces para refletir tipos opcionais e coleções específicas do Dart.
