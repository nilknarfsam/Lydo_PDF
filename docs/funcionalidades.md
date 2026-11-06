# Funcionalidades: como cada recurso funciona

Explicação técnica de cada recurso, para quem vai mexer no código. Os nomes de classes e arquivos são os do repositório. Para o mapa completo dos arquivos, veja [Arquitetura](arquitetura.md).

## Retomar leitura

Dois dados são guardados para cada documento, no `DocumentEntry` (`lib/domain/document_entry.dart`):

- **Identidade:** impressão digital do conteúdo, e não o nome do arquivo.
- **Posição:** página atual e matriz de zoom/rolagem.

### Identidade do documento

`PdfImportService.fingerprint` (`lib/data/pdf_import_service.dart`):

1. Lê os **primeiros 64 KB** do arquivo.
2. Calcula **FNV-1a de 64 bits** sobre esses bytes.
3. Monta o `id` como `<hash em hexa de 16 dígitos>_<tamanho do arquivo em hexa>`.

Efeitos:

- O mesmo PDF importado de novo cai na **mesma entrada** e mantém o progresso. O arquivo temporário é apagado.
- Se o arquivo for renomeado no celular, a identidade continua a mesma.
- A cópia fica em `<docs>/pdfs/<id>.pdf`. Isso é necessário porque o `content://` do Android pode expirar.
- PDFs diferentes que compartilham os 64 KB iniciais se distinguem pelo tamanho.

### Posição

- `ReaderController` (`lib/presentation/reader/reader_controller.dart`) salva a posição **800 ms depois da última mudança** (`_scheduleSave`), e de forma imediata ao sair (`saveNow`).
- O que é salvo: página atual, número de páginas, `viewMatrix` (16 valores de `viewer.value.storage`) e `lastLayoutHorizontal` (o modo em que a matriz foi gerada).
- Na abertura, `onViewerReady` restaura a matriz **só se** o modo de rolagem for o mesmo em que ela foi salva, a matriz tiver 16 valores e a opção "Retomar última página" estiver ligada. Ou seja, a matriz de um modo não vale no outro.
- Se a restauração não for possível, o leitor abre na página salva (`initialPage`, limitada ao número de páginas).
- Salvamento só começa **depois** da restauração, para não gravar uma posição zerada por cima da boa.

### Continuar lendo

`HomeState` escolhe o "Continuar lendo": o último documento aberto que já foi começado e ainda não terminou. Documentos que nunca foram abertos são pulados. Está coberto por teste.

## Busca no texto

- A barra de busca abre pelo ícone de lupa, na barra superior do leitor.
- `ReaderController` usa o `PdfTextSearcher` do `pdfrx`, com `caseInsensitive: true` e `goToFirstMatch: true`.
- `nextMatch` e `previousMatch` navegam entre os resultados.
- O texto de status é montado no controller: "3 de 12", "Buscando…" ou "Nada encontrado".
- Fechar a busca limpa os resultados (`resetTextSearch`).

## Modo noturno

- Ativado em **Mais opções → Página noturna** no leitor.
- Aplica um `ColorFilter.matrix` na imagem da página (`_nightFilter` em `reader_page.dart`). Os multiplicadores -1 com deslocamento 255 **invertem as cores** da página.
- A barra do leitor é sempre escura, por decisão de design.
- O estado **não é salvo**: o modo noturno começa desligado em cada abertura.

## Rolagem horizontal

- Ajuste **Modo de rolagem** (Ajustes) ou `ScrollMode.horizontal`.
- `ReaderController.horizontalLayout` monta um `PdfPageLayout` com as páginas lado a lado, separadas pela margem e centralizadas na vertical.
- Ao trocar de modo, a matriz salva deixa de valer (ver "Posição").

## Realce que gruda no texto

Função pura `highlightRects` em `lib/domain/annotation.dart`:

1. Recebe as **caixas de cada letra** da página (`charRects`), o ponto inicial e o ponto final do gesto.
2. Para cada ponto, acha a letra **mais próxima**. Se a distância for maior que **24 pt**, o gesto não está sobre texto.
3. Entre as duas letras (na ordem do texto), junta as caixas que estão na **mesma linha**: caixas cujos centros verticais diferem menos de 60% da menor altura.
4. Devolve **um retângulo por linha**.

