import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../domain/document_entry.dart';
import '../../domain/library_repository.dart';
import '../settings/settings_controller.dart';
import '../theme/lydo_theme.dart';
import 'reader_controller.dart';

/// Inverte as cores da página (fundo preto, letra clara) para ler à noite.
const _nightFilter = ColorFilter.matrix(<double>[
  -1, 0, 0, 0, 255, //
  0, -1, 0, 0, 255, //
  0, 0, -1, 0, 255, //
  0, 0, 0, 1, 0, //
]);

// O leitor é sempre escuro, como na referência: o foco fica na página.
const _bar = Color(0xFF1A2130);
const _barBorder = Color(0xFF2C3546);
const _onBar = Colors.white;
const _onBarMuted = Color(0xFFA3ACBD);

class ReaderPage extends StatefulWidget {
  const ReaderPage({
    super.key,
    required this.entry,
    required this.repository,
    required this.settings,
  });

  final DocumentEntry entry;
  final LibraryRepository repository;
  final SettingsController settings;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> with WidgetsBindingObserver {
  late final ReaderController _c;

  @override
  void initState() {
    super.initState();
    _c = ReaderController(
      entry: widget.entry,
      repository: widget.repository,
      settings: widget.settings.settings.value,
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Se o Android matar o app em segundo plano, a posição já está salva.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _c.saveNow();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _c.dispose();
    super.dispose();
  }

  Future<void> _askPage() async {
    final page = await showDialog<int>(
      context: context,
      builder: (_) => _GoToPageDialog(current: _c.currentPage.value, total: _c.pageCount.value),
    );
    if (page != null) await _c.goToPage(page);
  }

  void _comingSoon(String what) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$what chega na próxima versão do Lydo.')));
  }

  void _onModeSelected(ReaderMode m) {
    switch (m) {
      case ReaderMode.read:
        _c.setMode(m);
      case ReaderMode.annotate:
        _comingSoon('O modo Anotar');
      case ReaderMode.edit:
        _comingSoon('O modo Editar');
    }
  }

  @override
  Widget build(BuildContext context) {
    PdfViewerParams params({required bool night}) => PdfViewerParams(
      backgroundColor: LydoColors.readerBg,
      pageImageColorFilter: night ? _nightFilter : null,
      margin: 12,
      layoutPages: _c.horizontal ? ReaderController.horizontalLayout : null,
      calculateInitialPageNumber: (document, _) => _c.initialPage(document.pages.length),
      onViewerReady: (document, _) => _c.onViewerReady(document),
      onPageChanged: _c.onPageChanged,
      pagePaintCallbacks: [_c.searcher.pageTextMatchPaintCallback],
      onGeneralTap: (_, _, details) {
        if (details.type != PdfViewerGeneralTapType.tap) return false;
        _c.toggleChrome();
        return true;
      },
    );

    return PopScope(
      onPopInvokedWithResult: (_, _) => _c.saveNow(),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: LydoColors.readerBg,
          body: Stack(
            children: [
              Positioned.fill(
                child: ValueListenableBuilder<bool>(
                  valueListenable: _c.nightMode,
                  builder: (_, night, _) => PdfViewer.file(
                    widget.entry.path,
                    controller: _c.viewer,
                    params: params(night: night),
                  ),
                ),
              ),
              _Chrome(controller: _c, onAskPage: _askPage, onModeSelected: _onModeSelected),
            ],
          ),
        ),
      ),
    );
  }
}

