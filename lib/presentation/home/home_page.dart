import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/formatters.dart';
import '../../core/result.dart';
import '../../domain/document_entry.dart';
import '../reader/reader_page.dart';
import '../settings/settings_controller.dart';
import '../theme/lydo_theme.dart';
import 'home_controller.dart';

/// Aba "Arquivos": biblioteca com busca, filtros e lista/grade.
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.controller, required this.settings});
  final HomeController controller;
  final SettingsController settings;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  HomeController get _c => widget.controller;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _c.load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _open(DocumentEntry entry) async {
    if (!File(entry.path).existsSync()) {
      _snack('O arquivo não foi encontrado. Abra o PDF de novo.');
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ReaderPage(
          entry: entry,
          repository: _c.repository,
          settings: widget.settings,
        ),
      ),
    );
    await _c.load(); // atualiza o progresso exibido
  }

  Future<void> _import() async {
    final result = await _c.importPdf();
    if (!mounted) return;
    switch (result) {
      case Ok(value: final entry?):
        await _open(entry);
      case Err(:final failure):
        _snack(failure.message);
      case Ok():
        break; // cancelado
    }
  }

  Future<void> _confirmRemove(DocumentEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover da biblioteca?'),
        content: Text('"${entry.name}" e o progresso de leitura serão apagados do Lydo. '
            'O arquivo original no celular não é afetado.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remover')),
        ],
      ),
    );
    if (ok == true) await _c.remove(entry);
  }

  Future<void> _rename(DocumentEntry entry) async {
    final text = TextEditingController(text: entry.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renomear'),
        content: TextField(
          controller: text,
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, text.text), child: const Text('Salvar')),
        ],
      ),
    );
    if (name != null) await _c.rename(entry, name);
  }

  void _showMenu(DocumentEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: const Text('Abrir'),
              onTap: () {
                Navigator.pop(sheet);
                _open(entry);
              },
            ),
            ListTile(
              leading: Icon(entry.favorite ? Icons.star : Icons.star_border),
              title: Text(entry.favorite ? 'Tirar dos favoritos' : 'Favoritar'),
              onTap: () {
                Navigator.pop(sheet);
                _c.toggleFavorite(entry);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Renomear'),
              onTap: () {
                Navigator.pop(sheet);
                _rename(entry);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Remover'),
              onTap: () {
                Navigator.pop(sheet);
                _confirmRemove(entry);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _snack(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _import,
        icon: const Icon(Icons.add),
        label: const Text('Abrir PDF', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      ),
      body: SafeArea(
        bottom: false,
        child: ValueListenableBuilder<HomeState>(
          valueListenable: _c.state,
          builder: (context, state, _) => CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _Header(settings: widget.settings)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.list(
                  children: [
                    const SizedBox(height: 8),
                    Text('Seus documentos', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 4),
                    Text(
                      state.documents.isEmpty ? 'Abra um PDF para começar.' : 'Tudo pronto para continuar.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: context.mutedText),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _search,
                      onChanged: _c.search,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Buscar PDF',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: state.query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  _search.clear();
                                  _c.search('');
                                },
                              ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _FilterChips(selected: state.filter, onSelected: _c.setFilter),
                    if (state.continueReading case final cont?) ...[
                      const SizedBox(height: 24),
                      Text('Continuar lendo', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      _ContinueCard(entry: cont, onTap: () => _open(cont)),
                    ],
                    const SizedBox(height: 24),
                    _SectionHeader(state: state, settings: widget.settings),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              ..._buildDocuments(state),
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDocuments(HomeState state) {
    if (state.loading) {
      return const [SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()))];
    }
    if (state.error != null) {
      return [SliverToBoxAdapter(child: Center(child: Text(state.error!)))];
    }
    final docs = state.visible;
    if (docs.isEmpty) {
      return [SliverToBoxAdapter(child: _EmptyState(state: state))];
    }
    return [
      ValueListenableBuilder(
        valueListenable: widget.settings.settings,
        builder: (context, s, _) => SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: s.gridView
              ? SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 180,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.54,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (_, i) => _GridItem(
                    entry: docs[i],
                    onTap: () => _open(docs[i]),
                    onMenu: () => _showMenu(docs[i]),
                  ),
                )
              : SliverToBoxAdapter(
                  child: _ListCard(
                    docs: docs,
                    onTap: _open,
                    onMenu: _showMenu,
                  ),
                ),
        ),
      ),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.settings});
  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          const LydoLogo(size: 30),
          const SizedBox(width: 12),
          Text('Lydo', style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          IconButton.outlined(
            tooltip: dark ? 'Modo claro' : 'Modo escuro',
            style: IconButton.styleFrom(
              side: BorderSide(color: context.borderColor),
              backgroundColor: Theme.of(context).colorScheme.surface,
            ),
            icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            onPressed: () => settings.toggleDark(currentlyDark: dark),
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelected});
  final LibraryFilter selected;
  final ValueChanged<LibraryFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    Widget chip(LibraryFilter f, String label, IconData? icon) {
      final active = f == selected;
      return ChoiceChip(
        selected: active,
        showCheckmark: false,
        onSelected: (_) => onSelected(f),
        avatar: icon == null ? null : Icon(icon, size: 20, color: active ? Colors.white : context.mutedText),
        label: Text(label),
        labelStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: active ? Colors.white : Theme.of(context).colorScheme.onSurface,
        ),
        selectedColor: LydoColors.primary,
        backgroundColor: Colors.transparent,
        side: BorderSide(color: active ? LydoColors.primary : context.borderColor),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        chip(LibraryFilter.all, 'Todos', null),
        chip(LibraryFilter.recent, 'Recentes', Icons.schedule),
        chip(LibraryFilter.favorites, 'Favoritos', Icons.star_border),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.state, required this.settings});
  final HomeState state;
  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    final title = state.query.isNotEmpty
        ? 'Resultados'
        : switch (state.filter) {
            LibraryFilter.all => 'Arquivos recentes',
            LibraryFilter.recent => 'Abertos nos últimos 7 dias',
            LibraryFilter.favorites => 'Favoritos',
          };
    return Row(
      children: [
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
        ValueListenableBuilder(
          valueListenable: settings.settings,
          builder: (context, s, _) => SegmentedButton<bool>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: context.softPrimary,
              selectedForegroundColor: LydoColors.primary,
              foregroundColor: context.mutedText,
              side: BorderSide(color: context.borderColor),
              visualDensity: VisualDensity.compact,
            ),
            segments: const [
              ButtonSegment(value: false, icon: Icon(Icons.view_list_outlined), tooltip: 'Lista'),
              ButtonSegment(value: true, icon: Icon(Icons.grid_view_outlined), tooltip: 'Grade'),
            ],
            selected: {s.gridView},
            onSelectionChanged: (v) => settings.update((c) => c.copyWith(gridView: v.first)),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.state});
  final HomeState state;

  @override
  Widget build(BuildContext context) {
    final (icon, title, text) = state.documents.isEmpty
        ? (Icons.picture_as_pdf_outlined, 'Nenhum PDF ainda', 'Toque em "Abrir PDF". O Lydo lembra onde você parou em cada arquivo.')
        : state.query.isNotEmpty
            ? (Icons.search_off, 'Nada encontrado', 'Nenhum PDF com "${state.query}".')
            : state.filter == LibraryFilter.favorites
                ? (Icons.star_border, 'Sem favoritos', 'Toque em ⋮ ao lado de um PDF e escolha Favoritar.')
                : (Icons.schedule, 'Nada recente', 'Nenhum PDF aberto nos últimos 7 dias.');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        children: [
          Icon(icon, size: 56, color: LydoColors.primary),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Capa (primeira página) renderizada em miniatura.
class DocumentCover extends StatelessWidget {
  const DocumentCover({super.key, required this.path, required this.width});
  final String path;
  final double width;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        width: width,
        height: width * 1.33,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: context.borderColor),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        clipBehavior: Clip.antiAlias,
        child: PdfDocumentViewBuilder.file(
          path,
          builder: (context, document) => document == null
              ? const SizedBox.shrink()
              : PdfPageView(document: document, pageNumber: 1, maximumDpi: 72),
        ),
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.entry, required this.onTap});
  final DocumentEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              DocumentCover(path: entry.path, width: 76),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 19)),
                    const SizedBox(height: 6),
                    Text('Página ${entry.lastPage} de ${entry.pageCount}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.mutedText)),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: entry.progress, minHeight: 6),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: context.mutedText),
            ],
          ),
        ),
      ),
    );
  }
}

