import 'package:material_ui/material_ui.dart';

import '../../core/formatters.dart';
import '../../domain/app_settings.dart';
import '../theme/lydo_theme.dart';
import 'settings_controller.dart';

/// Aba "Ajustes".
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.controller});
  final SettingsController controller;

  Future<void> _pick<T>(
    BuildContext context, {
    required String title,
    required List<T> options,
    required T current,
    required String Function(T) label,
    required void Function(T) onPick,
  }) async {
    final picked = await showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(title, style: Theme.of(sheet).textTheme.titleLarge),
            ),
            for (final o in options)
              ListTile(
                title: Text(label(o)),
                trailing: o == current ? const Icon(Icons.check, color: LydoColors.primary) : null,
                onTap: () => Navigator.pop(sheet, o),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) onPick(picked);
  }

  Future<void> _showStorage(BuildContext context) async {
    final used = await controller.storageUsed();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Armazenamento'),
        content: Text(used == null
            ? 'Não foi possível medir o espaço usado.'
            : 'Os PDFs da sua biblioteca ocupam ${formatBytes(used)} dentro do Lydo.\n\n'
                'Para liberar espaço, remova documentos pela aba Arquivos (⋮ → Remover).'),
        actions: [TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ValueListenableBuilder<AppSettings>(
        valueListenable: controller.settings,
        builder: (context, s, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: [
            Row(
              children: [
                const LydoLogo(size: 30),
                const SizedBox(width: 12),
                Text('Lydo', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text('Configurações', style: Theme.of(context).textTheme.headlineMedium),
            const _Section('APARÊNCIA'),
            _Group(children: [
              _Tile(
                icon: Icons.palette_outlined,
                title: 'Tema',
                value: s.themeMode.label,
                onTap: () => _pick(
                  context,
                  title: 'Tema',
                  options: AppThemeMode.values,
                  current: s.themeMode,
                  label: (o) => o.label,
                  onPick: (o) => controller.update((c) => c.copyWith(themeMode: o)),
                ),
              ),
              _Tile(
                icon: Icons.text_fields,
                title: 'Tamanho da interface',
                value: s.uiScale.label,
                onTap: () => _pick(
                  context,
                  title: 'Tamanho da interface',
                  options: UiScale.values,
                  current: s.uiScale,
                  label: (o) => o.label,
                  onPick: (o) => controller.update((c) => c.copyWith(uiScale: o)),
                ),
              ),
            ]),
            const _Section('LEITURA'),
            _Group(children: [
              _Tile(
                icon: Icons.menu_book_outlined,
                title: 'Modo de rolagem',
                value: s.scrollMode.label,
                onTap: () => _pick(
                  context,
                  title: 'Modo de rolagem',
                  options: ScrollMode.values,
                  current: s.scrollMode,
                  label: (o) => o.label,
                  onPick: (o) => controller.update((c) => c.copyWith(scrollMode: o)),
                ),
              ),
              _SwitchTile(
                icon: Icons.bookmark_border,
                title: 'Retomar última página',
                value: s.resumeLastPage,
                onChanged: (v) => controller.update((c) => c.copyWith(resumeLastPage: v)),
              ),
              _SwitchTile(
                icon: Icons.stay_current_portrait_outlined,
                title: 'Manter tela ligada',
                value: s.keepScreenOn,
                onChanged: (v) => controller.update((c) => c.copyWith(keepScreenOn: v)),
              ),
            ]),
            const _Section('PRIVACIDADE E DADOS'),
            _Group(children: [
              _Tile(
                icon: Icons.storage_outlined,
                title: 'Armazenamento',
                onTap: () => _showStorage(context),
              ),
              _Tile(
                icon: Icons.shield_outlined,
                title: 'Seus dados',
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (d) => AlertDialog(
                    title: const Text('Seus dados'),
                    content: const Text(
                      'Tudo fica só no seu celular: os PDFs, o progresso de leitura e os ajustes. '
                      'O Lydo não envia nada para a internet.',
                    ),
                    actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('OK'))],
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 24),
            Center(child: Text('Lydo 0.2', style: Theme.of(context).textTheme.bodySmall)),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 28, 12, 10),
        child: Text(text, style: Theme.of(context).textTheme.labelSmall),
      );
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(indent: 16, endIndent: 16),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, this.value, required this.onTap});
  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 60,
      leading: Icon(icon),
      title: Text(title, style: Theme.of(context).textTheme.bodyLarge),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null) Text(value!, style: TextStyle(color: context.mutedText, fontSize: 15)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: context.mutedText),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({required this.icon, required this.title, required this.value, required this.onChanged});
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(title, style: Theme.of(context).textTheme.bodyLarge),
      value: value,
      onChanged: onChanged,
      minTileHeight: 60,
    );
  }
}
