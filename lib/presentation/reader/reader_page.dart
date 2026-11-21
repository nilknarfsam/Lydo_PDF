import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pdfrx/pdfrx.dart';

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';

import '../../core/annotation_renderer.dart';
import '../../core/result.dart';
import '../../data/pdf_edit_service.dart';
import '../../data/stamp_import_service.dart';
import '../../domain/annotation.dart';
import '../../domain/annotation_repository.dart';
import '../../domain/app_settings.dart';
import '../../domain/document_entry.dart';
import '../../domain/library_repository.dart';
import '../../domain/page_plan.dart';
import '../../domain/signature_repository.dart';
import '../edit/page_organizer_page.dart';
import '../edit/signature_pad_page.dart';
import '../edit/signature_picker_sheet.dart';
import '../settings/settings_controller.dart';
import '../theme/lydo_theme.dart';
import 'annotation_controller.dart';
import 'annotation_layer.dart';
import 'edit_toolbar.dart';
import 'reader_controller.dart';

/// Inverte as cores da página (fundo preto, letra clara) para ler à noite.
const _nightFilter = ColorFilter.matrix(<double>[
  -1, 0, 0, 0, 255, //
  0, -1, 0, 0, 255, //
  0, 0, -1, 0, 255, //
  0, 0, 0, 1, 0, //
]);

// O leitor é sempre escuro, como na referência: o foco fica na página.
const _onBar = Colors.white;
const _onBarMuted = Color(0xFFA3ACBD);

// Barras por cima do PDF: vidro fosco (translúcido + desfoque), a página aparece por trás.
const _glass = Color(0xC71A2130);
const _glassBorder = Color(0x80394357);

/// Fundo de vidro fosco das barras do leitor.
class _Glass extends StatelessWidget {
  const _Glass({required this.child, this.radius = 18, this.color = _glass, this.border = true});
  final Widget child;
  final double radius;
  final Color color;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: shape,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: shape,
            border: border ? Border.all(color: _glassBorder) : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

class ReaderPage extends StatefulWidget {
  const ReaderPage({
    super.key,
    required this.entry,
    required this.repository,
    required this.annotationRepository,
    required this.signatureRepository,
    required this.settings,
  });

  final DocumentEntry entry;
  final LibraryRepository repository;
  final AnnotationRepository annotationRepository;
  final SignatureRepository signatureRepository;
  final SettingsController settings;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> with WidgetsBindingObserver {
  late final ReaderController _c;
  late final AnnotationController _a;
  final _images = AnnotationImageCache();
  final _editService = PdfEditService();
  final _stamps = StampImportService();

  @override
  void initState() {
    super.initState();
    _c = ReaderController(entry: widget.entry, repository: widget.repository, settings: widget.settings.settings.value);
    _a = AnnotationController(documentId: widget.entry.id, repository: widget.annotationRepository)
      ..onChanged = () {
        _images.ensureLoaded(_a.annotations.value, onLoaded: _repaintPages);
        _repaintPages();
      };
    _a.load().then((error) {
      if (error != null && mounted) _snack(error);
    });
    WidgetsBinding.instance.addObserver(this);
    _c.chromeVisible.addListener(_applySystemBars);
  }

  /// Tela limpa: com as barras do leitor escondidas, some também a barra de
  /// status e a de navegação do Android (bom para ler e tirar print).
  void _applySystemBars() {
    SystemChrome.setEnabledSystemUIMode(
      _c.chromeVisible.value ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
    );
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
    final r = await _askText(title: note ? 'Nota' : 'Texto', initial: a.text, multiline: note, canDelete: true);
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
      builder: (_) =>
          _TextDialog(title: title, initial: initial, hint: hint, multiline: multiline, canDelete: canDelete),
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

  /// Escolher Contínua / Horizontal / Página por página sem sair do PDF.
  /// A escolha também vira o padrão nos Ajustes.
  Future<void> _askScrollMode() async {
    final current = _c.scrollMode.value;
    final picked = await showModalBottomSheet<ScrollMode>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text('Modo de leitura', style: Theme.of(sheet).textTheme.titleLarge),
            ),
            for (final m in ScrollMode.values)
              ListTile(
                title: Text(m.label),
                trailing: m == current ? const Icon(Icons.check, color: LydoColors.primary) : null,
                onTap: () => Navigator.pop(sheet, m),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || picked == current) return;
    _c.changeScrollMode(picked);
    widget.settings.update((s) => s.copyWith(scrollMode: picked));
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
    _c.chromeVisible.removeListener(_applySystemBars);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _c.dispose();
    _a.dispose();
    _images.dispose();
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
        _a.cancelStroke();
        _c.setMode(m);
        _c.chromeVisible.value = true;
    }
  }