String _meta(DocumentEntry e) => '${formatBytes(e.sizeBytes)}  •  ${formatRelativeDay(e.lastOpenedAt)}';

class _PdfBadge extends StatelessWidget {
  const _PdfBadge();

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return SizedBox(
      width: 40,
      height: 44,
      child: Stack(
        children: [
          Icon(Icons.insert_drive_file_outlined, size: 44, color: Theme.of(context).colorScheme.onSurface),
          Positioned(
            left: 2,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: dark ? LydoColors.primary : LydoColors.pdfRed,
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text('PDF',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({required this.docs, required this.onTap, required this.onMenu});
  final List<DocumentEntry> docs;
  final ValueChanged<DocumentEntry> onTap;
  final ValueChanged<DocumentEntry> onMenu;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < docs.length; i++) ...[
            if (i > 0) const Divider(indent: 16, endIndent: 16),
            ListTile(
              contentPadding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
              leading: const _PdfBadge(),
              title: Row(
                children: [
                  Flexible(
                    child: Text(docs[i].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  ),
                  if (docs[i].favorite) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.star, size: 16, color: Color(0xFFF5B400)),
                  ],
                ],
              ),
              subtitle: Text(_meta(docs[i]), style: Theme.of(context).textTheme.bodySmall),
              onTap: () => onTap(docs[i]),
              onLongPress: () => onMenu(docs[i]),
              trailing: IconButton(
                tooltip: 'Opções',
                icon: const Icon(Icons.more_vert),
                onPressed: () => onMenu(docs[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GridItem extends StatelessWidget {
  const _GridItem({required this.entry, required this.onTap, required this.onMenu});
  final DocumentEntry entry;
  final VoidCallback onTap;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      onLongPress: onMenu,
      child: LayoutBuilder(
        builder: (context, box) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                DocumentCover(path: entry.path, width: box.maxWidth),
                if (entry.hasStarted)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: LinearProgressIndicator(value: entry.progress, minHeight: 4),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(entry.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                if (entry.favorite) const Icon(Icons.star, size: 16, color: Color(0xFFF5B400)),
              ],
            ),
            Text(_meta(entry), style: Theme.of(context).textTheme.bodySmall, maxLines: 1),
          ],
        ),
      ),
    );
  }
}
