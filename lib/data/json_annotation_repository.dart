import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../core/result.dart';
import '../domain/annotation.dart';
import '../domain/annotation_repository.dart';

/// Um arquivo JSON por documento em `<documentos do app>/annotations/`.
///
/// Fica fora do SharedPreferences porque traços de caneta podem ter
/// milhares de pontos — o SharedPreferences carrega tudo na memória a cada
/// leitura e não é feito para blocos grandes. Continua sendo JSON local.
class JsonAnnotationRepository implements AnnotationRepository {
  JsonAnnotationRepository({Future<Directory> Function()? baseDir})
      : _baseDir = baseDir ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _baseDir;

  Future<File> _file(String documentId) async {
    final dir = Directory('${(await _baseDir()).path}/annotations');
    await dir.create(recursive: true);
    return File('${dir.path}/$documentId.json');
  }

  @override
  Future<Result<List<Annotation>>> load(String documentId) async {
    try {
      final file = await _file(documentId);
      if (!await file.exists()) return const Result.ok([]);
      final list = jsonDecode(await file.readAsString()) as List<dynamic>;
      return Result.ok([for (final j in list) Annotation.fromJson(j as Map<String, dynamic>)]);
    } catch (e) {
      return Result.error(AppFailure(FailureKind.storage, 'Não foi possível ler as anotações.', e));
    }
  }

  @override
  Future<Result<void>> save(String documentId, List<Annotation> annotations) async {
    try {
      final file = await _file(documentId);
      // Grava num temporário e renomeia: se o app fechar no meio, o arquivo antigo continua íntegro.
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(jsonEncode(annotations.map((a) => a.toJson()).toList()), flush: true);
      await temp.rename(file.path);
      return const Result.ok(null);
    } catch (e) {
      return Result.error(AppFailure(FailureKind.storage, 'Não foi possível salvar as anotações.', e));
    }
  }

  @override
  Future<Result<void>> delete(String documentId) async {
    try {
      final file = await _file(documentId);
      if (await file.exists()) await file.delete();
      return const Result.ok(null);
    } catch (e) {
      return Result.error(AppFailure(FailureKind.storage, 'Não foi possível apagar as anotações.', e));
    }
  }
}
