import 'package:material_ui/material_ui.dart';

import '../home/home_controller.dart';
import '../home/home_page.dart';
import '../settings/settings_controller.dart';
import '../settings/settings_page.dart';
import '../tools/tools_page.dart';

/// Estrutura principal com a barra inferior: Arquivos, Ferramentas, Ajustes.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.home, required this.settings});
  final HomeController home;
  final SettingsController settings;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _tab = ValueNotifier(0);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _tab,
      builder: (context, tab, _) => PopScope(
        // Voltar em Ferramentas/Ajustes leva para Arquivos antes de sair do app.
        canPop: tab == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _tab.value = 0;
        },
        child: Scaffold(
          body: IndexedStack(
            index: tab,
            children: [
              HomePage(controller: widget.home, settings: widget.settings),
              const ToolsPage(),
              SettingsPage(controller: widget.settings),
            ],
          ),
          bottomNavigationBar: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Theme.of(context).dividerTheme.color!)),
            ),
            child: NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (i) => _tab.value = i,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.folder_outlined),
                  selectedIcon: Icon(Icons.folder),
                  label: 'Arquivos',
                ),
                NavigationDestination(
                  icon: Icon(Icons.grid_view_outlined),
                  selectedIcon: Icon(Icons.grid_view_rounded),
                  label: 'Ferramentas',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'Ajustes',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
