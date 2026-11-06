# Documentação do Lydo

Índice da documentação do Lydo, leitor e editor de PDF para Android feito em Flutter.

Quem é novo no projeto deve começar por [Visão geral](visao-geral.md), depois [Arquitetura](arquitetura.md). Quem vai mexer no código deve ler também [Funcionalidades](funcionalidades.md) e [Desenvolvimento](desenvolvimento.md).

## Arquivos

| Arquivo | Para que serve |
|---|---|
| [visao-geral.md](visao-geral.md) | O que é o Lydo, para quem é, stack, funcionalidades atuais e diferenciais. |
| [fases.md](fases.md) | Roteiro por fases (1 a 3 concluídas, 4+ planejadas), commits de cada fase e pendências conhecidas. |
| [arquitetura.md](arquitetura.md) | Camadas da Clean Architecture, mapa "arquivo → responsabilidade", padrões e onde cada dado é salvo. |
| [funcionalidades.md](funcionalidades.md) | Como cada recurso funciona por dentro: retomar leitura, busca, realce, anotações, assinatura, organizar páginas e exportar. |
| [desenvolvimento.md](desenvolvimento.md) | Requisitos, comandos de build e teste, testes existentes, convenções, armadilhas e como fazer commit. |
| [orquestracao-ia.md](orquestracao-ia.md) | Como o projeto é desenvolvido com IA: papéis dos modelos, ciclo de cada tarefa e regras de economia de tokens. |

## Fontes internas (fora desta pasta)

| Arquivo | Para que serve |
|---|---|
| [../CLAUDE.md](../CLAUDE.md) | Instruções de trabalho para o Claude: idioma, convenções obrigatórias e checklist de revisão. |
| [../MEMORIA.md](../MEMORIA.md) | Memória do projeto: estado atual, mapa do código, decisões, próximos passos e histórico. É a fonte principal para quem está retomando o trabalho. |

Esta documentação descreve o estado do código no commit `5cd4604` (fim da fase 3). Quando algo mudar, atualize o arquivo afetado e o [Histórico da MEMORIA](../MEMORIA.md).