Casos especiais:

- **Página sem texto** (escaneada) ou gesto fora do texto: cai no `fallbackHeight` e desenha uma **faixa reta** de altura fixa.
- Caixas de espaços e quebras de linha (altura zero) são ignoradas.

As caixas de letras vêm de `loadStructuredText` do `pdfrx` e são guardadas em cache por página (`_textCache` em `annotation_controller.dart`).

Testado em `test/annotation_test.dart`: arrastar numa linha, entre linhas e em página sem texto.

## Caneta, texto, nota, borracha e desfazer

Controller: `AnnotationController` (`lib/presentation/reader/annotation_controller.dart`).

- **Ferramentas:** Realçar, Caneta, Texto, Nota e Borracha. Tocar de novo na ferramenta ativa a solta, e a página volta a rolar e dar zoom.
- **Cores:** 4 por ferramenta. Realçar e Nota usam a paleta de realce; Caneta, Texto e Borracha usam a de tinta.
- **Caneta:** `beginStroke`, `extendStroke` e `endStroke`. Os pontos são guardados em coordenadas do PDF. Antes de salvar, `_simplify` retira pontos quase alinhados (quando a distância do ponto à reta entre os vizinhos fica abaixo de 0,25 pt), para o arquivo ficar leve.
- **Espessura:** `StrokeSize` com 3 valores (fina, média e grossa).
- **Texto:** diálogo "Texto na página". Tocar de novo numa caixa de texto a edita (`updateText`).
- **Nota:** igual ao texto, com campo de várias linhas.
- **Borracha:** `eraseAt` apaga a anotação mais recente sob o toque. A tolerância depende do tipo: realces usam metade da tolerância, traços somam metade da espessura, e textos e notas aceitam até 24 pt do ponto de ancoragem.
- **Desfazer e refazer:** duas pilhas de listas de anotações (`_undo` e `_redo`). Cada alteração grava a lista inteira no repositório.
- **Limpar página:** pede confirmação e pode ser desfeito.

Gravação: `JsonAnnotationRepository` (`lib/data/json_annotation_repository.dart`) escreve `<docs>/annotations/<id>.json` por `.tmp` e `rename`.

## Assinatura

Telas e controllers em `lib/presentation/edit/`:

1. **Desenhar:** `SignaturePadPage` com fundo branco na tela. `SignaturePadController` guarda os traços.
2. **Gerar o PNG:** recorta a área ao redor dos traços (com margem) e exporta com **3x** de resolução (`_pixelRatio = 3.0`) e **fundo transparente**.
3. **Salvar:** `FileSignatureRepository` grava `<docs>/signatures/<microssegundos>.png`. A lista sai da mais recente para a mais antiga.
4. **Usar:** `SignaturePickerSheet` lista as assinaturas salvas ou abre o desenho de uma nova.
5. **Colocar:** `StampImportService.fromSignature` **copia** o PNG para `<docs>/stamps/`. Assim, apagar a assinatura da lista não quebra as assinaturas já colocadas nos PDFs.
6. **Tamanho na página:** assinatura ocupa **32%** da largura da página; imagem comum, **50%** (`reader_page.dart`).

## Imagens

- **Escolher:** `StampImportService.pickImage` abre a galeria pelo `file_picker` e copia o arquivo para `<docs>/stamps/<microssegundos>.<ext>`. A proporção (altura / largura) é medida na própria imagem.
- **Colocar:** toque na página, com a imagem pendente (`pendingStamp`). `placeImage` cria a anotação com a largura de 50% da página.
- **Giro (`turns`):** a anotação guarda o giro da página no momento em que foi colocada (`turns = pageTurns % 4`). Se a página for girada depois, o renderizador gira a imagem pela **diferença** (`(page.rotation - turns) % 4`), para ela acompanhar o conteúdo.
- **Proporção ao girar:** se a página estava em giro ímpar no momento da colocação, a caixa da imagem usa a proporção invertida, para a imagem ficar em pé.
- **Editar:** só pelo menu, ao tocar na imagem no modo Editar: **Mover** (depois toque no novo lugar), **Aumentar**, **Diminuir** e **Excluir**. Aumentar e diminuir multiplicam a largura, limitada entre 24 e 2000 pt. Ainda não há arrastar com o dedo.