  // ---------- Modo Editar ----------

  Future<void> _onEditAction(EditAction action) async {
    switch (action) {
      case EditAction.image:
        final r = await _stamps.pickImage();
        switch (r) {
          case Ok(value: final asset?):
            _startPlacing(asset);
          case Err(:final failure):
            _snack(failure.message);
          case Ok():
            break;
        }
      case EditAction.signature:
        await _chooseSignature();
      case EditAction.pages:
        await _organizePages();
      case EditAction.export:
        await _export();
    }
  }

  void _startPlacing(StampAsset asset) {
    _c.movingImage.value = null;
    _c.pendingStamp.value = asset;
  }

  Future<void> _chooseSignature() async {
    final choice = await showSignaturePicker(context, widget.signatureRepository);
    if (!mounted || choice == null) return;
    String? path;
    switch (choice) {
      case UseSaved(:final signature):
        path = signature.path;
      case CreateNew():
        final png = await Navigator.push<Uint8List>(
          context,
          MaterialPageRoute(builder: (_) => const SignaturePadPage()),
        );
        if (png == null) return;
        switch (await widget.signatureRepository.save(png)) {
          case Ok(:final value):
            path = value.path;
          case Err(:final failure):
            return _snack(failure.message);
        }
    }
    if (!mounted) return;
    switch (await _stamps.fromSignature(path)) {
      case Ok(:final value):
        _startPlacing(value);
      case Err(:final failure):
        _snack(failure.message);
    }
  }

  /// Toque na página no modo Editar: colocar, mover ou abrir opções da imagem.
  void _onEditTap(Offset local) {
    final hit = _hitTest(local);
    if (hit == null) return;
    final pending = _c.pendingStamp.value;
    final moving = _c.movingImage.value;
    if (pending != null) {
      final page = _c.document.value?.pages[hit.page - 1];
      // Assinatura nasce com ~1/3 da largura visível da página; foto com ~1/2.
      final width = (page?.width ?? 595) * (pending.isSignature ? 0.32 : 0.5);
      _a.placeImage(hit.page, hit.point, pending.path, pending.aspect, width, page?.rotation.index ?? 0);
      _c.pendingStamp.value = null;
    } else if (moving != null) {
      _a.moveImage(moving, hit.page, hit.point);
      _c.movingImage.value = null;
    } else if (_a.imageAt(hit.page, hit.point) case final image?) {
      _imageOptions(image);
    } else {
      _c.toggleChrome();
    }
  }

