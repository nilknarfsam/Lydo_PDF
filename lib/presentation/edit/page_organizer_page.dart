import 'package:material_ui/material_ui.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../domain/page_plan.dart';
import '../theme/lydo_theme.dart';
import 'page_organizer_controller.dart';

/// Tela "Organizar páginas": gira, exclui e reordena. Não altera o PDF.
/// Devolve o [PagePlan] escolhido via Navigator.pop, ou null se o usuário cancelou.
class PageOrganizerPage extends StatefulWidget {
  const PageOrganizerPage({super.key, required this.pdfPath, required this.pageCount});

  final String pdfPath;
  final int pageCount;

  @override
  State<PageOrganizerPage> createState() => _PageOrganizerPageState();
}

class _PageOrganizerPageState extends State<PageOrganizerPage> {
  late final PageOrganizerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageOrganizerController(widget.pageCount);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _deleteSelected() {
    final removed = _controller.deleteSelected();
    if (!removed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O PDF precisa ter pelo menos uma página.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Organizar páginas'),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: c.canUndo,
            builder: (context, canUndo, _) => IconButton(
              tooltip: 'Desfazer',
              icon: const Icon(Icons.undo),
              onPressed: canUndo ? c.undo : null,
            ),
          ),
          ValueListenableBuilder<List<PageSlot>>(
            valueListenable: c.slots,
            builder: (context, _, _) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(
                onPressed: c.hasChanges ? () => Navigator.of(context).pop(c.plan) : null,
                child: const Text('Concluir'),
              ),
            ),
          ),
        ],
      ),
      body: PdfDocumentViewBuilder.file(
        widget.pdfPath,
        builder: (context, document) => ListenableBuilder(
          listenable: Listenable.merge([c.slots, c.selected]),
          builder: (context, _) {
            final slots = c.slots.value;
            final selection = c.selected.value;
            return ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              buildDefaultDragHandles: false,
              itemCount: slots.length,
              // onReorderItem já devolve o índice final; o move() espera o índice antes da remoção.
              onReorderItem: (from, to) => c.move(from, to > from ? to + 1 : to),
              itemBuilder: (context, index) => _PageCard(
                key: ValueKey(slots[index].sourcePage),
                index: index,
                slot: slots[index],
                selected: selection.contains(index),
                document: document,
                onTap: () => c.toggleSelect(index),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: ValueListenableBuilder<Set<int>>(
          valueListenable: c.selected,
          builder: (context, selection, _) {
            final hasSelection = selection.isNotEmpty;
            return Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(top: BorderSide(color: context.borderColor)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: hasSelection ? c.rotateSelected : null,
                      icon: const Icon(Icons.rotate_right),
                      label: const Text('Girar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: hasSelection ? _deleteSelected : null,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Excluir'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Cartão de uma página no novo arranjo. Toque seleciona; a alça à direita arrasta.
class _PageCard extends StatelessWidget {
  const _PageCard({
    super.key,
    required this.index,
    required this.slot,
    required this.selected,
    required this.document,
    required this.onTap,
  });

  final int index;
  final PageSlot slot;
  final bool selected;
  final PdfDocument? document;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final number = index + 1;
    final moved = slot.sourcePage != number;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? LydoColors.primary : context.borderColor,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _Thumb(slot: slot, document: document, selected: selected),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Página $number', style: textTheme.titleMedium),
                    if (moved) ...[
                      const SizedBox(height: 4),
                      Text('(original ${slot.sourcePage})', style: textTheme.bodySmall),
                    ],
                    if (slot.quarterTurns != 0) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.rotate_right, size: 16, color: context.mutedText),
                          const SizedBox(width: 4),
                          Text('Girada ${slot.quarterTurns * 90}°', style: textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.drag_handle, color: context.mutedText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Miniatura 72x96 da página original, girada conforme o plano.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.slot, required this.document, required this.selected});

  final PageSlot slot;
  final PdfDocument? document;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final doc = document;
    return Stack(
      children: [
        Container(
          width: 72,
          height: 96,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: context.borderColor),
          ),
          child: RepaintBoundary(
            child: RotatedBox(
              quarterTurns: slot.quarterTurns,
              child: doc == null
                  ? const SizedBox.shrink()
                  : PdfPageView(document: doc, pageNumber: slot.sourcePage, maximumDpi: 48),
            ),
          ),
        ),
        if (selected)
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(color: LydoColors.primary, shape: BoxShape.circle),
              child: const Icon(Icons.check, size: 14, color: Colors.white),
            ),
          ),
      ],
    );
  }
}
