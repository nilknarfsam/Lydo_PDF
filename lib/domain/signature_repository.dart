import 'dart:typed_data';

import '../core/result.dart';

/// Uma assinatura desenhada e salva como PNG (fundo transparente).
class SavedSignature {
  const SavedSignature({required this.id, required this.path, required this.createdAt});

  final String id;
  final String path;
  final DateTime createdAt;
}

/// Contrato do armazenamento de assinaturas.
abstract interface class SignatureRepository {
  /// Todas as assinaturas, da mais recente para a mais antiga.
  Future<Result<List<SavedSignature>>> list();

  Future<Result<SavedSignature>> save(Uint8List pngBytes);

  Future<Result<void>> delete(String id);
}
