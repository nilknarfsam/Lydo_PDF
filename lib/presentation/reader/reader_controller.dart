import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../data/stamp_import_service.dart';
import '../../domain/annotation.dart';
import '../../domain/app_settings.dart';
import '../../domain/document_entry.dart';
import '../../domain/library_repository.dart';

enum ReaderMode { read, annotate, edit }

/// Estado e regras do leitor: página atual, busca, modo noturno e o
/// salvamento automático da posição de leitura.
class ReaderController {
  ReaderController({
    required DocumentEntry entry,
    required this.repository,
    required this.settings,
  })  : _entry = entry,
        currentPage = ValueNotifier(entry.lastPage),
        pageCount = ValueNotifier(entry.pageCount),
        scrollMode = ValueNotifier(settings.scrollMode) {
    searcher = PdfTextSearcher(viewer)..addListener(_onSearchChanged);
    if (settings.keepScreenOn) WakelockPlus.enable();
  }

  static const _saveDelay = Duration(milliseconds: 800);

  final LibraryRepository repository;
  final AppSettings settings;
  DocumentEntry _entry;

  final viewer = PdfViewerController();
  late final PdfTextSearcher searcher;

  final ValueNotifier<int> currentPage;
  final ValueNotifier<int> pageCount;
  final document = ValueNotifier<PdfDocument?>(null);
  final nightMode = ValueNotifier(false);
  final chromeVisible = ValueNotifier(true);
  final mode = ValueNotifier(ReaderMode.read);

  /// Faixa de miniaturas aberta por cima da barra de ferramentas (Anotar/Editar).
  final toolThumbs = ValueNotifier(false);
  void toggleToolThumbs() => toolThumbs.value = !toolThumbs.value;

  /// Modo de rolagem em uso (começa no dos Ajustes; dá para trocar no leitor).
  final ValueNotifier<ScrollMode> scrollMode;

  // ---------- Modo Editar ----------
  /// Imagem/assinatura escolhida, esperando o toque na página.
  final pendingStamp = ValueNotifier<StampAsset?>(null);

  /// Imagem que será levada para o próximo ponto tocado.
  final movingImage = ValueNotifier<Annotation?>(null);

  /// Operação demorada em andamento (exportar, reorganizar).
  final editBusy = ValueNotifier(false);

  String? get editHint => pendingStamp.value != null
      ? 'Toque na página onde quer colocar'
      : movingImage.value != null
          ? 'Toque no novo lugar da imagem'
          : null;

  /// Busca aberta na barra superior.
  final searchOpen = ValueNotifier(false);

  /// "3 de 12", "Buscando…", "Nada encontrado" — já pronto para exibir.
  final searchStatus = ValueNotifier('');

  Timer? _saveTimer;
  bool _restored = false;

  /// O documento foi trocado por outro arquivo (ex.: páginas reorganizadas):
  /// este leitor não grava mais nada, para não sobrescrever a entrada nova.
  bool _replaced = false;
  void markReplaced() {
    _replaced = true;
    _saveTimer?.cancel();
  }

  DocumentEntry get entry => _entry;
  bool get horizontal => scrollMode.value == ScrollMode.horizontal;

  /// Uma página por vez: deslizar troca de página e ela sempre encaixa inteira na tela.
  bool get paged => scrollMode.value == ScrollMode.paged;

  /// Página em que o gesto atual começou (para saber se deslizou para a próxima).
  int _gestureStartPage = 1;

  /// Centro da área visível (coordenadas do documento) quando o gesto começou.
  Offset? _gestureStartCenter;

  /// Página inicial que o PdfViewer deve abrir.
  int initialPage(int documentPages) =>
      settings.resumeLastPage ? _entry.lastPage.clamp(1, documentPages) : 1;

