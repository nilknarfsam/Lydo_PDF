import '../core/result.dart';
import 'document_entry.dart';

/// Contrato da biblioteca de PDFs. A UI só conhece esta interface.
abstract interface class LibraryRepository {
  /// Todos os documentos, do aberto mais recentemente para o mais antigo.
  Future<Result<List<DocumentEntry>>> loadAll();

  Future<Result<DocumentEntry?>> findById(String id);

  /// Grava (insere ou substitui) uma entrada.
  Future<Result<void>> save(DocumentEntry entry);

  /// Remove da biblioteca e apaga a cópia local do PDF.
  Future<Result<void>> remove(String id);
}
