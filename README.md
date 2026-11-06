# Lydo

Leitor e editor de PDF para Android, leve e que **continua a leitura exatamente de onde você parou**.

Feito em Flutter com o motor [pdfrx](https://pub.dev/packages/pdfrx) (PDFium, o mesmo do Chrome).

## O que já funciona

- **Biblioteca:** "Continuar lendo", busca sem acentos, filtros Todos/Recentes/Favoritos, lista ou grade, renomear e remover.
- **Leitor:** retoma página, zoom e rolagem; busca no texto; miniaturas; página noturna; rolagem contínua ou horizontal.
- **Ajustes:** tema claro/escuro/sistema, tamanho da interface, retomar última página, manter tela ligada.

## Em desenvolvimento

- **Fase 2:** anotações (realçar, caneta, texto, nota).
- **Depois:** assinar, imagens, organizar páginas, juntar/dividir, OCR e resumo com IA.

## Rodar

```bash
flutter pub get
flutter run
```

Requer Flutter 3.47+ e Android SDK.

## Estrutura

```
lib/
  core/          Result tipado e formatadores
  domain/        entidades e contratos (sem Flutter)
  data/          repositórios (SharedPreferences + JSON local)
  presentation/  telas e controllers (ValueNotifier)
```

As telas de referência do design estão na raiz do projeto (`*.png`).