## Organizar páginas

Tela `PageOrganizerPage` com `PageOrganizerController` (`lib/presentation/edit/`). O resultado é um `PagePlan` (`lib/domain/page_plan.dart`): uma lista de `PageSlot`, cada um com a página original (`sourcePage`, 1-based) e os giros de 90° (`quarterTurns`, 0 a 3).

Ações na tela:

- **Selecionar** páginas (toque).
- **Girar** as selecionadas: cada toque soma um giro de 90° no sentido horário.
- **Excluir** as selecionadas. Excluir todas é recusado, porque o PDF precisa de pelo menos uma página.
- **Reordenar** por arrastar, com a semântica do `ReorderableListView`.
- **Desfazer** giros e reordenações.
- **Concluir** devolve o `PagePlan`. Se o plano for igual ao original (`isIdentity`), nada acontece.

Aplicação, em `ReaderPage._organizePages`, nesta ordem:

1. `saveNow()` grava a posição atual.
2. `PdfEditService.applyPagePlan` monta um **arquivo novo** `<id>_<timestamp>.pdf` na mesma pasta, reordenando e girando as páginas com o PDFium. O arquivo é escrito como `.tmp` e depois renomeado. Não sobrescreve o arquivo que o leitor ainda tem aberto.
3. `markReplaced()` impede o leitor antigo de gravar qualquer coisa depois disso.
4. `remapAnnotations` renumera as anotações pela nova ordem e descarta as das páginas excluídas. As coordenadas não mudam, porque são as do PDF original e o giro é aplicado pelo próprio PDF.
5. A entrada da biblioteca é atualizada com o novo `path`, o número de páginas e a `lastPage` (página atual na nova numeração). A `viewMatrix` é zerada, pois a posição antiga não vale mais.
6. Ordem de gravação: **anotações → entrada → só então apaga o PDF antigo**. Se algo falhar antes, o arquivo antigo continua existindo.
7. O leitor é reaberto com a entrada nova (`pushReplacement`).

Testado em `test/page_plan_test.dart` (plano, controller e histórico) e na própria `remapAnnotations` em `test/annotation_test.dart`.

## Exportar PDF com anotações

Função `PdfEditService.exportWithAnnotations` (`lib/data/pdf_edit_service.dart`). Entrada: caminho do PDF e a lista de anotações. Saída: os bytes do PDF novo.

Passos:

1. Agrupa as anotações por página. Anotações de páginas inexistentes são ignoradas.
2. **Uma página por vez** para não estourar a memória em PDFs grandes.
3. **Realces** viram **anotações de realce nativas** do PDF (`FPDF_ANNOT_HIGHLIGHT`), com cor, um quad por retângulo e os limites da anotação. Leitores como o Adobe reconhecem e o texto não escurece.
4. **Demais anotações** (caneta, texto, nota e imagens) são desenhadas por `paintAnnotations`, a mesma função da tela, numa imagem RGBA:
   - escala de **2 pixels por ponto** (cerca de 144 dpi), reduzida se a página passar de **4 megapixels**;
   - a imagem é convertida de RGBA para **BGRA** (formato do PDFium);
   - a posição vem de converter os três cantos da imagem com `toPdfPoint`, então funciona em páginas giradas.
5. A imagem entra como **um único objeto de imagem transparente** por página, inserido por cima do conteúdo (`FPDFPage_InsertObject` e `FPDFPage_GenerateContent`). O texto original continua selecionável e pesquisável.
6. `doc.encodePdf()` gera os bytes.
7. A tela pede onde salvar com `FilePicker.saveFile`, com o nome `<nome> (Lydo).pdf`.

Limitações conhecidas:

- Notas viram uma caixinha desenhada, e não a nota "pop-up" do PDF.
- A exportação **ainda não foi testada em aparelho** e não tem teste automatizado.
- O arquivo original **não é alterado**: a exportação gera um PDF novo.

## Ver também

- [Arquitetura](arquitetura.md): onde fica cada arquivo citado aqui.
- [Desenvolvimento](desenvolvimento.md): como rodar os testes.
