enum AppThemeMode { system, light, dark }

enum UiScale { small, normal, large }

enum ScrollMode { continuous, horizontal }

extension AppThemeModeLabel on AppThemeMode {
  String get label => switch (this) {
        AppThemeMode.system => 'Sistema',
        AppThemeMode.light => 'Claro',
        AppThemeMode.dark => 'Escuro',
      };
}

extension UiScaleInfo on UiScale {
  String get label => switch (this) {
        UiScale.small => 'Compacto',
        UiScale.normal => 'Padrão',
        UiScale.large => 'Grande',
      };

  double get factor => switch (this) {
        UiScale.small => 0.9,
        UiScale.normal => 1.0,
        UiScale.large => 1.15,
      };
}

extension ScrollModeLabel on ScrollMode {
  String get label => switch (this) {
        ScrollMode.continuous => 'Contínua',
        ScrollMode.horizontal => 'Horizontal',
      };
}

/// Preferências do usuário (tela Ajustes).
class AppSettings {
  const AppSettings({
    this.themeMode = AppThemeMode.system,
    this.uiScale = UiScale.normal,
    this.scrollMode = ScrollMode.continuous,
    this.resumeLastPage = true,
    this.keepScreenOn = false,
    this.gridView = false,
  });

  final AppThemeMode themeMode;
  final UiScale uiScale;
  final ScrollMode scrollMode;
  final bool resumeLastPage;
  final bool keepScreenOn;

  /// Biblioteca em grade (true) ou lista (false).
  final bool gridView;

  AppSettings copyWith({
    AppThemeMode? themeMode,
    UiScale? uiScale,
    ScrollMode? scrollMode,
    bool? resumeLastPage,
    bool? keepScreenOn,
    bool? gridView,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      uiScale: uiScale ?? this.uiScale,
      scrollMode: scrollMode ?? this.scrollMode,
      resumeLastPage: resumeLastPage ?? this.resumeLastPage,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      gridView: gridView ?? this.gridView,
    );
  }

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode.name,
        'uiScale': uiScale.name,
        'scrollMode': scrollMode.name,
        'resumeLastPage': resumeLastPage,
        'keepScreenOn': keepScreenOn,
        'gridView': gridView,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    T pick<T extends Enum>(List<T> values, Object? name, T fallback) =>
        values.where((v) => v.name == name).firstOrNull ?? fallback;
    return AppSettings(
      themeMode: pick(AppThemeMode.values, json['themeMode'], AppThemeMode.system),
      uiScale: pick(UiScale.values, json['uiScale'], UiScale.normal),
      scrollMode: pick(ScrollMode.values, json['scrollMode'], ScrollMode.continuous),
      resumeLastPage: json['resumeLastPage'] as bool? ?? true,
      keepScreenOn: json['keepScreenOn'] as bool? ?? false,
      gridView: json['gridView'] as bool? ?? false,
    );
  }
}