  /// Chamado quando o PDF terminou de carregar: devolve o leitor ao ponto
  /// exato (zoom + rolagem) onde a pessoa parou.
  Future<void> onViewerReady(PdfDocument doc) async {
    if (_restored) return; // só restaura uma vez por abertura
    document.value = doc;
    pageCount.value = doc.pages.length;
    final matrix = _entry.viewMatrix;
    // A matriz só vale para o mesmo modo de rolagem em que foi salva.
    final sameLayout = _entry.lastLayout == scrollMode.value.name;
    if (paged) {
      // Página por página: sempre abre com a página salva inteira na tela.
      await fitPage(initialPage(doc.pages.length), duration: Duration.zero);
    } else if (settings.resumeLastPage && sameLayout && matrix != null && matrix.length == 16) {
      await viewer.goTo(Matrix4.fromList(matrix), duration: Duration.zero);
    }
    _restored = true;
    viewer.addListener(_scheduleSave);
    _scheduleSave();
  }

  void onPageChanged(int? page) {
    if (page == null) return;
    currentPage.value = page;
    _scheduleSave();
  }

  Future<void> goToPage(int page) {
    final target = page.clamp(1, math.max(1, pageCount.value)).toInt();
    if (paged) return fitPage(target);
    return viewer.goToPage(pageNumber: target);
  }

  /// Mostra a página [page] inteira, centralizada.
  Future<void> fitPage(int page, {Duration duration = const Duration(milliseconds: 220)}) async {
    if (!viewer.isReady) return;
    final matrix = viewer.calcMatrixForFit(pageNumber: page);
    if (matrix == null) return;
    await viewer.goTo(matrix, duration: duration);
    currentPage.value = page;
  }

