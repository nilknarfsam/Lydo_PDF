import 'dart:math' as math;

/// Ponto em coordenadas da página PDF (pontos, origem no canto inferior esquerdo).
class APoint {
  const APoint(this.x, this.y);
  final double x;
  final double y;

  double distanceTo(APoint o) => math.sqrt((x - o.x) * (x - o.x) + (y - o.y) * (y - o.y));

  List<double> toJson() => [x, y];
  factory APoint.fromJson(List<dynamic> j) => APoint((j[0] as num).toDouble(), (j[1] as num).toDouble());
}

/// Retângulo em coordenadas da página PDF ([top] > [bottom]).
class ARect {
  const ARect(this.left, this.top, this.right, this.bottom);
  final double left;
  final double top;
  final double right;
  final double bottom;

  double get height => top - bottom;
  double get centerY => (top + bottom) / 2;

  bool contains(APoint p, {double tolerance = 0}) =>
      p.x >= left - tolerance && p.x <= right + tolerance && p.y >= bottom - tolerance && p.y <= top + tolerance;

  /// Distância do ponto até a borda (0 se estiver dentro).
  double distanceTo(APoint p) {
    final dx = math.max(0.0, math.max(left - p.x, p.x - right));
    final dy = math.max(0.0, math.max(bottom - p.y, p.y - top));
    return math.sqrt(dx * dx + dy * dy);
  }

  ARect expandToInclude(ARect o) => ARect(
        math.min(left, o.left),
        math.max(top, o.top),
        math.max(right, o.right),
        math.min(bottom, o.bottom),
      );

  List<double> toJson() => [left, top, right, bottom];
  factory ARect.fromJson(List<dynamic> j) => ARect(
        (j[0] as num).toDouble(),
        (j[1] as num).toDouble(),
        (j[2] as num).toDouble(),
        (j[3] as num).toDouble(),
      );
}

enum AnnotationType { highlight, ink, text, note }

/// Uma anotação feita pelo usuário numa página.
class Annotation {
  const Annotation({
    required this.id,
    required this.type,
    required this.page,
    required this.color,
    required this.createdAt,
    this.width = 2,
    this.rects = const [],
    this.points = const [],
    this.text = '',
  });

  final String id;
  final AnnotationType type;

  /// Número da página (começa em 1).
  final int page;

  /// Cor ARGB (ex.: 0xFFFFD43B).
  final int color;
  final DateTime createdAt;

  /// Caneta: espessura do traço. Texto: tamanho da fonte. Em pontos PDF.
  final double width;

  /// Realce: um retângulo por linha marcada.
  final List<ARect> rects;

  /// Caneta: pontos do traço. Texto/nota: um ponto (canto superior esquerdo).
  final List<APoint> points;

  /// Texto da caixa de texto ou da nota.
  final String text;

  APoint? get anchor => points.isEmpty ? null : points.first;

  Annotation copyWith({String? text, int? color, double? width, List<APoint>? points}) => Annotation(
        id: id,
        type: type,
        page: page,
        color: color ?? this.color,
        createdAt: createdAt,
        width: width ?? this.width,
        rects: rects,
        points: points ?? this.points,
        text: text ?? this.text,
      );

  /// O toque em [p] (mesma página) acerta esta anotação?
  bool hitTest(APoint p, {double tolerance = 8}) {
    switch (type) {
      case AnnotationType.highlight:
        return rects.any((r) => r.contains(p, tolerance: tolerance / 2));
      case AnnotationType.ink:
        final reach = tolerance + width / 2;
        if (points.length == 1) return points.first.distanceTo(p) <= reach;
        for (var i = 1; i < points.length; i++) {
          if (_distanceToSegment(p, points[i - 1], points[i]) <= reach) return true;
        }
        return false;
      case AnnotationType.text:
      case AnnotationType.note:
        final a = anchor;
        return a != null && a.distanceTo(p) <= tolerance * 3;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'page': page,
        'color': color,
        'createdAt': createdAt.toIso8601String(),
        'width': width,
        if (rects.isNotEmpty) 'rects': rects.map((r) => r.toJson()).toList(),
        if (points.isNotEmpty) 'points': points.map((p) => p.toJson()).toList(),
        if (text.isNotEmpty) 'text': text,
      };

  factory Annotation.fromJson(Map<String, dynamic> j) => Annotation(
        id: j['id'] as String,
        type: AnnotationType.values.byName(j['type'] as String),
        page: j['page'] as int,
        color: j['color'] as int,
        createdAt: DateTime.parse(j['createdAt'] as String),
        width: (j['width'] as num?)?.toDouble() ?? 2,
        rects: [for (final r in (j['rects'] as List<dynamic>? ?? [])) ARect.fromJson(r as List<dynamic>)],
        points: [for (final p in (j['points'] as List<dynamic>? ?? [])) APoint.fromJson(p as List<dynamic>)],
        text: j['text'] as String? ?? '',
      );
}

double _distanceToSegment(APoint p, APoint a, APoint b) {
  final dx = b.x - a.x, dy = b.y - a.y;
  final len2 = dx * dx + dy * dy;
  if (len2 == 0) return p.distanceTo(a);
  final t = (((p.x - a.x) * dx + (p.y - a.y) * dy) / len2).clamp(0.0, 1.0);
  return p.distanceTo(APoint(a.x + t * dx, a.y + t * dy));
}

/// Marca-texto que "gruda" no texto: do caractere mais perto de [start]
/// até o mais perto de [end], um retângulo por linha.
///
/// [charRects] são as caixas de cada letra da página. Se a página não tem
/// texto (PDF escaneado), devolve uma faixa reta de altura [fallbackHeight].
List<ARect> highlightRects({
  required List<ARect> charRects,
  required APoint start,
  required APoint end,
  required double fallbackHeight,
}) {
  int? nearest(APoint p) {
    int? best;
    var bestDist = double.infinity;
    for (var i = 0; i < charRects.length; i++) {
      final r = charRects[i];
      if (r.height <= 0) continue; // espaços/quebras sem caixa
      final d = r.distanceTo(p);
      if (d < bestDist) {
        bestDist = d;
        best = i;
        if (d == 0) break;
      }
    }
    // Longe demais de qualquer letra: não é um gesto sobre texto.
    return bestDist <= 24 ? best : null;
  }

  final a = nearest(start);
  final b = nearest(end);
  if (a == null || b == null) {
    final half = fallbackHeight / 2;
    final y = start.y;
    return [ARect(math.min(start.x, end.x), y + half, math.max(start.x, end.x), y - half)];
  }

  final from = math.min(a, b), to = math.max(a, b);
  final lines = <ARect>[];
  for (var i = from; i <= to; i++) {
    final r = charRects[i];
    if (r.height <= 0 || r.right <= r.left) continue;
    if (lines.isNotEmpty) {
      final last = lines.last;
      final sameLine = (r.centerY - last.centerY).abs() < math.min(r.height, last.height) * 0.6;
      if (sameLine) {
        lines[lines.length - 1] = last.expandToInclude(r);
        continue;
      }
    }
    lines.add(r);
  }
  return lines;
}
