import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../core/result.dart';

/// Imagem pronta para ir para a página: arquivo dentro do app + proporção.
class StampAsset {
  const StampAsset({required this.path, required this.aspect, this.isSignature = false});
  final String path;

  /// altura / largura
  final double aspect;

  /// Assinatura nasce menor na página que uma foto.
  final bool isSignature;
}

/// Copia imagens para `<docs>/stamps/` (cópia própria de cada uso) e mede a proporção.
class StampImportService {
  /// `Ok(null)` quando o usuário cancela.
  Future<Result<StampAsset?>> pickImage() async {
    File? file;
    try {
      final picked = await FilePicker.pickFile(type: FileType.image);
      if (picked == null) return const Result.ok(null);
      file = await _newFile((picked.extension ?? 'jpg').toLowerCase());
      final sink = file.openWrite();
      await sink.addStream(picked.readAsByteStream());
      await sink.close();
      return Result.ok(StampAsset(path: file.path, aspect: await _aspectOf(await file.readAsBytes())));
    } catch (e) {
      await _discard(file);
      return Result.error(AppFailure(FailureKind.importFailed, 'Não foi possível abrir esta imagem.', e));
    }
  }

  /// Usa uma assinatura salva. Faz uma **cópia** em `stamps/`: se a pessoa
  /// apagar a assinatura da lista depois, as já colocadas nos PDFs continuam.
  Future<Result<StampAsset>> fromSignature(String signaturePath) async {
    File? file;
    try {
      final bytes = await File(signaturePath).readAsBytes();
      file = await _newFile('png');
      await file.writeAsBytes(bytes, flush: true);
      return Result.ok(StampAsset(path: file.path, aspect: await _aspectOf(bytes), isSignature: true));
    } catch (e) {
      await _discard(file);
      return Result.error(AppFailure(FailureKind.fileNotFound, 'Não foi possível abrir a assinatura.', e));
    }
  }

  Future<File> _newFile(String ext) async {
    final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/stamps');
    await dir.create(recursive: true);
    return File('${dir.path}/${DateTime.now().microsecondsSinceEpoch}.$ext');
  }

  static Future<void> _discard(File? file) async {
    try {
      if (file != null && await file.exists()) await file.delete();
    } catch (_) {}
  }

  static Future<double> _aspectOf(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final aspect = frame.image.height / frame.image.width;
    frame.image.dispose();
    codec.dispose();
    return aspect;
  }
}
