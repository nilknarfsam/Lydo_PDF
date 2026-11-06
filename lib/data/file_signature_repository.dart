import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../core/result.dart';
import '../domain/signature_repository.dart';

/// Um PNG por assinatura em `<documentos do app>/signatures/<id>.png`.
///
/// O id é o instante de criação (microsegundos desde a época), e a data
/// de criação é a data de modificação do arquivo.
class FileSignatureRepository implements SignatureRepository {
  FileSignatureRepository({Future<Directory> Function()? baseDir})
      : _baseDir = baseDir ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _baseDir;

  Future<Directory> _dir() async {
    final dir = Directory('${(await _baseDir()).path}/signatures');
    await dir.create(recursive: true);
    return dir;
  }

  @override
  Future<Result<List<SavedSignature>>> list() async {
    try {
      final dir = await _dir();
      final entries = await dir.list().toList();
      final result = <SavedSignature>[];
      for (final entry in entries) {
        if (entry is! File || !entry.path.endsWith('.png')) continue;
        final name = entry.path.split(RegExp(r'[\\/]')).last;
        final id = name.substring(0, name.length - '.png'.length);
        final stat = await entry.stat();
        result.add(SavedSignature(id: id, path: entry.path, createdAt: stat.modified));
      }
      result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return Result.ok(result);
    } catch (e) {
      return Result.error(AppFailure(FailureKind.storage, 'Não foi possível carregar as assinaturas.', e));
    }
  }

  @override
  Future<Result<SavedSignature>> save(Uint8List pngBytes) async {
    try {
      final dir = await _dir();
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      final file = File('${dir.path}/$id.png');
      // Grava num temporário e renomeia: um PNG pela metade nunca fica com o nome final.
      final temp = File('${file.path}.tmp');
      await temp.writeAsBytes(pngBytes, flush: true);
      await temp.rename(file.path);
      final stat = await file.stat();
      return Result.ok(SavedSignature(id: id, path: file.path, createdAt: stat.modified));
    } catch (e) {
      return Result.error(AppFailure(FailureKind.storage, 'Não foi possível salvar a assinatura.', e));
    }
  }

  @override
  Future<Result<void>> delete(String id) async {
    try {
      final dir = await _dir();
      final file = File('${dir.path}/$id.png');
      if (await file.exists()) await file.delete();
      return const Result.ok(null);
    } catch (e) {
      return Result.error(AppFailure(FailureKind.storage, 'Não foi possível apagar a assinatura.', e));
    }
  }
}
