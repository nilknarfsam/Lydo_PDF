import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

/// Traços da assinatura, em coordenadas locais da área de desenho.
///
/// A lista externa é sempre uma instância nova a cada mudança (para o
/// ValueNotifier avisar); o último traço é o que está sendo desenhado.
class SignaturePadController {
  final ValueNotifier<List<List<Offset>>> strokes = ValueNotifier(const []);
  final ValueNotifier<bool> isEmpty = ValueNotifier(true);

  List<Offset>? _current;

  void start(Offset point) {
    final stroke = <Offset>[point];
    _current = stroke;
    _publish([...strokes.value, stroke]);
  }

  void extend(Offset point) {
    final current = _current;
    if (current == null) return;
    current.add(point);
    _publish(List.of(strokes.value));
  }

  void end() {
    _current = null;
  }

  void undo() {
    final list = strokes.value;
    if (list.isEmpty) return;
    _current = null;
    _publish(list.sublist(0, list.length - 1));
  }

  void clear() {
    _current = null;
    _publish(const []);
  }

  void _publish(List<List<Offset>> next) {
    strokes.value = next;
    isEmpty.value = next.isEmpty;
  }

  /// Gera um PNG com os traços em fundo transparente, recortado ao redor
  /// dos traços com margem de 8px. Devolve null se não há traços.
  static const _pixelRatio = 3.0;

  Future<Uint8List?> exportPng({
    required Size size,
    double strokeWidth = 3,
    Color color = const Color(0xFF111827),
  }) async {
    final all = strokes.value;
    final points = [for (final s in all) ...s];
    if (points.isEmpty) return null;

    var box = Rect.fromPoints(points.first, points.first);
    for (final p in points) {
      box = box.expandToInclude(Rect.fromPoints(p, p));
    }
    const margin = 8.0;
    final crop = box.inflate(margin).intersect(Offset.zero & size);
    if (crop.isEmpty) return null;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    // 3x a resolução da tela: a assinatura sai nítida no PDF exportado.
    canvas
      ..scale(_pixelRatio)
      ..translate(-crop.left, -crop.top);

    final linePaint = ui.Paint()
      ..color = color
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = ui.StrokeCap.round
      ..strokeJoin = ui.StrokeJoin.round
      ..isAntiAlias = true;
    final dotPaint = ui.Paint()
      ..color = color
      ..isAntiAlias = true;

    for (final stroke in all) {
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, strokeWidth / 2, dotPaint);
        continue;
      }
      final path = ui.Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final p in stroke.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, linePaint);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage((crop.width * _pixelRatio).ceil(), (crop.height * _pixelRatio).ceil());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    return data?.buffer.asUint8List();
  }

  void dispose() {
    strokes.dispose();
    isEmpty.dispose();
  }
}
