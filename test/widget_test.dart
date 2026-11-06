import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_reader/core/result.dart';
import 'package:pdf_reader/data/pdf_import_service.dart';
import 'package:pdf_reader/data/prefs_library_repository.dart';
import 'package:pdf_reader/domain/document_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

DocumentEntry _entry(String id, {DateTime? opened, int page = 1}) => DocumentEntry(
      id: id,
      name: 'Livro $id',
      path: '/nao/existe/$id.pdf',
      addedAt: DateTime(2026, 1, 1),
      lastOpenedAt: opened ?? DateTime(2026, 1, 1),
      pageCount: 200,
      lastPage: page,
      viewMatrix: List.generate(16, (i) => i.toDouble()),
    );

void main() {
  test('DocumentEntry ida e volta em JSON mantém a posição de leitura', () {
    final e = _entry('a', page: 42);
    final back = DocumentEntry.fromJson(e.toJson());
    expect(back.lastPage, 42);
    expect(back.pageCount, 200);
    expect(back.viewMatrix, e.viewMatrix);
    expect(back.progress, closeTo(0.21, 0.001));
  });

  test('impressão digital é estável e diferencia conteúdo e tamanho', () {
    final a = PdfImportService.fingerprintBytes([1, 2, 3], 3);
    expect(PdfImportService.fingerprintBytes([1, 2, 3], 3), a);
    expect(PdfImportService.fingerprintBytes([1, 2, 4], 3), isNot(a));
    expect(PdfImportService.fingerprintBytes([1, 2, 3], 9), isNot(a));
  });

  group('PrefsLibraryRepository', () {
    late PrefsLibraryRepository repo;

    setUp(() {
      SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
      repo = PrefsLibraryRepository(SharedPreferencesAsync());
    });

    test('salva, atualiza e lista do mais recente para o mais antigo', () async {
      await repo.save(_entry('velho', opened: DateTime(2026, 1, 1)));
      await repo.save(_entry('novo', opened: DateTime(2026, 5, 1)));
      await repo.save(_entry('velho', opened: DateTime(2026, 1, 1), page: 77));

      final result = await repo.loadAll();
      final list = (result as Ok<List<DocumentEntry>>).value;
      expect(list.map((e) => e.id), ['novo', 'velho']);
      expect(list.last.lastPage, 77);
    });

    test('remove tira a entrada da biblioteca', () async {
      await repo.save(_entry('x'));
      await repo.remove('x');
      final found = await repo.findById('x');
      expect((found as Ok<DocumentEntry?>).value, isNull);
    });
  });
}
