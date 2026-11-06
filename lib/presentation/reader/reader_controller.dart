import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

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
        pageCount = ValueNotifier(entry.pageCount) {
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

  /// Busca aberta na barra superior.
  final searchOpen = ValueNotifier(false);

  /// "3 de 12", "Buscando…", "Nada encontrado" — já pronto para exibir.
  final searchStatus = ValueNotifier('');

  Timer? _saveTimer;
  bool _restored = false;

  DocumentEntry get entry => _entry;
  bool get horizontal => settings.scrollMode == ScrollMode.horizontal;

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
    final sameLayout = _entry.lastLayoutHorizontal == horizontal;
    if (settings.resumeLastPage && sameLayout && matrix != null && matrix.length == 16) {
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
    return viewer.goToPage(pageNumber: target);
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
    if (!_restored) return; // não sobrescrever a posição salva antes de restaurá-la
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDelay, saveNow);
  }

  /// Grava a posição imediatamente (ex.: ao sair da tela ou minimizar o app).
  Future<void> saveNow() async {
    _saveTimer?.cancel();
    if (!_restored) return;
    _entry = _entry.copyWith(
      lastOpenedAt: DateTime.now(),
      lastPage: currentPage.value,
      pageCount: pageCount.value,
      viewMatrix: viewer.isReady ? viewer.value.storage.toList() : null,
      lastLayoutHorizontal: horizontal,
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
      searchOpen,
      searchStatus,
    ]) {
      n.dispose();
    }
  }
}