  void _imageOptions(Annotation image) {
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
                leading: const Icon(Icons.open_with),
                title: const Text('Mover'),
                subtitle: const Text('Depois toque no novo lugar'),
                onTap: () => run(() {
                  _c.pendingStamp.value = null;
                  _c.movingImage.value = image;
                }),
              ),
              ListTile(
                leading: const Icon(Icons.zoom_in),
                title: const Text('Aumentar'),
                onTap: () => run(() => _a.resizeImage(image, 1.25)),
              ),
              ListTile(
                leading: const Icon(Icons.zoom_out),
                title: const Text('Diminuir'),
                onTap: () => run(() => _a.resizeImage(image, 0.8)),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Excluir'),
                onTap: () => run(() => _a.remove(image)),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _organizePages() async {
    final count = _c.pageCount.value;
    if (count == 0) return _snack('Aguarde o PDF terminar de abrir.');
    final plan = await Navigator.push<PagePlan>(
      context,
      MaterialPageRoute(
        builder: (_) => PageOrganizerPage(pdfPath: _c.entry.path, pageCount: count),
      ),
    );
    if (!mounted || plan == null || plan.isIdentity(count)) return;

    _c.editBusy.value = true;
    await _c.saveNow();
    // Arquivo novo (em vez de sobrescrever): o leitor ainda está com o atual aberto.
    final old = _c.entry.path;
    final target = '${File(old).parent.path}/${_c.entry.id}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final result = await _editService.applyPagePlan(sourcePath: old, targetPath: target, plan: plan);
    if (!mounted) return;
    _c.editBusy.value = false;
    if (result case Err(:final failure)) return _snack(failure.message);

    // Daqui em diante este leitor não grava mais posição (senão voltaria a apontar para o arquivo antigo).
    _c.markReplaced();
    final firstPage = plan.newNumberOf(_c.currentPage.value) ?? 1;
    final updated = _c.entry.copyWith(
      path: target,
      pageCount: plan.slots.length,
      lastPage: firstPage,
      viewMatrix: const [], // posição antiga não vale mais
    );
    // Ordem segura: anotações renumeradas → entrada nova → só então apaga o PDF antigo.
    final savedNotes = await _a.replaceAll(remapAnnotations(_a.annotations.value, plan.newNumberOf));
    final savedEntry = await widget.repository.save(updated);
    if (savedNotes is Err || savedEntry is Err) {
      _snack('Páginas reorganizadas, mas houve erro ao salvar. Abra o PDF de novo.');
    } else {
      try {
        await File(old).delete();
      } catch (_) {}
    }
    if (!mounted) return;
    unawaited(
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ReaderPage(
            entry: updated,
            repository: widget.repository,
            annotationRepository: widget.annotationRepository,
            signatureRepository: widget.signatureRepository,
            settings: widget.settings,
          ),
        ),
      ),
    );
  }

