import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../core/result.dart';

/// Apaga de `<docs>/stamps/` as imagens que nenhuma anotação usa mais
/// (imagem/assinatura apagada da página, PDF removido da biblioteca).
///
/// Roda fora do leitor (ao abrir o app e ao remover um PDF), porque o leitor
/// aberto pode ter na pilha de desfazer uma imagem que ainda não está no JSON.
class StampCleanupService {
  StampCleanupService({Future<Directory> Function()? baseDir})
      : _baseDir = baseDir ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _baseDir;

  /// Devolve quantos arquivos foram apagados. Se algum JSON de anotações não
  /// puder ser lido, não apaga nada (melhor sobrar arquivo do que sumir imagem).
  Future<Result<int>> sweep() async {
    try {
      final base = (await _baseDir()).path;
      final stamps = Directory('$base/stamps');
      if (!await stamps.exists()) return const Result.ok(0);

      final used = <String>{};
      final annotations = Directory('$base/annotations');
      if (await annotations.exists()) {
        await for (final entity in annotations.list()) {
          if (entity is! File || !entity.path.endsWith('.json')) continue;
          final list = jsonDecode(await entity.readAsString()) as List<dynamic>;
          for (final item in list) {
            final path = (item as Map<String, dynamic>)['assetPath'];
            if (path is String) used.add(_name(path));
          }
        }
      }

      var deleted = 0;
      await for (final entity in stamps.list()) {
        if (entity is File && !used.contains(_name(entity.path))) {
          await entity.delete();
          deleted++;
        }
      }
      return Result.ok(deleted);
    } catch (e) {
      return Result.error(AppFailure(FailureKind.storage, 'Não foi possível limpar as imagens sem uso.', e));
    }
  }

  /// Compara pelo nome do arquivo: o caminho absoluto pode mudar entre instalações.
  static String _name(String path) => path.split(RegExp(r'[\\/]')).last;
}
