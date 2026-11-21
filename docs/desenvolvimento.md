# Desenvolvimento

Guia para rodar, testar e contribuir no Lydo.

## Requisitos

- **Flutter 3.50** ou mais recente (o `pubspec.yaml` pede Dart `^3.13.1`).
- **Android SDK** instalado (o Android Studio instala e gerencia). O projeto usa o Android Gradle Plugin 9.1.1 (`android/settings.gradle.kts`).
- **Java**: o JDK que vem com o Android Studio basta.
- **Celular Android** com depuração USB ligada. O `adb` não fica no PATH deste PC: use `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe`. O aparelho de testes do Franklin está descrito no `CLAUDE.md`. Sem celular, ver [Emulador](#emulador).

Confira o ambiente com `flutter doctor`.

## Comandos

Rode na raiz do projeto (`C:\PROJETOS\Lydo_PDF`).

| Comando | Quando usar |
|---|---|
| `flutter pub get` | Depois de clonar ou mudar o `pubspec.yaml`. |
| `flutter analyze` | Antes de todo commit. Deve sair sem avisos. |
| `flutter test` | Roda os 43 testes. |
| `flutter build apk --debug` | Gera o APK de depuração. |
| `adb install -r build/app/outputs/flutter-apk/app-debug.apk` | Instala o APK de debug (`-r` reinstala mantendo os dados). A debug tem outra assinatura: não instala por cima da release. |
| `flutter build apk --release` | Gera o APK de release, assinado com a chave do Lydo (ver [Versão release](#versão-release-e-chave-de-assinatura)). |
| `adb install -r build/app/outputs/flutter-apk/app-release.apk` | Instala a release por cima da versão instalada, mantendo os dados. |

Checagem completa antes de entregar:

```bash
flutter analyze
flutter test
flutter build apk --debug
```

A versão debug demora alguns segundos para abrir no celular. Tela preta no começo é normal.

## Testes

Os testes estão em `test/`. São 43 casos, sem dependência de aparelho.

| Arquivo | O que cobre |
|---|---|
| `widget_test.dart` | `DocumentEntry` em JSON (mantém a posição de leitura), impressão digital (estável e diferencia conteúdo e tamanho) e `PrefsLibraryRepository` (salvar, atualizar, listar do mais recente ao mais antigo e remover). |
| `library_logic_test.dart` | Formatadores (tamanho de arquivo e dia relativo), `HomeState` (busca sem diferenciar maiúsculas e acentos, filtros de recentes e favoritos, "Continuar lendo") e `AppSettings` em JSON, incluindo valores desconhecidos. |
| `annotation_test.dart` | `highlightRects` (uma linha, várias linhas, página sem texto), `remapAnnotations`, `stampRect`, teste de imagem, borracha, ida e volta de anotação em JSON e o repositório JSON (salvar, carregar e apagar por documento). |
| `signature_test.dart` | `FileSignatureRepository` (salvar, listar e apagar; mais recente primeiro; apagar id inexistente não é erro) e `SignaturePadController` (começar, estender, desfazer e limpar). |
| `page_plan_test.dart` | `PagePlan` (identidade, `isIdentity`, `newNumberOf` depois de excluir e mover) e `PageOrganizerController` (girar 4 vezes volta ao original, excluir todas é recusado, mover, desfazer e `hasChanges`). |
| `stamp_cleanup_test.dart` | `StampCleanupService.sweep()` (limpeza de `stamps/`). |

O que **não** tem teste automatizado: a exportação com PDFium (`pdf_edit_service.dart`), a renderização real no leitor e a câmera/galeria. Esses pontos são verificados no celular.

## Versão release e chave de assinatura

A release é assinada com uma chave própria do Lydo, e não com a de debug. O Android só atualiza um app instalado se a assinatura for a mesma, então a chave precisa ser sempre a mesma.

- **Chave:** `C:\Users\<usuário>\.lydo\lydo-release.jks`, alias `lydo`.
- **Configuração:** o Gradle lê `android/key.properties` (`signingConfig`). Esse arquivo fica **fora do Git**. O modelo é `android/key.properties.example`.
- **Sem `key.properties`:** a release cai na chave de debug. O APK compila, mas não atualiza o app já instalado com a chave do Lydo.
- **Criar a chave:** dê dois cliques em `tools/criar_chave_release.bat`. Ele pede a senha e grava o `key.properties`.
- **Backup:** a pasta `backup_chave/` (fora do Git) guarda a cópia. Guarde-a num lugar seguro.
- **Outro PC:** copie o `.jks` e o `key.properties`. Sem os dois não dá para atualizar o app instalado: só desinstalando, o que apaga os dados.

```bash
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

## Emulador

O emulador deste PC é o AVD `MotoEdge20`. Suba com a opção `-gpu swiftshader_indirect`, senão o boot pode travar como "offline". Para girar a tela (com `adb` do caminho acima):

```bash
adb shell cmd window user-rotation lock 1   # deitado
adb shell cmd window user-rotation lock 0   # em pé
```

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
- **Chave de release.** O `.jks` e o `key.properties` nunca vão para o Git. Sem eles, a atualização do app instalado é impossível. Ver [Versão release](#versão-release-e-chave-de-assinatura).
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
