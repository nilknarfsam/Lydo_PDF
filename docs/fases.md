# Roteiro de fases

Legenda: ✅ pronto · 📋 planejado.

| Fase | Conteúdo | Commit(s) | Status |
|---|---|---|---|
| 1 | Biblioteca, leitor, busca, miniaturas e ajustes | `1a9b4cc` | ✅ pronto e instalado no celular |
| 2 | Modo Anotar | `68403d6` | ✅ pronto, aguardando teste no celular |
| 3 | Modo Editar e exportar PDF anotado | `5cd4604` | ✅ pronto e instalado, aguardando teste (a exportação ainda não rodou em aparelho) |
| 4+ | Juntar/dividir, OCR, resumo com IA, "Abrir com" | — | 📋 ideias |

## Fase 1: biblioteca, leitor e ajustes ✅

Commit `1a9b4cc`: "Lydo: leitor de PDF para Android (fase 1)".

**Biblioteca**
- Importar PDF pelo seletor do Android, com cópia para dentro do app.
- Lista e grade, com alternância.
- Busca por nome, sem diferenciar maiúsculas e acentos.
- Filtros Todos, Recentes e Favoritos.
- Cartão "Continuar lendo".
- Abrir, favoritar, renomear e remover pelo menu ⋮.

**Leitor**
- Rolagem contínua e horizontal.
- Retomada da posição (página, zoom e rolagem).
- Busca no texto com contagem e navegação.
- Miniaturas.
- Modo noturno.
- Ir para a página.
- Manter tela ligada.

**Ajustes**
- Tema (sistema, claro, escuro).
- Tamanho da interface (compacto, padrão, grande).
- Modo de rolagem.
- Retomar última página.
- Manter tela ligada.
- Armazenamento e "Seus dados".

## Fase 2: Anotar ✅

Commit `68403d6`: "Fase 2: modo Anotar e CLAUDE.md". Os commits `dd4edf7` (CLAUDE.md com foco em economia de tokens) e `cb5cd86` (criação da MEMORIA.md) vieram em seguida.

- Realçar que acompanha o texto, com 4 cores.
- Caneta, com 4 cores e 3 espessuras.
- Texto em caixa, editável ao tocar de novo.
- Nota com várias linhas.
- Borracha.
- Desfazer e refazer.
- Mover a página: solta a ferramenta para rolar e dar zoom.
- Limpar as anotações de uma página, com confirmação.
- Anotações salvas em JSON, uma por documento.

## Fase 3: Editar e exportar ✅

Commit `5cd4604`: "Fase 3: modo Editar (assinatura, imagem, organizar páginas, exportar PDF)". Foi feita com subagentes Haiku e revisada por um Sonnet; detalhes em [Orquestração com IA](orquestracao-ia.md#exemplo-real-fase-3).

- **Assinar**: tela de desenho com o dedo, PNG 3x com fundo transparente, salvo em `signatures/` para reutilizar. Ao usar, é copiado para `stamps/`, para que apagar a assinatura da lista não quebre os PDFs já assinados.
- **Imagem**: foto da galeria, copiada para `stamps/`, colocada na página com giro compatível. Mover, aumentar, diminuir e excluir pelo menu.
- **Organizar páginas**: girar, excluir e reordenar com arrastar. Gera um arquivo novo, renumera as anotações e só depois apaga o antigo.
- **Barra do modo Editar**: Imagem, Assinar, Páginas e Exportar.
- **Exportar**: gera um PDF novo com as anotações e salva onde a pessoa escolher. Realces viram anotações nativas do PDF; caneta, texto, notas e imagens viram uma imagem transparente por página.
- Ao fim da fase: 38 testes passando (`flutter test`) e `flutter analyze` sem avisos.

## Fase 4 e seguintes (planejado) 📋

Ordem sugerida pela MEMORIA. Nada disso está implementado.

1. **Abrir com e compartilhar de outros apps.** Receber PDFs enviados por outros aplicativos Android, pelo "Abrir com" e pelo compartilhar.
2. **Juntar e dividir PDFs.** Hoje são só placeholders na aba Ferramentas.
3. **OCR.** Transformar PDF escaneado em texto pesquisável.
4. **Resumo com IA.** Perguntar e resumir o documento.
5. **Publicar na Play Store.** Ainda sem data definida.
6. Imagens para PDF (outro item da aba Ferramentas).

## Pendências conhecidas

Copiadas da MEMORIA (seções 4 e 5).

**Próximos passos imediatos**

- Franklin testar as fases 2 e 3 no celular, principalmente **Exportar** e **Páginas**.
- Pendências pequenas da revisão da fase 3:
  - pedir confirmação ao sair do Organizar páginas com mudanças não salvas;
  - limpar arquivos de `stamps/` que nenhuma anotação usa mais.

**Dívidas técnicas e limitações**

- Com uma ferramenta de anotação ativa, não dá para dar zoom com dois dedos (é preciso soltar a ferramenta).
- As miniaturas ficam escondidas nos modos Anotar e Editar, porque a barra de ferramentas ocupa o lugar delas.
- Imagem e assinatura só são movidas, aumentadas ou diminuídas pelo menu (toque na imagem no modo Editar). Ainda não há arrastar com o dedo.
- Notas no PDF exportado viram uma caixinha desenhada, e não a nota "pop-up" do PDF.
- O app antigo "Leitor PDF" (`com.franklin.pdf_reader`) pode ainda estar instalado no celular e pode ser desinstalado.
