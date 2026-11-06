import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/result.dart';
import '../domain/document_entry.dart';
import '../domain/library_repository.dart';

/// Biblioteca salva em SharedPreferences como uma lista JSON.
class PrefsLibraryRepository implements LibraryRepository {
  PrefsLibraryRepository(this._prefs);

  static const _key = 'library.v1';
  final SharedPreferencesAsync _prefs;

  Future<Map<String, DocumentEntry>> _read() async {
    final raw = await _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    final list = jsonDecode(raw) as List<dynamic>;
    final entries = list.map((e) => DocumentEntry.fromJson(e as Map<String, dynamic>));
    return {for (final e in entries) e.id: e};
  }

  Future<void> _write(Map<String, DocumentEntry> map) {
    final json = jsonEncode(map.values.map((e) => e.toJson()).toList());
    return _prefs.setString(_key, json);
  }

  @override
  Future<Result<List<DocumentEntry>>> loadAll() async {
    try {
      final list = (await _read()).values.toList()
        ..sort((a, b) => b.lastOpenedAt.compareTo(a.lastOpenedAt));
      return Result.ok(list);
    } catch (e) {
      return Result.error(AppFailure(FailureKind.storage, 'Não foi possível ler a biblioteca.', e));
    }
  }

  @override
  Future<Result<DocumentEntry?>> findById(String id) async {
    try {
      return Result.ok((await _read())[id]);
    } catch (e) {
      return Result.error(AppFailure(FailureKind.storage, 'Não foi possível ler a biblioteca.', e));
    }
  }

  @override
  Future<Result<void>> save(DocumentEntry entry) async {
    try {
      final map = await _read();
      map[entry.id] = entry;
      await _write(map);
      return const Result.ok(null);
    } catch (e) {
      return Result.error(AppFailure(FailureKind.storage, 'Não foi possível salvar o progresso.', e));
    }
  }

  @override
  Future<Result<void>> remove(String id) async {
    try {
      final map = await _read();
      final entry = map.remove(id);
      await _write(map);
      if (entry != null) {
        final file = File(entry.path);
        if (await file.exists()) await file.delete();
      }
      return const Result.ok(null);
    } catch (e) {
      return Result.error(AppFailure(FailureKind.storage, 'Não foi possível remover o documento.', e));
    }
  }
}
