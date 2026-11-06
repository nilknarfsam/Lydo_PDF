import 'package:material_ui/material_ui.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/json_annotation_repository.dart';
import 'data/pdf_import_service.dart';
import 'data/prefs_library_repository.dart';
import 'data/prefs_settings_repository.dart';
import 'domain/app_settings.dart';
import 'presentation/home/home_controller.dart';
import 'presentation/settings/settings_controller.dart';
import 'presentation/shell/app_shell.dart';
import 'presentation/theme/lydo_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  pdfrxFlutterInitialize();

  final prefs = SharedPreferencesAsync();
  final settings = SettingsController(PrefsSettingsRepository(prefs));
  await settings.load(); // tema certo já no primeiro quadro, sem "piscar"

  final home = HomeController(
    repository: PrefsLibraryRepository(prefs),
    annotationRepository: JsonAnnotationRepository(),
    importService: PdfImportService(),
  );
  runApp(LydoApp(home: home, settings: settings));
}

class LydoApp extends StatelessWidget {
  const LydoApp({super.key, required this.home, required this.settings});
  final HomeController home;
  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppSettings>(
      valueListenable: settings.settings,
      builder: (context, s, _) => MaterialApp(
        title: 'Lydo',
        debugShowCheckedModeBanner: false,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('pt', 'BR'), Locale('en')],
        theme: LydoTheme.light(),
        darkTheme: LydoTheme.dark(),
        themeMode: switch (s.themeMode) {
          AppThemeMode.system => ThemeMode.system,
          AppThemeMode.light => ThemeMode.light,
          AppThemeMode.dark => ThemeMode.dark,
        },
        builder: (context, child) {
          // "Tamanho da interface" multiplica a escala de texto do sistema.
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              textScaler: TextScaler.linear(media.textScaler.scale(1) * s.uiScale.factor),
            ),
            child: child!,
          );
        },
        home: AppShell(home: home, settings: settings),
      ),
    );
  }
}
