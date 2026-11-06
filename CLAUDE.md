# Lydo — instruções para o Claude

Leitor/editor de PDF para **Android** (por enquanto só Android), em Flutter 3.47 + `pdfrx` (PDFium).
Repositório: https://github.com/nilknarfsam/Lydo_PDF

## Memória do projeto

- **Antes de qualquer tarefa, leia `MEMORIA.md`**: estado atual, mapa do código, decisões e próximos passos.
- Todo briefing de subagente começa com: "Leia `CLAUDE.md` e `MEMORIA.md` antes de começar."
- Ao terminar uma tarefa, o principal atualiza `MEMORIA.md` (estado, próximos passos, histórico, arquivos novos no mapa). Subagentes **não** editam a MEMORIA.md, só informam o que mudou no relatório.

## Idioma

- Responder **sempre em português do Brasil**, tom informal (inclusive mensagens de progresso).
- Código, nomes de classes e identificadores podem ficar em inglês; comentários e textos da UI em PT-BR.

## Como trabalhar (orquestração com economia de tokens)

Objetivo: **gastar pouco do limite**. O modelo principal **orquestra**: entende o pedido, decide a
arquitetura, escreve briefings curtos, integra e verifica. Ele delega o máximo possível para
modelos mais baratos:

| Tarefa | Quem faz | Como |
|---|---|---|
| Coordenar: planejar com o Franklin, briefings, conferir cada entrega, redirecionar | **principal** + Franklin | direto |
| Partes minuciosas/delicadas: API do pdfrx (coordenadas, `PdfViewerParams`, edição do PDF), bugs difíceis | **principal** | direto |
| **Escrever o código** (widgets, telas, repositórios, controllers, testes, textos, estilo) | subagente **Haiku** | `Agent` com `model: "haiku"` |
| **Revisar** cada entrega do Haiku | subagente **Sonnet** | `Agent` com `model: "sonnet"`, checklist abaixo; só aponta, não edita |

Ciclo de cada tarefa: principal escreve o briefing → Haiku implementa → Sonnet revisa e lista
problemas → principal decide o que vale corrigir e devolve ao Haiku (ou corrige se for delicado)
→ principal roda `analyze`/`test` e confere o diff.

Economia:
- Mudança de 1 arquivo ou poucas linhas: o principal faz direto (subagente começa do zero e relê tudo, custaria mais).
- Briefing curto e completo: caminhos exatos, assinaturas, o que é "pronto". Não mandar o subagente "explorar".
- Não reler arquivos que já estão no contexto; ler só o trecho necessário.
- Não pedir revisão para mudança pequena — `flutter analyze` + `flutter test` bastam.
- Respostas finais curtas: o que mudou, o que testar, o que falta.

Regras da delegação:
- O briefing de cada subagente diz: arquivos que pode tocar, assinatura/contrato esperado, o que é "pronto" e que deve rodar `flutter analyze` no fim.
- Dois subagentes nunca editam o mesmo arquivo ao mesmo tempo.
- Peças independentes podem rodar em paralelo.
- O Opus sempre confere o resultado (diff + `flutter analyze` + `flutter test`) antes de dizer que terminou.
- Código que mexe na API do `pdfrx` (coordenadas, `PdfViewerParams`, texto da página) fica com o principal ou o Sonnet, nunca com o Haiku.

## Convenções de código (obrigatórias)

- Clean Architecture: `lib/domain` (entidades e contratos, **sem Flutter**), `lib/data` (repositórios), `lib/presentation` (telas + controllers), `lib/core` (`Result`, formatadores).
- Estado com **controllers + `ValueNotifier`/`ChangeNotifier`**. Sem Bloc/Riverpod/GetX/Provider.
- Erros com **`Result` tipado** (`lib/core/result.dart`), nunca exceção chegando na UI.
- Nada de regra de negócio dentro de `build()`.
- `RepaintBoundary` em listas, barras animadas e widgets caros.
- Persistência: `SharedPreferences` + JSON. Dados grandes (anotações) em arquivo JSON por documento. **Nada de banco** (Hive/Isar/sqflite/Drift) sem o Franklin decidir.
- UI usa `package:material_ui/material_ui.dart` (não `flutter/material.dart`): o pdfrx usa material_ui.
- Avisar antes de adicionar dependência no `pubspec.yaml` (qual e por quê).
- Mudanças cirúrgicas; problema fora do escopo vira uma linha no fim da resposta.

## Checklist de revisão

1. Lógica de negócio vazando para widget
2. Exceção em vez de `Result`
3. Rebuild desnecessário (notifier amplo, falta de `RepaintBoundary`)
4. Estado mutável compartilhado sem controller
5. `SharedPreferences` acessado fora de `lib/data`
6. Textos da UI em PT-BR e coerentes com as telas de referência (`*.png` na raiz)

## Verificar antes de entregar

```bash
flutter analyze
flutter test
flutter build apk --debug
```

Instalar no celular (aparelho real conectado por USB, id `0076070504`):

```bash
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

- Não enviar arquivos para o celular nem tirar print dele sem o Franklin pedir.
- A versão debug demora alguns segundos para abrir (tela preta no começo é normal).

## Armadilhas conhecidas

- **Windows PowerShell 5.1:** nunca gravar arquivos Android/Gradle com `Set-Content -Encoding utf8`, porque ele grava um BOM que quebra o `build.gradle.kts`. Use as ferramentas de edição ou `UTF8Encoding($false)`.
- O pacote Dart chama `pdf_reader`. O app e o ID Android são **Lydo** / `com.franklin.lydo`.
- Coordenadas do PDF têm origem no canto **inferior** esquerdo (Y para cima). As anotações são salvas assim (`APoint`/`ARect`).

## Roteiro

- ✅ Fase 1: biblioteca, leitor (retomar posição, busca, miniaturas), ajustes.
- ✅ Fase 2: Anotar (realçar no texto, caneta, texto, nota, borracha, desfazer).
- ⏭️ Fase 3: Editar (imagem, assinar, organizar páginas) e exportar PDF com anotações.
- Depois: juntar/dividir, OCR, resumo com IA, abrir PDF por "Abrir com" de outros apps.
