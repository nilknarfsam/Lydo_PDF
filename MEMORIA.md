# MEMÓRIA DO PROJETO — Lydo

> Leia isto **antes** de qualquer tarefa. Atualize as seções "Estado atual", "Próximos passos"
> e "Histórico" **ao terminar** cada tarefa. Regras de código ficam no `CLAUDE.md`.

_Última atualização: 2026-11-06 — fim da fase 2._

---

## 1. Estado atual

| Fase | O quê | Status |
|---|---|---|
| 1 | Biblioteca, leitor que retoma a posição, busca, miniaturas, ajustes | ✅ pronto e instalado no celular |
| 2 | Modo Anotar: realçar, caneta, texto, nota, borracha, desfazer | ✅ pronto, **aguardando teste do Franklin no celular** |
| 3 | Modo Editar: assinar, imagem, organizar páginas + exportar PDF anotado | ⏭️ próximo |
| 4+ | Juntar/dividir, OCR, resumo com IA, "Abrir com" de outros apps | 📋 ideias |

- **Testes:** 16 passando (`flutter test`). `flutter analyze` sem avisos.
- **Último commit:** ver `git log -1`.

## 2. Mapa do código (onde está cada coisa)

```
lib/
  main.dart                         monta repositórios/controllers, tema e escala da interface
  core/
    result.dart                     Result<T> (Ok/Err) + AppFailure
    formatters.dart                 formatBytes ("4,2 MB"), formatRelativeDay ("Hoje")
  domain/                           (Dart puro, sem Flutter)
    document_entry.dart             PDF da biblioteca + posição (página, matriz, favorito, tamanho)
    library_repository.dart         contrato da biblioteca
    app_settings.dart               ajustes (tema, escala, rolagem, retomar, tela ligada, grade)
    settings_repository.dart        contrato dos ajustes
    annotation.dart                 Annotation, APoint, ARect, highlightRects() (realce que gruda no texto)
    annotation_repository.dart      contrato das anotações
  data/
    prefs_library_repository.dart   biblioteca em SharedPreferences (chave library.v1)
    prefs_settings_repository.dart  ajustes em SharedPreferences (chave settings.v1)
    json_annotation_repository.dart anotações em <docs>/annotations/<id>.json
    pdf_import_service.dart         seletor de arquivo + cópia para <docs>/pdfs/<id>.pdf + impressão digital
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
    reader/annotation_layer.dart    pintura das anotações, overlays de texto/nota, gestos, barra de ferramentas
test/
  widget_test.dart                  DocumentEntry, impressão digital, repositório da biblioteca
  library_logic_test.dart           formatadores, filtros/busca, AppSettings
  annotation_test.dart              highlightRects, borracha, JSON, repositório de anotações
```

Telas de referência do design: `*.png` na raiz (nome antigo nas imagens: "Forma PDF").

## 3. Decisões tomadas (não rediscutir sem o Franklin)

- **Nome:** Lydo. ID Android `com.franklin.lydo`. Pacote Dart continua `pdf_reader`.
- **Plataforma:** só Android por enquanto.
- **Motor PDF:** `pdfrx` 2.12 (PDFium, licença BSD). UI com `material_ui` (exigência do pdfrx no Flutter 3.47).
- **Identidade do documento:** hash FNV-1a dos primeiros 64 KB + tamanho → o mesmo PDF reaberto mantém o progresso, mesmo renomeado.
- **PDF importado é copiado** para a pasta do app (o `content://` do Android expira).
- **Posição salva:** página + matriz de zoom/rolagem (só reaplicada no mesmo modo de rolagem).
- **Anotações:** ficam no JSON do Lydo, em coordenadas do PDF (origem no canto inferior esquerdo). **Ainda não são gravadas dentro do arquivo PDF**: isso é a fase 3 (exportar).
- **Gesto no modo Anotar:** com ferramenta ativa o dedo desenha; tocar de novo na ferramenta solta e a página volta a rolar/dar zoom.
- **Editar o texto original do PDF** (fonte/tamanho, como na tela de referência) é muito difícil: o plano é "cobrir e escrever por cima".
- **Fora por enquanto:** avatar "FC" (sem login), ajustes "Salvar rascunhos / Preservar original / Pasta de exportação" (voltam na fase 3).
- **Dependências:** pdfrx, shared_preferences, file_picker, path_provider, material_ui, wakelock_plus. Nova dependência → avisar o Franklin.

## 4. Próximos passos

1. Franklin testa a fase 2 no celular e diz se há ajustes.
2. Fase 3 — Editar (sugestão de divisão para subagentes):
   - **Páginas:** girar, reordenar, excluir (pdfrx tem manipulação de páginas) → principal/Sonnet.
   - **Assinar:** tela para desenhar a assinatura, salvar e posicionar na página → Haiku (tela) + principal (posição).
   - **Imagem:** escolher foto e posicionar na página → Haiku (UI) + principal (posição).
   - **Exportar PDF anotado/editado** para compartilhar → principal (verificar API de edição do pdfrx).
   - Voltar com os ajustes "Preservar PDF original" e "Pasta de exportação".

## 5. Problemas conhecidos / dívidas

- Com uma ferramenta de anotação ativa, não dá para dar zoom com dois dedos (é preciso soltar a ferramenta).
- Miniaturas ficam escondidas no modo Anotar (a barra de ferramentas ocupa o lugar).
- O app antigo "Leitor PDF" (`com.franklin.pdf_reader`) pode ainda estar no celular, e pode ser desinstalado.

## 6. Histórico

| Data | O que foi feito | Commit |
|---|---|---|
| 2026-11-06 | Projeto criado; v0.1 leitor com retomada de leitura | — |
| 2026-11-06 | Nome Lydo; fase 1 com o visual das referências; repositório no GitHub | `1a9b4cc` |
| 2026-11-06 | Fase 2: modo Anotar; CLAUDE.md com orquestração | `68403d6` |
| 2026-11-06 | CLAUDE.md focado em economia de tokens; criada esta MEMORIA.md | (este commit) |