  /// Troca o modo de rolagem sem fechar o PDF: o leitor refaz o layout e
  /// depois volta para a página em que a pessoa estava.
  void changeScrollMode(ScrollMode m) {
    if (m == scrollMode.value) return;
    final page = currentPage.value;
    scrollMode.value = m;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!viewer.isReady) return;
      if (paged) {
        fitPage(page, duration: Duration.zero);
      } else {
        viewer.goToPage(pageNumber: page, duration: Duration.zero);
      }
    });
  }

  /// A tela mudou de tamanho (ex.: celular girado): no modo página por
  /// página, reencaixa a página atual inteira.
  void onViewSizeChanged(Size size, Size? oldSize) {
    if (!paged || oldSize == null || size == oldSize) return;
    final page = currentPage.value;
    WidgetsBinding.instance.addPostFrameCallback((_) => fitPage(page, duration: Duration.zero));
  }

  // ---------- Página por página ----------

  void onGestureStart() {
    _gestureStartPage = currentPage.value;
    _gestureStartCenter = viewer.isReady ? viewer.visibleRect.center : null;
  }

  /// Fim do gesto no modo página por página: com zoom normal, encaixa na
  /// página seguinte/anterior (conforme o deslize) ou volta para a mesma.
  /// Com zoom aumentado, deixa a pessoa andar pela página à vontade.
  void onGestureEnd(Velocity velocity) {
    if (!paged || !viewer.isReady) return;
    final fit = viewer.calcMatrixForFit(pageNumber: _gestureStartPage);
    if (fit != null && viewer.value.zoom > fit.zoom * 1.05) return;
    final vx = velocity.pixelsPerSecond.dx;
    // Quanto a página andou, em fração da largura visível (+ = foi para a direita no documento).
    final visible = viewer.visibleRect;
    final start = _gestureStartCenter;
    final moved = start == null ? 0.0 : (visible.center.dx - start.dx) / visible.width;
    final int target;
    if (vx < -_swipeVelocity || moved > _swipeFraction) {
      target = _gestureStartPage + 1;
    } else if (vx > _swipeVelocity || moved < -_swipeFraction) {
      target = _gestureStartPage - 1;
    } else {
      target = _pageNearestToCenter() ?? _gestureStartPage;
    }
    final page = target.clamp(1, math.max(1, pageCount.value)).toInt();
    // O pdfrx avisa o fim do gesto ANTES de começar a inércia; encaixar só
    // depois, senão a inércia atropela a animação e a página fica pela metade.
    Future<void>.delayed(Duration.zero, () => fitPage(page));
  }

  static const _swipeVelocity = 250.0;
  static const _swipeFraction = 0.15;

  int? _pageNearestToCenter() {
    final center = viewer.visibleRect.center;
    final rects = viewer.layout.pageLayouts;
    int? best;
    var bestDistance = double.infinity;
    for (var i = 0; i < rects.length; i++) {
      final d = (rects[i].center - center).distance;
      if (d < bestDistance) {
        bestDistance = d;
        best = i + 1;
      }
    }
    return best;
  }

  /// Páginas lado a lado com um vão grande entre elas, para que a página
  /// vizinha nunca apareça na tela quando uma página está inteira à mostra.
  static PdfPageLayout pagedLayout(List<PdfPage> pages, PdfViewerParams params) {
    final tallest = pages.fold(0.0, (h, p) => math.max(h, p.height));
    final widest = pages.fold(0.0, (w, p) => math.max(w, p.width));
    final gap = math.max(tallest, widest);
    final height = tallest + params.margin * 2;
    final rects = <Rect>[];
    var x = params.margin;
    for (final page in pages) {
      final slot = widest + gap;
      rects.add(Rect.fromLTWH(x + (slot - page.width) / 2, (height - page.height) / 2, page.width, page.height));
      x += slot;
    }
    return PdfPageLayout(pageLayouts: rects, documentSize: Size(x + params.margin, height));
  }

  void toggleNightMode() => nightMode.value = !nightMode.value;
  void toggleChrome() => chromeVisible.value = !chromeVisible.value;
  void setMode(ReaderMode m) => mode.value = m;

  // ---------- Busca ----------

  void openSearch() {
    searchOpen.value = true;
    chromeVisible.value = true;
  }

  void closeSearch() {
    searchOpen.value = false;
    searcher.resetTextSearch();
    searchStatus.value = '';
  }

  void search(String text) {
    final q = text.trim();
    if (q.isEmpty) {
      searcher.resetTextSearch();
      searchStatus.value = '';
      return;
    }
    searcher.startTextSearch(q, caseInsensitive: true, goToFirstMatch: true);
  }

  Future<void> nextMatch() => searcher.goToNextMatch();
  Future<void> previousMatch() => searcher.goToPrevMatch();

  void _onSearchChanged() {
    if (!searchOpen.value) return;
    final total = searcher.matches.length;
    final index = searcher.currentIndex;
    searchStatus.value = searcher.isSearching && total == 0
        ? 'Buscando…'
        : total == 0
            ? 'Nada encontrado'
            : '${(index ?? 0) + 1} de $total${searcher.isSearching ? '…' : ''}';
  }

  /// Páginas lado a lado (rolagem horizontal), centralizadas na vertical.
  static PdfPageLayout horizontalLayout(List<PdfPage> pages, PdfViewerParams params) {
    final height = pages.fold(0.0, (h, p) => math.max(h, p.height)) + params.margin * 2;
    final rects = <Rect>[];
    var x = params.margin;
    for (final page in pages) {
      rects.add(Rect.fromLTWH(x, (height - page.height) / 2, page.width, page.height));
      x += page.width + params.margin;
    }
    return PdfPageLayout(pageLayouts: rects, documentSize: Size(x, height));
  }

  // ---------- Salvamento ----------

  void _scheduleSave() {
    if (!_restored || _replaced) return; // não sobrescrever a posição salva antes de restaurá-la
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDelay, saveNow);
  }

  /// Grava a posição imediatamente (ex.: ao sair da tela ou minimizar o app).
  Future<void> saveNow() async {
    _saveTimer?.cancel();
    if (!_restored || _replaced) return;
    _entry = _entry.copyWith(
      lastOpenedAt: DateTime.now(),
      lastPage: currentPage.value,
      pageCount: pageCount.value,
      viewMatrix: viewer.isReady ? viewer.value.storage.toList() : null,
      lastLayout: scrollMode.value.name,
    );
    await repository.save(_entry);
  }

  Future<void> dispose() async {
    viewer.removeListener(_scheduleSave);
    searcher.removeListener(_onSearchChanged);
    searcher.dispose();
    if (settings.keepScreenOn) WakelockPlus.disable();
    await saveNow();
    for (final n in <ChangeNotifier>[
      currentPage,
      pageCount,
      document,
      nightMode,
      chromeVisible,
      mode,
      scrollMode,
      searchOpen,
      searchStatus,
      pendingStamp,
      movingImage,
      editBusy,
      toolThumbs,
    ]) {
      n.dispose();
    }
  }
}
