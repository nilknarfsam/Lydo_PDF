# MEMÓRIA DO PROJETO — Lydo

> Leia isto **antes** de qualquer tarefa. Atualize as seções "Estado atual", "Próximos passos"
> e "Histórico" **ao terminar** cada tarefa. Regras de código ficam no `CLAUDE.md`.

_Última atualização: 2026-11-13 — modo "Página por página" + tela limpa; plano de polimento (fase 3.5)._

---

## 1. Estado atual

| Fase | O quê | Status |
|---|---|---|
| 1 | Biblioteca, leitor que retoma a posição, busca, miniaturas, ajustes | ✅ pronto e instalado no celular |
| 2 | Modo Anotar: realçar, caneta, texto, nota, borracha, desfazer | ✅ pronto, aguardando teste no celular |
| 3 | Modo Editar: assinar, imagem, organizar páginas, exportar PDF anotado | ✅ pronto e instalado, **aguardando teste do Franklin** (exportação nunca rodou num aparelho) |
| 3.5 | Polimento: página por página ✅, tela limpa ✅, demais itens em "Próximos passos" | 🚧 em andamento |
| 4+ | Juntar/dividir, OCR, resumo com IA, "Abrir com" de outros apps | 📋 ideias |

- **Testes:** 43 passando (`flutter test`). `flutter analyze` sem avisos. Flutter 3.50 → AGP 9.1.1 (`android/settings.gradle.kts`).
- **Assinatura:** chave de release própria `C:\Users\nilkn\.lydo\lydo-release.jks` (alias `lydo`, `CN=Lydo`, SHA-256 `08d784c7…be64238`), lida de `android/key.properties` (fora do Git; modelo em `android/key.properties.example`). Sem o key.properties, a release cai na chave de debug. Criada com `tools/criar_chave_release.bat`. Em outro PC: copiar o .jks e o key.properties. Backup: pasta `backup_chave/` no projeto (fora do Git) → Franklin sobe para o Drive em "💻 Trabalho e Projetos / Lydo PDF / Chave de release (backup)" (pasta com acesso só dele). Release com essa chave instalada no celular em 2026-11-20.
- **adb** não está no PATH: `$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe`.
- **Último commit:** ver `git log -1`.
- **Emulador para conferir telas:** AVD `Medium_Phone_API_36.1` (1080×2400, igual ao Moto Edge 20 do Franklin; densidade 400 via `adb shell wm density 400`). PDF de teste em `/sdcard/Download/teste_lydo.pdf`. No Git Bash use `MSYS_NO_PATHCONV=1` com `adb`.

## 2. Mapa do código (onde está cada coisa)

