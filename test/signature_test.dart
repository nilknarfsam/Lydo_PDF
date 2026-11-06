import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_reader/core/result.dart';
import 'package:pdf_reader/data/file_signature_repository.dart';
import 'package:pdf_reader/presentation/edit/signature_pad_controller.dart';

T _unwrap<T>(Result<T> result) => switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => throw TestFailure(failure.message),
    };

void main() {
  group('FileSignatureRepository', () {
    late Directory tempDir;
    late FileSignatureRepository repo;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('signature_test');
      repo = FileSignatureRepository(baseDir: () async => tempDir);
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('save, list e delete', () async {
      final bytes = Uint8List.fromList([137, 80, 78, 71]);
      final saved = _unwrap(await repo.save(bytes));
      expect(File(saved.path).existsSync(), isTrue);
      expect(File(saved.path).readAsBytesSync(), bytes);

      final listed = _unwrap(await repo.list());
      expect(listed.map((s) => s.id), [saved.id]);

      _unwrap(await repo.delete(saved.id));
      expect(_unwrap(await repo.list()), isEmpty);
      expect(File(saved.path).existsSync(), isFalse);
    });

    test('list devolve a mais recente primeiro', () async {
      final older = _unwrap(await repo.save(Uint8List.fromList([1])));
      final newer = _unwrap(await repo.save(Uint8List.fromList([2])));
      // Garante datas de modificação distintas, independente da velocidade do teste.
      File(older.path).setLastModifiedSync(DateTime(2020));

      final listed = _unwrap(await repo.list());
      expect(listed.map((s) => s.id), [newer.id, older.id]);
    });

    test('delete de id inexistente não é erro', () async {
      final result = await repo.delete('nao-existe');
      expect(result, isA<Ok<void>>());
    });
  });

  group('SignaturePadController', () {
    late SignaturePadController controller;

    setUp(() => controller = SignaturePadController());
    tearDown(() => controller.dispose());

    test('começa vazio', () {
      expect(controller.isEmpty.value, isTrue);
      expect(controller.strokes.value, isEmpty);
    });

    test('start, extend e end tiram do estado vazio e mantêm os pontos', () {
      controller.start(const Offset(0, 0));
      expect(controller.isEmpty.value, isFalse);

      controller.extend(const Offset(10, 5));
      controller.extend(const Offset(20, 10));
      controller.end();

      expect(controller.isEmpty.value, isFalse);
      expect(controller.strokes.value, hasLength(1));
      expect(controller.strokes.value.first, hasLength(3));
    });

    test('extend sem start é ignorado', () {
      controller.extend(const Offset(10, 10));
      expect(controller.isEmpty.value, isTrue);
    });

    test('undo remove o último traço e volta a vazio', () {
      controller.start(const Offset(0, 0));
      controller.extend(const Offset(5, 5));
      controller.end();
      controller.start(const Offset(30, 30));
      controller.end();
      expect(controller.strokes.value, hasLength(2));

      controller.undo();
      expect(controller.strokes.value, hasLength(1));
      expect(controller.isEmpty.value, isFalse);

      controller.undo();
      expect(controller.strokes.value, isEmpty);
      expect(controller.isEmpty.value, isTrue);

      controller.undo();
      expect(controller.strokes.value, isEmpty);
    });

    test('clear apaga todos os traços', () {
      controller.start(const Offset(0, 0));
      controller.end();
      controller.start(const Offset(1, 1));
      controller.end();

      controller.clear();
      expect(controller.strokes.value, isEmpty);
      expect(controller.isEmpty.value, isTrue);
    });
  });
}
