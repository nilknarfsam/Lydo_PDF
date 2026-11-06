import 'package:flutter/foundation.dart';

import '../../core/result.dart';
import '../../data/pdf_import_service.dart';
import '../../domain/annotation_repository.dart';
import '../../domain/document_entry.dart';
import '../../domain/library_repository.dart';

enum LibraryFilter { all, recent, favorites }

class HomeState {
  const HomeState({
    this.documents = const [],
    this.loading = true,
    this.error,
    this.query = '',
    this.filter = LibraryFilter.all,
  });

  /// Todos os documentos, do aberto mais recentemente para o mais antigo.
  final List<DocumentEntry> documents;
  final bool loading;
  final String? error;
  final String query;
  final LibraryFilter filter;

  bool get isFiltering => query.isNotEmpty || filter != LibraryFilter.all;

  /// Último PDF aberto que já foi começado e ainda não terminou.
  DocumentEntry? get continueReading => isFiltering
      ? null
      : documents.where((d) => d.hasStarted && d.lastPage < d.pageCount).firstOrNull ??
          documents.where((d) => d.hasStarted).firstOrNull;

  /// Lista exibida, aplicando busca e filtro.
  List<DocumentEntry> get visible {
    final q = _normalize(query);
    Iterable<DocumentEntry> list = documents;
    if (q.isNotEmpty) list = list.where((d) => _normalize(d.name).contains(q));
    switch (filter) {
      case LibraryFilter.all:
        return list.toList();
      case LibraryFilter.recent:
        final limit = DateTime.now().subtract(const Duration(days: 7));
        return list.where((d) => d.lastOpenedAt.isAfter(limit)).toList();
      case LibraryFilter.favorites:
        return list.where((d) => d.favorite).toList();
    }
  }

  HomeState copyWith({
    List<DocumentEntry>? documents,
    bool? loading,
    String? error,
    String? query,
    LibraryFilter? filter,
  }) {
    return HomeState(
      documents: documents ?? this.documents,
      loading: loading ?? this.loading,
      error: error,
      query: query ?? this.query,
      filter: filter ?? this.filter,
    );
  }
}

/// Busca sem diferenciar maiúsculas e acentos ("manual" acha "Manual Técnico").
String _normalize(String s) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const to = 'aaaaaeeeeiiiiooooouuuucn';
  final lower = s.toLowerCase();
  final buffer = StringBuffer();
  for (final ch in lower.split('')) {
    final i = from.indexOf(ch);
    buffer.write(i >= 0 ? to[i] : ch);
  }
  return buffer.toString();
}

/// Tela Arquivos: biblioteca, busca, filtros e importação de PDFs.
class HomeController {
  HomeController({
    required this.repository,
    required this.annotationRepository,
    required PdfImportService importService,
  }) : _import = importService;

  final LibraryRepository repository;
  final AnnotationRepository annotationRepository;
  final PdfImportService _import;
  final state = ValueNotifier(const HomeState());

  Future<void> load() async {
    final result = await repository.loadAll();
    state.value = switch (result) {
      Ok(:final value) => state.value.copyWith(documents: value, loading: false),
      Err(:final failure) => state.value.copyWith(loading: false, error: failure.message),
    };
  }

  void search(String query) => state.value = state.value.copyWith(query: query.trim());
  void setFilter(LibraryFilter filter) => state.value = state.value.copyWith(filter: filter);

  /// Escolhe um PDF e devolve a entrada pronta para abrir.
  /// Se o arquivo já estava na biblioteca, mantém o progresso dele.
  Future<Result<DocumentEntry?>> importPdf() async {
    final imported = await _import.pickAndImport();
    switch (imported) {
      case Err(:final failure):
        return Result.error(failure);
      case Ok(value: null):
        return const Result.ok(null);
      case Ok(:final value?):
        final existing = await repository.findById(value.id);
        final now = DateTime.now();
        final entry = switch (existing) {
          Ok(value: final found?) => found.copyWith(lastOpenedAt: now, sizeBytes: value.sizeBytes),
          _ => DocumentEntry(
              id: value.id,
              name: value.name,
              path: value.path,
              addedAt: now,
              lastOpenedAt: now,
              sizeBytes: value.sizeBytes,
            ),
        };
        final saved = await repository.save(entry);
        if (saved case Err(:final failure)) return Result.error(failure);
        await load();
        return Result.ok(entry);
    }
  }

  Future<void> toggleFavorite(DocumentEntry entry) async {
    await repository.save(entry.copyWith(favorite: !entry.favorite));
    await load();
  }

  Future<void> rename(DocumentEntry entry, String newName) async {
    final name = newName.trim();
    if (name.isEmpty || name == entry.name) return;
    await repository.save(entry.copyWith(name: name));
    await load();
  }

  Future<void> remove(DocumentEntry entry) async {
    await repository.remove(entry.id);
    await annotationRepository.delete(entry.id);
    await load();
  }

  void dispose() => state.dispose();
}
