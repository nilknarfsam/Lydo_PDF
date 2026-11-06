# Visão geral do Lydo

## O que é

O **Lydo** é um leitor e editor de PDF para **Android**. Ele abre PDFs do celular, guarda onde você parou e permite marcar, assinar, reorganizar e exportar o documento.

## Objetivo

Ser um **leitor leve, no estilo do Adobe Reader**, que **continua de onde você parou**:

- abre rápido, sem login e sem conta;
- lembra a página, o zoom e a posição de rolagem de cada documento;
- deixa anotar e editar o PDF sem transformar o app em um pacote pesado de escritório.

## Para quem

- **Hoje:** uso pessoal do Franklin, dono do projeto.
- **Em geral:** qualquer pessoa que lê, marca ou assina PDFs no Android e quer algo simples, sem anúncios nem envio de dados (o próprio app diz: "Tudo fica só no seu celular").

## Plataforma

- **Android** é a única plataforma por enquanto.
- ID do aplicativo: `com.franklin.lydo`.
- Nome do app: **Lydo**. O pacote Dart do projeto continua se chamando `pdf_reader` (detalhe em [Desenvolvimento](desenvolvimento.md#armadilhas-conhecidas)).

## Stack

| Parte | Tecnologia | Uso |
|---|---|---|
| Framework | Flutter 3.47 (Dart `^3.13.1`) | Interface e lógica do app |
| Leitura e edição de PDF | `pdfrx` 2.12 sobre o **PDFium** (licença BSD) | Renderização, busca no texto, realce nativo e montagem do PDF exportado |
| Interface | `material_ui` 1.10 | Widgets usados em todas as telas (o `pdfrx` exige este pacote no Flutter 3.47) |
| Arquivos | `file_picker`, `path_provider` | Seletor do Android e pastas do app |
| Preferências | `shared_preferences` | Biblioteca, ajustes e posição de leitura |
| Exportação (FFI) | `pdfium_dart`, `ffi` | Gravar anotações dentro do PDF |
| Tela | `wakelock_plus` | Opção "Manter tela ligada" |

Não há banco de dados, serviço de nuvem nem dependência de rede.

## Funcionalidades atuais

### Biblioteca

- Importar um PDF pelo seletor do Android. O arquivo é copiado para dentro do app.
- Lista ou grade.
- Busca por nome (ignora maiúsculas e acentos).
- Filtros: **Todos**, **Recentes** e **Favoritos**.
- Cartão **Continuar lendo** com o último documento começado e não terminado.
- Menu ⋮ de cada documento: abrir, favoritar, renomear e remover.
- Alternar tema claro/escuro a partir da própria biblioteca.

### Leitor

- Rolagem **contínua** ou **horizontal** (páginas lado a lado).
- Zoom e rolagem.
- Retomada exata: página, zoom e posição.
- Busca no texto, com contagem ("3 de 12") e navegação entre resultados.
- Miniaturas na parte de baixo, no modo Ler.
- **Página noturna** (inverte as cores da página) pelo menu ⋮ do leitor.
- **Ir para a página** pelo menu.
- Toque na página mostra ou esconde as barras.

### Anotar

- **Realçar**: o marca-texto acompanha as letras, linha por linha.
- **Caneta**: traço livre, 4 cores e 3 espessuras.
- **Texto**: caixa de texto em qualquer ponto da página.
- **Nota**: anotação com texto de várias linhas.
- **Borracha**: toque na anotação para apagá-la.
- **Desfazer** e **refazer**.
- **Mover a página**: solta a ferramenta para rolar e dar zoom.
- **Limpar anotações da página**, com confirmação (dá para desfazer).

### Editar

- **Imagem**: coloca uma foto na página. Pode mover, aumentar, diminuir e excluir.
- **Assinar**: desenha a assinatura com o dedo, salva para reutilizar e a coloca na página.
- **Páginas**: gira, reordena e exclui páginas.
- **Exportar**: gera um PDF novo com as anotações e as imagens, e você escolhe onde salvar.

### Ajustes

- **Tema**: sistema, claro ou escuro.
- **Tamanho da interface**: compacto, padrão ou grande.
- **Modo de rolagem**: contínua ou horizontal.
- **Retomar última página**.
- **Manter tela ligada**.
- **Armazenamento**: mostra quanto espaço os PDFs da biblioteca ocupam.
- **Seus dados**: explica que nada sai do celular.

### Ferramentas

A aba **Ferramentas** é uma vitrine: OCR, juntar e dividir PDFs, imagens para PDF e resumo com IA aparecem como "em breve". Nenhuma delas está implementada ainda.

## O que diferencia o Lydo

- **Continua de onde você parou.** A posição guarda página, zoom e rolagem, e não só a página. Ela é reconhecida mesmo se o arquivo for renomeado (a identidade vem do conteúdo, não do nome).
- **Leve e offline.** Sem login, sem conta, sem nuvem e sem rede.
- **Anotações não alteram o PDF original.** Ficam salvas no próprio app e só entram no arquivo quando você exporta.
- **Texto continua pesquisável.** Ao exportar, o realce vira uma anotação nativa do PDF e as demais marcas vão numa camada transparente por cima do texto original.
- **Realce que gruda no texto.** O marca-texto segue as letras, em vez de ser um retângulo solto.

## Status

Fases 1, 2 e 3 estão prontas. A fase 3 (exportação) ainda aguarda teste em aparelho real. Veja o roteiro completo em [Fases](fases.md).
