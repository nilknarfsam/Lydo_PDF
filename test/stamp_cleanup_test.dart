import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_reader/core/result.dart';
import 'package:pdf_reader/data/stamp_cleanup_service.dart';

void main() {
  late Directory base;
  late StampCleanupService service;

  setUp(() async {
    base = await Directory.systemTemp.createTemp('lydo_stamps_');
    service = StampCleanupService(baseDir: () async => base);
    await Directory('${base.path}/stamps').create();
    await Directory('${base.path}/annotations').create();
  });

  tearDown(() => base.delete(recursive: true));

  File stamp(String name) => File('${base.path}/stamps/$name')..writeAsBytesSync([1, 2, 3]);

  void annotations(String id, List<String?> assetPaths) {
    File('${base.path}/annotations/$id.json').writeAsStringSync(jsonEncode([
      for (final p in assetPaths) {'type': 'stamp', 'assetPath': ?p},
    ]));
  }

  test('apaga só as imagens que nenhuma anotação usa', () async {
    final used = stamp('1.png');
    final usedOtherPath = stamp('2.jpg');
    final orphan = stamp('3.png');
    annotations('a', [used.path, null]);
    // Caminho antigo de outra instalação: vale pelo nome do arquivo.
    annotations('b', ['/data/user/0/old/app_flutter/stamps/2.jpg']);

    final result = await service.sweep();

    expect((result as Ok<int>).value, 1);
    expect(used.existsSync(), isTrue);
    expect(usedOtherPath.existsSync(), isTrue);
    expect(orphan.existsSync(), isFalse);
  });

  test('com JSON ilegível não apaga nada', () async {
    final orphan = stamp('3.png');
    File('${base.path}/annotations/x.json').writeAsStringSync('{quebrado');

    final result = await service.sweep();

    expect(result, isA<Err<int>>());
    expect(orphan.existsSync(), isTrue);
  });

  test('sem pasta stamps não faz nada', () async {
    await Directory('${base.path}/stamps').delete(recursive: true);
    expect((await service.sweep() as Ok<int>).value, 0);
  });
}
