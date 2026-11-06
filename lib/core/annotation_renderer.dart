import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:pdfrx/pdfrx.dart';

import '../domain/annotation.dart';

/// Desenha anotações de uma página dentro de [pageRect] (a página como
/// aparece, já girada). Usado pela tela e pela exportação, para que o PDF
/// salvo fique igual ao que a pessoa viu.
///
/// [images]: imagens/assinaturas já decodificadas, por caminho do arquivo.
/// [includeTextAndNotes]: na tela, texto e notas são widgets tocáveis, então
/// ficam de fora; na exportação são desenhados aqui.
void paintAnnotations(
  Canvas canvas, {
  required Rect pageRect,
  required PdfPage page,
  required Iterable<Annotation> annotations,
  Map<String, ui.Image> images = const {},
  bool includeTextAndNotes = false,
  bool includeHighlights = true,
}) {
  final scale = pageRect.width / page.width;
  Offset pt(APoint p) => PdfPoint(p.x, p.y).toOffsetInDocument(page: page, pageRect: pageRect);
  Rect rect(ARect r) =>
      PdfRect(r.left, r.top, r.right, r.bottom).toRectInDocument(page: page, pageRect: pageRect);

  for (final a in annotations) {
    switch (a.type) {
      case AnnotationType.highlight:
        if (!includeHighlights) continue;
        final paint = Paint()
          ..color = Color(a.color).withValues(alpha: 0.45)
          ..blendMode = BlendMode.multiply;
        for (final r in a.rects) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect(r).inflate(scale), Radius.circular(2 * scale)),
            paint,
          );
        }
      case AnnotationType.ink:
        final paint = Paint()
          ..color = Color(a.color)
          ..style = PaintingStyle.stroke
          ..strokeWidth = a.width * scale
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        if (a.points.length == 1) {
          canvas.drawCircle(pt(a.points.first), a.width * scale / 2, paint..style = PaintingStyle.fill);
          continue;
        }
        final first = pt(a.points.first);
        final path = Path()..moveTo(first.dx, first.dy);
        for (final p in a.points.skip(1)) {
          final o = pt(p);
          path.lineTo(o.dx, o.dy);
        }
        canvas.drawPath(path, paint);
      case AnnotationType.image:
        final img = images[a.assetPath];
        if (img == null || a.rects.isEmpty) continue;
        final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
        final dst = rect(a.rects.first);
        final paint = Paint()..filterQuality = FilterQuality.medium;
        // Quanto a página girou desde que a imagem foi colocada.
        final delta = (page.rotation.index - a.turns) % 4;
        if (delta == 0) {
          canvas.drawImageRect(img, src, dst, paint);
          continue;
        }
        final odd = delta.isOdd;
        canvas
          ..save()
          ..translate(dst.center.dx, dst.center.dy)
          ..rotate(delta * math.pi / 2)
          ..drawImageRect(
            img,
            src,
            Rect.fromCenter(
              center: Offset.zero,
              width: odd ? dst.height : dst.width,
              height: odd ? dst.width : dst.height,
            ),
            paint,
          )
          ..restore();
      case AnnotationType.text:
        if (!includeTextAndNotes || a.anchor == null) continue;
        TextPainter(
          text: TextSpan(
            text: a.text,
            style: TextStyle(color: Color(a.color), fontSize: a.width * scale, height: 1.2),
          ),
          textDirection: TextDirection.ltr,
        )
          ..layout()
          ..paint(canvas, pt(a.anchor!));
      case AnnotationType.note:
        if (!includeTextAndNotes || a.anchor == null) continue;
        _paintNote(canvas, pt(a.anchor!), a, scale);
    }
  }
}

/// Nota no PDF exportado: marcador colorido + caixinha com o texto.
void _paintNote(Canvas canvas, Offset at, Annotation a, double scale) {
  final s = 10 * scale;
  final marker = Rect.fromCenter(center: at, width: s * 2, height: s * 2);
  canvas.drawRRect(RRect.fromRectAndRadius(marker, Radius.circular(s / 2)), Paint()..color = Color(a.color));

  final tp = TextPainter(
    text: TextSpan(
      text: a.text,
      style: TextStyle(color: const Color(0xFF1F2937), fontSize: 8 * scale, height: 1.25),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: 140 * scale);
  final pad = 4 * scale;
  final box = Rect.fromLTWH(marker.right + pad, marker.top, tp.width + pad * 2, tp.height + pad * 2);
  canvas.drawRRect(
    RRect.fromRectAndRadius(box, Radius.circular(3 * scale)),
    Paint()..color = Color(a.color).withValues(alpha: 0.92),
  );
  tp.paint(canvas, box.topLeft + Offset(pad, pad));
}

/// Carrega (e guarda) as imagens usadas pelas anotações.
class AnnotationImageCache {
  /// Fotos grandes são reduzidas a esta largura (sobra para impressão A4).
  static const maxWidth = 1600;

  final _images = <String, ui.Image>{};
  final _loading = <String>{};
  final _failed = <String>{};
  bool _disposed = false;

  Map<String, ui.Image> get images => _images;

  /// Decodifica as imagens que faltam; chama [onLoaded] quando alguma chega.
  void ensureLoaded(Iterable<Annotation> annotations, {VoidCallback? onLoaded}) {
    for (final a in annotations) {
      final path = a.assetPath;
      if (a.type != AnnotationType.image || path == null) continue;
      if (_images.containsKey(path) || _failed.contains(path) || !_loading.add(path)) continue;
      load(path).then((img) {
        _loading.remove(path);
        if (img != null && !_disposed) onLoaded?.call();
      });
    }
  }

  Future<ui.Image?> load(String path) async {
    final cached = _images[path];
    if (cached != null) return cached;
    try {
      final bytes = await File(path).readAsBytes();
      final probe = await ui.instantiateImageCodec(bytes);
      final first = await probe.getNextFrame();
      final width = first.image.width;
      ui.Image image;
      if (width > maxWidth) {
        first.image.dispose();
        probe.dispose();
        final codec = await ui.instantiateImageCodec(bytes, targetWidth: maxWidth);
        image = (await codec.getNextFrame()).image;
        codec.dispose();
      } else {
        image = first.image;
        probe.dispose();
      }
      if (_disposed) {
        image.dispose();
        return null;
      }
      return _images[path] = image;
    } catch (_) {
      _failed.add(path); // arquivo sumiu ou corrompeu: não tenta de novo a cada mudança
      return null;
    }
  }

  void dispose() {
    _disposed = true;
    for (final img in _images.values) {
      img.dispose();
    }
    _images.clear();
  }
}
