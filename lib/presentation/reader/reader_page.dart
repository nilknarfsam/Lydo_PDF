import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../domain/annotation.dart';
import '../../domain/annotation_repository.dart';
import '../../domain/document_entry.dart';
import '../../domain/library_repository.dart';
import '../settings/settings_controller.dart';
import '../theme/lydo_theme.dart';
import 'annotation_controller.dart';
import 'annotation_layer.dart';
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
    required this.annotationRepository,
    required this.settings,
  });

  final DocumentEntry entry;
  final LibraryRepository repository;
  final AnnotationRepository annotationRepository;
  final SettingsController settings;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> with WidgetsBindingObserver {
  late final ReaderController _c;
  late final AnnotationController _a;

  @override
  void initState() {
    super.initState();
    _c = ReaderController(
      entry: widget.entry,
      repository: widget.repository,
      settings: widget.settings.settings.value,
    );
    _a = AnnotationController(documentId: widget.entry.id, repository: widget.annotationRepository)
      ..onChanged = _repaintPages;
    _a.load().then((error) {
      if (error != null && mounted) _snack(error);
    });
    WidgetsBinding.instance.addObserver(this);
  }

  void _repaintPages() {
    if (_c.viewer.isReady) _c.viewer.invalidate();
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// Toque na tela → página e ponto em coordenadas do PDF.
  PageHit? _hitTest(Offset local) {
    if (!_c.viewer.isReady) return null;
    final r = _c.viewer.getPdfPageHitTestResult(local, useDocumentLayoutCoordinates: false);
    if (r == null) return null;
    return (page: r.page.pageNumber, point: APoint(r.offset.x, r.offset.y));
  }

  Future<void> _onPlace(AnnotationTool tool, PageHit hit) async {
    switch (tool) {
      case AnnotationTool.eraser:
        if (!_a.eraseAt(hit.page, hit.point)) _snack('Nenhuma anotação neste ponto.');
      case AnnotationTool.text:
        final r = await _askText(title: 'Texto na página', hint: 'Escreva o texto');
        if (r?.text case final text?) _a.addText(hit.page, hit.point, text);
      case AnnotationTool.note:
        final r = await _askText(title: 'Nova nota', hint: 'Escreva sua nota', multiline: true);
        if (r?.text case final text?) _a.addNote(hit.page, hit.point, text);
      default:
        break;
    }
  }

  /// Toque numa caixa de texto ou nota: editar ou excluir.
  Future<void> _editAnnotation(Annotation a) async {
    if (_a.tool.value == AnnotationTool.eraser) return _a.remove(a);
    final note = a.type == AnnotationType.note;
    final r = await _askText(
      title: note ? 'Nota' : 'Texto',
      initial: a.text,
      multiline: note,
      canDelete: true,
    );
    if (r == null) return;
    if (r.delete) return _a.remove(a);
    if (r.text != null) _a.updateText(a, r.text!);
  }

  Future<({String? text, bool delete})?> _askText({
    required String title,
    String initial = '',
    String? hint,
    bool multiline = false,
    bool canDelete = false,
  }) {
    return showDialog<({String? text, bool delete})>(
      context: context,
      builder: (_) => _TextDialog(
        title: title,
        initial: initial,
        hint: hint,
        multiline: multiline,
        canDelete: canDelete,
      ),
    );
  }

  void _showMore() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) {
        void run(VoidCallback f) {
          Navigator.pop(sheet);
          f();
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                enabled: _a.canUndo.value,
                leading: const Icon(Icons.undo),
                title: const Text('Desfazer'),
                onTap: () => run(_a.undo),
              ),
              ListTile(
                enabled: _a.canRedo.value,
                leading: const Icon(Icons.redo),
                title: const Text('Refazer'),
                onTap: () => run(_a.redo),
              ),
              ListTile(
                leading: const Icon(Icons.auto_fix_normal_outlined),
                title: const Text('Borracha'),
                subtitle: const Text('Toque numa anotação para apagar'),
                onTap: () => run(() => _a.tool.value = AnnotationTool.eraser),
              ),
              ListTile(
                leading: const Icon(Icons.pan_tool_outlined),
                title: const Text('Mover a página'),
                subtitle: const Text('Solta a ferramenta para rolar e dar zoom'),
                onTap: () => run(() => _a.tool.value = null),
              ),
              ListTile(
                leading: const Icon(Icons.layers_clear_outlined),
                title: Text('Limpar anotações da página ${_c.currentPage.value}'),
                onTap: () => run(_confirmClearPage),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmClearPage() async {
    final page = _c.currentPage.value;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Limpar a página $page?'),
        content: const Text('Todas as anotações desta página serão apagadas. Dá para desfazer em seguida.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Limpar')),
        ],
      ),
    );
    if (ok == true) _a.clearPage(page);
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
    _a.dispose();
    super.dispose();
  }

  Future<void> _askPage() async {
    final page = await showDialog<int>(
      context: context,
      builder: (_) => _GoToPageDialog(current: _c.currentPage.value, total: _c.pageCount.value),
    );
    if (page != null) await _c.goToPage(page);
  }

  void _onModeSelected(ReaderMode m) {
    switch (m) {
      case ReaderMode.read:
        _a.cancelStroke();
        _c.setMode(m);
      case ReaderMode.annotate:
        _c.setMode(m);
        _c.chromeVisible.value = true;
      case ReaderMode.edit:
        _snack('O modo Editar chega na próxima versão do Lydo.');
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
      pagePaintCallbacks: [
        (canvas, rect, page) => paintPageAnnotations(canvas, rect, page, _a.onPage(page.pageNumber)),
        _c.searcher.pageTextMatchPaintCallback,
      ],
      pageOverlaysBuilder: (context, rect, page) => pageAnnotationOverlays(
        pageRectInViewer: rect,
        page: page,
        list: _a.onPage(page.pageNumber),
        onTap: _editAnnotation,
      ),
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
              Positioned.fill(
                child: ValueListenableBuilder<ReaderMode>(
                  valueListenable: _c.mode,
                  builder: (_, mode, _) => mode != ReaderMode.annotate
                      ? const SizedBox.shrink()
                      : AnnotationGestureLayer(
                          controller: _a,
                          hitTest: _hitTest,
                          onStrokeEnd: () => _a.endStroke(_c.document.value),
                          onPlace: _onPlace,
                        ),
                ),
              ),
              _Chrome(
                controller: _c,
                annotations: _a,
                onAskPage: _askPage,
                onModeSelected: _onModeSelected,
                onMore: _showMore,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Barras do leitor (topo, abas, miniaturas). Some com um toque na página.
class _Chrome extends StatelessWidget {
  const _Chrome({
    required this.controller,
    required this.annotations,
    required this.onAskPage,
    required this.onModeSelected,
    required this.onMore,
  });
  final ReaderController controller;
  final AnnotationController annotations;
  final VoidCallback onAskPage;
  final ValueChanged<ReaderMode> onModeSelected;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([controller.chromeVisible, controller.mode]),
      builder: (context, _) {
        final visible = controller.chromeVisible.value;
        final annotating = controller.mode.value == ReaderMode.annotate;
        return Stack(
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
            bottom: !visible ? 24 : (annotating ? 172 : 140),
            child: SafeArea(child: _PagePill(controller: controller, onTap: onAskPage)),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            left: 0,
            right: 0,
            bottom: visible ? 0 : -260,
            child: RepaintBoundary(
              // No modo Anotar a barra de ferramentas ocupa o lugar das miniaturas.
              child: annotating
                  ? AnnotationToolbar(controller: annotations, onMore: onMore)
                  : _ThumbnailStrip(controller: controller),
            ),
          ),
        ],
      );
      },
    );
  }
}

class _TextDialog extends StatefulWidget {
  const _TextDialog({
    required this.title,
    required this.initial,
    required this.hint,
    required this.multiline,
    required this.canDelete,
  });
  final String title;
  final String initial;
  final String? hint;
  final bool multiline;
  final bool canDelete;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _text,
        autofocus: true,
        minLines: widget.multiline ? 3 : 1,
        maxLines: widget.multiline ? 6 : 1,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: widget.hint),
      ),
      actions: [
        if (widget.canDelete)
          TextButton(
            onPressed: () => Navigator.pop(context, (text: null, delete: true)),
            child: const Text('Excluir', style: TextStyle(color: LydoColors.pdfRed)),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(context, (text: _text.text, delete: false)),
          child: const Text('Salvar'),
        ),
      ],
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