  Future<void> _export() async {
    _c.editBusy.value = true;
    final result = await _editService.exportWithAnnotations(path: _c.entry.path, annotations: _a.annotations.value);
    if (!mounted) return;
    _c.editBusy.value = false;
    switch (result) {
      case Err(:final failure):
        _snack(failure.message);
      case Ok(:final value):
        try {
          final saved = await FilePicker.saveFile(
            fileName: '${_c.entry.name} (Lydo).pdf',
            bytes: value,
            mimeType: 'application/pdf',
            dialogTitle: 'Salvar PDF',
          );
          if (saved != null && mounted) _snack('PDF salvo com as anotações.');
        } catch (_) {
          if (mounted) _snack('Não foi possível salvar o PDF.');
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    PdfViewerParams params({required bool night}) => PdfViewerParams(
      backgroundColor: LydoColors.readerBg,
      pageImageColorFilter: night ? _nightFilter : null,
      margin: 12,
      layoutPages: _c.paged
          ? ReaderController.pagedLayout
          : _c.horizontal
          ? ReaderController.horizontalLayout
          : null,
      onInteractionStart: (_) => _c.onGestureStart(),
      onInteractionEnd: (details) => _c.onGestureEnd(details.velocity),
      onViewSizeChanged: (size, oldSize, _) => _c.onViewSizeChanged(size, oldSize),
      calculateInitialPageNumber: (document, _) => _c.initialPage(document.pages.length),
      onViewerReady: (document, _) => _c.onViewerReady(document),
      onPageChanged: _c.onPageChanged,
      pagePaintCallbacks: [
        (canvas, rect, page) => paintPageAnnotations(canvas, rect, page, _a.onPage(page.pageNumber), _images),
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
        if (_c.mode.value == ReaderMode.edit) {
          _onEditTap(details.localPosition);
        } else {
          _c.toggleChrome();
        }
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
                // O modo de rolagem entra aqui para o pdfrx refazer o layout ao trocar.
                child: ListenableBuilder(
                  listenable: Listenable.merge([_c.nightMode, _c.scrollMode]),
                  builder: (_, _) => PdfViewer.file(
                    widget.entry.path,
                    controller: _c.viewer,
                    params: params(night: _c.nightMode.value),
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
                          viewer: _c.viewer,
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
                onAskScrollMode: _askScrollMode,
                onModeSelected: _onModeSelected,
                onMore: _showMore,
                onEditAction: _onEditAction,
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
    required this.onAskScrollMode,
    required this.onModeSelected,
    required this.onMore,
    required this.onEditAction,
  });
  final ReaderController controller;
  final AnnotationController annotations;
  final VoidCallback onAskPage;
  final VoidCallback onAskScrollMode;
  final ValueChanged<ReaderMode> onModeSelected;
  final VoidCallback onMore;
  final ValueChanged<EditAction> onEditAction;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([controller.chromeVisible, controller.mode, controller.toolThumbs]),
      builder: (context, _) {
        final visible = controller.chromeVisible.value;
        final annotating = controller.mode.value != ReaderMode.read;
        // Em Anotar/Editar as miniaturas são opcionais e ficam por cima da barra de ferramentas.
        final thumbsOverTools = annotating && controller.toolThumbs.value;
        // De lado a tela é baixa: barra e abas numa linha só, miniaturas menores.
        final compact = MediaQuery.orientationOf(context) == Orientation.landscape;
        final stripHeight = _ThumbnailStripState.heightFor(compact: compact);
        final tabs = ValueListenableBuilder(
          valueListenable: controller.searchOpen,
          builder: (_, searching, _) => searching
              ? const SizedBox.shrink()
              : _ModeTabs(controller: controller, onSelected: onModeSelected, compact: compact),
        );
        final topBar = _TopBar(
          controller: controller,
          onAskPage: onAskPage,
          onAskScrollMode: onAskScrollMode,
          compact: compact,
        );
        final toolbar = switch (controller.mode.value) {
          ReaderMode.annotate => AnnotationToolbar(controller: annotations, onMore: onMore),
          ReaderMode.edit => ListenableBuilder(
            listenable: Listenable.merge([controller.pendingStamp, controller.movingImage, controller.editBusy]),
            builder: (_, _) =>
                EditToolbar(onAction: onEditAction, hint: controller.editHint, busy: controller.editBusy.value),
          ),
          ReaderMode.read => null,
        };
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
                    child: compact
                        ? Row(
                            children: [
                              Expanded(child: topBar),
                              const SizedBox(width: 8),
                              SizedBox(width: 360, child: tabs),
                            ],
                          )
                        : Column(children: [topBar, const SizedBox(height: 10), tabs]),
                  ),
                ),
              ),
            ),
            if (visible)
              Positioned(
                right: 16,
                bottom: (annotating ? 172 : stripHeight + 16) + (thumbsOverTools ? stripHeight : 0),
                child: SafeArea(
                  child: Row(
                    children: [
                      if (annotating) ...[
                        _ThumbsToggle(active: thumbsOverTools, onTap: controller.toggleToolThumbs),
                        const SizedBox(width: 8),
                      ],
                      _PagePill(controller: controller, onTap: onAskPage),
                    ],
                  ),
                ),
              ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              left: 0,
              right: 0,
              bottom: visible ? 0 : -260 - (thumbsOverTools ? stripHeight : 0),
              child: RepaintBoundary(
                child: toolbar == null
                    ? _ThumbnailStrip(controller: controller, compact: compact)
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (thumbsOverTools)
                            _ThumbnailStrip(controller: controller, safeBottom: false, compact: compact),
                          toolbar,
                        ],
                      ),
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
  const _TopBar({
    required this.controller,
    required this.onAskPage,
    required this.onAskScrollMode,
    this.compact = false,
  });
  final ReaderController controller;
  final VoidCallback onAskPage;
  final VoidCallback onAskScrollMode;

  /// Celular de lado: barra mais baixa.
  final bool compact;

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
    return SizedBox(
      height: widget.compact ? 50 : 60,
      child: _Glass(
        child: IconTheme(
          data: const IconThemeData(color: _onBar),
          child: ValueListenableBuilder<bool>(
            valueListenable: c.searchOpen,
            builder: (context, searching, _) => searching ? _searchRow(c) : _titleRow(c),
          ),
        ),
      ),
    );
  }

  Widget _titleRow(ReaderController c) {
    return Row(
      children: [
        IconButton(tooltip: 'Voltar', icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.maybePop(context)),
        Expanded(
          child: Text(
            c.entry.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: _onBar, fontSize: widget.compact ? 16 : 18, fontWeight: FontWeight.w700),
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
              'layout' => widget.onAskScrollMode(),
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
              PopupMenuItem(
                value: 'layout',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.auto_stories_outlined),
                  title: const Text('Modo de leitura'),
                  subtitle: Text(c.scrollMode.value.label),
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
  const _ModeTabs({required this.controller, required this.onSelected, this.compact = false});
  final ReaderController controller;
  final ValueChanged<ReaderMode> onSelected;

  /// Celular de lado: abas mais baixas, na mesma linha da barra de cima.
  final bool compact;

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
              height: compact ? 40 : 46,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: compact ? 20 : 22, color: _onBar),
                  SizedBox(width: compact ? 6 : 10),
                  Text(
                    label,
                    style: TextStyle(color: _onBar, fontSize: compact ? 14 : 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return _Glass(
      radius: 16,
      child: Padding(
        padding: const EdgeInsets.all(4),
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
      color: const Color(0xC7343C4B),
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

/// Botão redondo ao lado da pílula da página: mostra/esconde as miniaturas em Anotar/Editar.
class _ThumbsToggle extends StatelessWidget {
  const _ThumbsToggle({required this.active, required this.onTap});
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: active ? 'Esconder miniaturas' : 'Mostrar miniaturas',
      child: Material(
        color: active ? LydoColors.primary : const Color(0xC7343C4B),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.all(9),
            child: Icon(Icons.view_carousel_outlined, color: _onBar, size: 22),
          ),
        ),
      ),
    );
  }
}

/// Faixa de miniaturas: a página atual fica destacada e centralizada.
class _ThumbnailStrip extends StatefulWidget {
  const _ThumbnailStrip({required this.controller, this.safeBottom = true, this.compact = false});
  final ReaderController controller;

  /// Celular de lado: faixa mais baixa, sobra mais tela para a página.
  final bool compact;

  /// Falso quando a faixa fica em cima da barra de ferramentas (a barra já cuida da borda de baixo).
  final bool safeBottom;

  @override
  State<_ThumbnailStrip> createState() => _ThumbnailStripState();
}

class _ThumbnailStripState extends State<_ThumbnailStrip> {
  static double heightFor({required bool compact}) => compact ? 84.0 : 124.0;
  double get _itemWidth => widget.compact ? 46.0 : 72.0;
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
    return _Glass(
      radius: 0,
      border: false,
      color: const Color(0xBF0D121B),
      child: SafeArea(
        top: false,
        bottom: widget.safeBottom,
        child: SizedBox(
          height: heightFor(compact: widget.compact),
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
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: widget.compact ? 8 : 12),
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
                                  border: Border.all(color: active ? LydoColors.primary : Colors.transparent, width: 3),
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
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
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
