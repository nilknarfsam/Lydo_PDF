import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../core/result.dart';

/// PDF já copiado para dentro do app.
class ImportedPdf {
  const ImportedPdf({required this.id, required this.name, required this.path, required this.sizeBytes});
  final String id;
  final String name;
  final String path;
  final int sizeBytes;
}

/// Abre o seletor do Android e copia o PDF escolhido para a pasta do app.
///
/// A cópia é necessária porque o Android entrega um link temporário
/// (content://) que pode deixar de funcionar depois que o app fecha.
class PdfImportService {
  static const _fingerprintBytes = 64 * 1024;

  /// `Ok(null)` quando o usuário cancela o seletor.
  Future<Result<ImportedPdf?>> pickAndImport() async {
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      if (picked == null) return const Result.ok(null);

      final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/pdfs');
      await dir.create(recursive: true);

      final temp = File('${dir.path}/.importando_${DateTime.now().microsecondsSinceEpoch}');
      final sink = temp.openWrite();
      await sink.addStream(picked.readAsByteStream());
      await sink.close();

      final id = await fingerprint(temp);
      final target = File('${dir.path}/$id.pdf');
      if (await target.exists()) {
        await temp.delete(); // mesmo PDF já está na biblioteca
      } else {
        await temp.rename(target.path);
      }

      final name = picked.name.toLowerCase().endsWith('.pdf')
          ? picked.name.substring(0, picked.name.length - 4)
          : picked.name;
      return Result.ok(
        ImportedPdf(id: id, name: name, path: target.path, sizeBytes: await target.length()),
      );
    } catch (e) {
      return Result.error(AppFailure(FailureKind.importFailed, 'Não foi possível abrir este PDF.', e));
    }
  }

  /// Impressão digital rápida: FNV-1a dos primeiros 64 KB + tamanho.
  /// Basta para reconhecer o mesmo arquivo sem ler PDFs enormes inteiros.
  static Future<String> fingerprint(File file) async {
    final length = await file.length();
    final raf = await file.open();
    final Uint8List head;
    try {
      head = await raf.read(_fingerprintBytes);
    } finally {
      await raf.close();
    }
    return fingerprintBytes(head, length);
  }

  static String fingerprintBytes(List<int> head, int length) {
    var hash = 0xcbf29ce484222325; // FNV-1a 64 bits
    const prime = 0x100000001b3;
    for (final b in head) {
      hash ^= b;
      hash *= prime; // int do Dart nativo tem 64 bits e "dá a volta" sozinho
    }
    final hex = hash.toUnsigned(64).toRadixString(16).padLeft(16, '0');
    return '${hex}_${length.toRadixString(16)}';
  }
}
