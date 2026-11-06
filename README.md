# Lydo

Leitor e editor de PDF para **Android**: leve, bonito e que **continua a leitura exatamente de onde você parou**.

Feito em Flutter com o motor [pdfrx](https://pub.dev/packages/pdfrx) (PDFium, o mesmo do Chrome).

## O que ele faz

| Área | Recursos |
|---|---|
| **Biblioteca** | Continuar lendo, busca sem acentos, filtros Todos/Recentes/Favoritos, lista ou grade, renomear, remover |
| **Leitor** | Retoma página, zoom e rolagem; busca no texto; miniaturas; página noturna; rolagem contínua ou horizontal |
| **Anotar** | Realce que gruda no texto, caneta, texto, notas, borracha, desfazer/refazer, 4 cores e 3 espessuras |
| **Editar** | Assinatura desenhada (salva para reusar), imagens, organizar páginas (girar, excluir, reordenar) |
| **Exportar** | PDF com tudo gravado dentro: realce nativo do PDF e texto original continua pesquisável |
| **Ajustes** | Tema claro/escuro/sistema, tamanho da interface, retomar última página, manter tela ligada |

## Status

| Fase | Conteúdo | Status |
|---|---|---|
| 1 | Biblioteca, leitor e ajustes | ✅ |
| 2 | Modo Anotar | ✅ |
| 3 | Modo Editar e exportar PDF | ✅ |
| 4+ | Abrir com outros apps, juntar/dividir, OCR, resumo com IA | 📋 planejado |

## Documentação

Tudo em [`docs/`](docs/README.md):

- [Visão geral](docs/visao-geral.md)
- [Fases do projeto](docs/fases.md)
- [Arquitetura](docs/arquitetura.md)
- [Como cada recurso funciona](docs/funcionalidades.md)
- [Guia de desenvolvimento](docs/desenvolvimento.md)
- [Desenvolvimento com IA (orquestração)](docs/orquestracao-ia.md)

Para agentes de IA: [`CLAUDE.md`](CLAUDE.md) (regras) e [`MEMORIA.md`](MEMORIA.md) (estado atual).

## Rodar

```bash
flutter pub get
flutter run
```

Requer Flutter 3.47+ e Android SDK. Detalhes em [docs/desenvolvimento.md](docs/desenvolvimento.md).

## Estrutura

```
lib/
  core/          Result tipado, formatadores, desenho das anotações
  domain/        entidades e contratos (Dart puro)
  data/          repositórios, importação e edição do PDF (PDFium)
  presentation/  telas e controllers (ValueNotifier)
docs/            documentação completa
```

As telas de referência do design estão na raiz do projeto (`*.png`).
