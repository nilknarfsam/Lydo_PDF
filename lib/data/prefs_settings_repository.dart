import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/result.dart';
import '../domain/app_settings.dart';
import '../domain/settings_repository.dart';

class PrefsSettingsRepository implements SettingsRepository {
  PrefsSettingsRepository(this._prefs);

  static const _key = 'settings.v1';
  final SharedPreferencesAsync _prefs;

  @override
  Future<Result<AppSettings>> load() async {
    try {
      final raw = await _prefs.getString(_key);
      if (raw == null || raw.isEmpty) return const Result.ok(AppSettings());
      return Result.ok(AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>));
    } catch (e) {
      return Result.error(AppFailure(FailureKind.storage, 'Não foi possível ler os ajustes.', e));
    }
  }

  @override
  Future<Result<void>> save(AppSettings settings) async {
    try {
      await _prefs.setString(_key, jsonEncode(settings.toJson()));
      return const Result.ok(null);
    } catch (e) {
      return Result.error(AppFailure(FailureKind.storage, 'Não foi possível salvar os ajustes.', e));
    }
  }

  @override
  Future<Result<int>> storageUsed() async {
    try {
      final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/pdfs');
      if (!await dir.exists()) return const Result.ok(0);
      var total = 0;
      await for (final f in dir.list()) {
        if (f is File) total += await f.length();
      }
      return Result.ok(total);
    } catch (e) {
      return Result.error(AppFailure(FailureKind.storage, 'Não foi possível medir o armazenamento.', e));
    }
  }
}
