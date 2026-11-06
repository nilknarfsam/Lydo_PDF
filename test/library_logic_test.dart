import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_reader/core/formatters.dart';
import 'package:pdf_reader/domain/app_settings.dart';
import 'package:pdf_reader/domain/document_entry.dart';
import 'package:pdf_reader/presentation/home/home_controller.dart';

DocumentEntry _doc(String name, {int page = 1, int pages = 0, bool fav = false, int daysAgo = 0}) =>
    DocumentEntry(
      id: name,
      name: name,
      path: '/x/$name.pdf',
      addedAt: DateTime(2026, 1, 1),
      lastOpenedAt: DateTime.now().subtract(Duration(days: daysAgo)),
      lastPage: page,
      pageCount: pages,
      favorite: fav,
    );

void main() {
  group('formatadores', () {
    test('tamanho de arquivo', () {
      expect(formatBytes(0), '—');
      expect(formatBytes(830 * 1024), '830 KB');
      expect(formatBytes((4.2 * 1024 * 1024).round()), '4,2 MB');
    });

    test('dia relativo', () {
      final now = DateTime(2026, 11, 6, 10);
      expect(formatRelativeDay(DateTime(2026, 11, 6, 1), now: now), 'Hoje');
      expect(formatRelativeDay(DateTime(2026, 11, 5, 23), now: now), 'Ontem');
      expect(formatRelativeDay(DateTime(2026, 11, 2), now: now), 'Há 4 dias');
      expect(formatRelativeDay(DateTime(2026, 3, 12), now: now), '12/03/2026');
    });
  });

  group('HomeState', () {
    final docs = [
      _doc('Manual Técnico', page: 8, pages: 24),
      _doc('Proposta', fav: true, daysAgo: 1),
      _doc('Notas antigas', page: 10, pages: 10, daysAgo: 30),
    ];

    test('busca ignora maiúsculas e acentos', () {
      final s = HomeState(documents: docs, loading: false, query: 'manual tecnico');
      expect(s.visible.map((d) => d.name), ['Manual Técnico']);
    });

    test('filtros de recentes e favoritos', () {
      expect(
        HomeState(documents: docs, filter: LibraryFilter.recent).visible.map((d) => d.name),
        ['Manual Técnico', 'Proposta'],
      );
      expect(
        HomeState(documents: docs, filter: LibraryFilter.favorites).visible.map((d) => d.name),
        ['Proposta'],
      );
    });

    test('"Continuar lendo" pula o que não começou e prefere o não terminado', () {
      expect(HomeState(documents: docs).continueReading?.name, 'Manual Técnico');
      expect(HomeState(documents: docs, query: 'x').continueReading, isNull);
    });
  });

  test('AppSettings ida e volta em JSON e valores desconhecidos', () {
    const s = AppSettings(
      themeMode: AppThemeMode.dark,
      uiScale: UiScale.large,
      scrollMode: ScrollMode.horizontal,
      resumeLastPage: false,
      keepScreenOn: true,
      gridView: true,
    );
    final back = AppSettings.fromJson(s.toJson());
    expect(back.themeMode, AppThemeMode.dark);
    expect(back.uiScale, UiScale.large);
    expect(back.scrollMode, ScrollMode.horizontal);
    expect(back.resumeLastPage, isFalse);
    expect(back.keepScreenOn, isTrue);
    expect(back.gridView, isTrue);
    expect(AppSettings.fromJson({'themeMode': 'roxo'}).themeMode, AppThemeMode.system);
  });
}