```
lib/
  main.dart                         monta repositórios/controllers, tema e escala da interface
  core/
    result.dart                     Result<T> (Ok/Err) + AppFailure
    formatters.dart                 formatBytes ("4,2 MB"), formatRelativeDay ("Hoje")
    annotation_renderer.dart        paintAnnotations() (tela E exportação usam o mesmo) + AnnotationImageCache
  domain/                           (Dart puro, sem Flutter)
    document_entry.dart             PDF da biblioteca + posição (página, matriz, favorito, tamanho)
    library_repository.dart         contrato da biblioteca
    app_settings.dart               ajustes (tema, escala, rolagem, retomar, tela ligada, grade)
    settings_repository.dart        contrato dos ajustes
    annotation.dart                 Annotation, APoint, ARect, highlightRects() (realce que gruda no texto)
    annotation_repository.dart      contrato das anotações
    page_plan.dart                  PagePlan/PageSlot: nova ordem + giros (organizar páginas)
    signature_repository.dart       contrato das assinaturas salvas
  data/
    prefs_library_repository.dart   biblioteca em SharedPreferences (chave library.v1)
    prefs_settings_repository.dart  ajustes em SharedPreferences (chave settings.v1)
    json_annotation_repository.dart anotações em <docs>/annotations/<id>.json
    pdf_import_service.dart         seletor de arquivo + cópia para <docs>/pdfs/<id>.pdf + impressão digital
    cover_cache_service.dart        capa (pág. 1) em PNG em <docs>/covers/<nome-do-pdf>.png, gerada uma vez
    pdf_edit_service.dart           DELICADO (FFI PDFium): applyPagePlan + exportWithAnnotations
    stamp_import_service.dart       fotos/assinaturas copiadas para <docs>/stamps/ + proporção
    stamp_cleanup_service.dart      apaga de stamps/ o que nenhum JSON de anotações cita (por nome do arquivo; JSON ilegível → não apaga nada)
    file_signature_repository.dart  assinaturas PNG em <docs>/signatures/
  presentation/
    theme/lydo_theme.dart           cores LydoColors, tema claro/escuro, LydoLogo, extensão context.*
    shell/app_shell.dart            barra inferior Arquivos/Ferramentas/Ajustes
    home/home_controller.dart       HomeState (busca, filtros, continuar lendo) + ações da biblioteca
    home/home_page.dart             tela Arquivos (lista/grade, menu ⋮, DocumentCover)
    tools/tools_page.dart           vitrine "em breve"
    settings/settings_controller.dart + settings_page.dart
    reader/reader_controller.dart   página atual, busca (PdfTextSearcher), salvar posição, layout horizontal
    reader/reader_page.dart         leitor: barra superior, abas Ler/Anotar/Editar, miniaturas, diálogos
    reader/annotation_controller.dart  ferramenta, cor, espessura, desfazer/refazer, traço em andamento
    reader/annotation_layer.dart    overlays de texto/nota, gestos de desenho, barra do modo Anotar
    reader/edit_toolbar.dart        barra do modo Editar (Imagem, Assinar, Páginas, Exportar)
    edit/signature_pad_*.dart       tela de desenhar assinatura (PNG 3x, fundo transparente)
    edit/signature_picker_sheet.dart  escolher assinatura salva ou criar nova
    edit/page_organizer_*.dart      organizar páginas (girar, excluir, arrastar) → devolve PagePlan
test/
  widget_test.dart                  DocumentEntry, impressão digital, repositório da biblioteca
  library_logic_test.dart           formatadores, filtros/busca, AppSettings
  annotation_test.dart              highlightRects, borracha, JSON, remap, stampRect, repositório
  signature_test.dart               repositório de assinaturas + controller do desenho
  page_plan_test.dart               PagePlan + PageOrganizerController
  stamp_cleanup_test.dart           limpeza de stamps/
```

Telas de referência do design: `*.png` na raiz (nome antigo nas imagens: "Forma PDF").

## 3. Decisões tomadas (não rediscutir sem o Franklin)

