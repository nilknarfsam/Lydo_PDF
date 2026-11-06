import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_reader/core/result.dart';
import 'package:pdf_reader/data/json_annotation_repository.dart';
import 'package:pdf_reader/domain/annotation.dart';

/// Duas linhas de texto: "abc" (y 700–712) e "de" (y 680–692), letras de 10pt.
final _chars = [
  const ARect(100, 712, 110, 700),
  const ARect(110, 712, 120, 700),
  const ARect(120, 712, 130, 700),
  const ARect(130, 712, 130, 712), // espaço sem caixa
  const ARect(100, 692, 110, 680),
  const ARect(110, 692, 120, 680),
];

Annotation _ink(List<APoint> pts) => Annotation(
      id: 'i',
      type: AnnotationType.ink,
      page: 1,
      color: 0xFF000000,
      createdAt: DateTime(2026),
      width: 2,
      points: pts,
    );

void main() {
  group('highlightRects', () {
    test('arrastar numa linha marca só as letras daquela linha', () {
      final r = highlightRects(
        charRects: _chars,
        start: const APoint(101, 705),
        end: const APoint(119, 705),
        fallbackHeight: 14,
      );
      expect(r, hasLength(1));
      expect([r[0].left, r[0].right, r[0].top, r[0].bottom], [100, 120, 712, 700]);
    });

    test('arrastar entre linhas gera um retângulo por linha', () {
      final r = highlightRects(
        charRects: _chars,
        start: const APoint(125, 705),
        end: const APoint(105, 685),
        fallbackHeight: 14,
      );
      expect(r, hasLength(2));
      expect(r[0].left, 120); // do "c"…
      expect(r[1].right, 110); // …até o "d"
    });

    test('página sem texto (escaneada) vira faixa reta', () {
      final r = highlightRects(
        charRects: const [],
        start: const APoint(50, 300),
        end: const APoint(10, 302),
        fallbackHeight: 14,
      );
      expect(r, hasLength(1));
      expect([r[0].left, r[0].right, r[0].top, r[0].bottom], [10, 50, 307, 293]);
    });
  });

  test('borracha acerta perto do traço e erra longe dele', () {
    final a = _ink(const [APoint(0, 0), APoint(100, 0)]);
    expect(a.hitTest(const APoint(50, 5)), isTrue);
    expect(a.hitTest(const APoint(50, 40)), isFalse);
  });

  test('anotação ida e volta em JSON', () {
    final a = Annotation(
      id: 'x',
      type: AnnotationType.highlight,
      page: 3,
      color: 0xFFFFD43B,
      createdAt: DateTime(2026, 11, 6),
      rects: const [ARect(1, 4, 3, 2)],
      text: 'oi',
    );
    final b = Annotation.fromJson(a.toJson());
    expect(b.type, AnnotationType.highlight);
    expect(b.page, 3);
    expect(b.rects.single.top, 4);
    expect(b.text, 'oi');
  });

  test('repositório JSON salva, carrega e apaga por documento', () async {
    final dir = await Directory.systemTemp.createTemp('lydo_test');
    addTearDown(() => dir.delete(recursive: true));
    final repo = JsonAnnotationRepository(baseDir: () async => dir);

    expect((await repo.load('doc') as Ok<List<Annotation>>).value, isEmpty);
    await repo.save('doc', [_ink(const [APoint(1, 2)])]);
    expect((await repo.load('doc') as Ok<List<Annotation>>).value.single.points.single.y, 2);
    await repo.delete('doc');
    expect((await repo.load('doc') as Ok<List<Annotation>>).value, isEmpty);
  });
}
