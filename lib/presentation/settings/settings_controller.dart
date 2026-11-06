import 'package:flutter/foundation.dart';

import '../../core/result.dart';
import '../../domain/app_settings.dart';
import '../../domain/settings_repository.dart';

/// Fonte única das preferências: o app inteiro escuta este notifier
/// (tema, escala da interface, modo de rolagem do leitor...).
class SettingsController {
  SettingsController(this._repository);

  final SettingsRepository _repository;
  final settings = ValueNotifier(const AppSettings());

  Future<void> load() async {
    if (await _repository.load() case Ok(:final value)) settings.value = value;
  }

  Future<void> update(AppSettings Function(AppSettings current) change) async {
    settings.value = change(settings.value);
    await _repository.save(settings.value);
  }

  /// Botão de sol/lua da tela inicial: alterna entre claro e escuro,
  /// partindo do brilho que está na tela agora.
  Future<void> toggleDark({required bool currentlyDark}) =>
      update((s) => s.copyWith(themeMode: currentlyDark ? AppThemeMode.light : AppThemeMode.dark));

  Future<int?> storageUsed() async => switch (await _repository.storageUsed()) {
        Ok(:final value) => value,
        Err() => null,
      };

  void dispose() => settings.dispose();
}
