# Orquestração com IA

O Lydo é desenvolvido com ajuda de modelos de IA. Este documento explica quem faz o quê, como cada tarefa passa pelo processo e por que ele existe: **gastar pouco do limite sem perder qualidade**.

As regras completas estão no [CLAUDE.md](../CLAUDE.md). Este texto é o resumo explicado.

## Papéis

| Papel | Quem | O que faz |
|---|---|---|
| Dono do projeto | Franklin | Decide o que fazer e o que é prioridade. Testa no celular. Aprova decisões de produto e de arquitetura. |
| Principal | Modelo que coordena a sessão (o `CLAUDE.md` cita o Opus) | Entende o pedido, decide a arquitetura, escreve os briefings, confere cada entrega e integra. Faz direto as partes delicadas. |
| Escritor | Subagente **Haiku** | Escreve o código: widgets, telas, repositórios, controllers, testes e textos. |
| Revisor | Subagente **Sonnet** | Revisa cada entrega do Haiku com um checklist. Só aponta problemas, não edita. |

Partes delicadas ficam com o principal (ou com o Sonnet), nunca com o Haiku:

- API do `pdfrx` (coordenadas, `PdfViewerParams`, texto da página);
- edição e exportação do PDF pelo PDFium (FFI);
- bugs difíceis.

### Divisão de tarefas

| Tarefa | Quem faz | Como |
|---|---|---|
| Coordenar: planejar com o Franklin, escrever briefings, conferir entregas, redirecionar | principal + Franklin | Direto |
| Partes minuciosas ou delicadas | principal | Direto |
| Escrever código (telas, repositórios, controllers, testes, textos) | Haiku | Subagente com `model: haiku` |
| Revisar entregas do Haiku | Sonnet | Subagente com `model: sonnet`, usando o checklist |

## Ciclo de cada tarefa

1. **Briefing.** O principal escreve um briefing curto e completo: caminhos exatos, assinaturas esperadas, o que é "pronto" e a instrução para rodar `flutter analyze` no fim.
2. **Implementação.** O Haiku escreve o código dentro dos arquivos indicados.
3. **Revisão.** O Sonnet revisa e lista os problemas. Para mudanças pequenas, essa etapa é pulada.
4. **Decisão.** O principal decide o que vale corrigir. Corrige sozinho o que é delicado ou devolve ao Haiku.
5. **Verificação.** O principal roda `flutter analyze` e `flutter test`, e confere o diff antes de dizer que terminou.
6. **Registro.** Ao fim da tarefa, o principal atualiza a [MEMORIA](../MEMORIA.md): estado, próximos passos, histórico e o mapa do código quando há arquivos novos.

## Regras de economia de tokens

- **Mudança de um arquivo ou poucas linhas:** o principal faz direto. Um subagente começa do zero e relê tudo, o que custa mais.
- **Briefing enxuto:** caminhos exatos, assinatura, critério de pronto. Nunca mandar o subagente "explorar".
- **Não reler o que já está no contexto.** Ler só o trecho necessário.
- **Revisão só para mudança grande.** Para mudança pequena, `flutter analyze` e `flutter test` bastam.
- **Respostas finais curtas:** o que mudou, o que testar, o que falta.
- **Trabalho independente em paralelo.** Peças que não tocam nos mesmos arquivos podem rodar ao mesmo tempo.

### Regras da delegação

- Cada briefing diz os arquivos que o subagente pode tocar, o contrato esperado e o que é "pronto".
- Dois subagentes **nunca editam o mesmo arquivo ao mesmo tempo**.
- Subagentes **não editam a MEMORIA.md**. Eles informam o que mudou no relatório, e o principal atualiza.
- Código que mexe na API do `pdfrx` ou no PDFium não vai para o Haiku.

## Checklist do revisor

1. Lógica de negócio vazando para widget.
2. Exceção em vez de `Result`.
3. Rebuild desnecessário (notifier amplo, falta de `RepaintBoundary`).
4. Estado mutável compartilhado sem controller.
5. `SharedPreferences` acessado fora de `lib/data`.
6. Textos da UI em português do Brasil e coerentes com as telas de referência.

## Como o CLAUDE.md e a MEMORIA.md são usados

- **`CLAUDE.md`** é lido automaticamente no início de cada sessão. Traz idioma, convenções obrigatórias, o processo de delegação e as armadilhas do projeto. Todo briefing de subagente começa com "Leia `CLAUDE.md` e `MEMORIA.md` antes de começar".
- **`MEMORIA.md`** é a **fonte principal** de contexto. Tem o estado atual, o mapa do código (onde fica cada coisa), as decisões já tomadas (que não devem ser rediscutidas sem o Franklin), os próximos passos, as dívidas e o histórico com commits.

Quando algo muda, o principal atualiza a MEMORIA. Sem isso, a próxima sessão começa do zero e gasta tokens redescobrindo o projeto.

## Exemplo real: fase 3

A fase 3 (Editar e exportar) ilustra o ciclo:

1. **Divisão em paralelo.** Três peças foram escritas pelo Haiku ao mesmo tempo: a tela de assinatura, a de organizar páginas e a barra do modo Editar. Cada uma em arquivos diferentes, o que permitiu o paralelismo.
2. **Revisão.** O Sonnet revisou as entregas e apontou **1 problema crítico**, com risco de estourar a memória na exportação, e **5 problemas importantes**.
   - Reorganizar páginas podia deixar a biblioteca apontando para o arquivo antigo (o leitor antigo regravava a posição ao fechar).
   - Imagens e assinaturas ficavam esticadas em páginas giradas.
   - Apagar uma assinatura da lista fazia ela sumir dos PDFs já assinados.
   - O realce escurecia o texto no PDF exportado (passou a ser anotação /Highlight nativa).
   - Fotos grandes eram carregadas em tamanho original na memória.
3. **Correção.** Os 6 problemas foram corrigidos. Como está hoje no código, a exportação cuida da memória processando **uma página por vez** e limitando a imagem a cerca de **4 megapixels** por página.
4. **Verificação.** `flutter analyze` sem avisos e `flutter test` com 38 testes passando.
5. **Registro.** A MEMORIA foi atualizada com o estado da fase, e o commit `5cd4604` foi feito.

O exemplo mostra o valor do processo: a revisão pegou o problema de memória antes de o Franklin testar a exportação no celular, que ainda não tinha sido feito.

## Ver também

- [CLAUDE.md](../CLAUDE.md): regras completas de trabalho.
- [MEMORIA.md](../MEMORIA.md): estado e histórico do projeto.
- [Desenvolvimento](desenvolvimento.md): comandos, testes e commits.
