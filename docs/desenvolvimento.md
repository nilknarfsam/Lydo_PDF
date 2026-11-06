# Desenvolvimento

Guia para rodar, testar e contribuir no Lydo.

## Requisitos

- **Flutter 3.47** ou mais recente (o `pubspec.yaml` pede Dart `^3.13.1`).
- **Android SDK** instalado (o Android Studio instala e gerencia).
- **Java**: o JDK que vem com o Android Studio basta.
- **Celular Android** com depuração USB ligada e `adb` disponível no PATH. O aparelho de testes do Franklin está descrito no `CLAUDE.md`.

Confira o ambiente com `flutter doctor`.

## Comandos

Rode na raiz do projeto (`C:\projetos\pdf_reader`).

| Comando | Quando usar |
|---|---|
| `flutter pub get` | Depois de clonar ou mudar o `pubspec.yaml`. |
| `flutter analyze` | Antes de todo commit. Deve sair sem avisos. |
| `flutter test` | Roda os 38 testes. |
| `flutter build apk --debug` | Gera o APK de depuração. |
| `adb install -r build/app/outputs/flutter-apk/app-debug.apk` | Instala o APK no celular conectado (`-r` reinstala mantendo os dados). |

Checagem completa antes de entregar:

```bash
flutter analyze
flutter test
flutter build apk --debug
```

A versão debug demora alguns segundos para abrir no celular. Tela preta no começo é normal.

## Testes

Os testes estão em `test/`. São 38 casos, sem dependência de aparelho.

| Arquivo | O que cobre |
|---|---|
| `widget_test.dart` | `DocumentEntry` em JSON (mantém a posição de leitura), impressão digital (estável e diferencia conteúdo e tamanho) e `PrefsLibraryRepository` (salvar, atualizar, listar do mais recente ao mais antigo e remover). |
| `library_logic_test.dart` | Formatadores (tamanho de arquivo e dia relativo), `HomeState` (busca sem diferenciar maiúsculas e acentos, filtros de recentes e favoritos, "Continuar lendo") e `AppSettings` em JSON, incluindo valores desconhecidos. |
| `annotation_test.dart` | `highlightRects` (uma linha, várias linhas, página sem texto), `remapAnnotations`, `stampRect`, teste de imagem, borracha, ida e volta de anotação em JSON e o repositório JSON (salvar, carregar e apagar por documento). |
| `signature_test.dart` | `FileSignatureRepository` (salvar, listar e apagar; mais recente primeiro; apagar id inexistente não é erro) e `SignaturePadController` (começar, estender, desfazer e limpar). |
| `page_plan_test.dart` | `PagePlan` (identidade, `isIdentity`, `newNumberOf` depois de excluir e mover) e `PageOrganizerController` (girar 4 vezes volta ao original, excluir todas é recusado, mover, desfazer e `hasChanges`). |

O que **não** tem teste automatizado: a exportação com PDFium (`pdf_edit_service.dart`), a renderização real no leitor e a câmera/galeria. Esses pontos são verificados no celular.

## Convenções de código

Resumo do `CLAUDE.md`, que é a fonte completa:

- **Clean Architecture:** `lib/domain` (sem Flutter), `lib/data` (repositórios e serviços), `lib/presentation` (telas e controllers), `lib/core` (`Result`, formatadores).
- **Estado:** controllers com `ValueNotifier` ou `ChangeNotifier`. Nada de Bloc, Riverpod, GetX ou Provider.
- **Erros:** `Result` tipado. Exceção não chega à interface.
- **Sem regra de negócio dentro de `build()`.**
- **`RepaintBoundary`** em listas, barras animadas e widgets caros.
- **Persistência:** `SharedPreferences` + JSON. Anotações em arquivo JSON por documento. Nada de banco sem decisão do Franklin.
- **UI:** `package:material_ui/material_ui.dart`, e não `flutter/material.dart`.
- **Dependências:** avisar antes de adicionar algo no `pubspec.yaml`, dizendo qual e por quê.
- **Mudanças cirúrgicas.** Problema fora do escopo vira uma linha no fim da resposta.
- **Textos da UI em português do Brasil**, coerentes com as telas de referência (`*.png` na raiz). Identificadores em inglês.

Checklist de revisão (do `CLAUDE.md`):

1. Lógica de negócio vazando para widget.
2. Exceção em vez de `Result`.
3. Rebuild desnecessário (notifier amplo, falta de `RepaintBoundary`).
4. Estado mutável compartilhado sem controller.
5. `SharedPreferences` acessado fora de `lib/data`.
6. Textos da UI em pt-BR e coerentes com as telas de referência.

## Armadilhas conhecidas

- **BOM do Windows PowerShell 5.1.** `Set-Content -Encoding utf8` grava um BOM, e isso quebra o `build.gradle.kts`. Para arquivos Android ou Gradle, use a ferramenta de edição do Claude ou grave com `UTF8Encoding($false)`.
- **Dois nomes diferentes.** O pacote Dart se chama `pdf_reader`. O app e o ID Android são **Lydo** / `com.franklin.lydo`. Não renomeie um pelo outro.
- **Coordenadas do PDF.** A origem fica no canto **inferior esquerdo**, com Y para cima. As anotações são salvas assim (`APoint` e `ARect`). Ao desenhar na tela, converta com o `pdfrx`.
- **Giro da página.** Anotações guardam coordenadas sem giro. Imagens guardam o `turns` do momento em que foram colocadas.
- **Pacote de app antigo.** O aplicativo "Leitor PDF" (`com.franklin.pdf_reader`) pode ainda estar instalado no celular. Não confunda com o Lydo.
- **Código da API do `pdfrx`** (coordenadas, `PdfViewerParams`, texto da página, FFI do PDFium) é delicado. Não delegue a tarefas automáticas sem revisão.
- **Pasta `build/`** é gerada pelo build. Não edite nada nela.

## Como fazer commit

1. Rode `flutter analyze` e `flutter test`. Só commite com os dois limpos.
2. Confira o que vai entrar: `git status` e `git diff`.
3. Adicione só os arquivos da mudança, pelo nome.
4. Escreva a mensagem em **português do Brasil**, começando pelo escopo, no mesmo estilo do histórico:

   ```text
   Fase 3: modo Editar (assinatura, imagem, organizar páginas, exportar PDF)
   ```

   Corpo opcional: o porquê da mudança, em frases curtas.

5. Commits feitos com IA levam a linha `Co-Authored-By` exigida pela configuração do ambiente. Veja a skill `configurar-autoria-git` se for preparar um PC novo.
6. Depois de commitar, atualize o [Histórico da MEMORIA](../MEMORIA.md#6-histórico) com o commit novo.

O repositório remoto está em https://github.com/nilknarfsam/Lydo_PDF.

## Ver também

- [Arquitetura](arquitetura.md): onde mexer para cada tipo de mudança.
- [Orquestração com IA](orquestracao-ia.md): como o trabalho é dividido entre os modelos.