/// Barras do leitor (topo, abas, miniaturas). Some com um toque na página.
class _Chrome extends StatelessWidget {
  const _Chrome({required this.controller, required this.onAskPage, required this.onModeSelected});
  final ReaderController controller;
  final VoidCallback onAskPage;
  final ValueChanged<ReaderMode> onModeSelected;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.chromeVisible,
      builder: (context, visible, _) => Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            left: 0,
            right: 0,
            top: visible ? 0 : -200,
            child: RepaintBoundary(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                  child: Column(
                    children: [
                      _TopBar(controller: controller, onAskPage: onAskPage),
                      const SizedBox(height: 10),
                      ValueListenableBuilder(
                        valueListenable: controller.searchOpen,
                        builder: (_, searching, _) => searching
                            ? const SizedBox.shrink()
                            : _ModeTabs(controller: controller, onSelected: onModeSelected),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: visible ? 140 : 24,
            child: SafeArea(child: _PagePill(controller: controller, onTap: onAskPage)),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            left: 0,
            right: 0,
            bottom: visible ? 0 : -200,
            child: RepaintBoundary(child: _ThumbnailStrip(controller: controller)),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatefulWidget {
  const _TopBar({required this.controller, required this.onAskPage});
  final ReaderController controller;
  final VoidCallback onAskPage;

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: _bar,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _barBorder),
      ),
      child: IconTheme(
        data: const IconThemeData(color: _onBar),
        child: ValueListenableBuilder<bool>(
          valueListenable: c.searchOpen,
          builder: (context, searching, _) => searching ? _searchRow(c) : _titleRow(c),
        ),
      ),
    );
  }

  Widget _titleRow(ReaderController c) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
        Expanded(
          child: Text(
            c.entry.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _onBar, fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(tooltip: 'Buscar no texto', icon: const Icon(Icons.search), onPressed: c.openSearch),
        ValueListenableBuilder<bool>(
          valueListenable: c.nightMode,
          builder: (context, night, _) => PopupMenuButton<String>(
            tooltip: 'Mais opções',
            icon: const Icon(Icons.more_vert, color: _onBar),
            onSelected: (v) => switch (v) {
              'night' => c.toggleNightMode(),
              'page' => widget.onAskPage(),
              _ => null,
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'night',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(night ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
                  title: Text(night ? 'Página normal' : 'Página noturna'),
                ),
              ),
              const PopupMenuItem(
                value: 'page',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.numbers),
                  title: Text('Ir para a página'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _searchRow(ReaderController c) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Fechar busca',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _query.clear();
            c.closeSearch();
          },
        ),
        Expanded(
          child: TextField(
            controller: _query,
            autofocus: true,
            textInputAction: TextInputAction.search,
            cursorColor: _onBar,
            style: const TextStyle(color: _onBar, fontSize: 16),
            decoration: const InputDecoration(
              hintText: 'Buscar no documento',
              hintStyle: TextStyle(color: _onBarMuted),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            onSubmitted: c.search,
            onChanged: c.search,
          ),
        ),
        ValueListenableBuilder<String>(
          valueListenable: c.searchStatus,
          builder: (_, status, _) => Text(status, style: const TextStyle(color: _onBarMuted, fontSize: 13)),
        ),
        IconButton(tooltip: 'Anterior', icon: const Icon(Icons.keyboard_arrow_up), onPressed: c.previousMatch),
        IconButton(tooltip: 'Próximo', icon: const Icon(Icons.keyboard_arrow_down), onPressed: c.nextMatch),
      ],
    );
  }
}

class _ModeTabs extends StatelessWidget {
  const _ModeTabs({required this.controller, required this.onSelected});
  final ReaderController controller;
  final ValueChanged<ReaderMode> onSelected;

  @override
  Widget build(BuildContext context) {
    Widget tab(ReaderMode m, IconData icon, String label, ReaderMode current) {
      final active = m == current;
      return Expanded(
        child: Material(
          color: active ? LydoColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onSelected(m),
            child: SizedBox(
              height: 46,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 22, color: _onBar),
                  const SizedBox(width: 10),
                  Text(label, style: const TextStyle(color: _onBar, fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _bar,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _barBorder),
      ),
      child: ValueListenableBuilder<ReaderMode>(
        valueListenable: controller.mode,
        builder: (_, current, _) => Row(
          children: [
            tab(ReaderMode.read, Icons.menu_book_outlined, 'Ler', current),
            tab(ReaderMode.annotate, Icons.edit_outlined, 'Anotar', current),
            tab(ReaderMode.edit, Icons.tune, 'Editar', current),
          ],
        ),
      ),
    );
  }
}

class _PagePill extends StatelessWidget {
  const _PagePill({required this.controller, required this.onTap});
  final ReaderController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xE6343C4B),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListenableBuilder(
            listenable: Listenable.merge([controller.currentPage, controller.pageCount]),
            builder: (_, _) => Text(
              '${controller.currentPage.value} / ${controller.pageCount.value}',
              style: const TextStyle(color: _onBar, fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}

/// Faixa de miniaturas: a página atual fica destacada e centralizada.
class _ThumbnailStrip extends StatefulWidget {
  const _ThumbnailStrip({required this.controller});
  final ReaderController controller;

  @override
  State<_ThumbnailStrip> createState() => _ThumbnailStripState();
}

class _ThumbnailStripState extends State<_ThumbnailStrip> {
  static const _itemWidth = 72.0;
  static const _gap = 12.0;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.controller.currentPage.addListener(_follow);
  }

  @override
  void dispose() {
    widget.controller.currentPage.removeListener(_follow);
    _scroll.dispose();
    super.dispose();
  }

  void _follow() {
    if (!_scroll.hasClients) return;
    final page = widget.controller.currentPage.value;
    final viewport = _scroll.position.viewportDimension;
    final target = (page - 1) * (_itemWidth + _gap) - (viewport - _itemWidth) / 2;
    _scroll.animateTo(
      target.clamp(0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Container(
      color: const Color(0xF20D121B),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 124,
          child: ValueListenableBuilder<PdfDocument?>(
            valueListenable: c.document,
            builder: (context, doc, _) {
              if (doc == null) return const SizedBox.shrink();
              WidgetsBinding.instance.addPostFrameCallback((_) => _follow());
              return ValueListenableBuilder<int>(
                valueListenable: c.currentPage,
                builder: (context, current, _) => ListView.separated(
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: doc.pages.length,
                  separatorBuilder: (_, _) => const SizedBox(width: _gap),
                  itemBuilder: (context, i) {
                    final page = i + 1;
                    final active = page == current;
                    return GestureDetector(
                      onTap: () => c.goToPage(page),
                      child: SizedBox(
                        width: _itemWidth,
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: active ? LydoColors.primary : Colors.transparent,
                                    width: 3,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: PdfPageView(document: doc, pageNumber: page, maximumDpi: 48),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                                decoration: BoxDecoration(
                                  color: active ? LydoColors.primary : const Color(0xCC4A5263),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$page',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GoToPageDialog extends StatefulWidget {
  const _GoToPageDialog({required this.current, required this.total});
  final int current;
  final int total;

  @override
  State<_GoToPageDialog> createState() => _GoToPageDialogState();
}

class _GoToPageDialogState extends State<_GoToPageDialog> {
  late final _text = TextEditingController(text: '${widget.current}');

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, int.tryParse(_text.text));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ir para a página'),
      content: TextField(
        controller: _text,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(helperText: 'De 1 a ${widget.total}'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _submit, child: const Text('Ir')),
      ],
    );
  }
}