- **Nome:** Lydo. ID Android `com.franklin.lydo`. Pacote Dart continua `pdf_reader`.
- **Plataforma:** só Android por enquanto.
- **Motor PDF:** `pdfrx` 2.12 (PDFium, licença BSD). UI com `material_ui` (exigência do pdfrx no Flutter 3.47).
- **Identidade do documento:** hash FNV-1a dos primeiros 64 KB + tamanho → o mesmo PDF reaberto mantém o progresso, mesmo renomeado.
- **PDF importado é copiado** para a pasta do app (o `content://` do Android expira).
- **Posição salva:** página + matriz de zoom/rolagem (só reaplicada no mesmo modo de rolagem).
- **Anotações:** ficam no JSON do Lydo, em coordenadas do PDF sem giro (origem no canto inferior esquerdo).
- **Exportar:** gera um PDF novo e salva onde a pessoa escolher (FilePicker.saveFile). Realce vira anotação /Highlight nativa do PDF; caneta/texto/nota/imagens viram UMA imagem transparente por página por cima do conteúdo (texto original continua pesquisável). Uma página por vez, máx. ~4 MP por página.
- **Imagem/assinatura:** guarda `turns` = giro da página quando foi colocada; o renderizador gira a imagem pela diferença. Assinatura usada é COPIADA para stamps/ (apagar da lista não some dos PDFs).
- **Organizar páginas:** grava um arquivo NOVO `<id>_<timestamp>.pdf`, renumera anotações, salva a entrada, só então apaga o antigo; o leitor antigo é marcado `markReplaced()` para não sobrescrever a entrada.
- **Página por página (`ScrollMode.paged`):** pdfrx não tem modo de página única. Layout próprio (`ReaderController.pagedLayout`): páginas lado a lado com vão = maior lado da página, para a vizinha nunca aparecer. No fim do gesto (`onGestureEnd`) encaixa com `calcMatrixForFit` na próxima/anterior (velocidade > 250 px/s OU arrasto > 15% da tela); com zoom > 105% do encaixe, não encaixa. O encaixe é adiado (`Future.delayed(Duration.zero)`) porque o pdfrx chama `onInteractionEnd` ANTES de iniciar a inércia. Nesse modo sempre abre com a página salva inteira (não usa a matriz).
- **Modo no leitor:** `ReaderController.scrollMode` (ValueNotifier, começa no dos Ajustes). O `PdfViewer` escuta `scrollMode`; o pdfrx refaz o layout a cada atualização do widget (`_layoutDirty`), então trocar não recarrega o PDF. Depois do frame, volta à página atual.
- **Ícone:** escolhido pelo Franklin (conceito "B · Marcador"). Adaptável: `res/drawable/ic_launcher_foreground.xml` (vetor, reduzido a 72% para a área segura) + fundo `@color/ic_launcher_background` (#2F6BF6) em `mipmap-anydpi-v26`; PNGs antigos em `mipmap-*` para Android < 8.
- **Capas:** `HomeController.coverFor` → `CoverCacheService` (PNG 320 px). O nome segue o arquivo do PDF, então PDF reorganizado ganha capa nova; remover da biblioteca apaga a capa.
- **Tela limpa:** tocar na página esconde barras, indicador de página e as barras do Android (`immersiveSticky`); ao sair do leitor volta `edgeToEdge`.
- **Posição salva:** `DocumentEntry.lastLayout` = nome do `ScrollMode` (lê o antigo `lastLayoutHorizontal`).
- **Gesto no modo Anotar:** com ferramenta ativa, 1 dedo desenha e 2 dedos dão zoom/rolam. A `AnnotationGestureLayer` fica por cima do PdfViewer e engole os toques, então a pinça é feita à mão: `onScale*` + `pointerCount`, e a matriz nova vai em `viewer.value = viewer.makeMatrixInSafeRange(m)` (tela = doc × zoom + translação). Se entrar o 2º dedo, o traço em andamento é cancelado; depois de uma pinça, 1 dedo só volta a desenhar após soltar todos (estado zerado no `onPointerDown`, porque o recognizer nem sempre chama `onScaleEnd`). Tocar de novo na ferramenta solta e a página volta ao gesto normal do pdfrx.
- **Barras do leitor em vidro fosco:** `_Glass` em `reader_page.dart` (cor translúcida + `BackdropFilter` blur 14) na barra de cima, abas e faixa de miniaturas.
- **Celular de lado:** barra + abas numa linha (`compact`), miniaturas de 84 px. Rolagem vertical: ao girar/abrir deitado, encaixa a página pela largura mantendo a altura lida (`_fitWidthKeepingPlace`). Página por página deitado: encaixe padrão = largura, do topo (`_baseFit`); rolar para baixo lê a mesma página (inércia livre, só recentraliza se escorregou >24 px para o lado); vira a página só com deslize mais horizontal que vertical. `onViewSizeChanged` só age quando a orientação muda (teclado não reencaixa).
- **Emulador deste PC:** AVD `MotoEdge20` (subir com `-gpu swiftshader_indirect`; o boot normal travou "offline"). Girar: `adb shell cmd window user-rotation lock 1` (0 = em pé).
- **Miniaturas em Anotar/Editar:** `ReaderController.toolThumbs` liga a faixa por cima da barra de ferramentas (botão redondo ao lado da pílula da página).
- **Editar o texto original do PDF** (fonte/tamanho, como na tela de referência) é muito difícil: o plano é "cobrir e escrever por cima".
- **Fora por enquanto:** avatar "FC" (sem login), ajustes "Salvar rascunhos / Preservar original / Pasta de exportação" (voltam na fase 3).
- **Dependências:** pdfrx, shared_preferences, file_picker, path_provider, material_ui, wakelock_plus, pdfium_dart e ffi (estes dois já vinham com o pdfrx; usados na exportação). Nova dependência → avisar o Franklin.

## 4. Próximos passos (plano combinado: deixar o app "redondinho" antes da fase 4)

**Fase 3.5 — polimento (nesta ordem):**
1. ✅ Franklin testou no celular (versão release instalada, estável e abrindo rápido): Exportar, Páginas, Página por página.
2. ✅ Trocar o modo de leitura direto no leitor (menu ⋮ → Modo de leitura; também vira o padrão nos Ajustes).
3. ✅ Girar o celular no modo página por página: reencaixa a página atual (`onViewSizeChanged`).
3a. ✅ Carregamento: capas em PNG (`CoverCacheService`). Medido no emulador: abrir o app em debug 3,4–5,6 s × release 0,7–1,3 s → a lentidão sentida é principalmente da versão debug.
3b. ✅ Ícone original: "B · Marcador" (página branca + fita laranja + ponto azul).
3c. ✅ Versão **release** instalada no celular do Franklin.
4. ✅ Organizar páginas pergunta "Descartar mudanças?" ao voltar com mudanças (`PopScope`); `StampCleanupService` limpa `stamps/` sem uso ao abrir o app e ao remover um PDF.
5. ✅ (aguardando teste do Franklin) Anotar: dois dedos dão zoom/rolam mesmo com ferramenta ativa; botão de miniaturas ao lado da pílula da página em Anotar/Editar.
6. Editar: arrastar imagem/assinatura com o dedo.

**Fase 4 — recursos novos:** "Abrir com"/compartilhar de outros apps → juntar/dividir PDFs → OCR → resumo com IA.

## 5. Problemas conhecidos / dívidas

- Pinça com ferramenta ativa não tem inércia nem encaixe de página (modo Página por página): solta onde parou.
- Imagem/assinatura: só dá para mover/aumentar/diminuir pelo menu (toque nela no modo Editar); não tem arrastar com o dedo ainda.
- Notas no PDF exportado viram uma caixinha desenhada (não é a nota "pop-up" do PDF).
- O app antigo "Leitor PDF" (`com.franklin.pdf_reader`) pode ainda estar no celular, e pode ser desinstalado.

## 6. Histórico

| Data | O que foi feito | Commit |
|---|---|---|
| 2026-11-06 | Projeto criado; v0.1 leitor com retomada de leitura | — |
| 2026-11-06 | Nome Lydo; fase 1 com o visual das referências; repositório no GitHub | `1a9b4cc` |
| 2026-11-06 | Fase 2: modo Anotar; CLAUDE.md com orquestração | `68403d6` |
| 2026-11-06 | CLAUDE.md focado em economia de tokens; criada esta MEMORIA.md | `cb5cd86` |
| 2026-11-06 | Fase 3: Editar (assinatura, imagem, páginas, exportar). Haiku escreveu telas, Sonnet revisou (1 crítico + 5 importantes corrigidos) | `5cd4604` |
| 2026-11-06 | Documentação completa em `docs/`, README novo, versão 0.3.0 | `920e821` |
| 2026-11-13 | Modo "Página por página" + tela limpa (esconde tudo ao tocar); testado no emulador 1080×2400 | `ac01d20` |
| 2026-11-13 | Trocar modo de leitura no menu ⋮ do leitor; reencaixar ao girar; capas em cache (PNG); ícone novo "Marcador"; testado com livro de 411 págs/131 MB | `60fae59` |
| 2026-11-20 | CLAUDE.md: fluxo com Antigravity (Gemini) e Codex (ChatGPT) além de Haiku/Sonnet; Flutter 3.50 (analyze limpo, 40 testes ok) | — |
| 2026-11-20 | Organizar: confirmar ao sair com mudanças; limpeza de stamps/ sem uso; AGP 9.1.1 para o Flutter 3.50; release compilada | `1e4e4dc` |
| 2026-11-20 | Chave de release própria do Lydo (`tools/criar_chave_release.bat` + signingConfig no Gradle) | `f49ffd3` |
| 2026-11-20 | Anotar: zoom com dois dedos com ferramenta ativa; miniaturas em Anotar/Editar; release instalada por cima no celular | `31948c0` |
| 2026-11-21 | Leitor: barras em vidro fosco; layout compacto e página pela largura com o celular de lado; testado no emulador | (este commit) |
