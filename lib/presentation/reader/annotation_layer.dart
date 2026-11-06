import 'package:material_ui/material_ui.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/annotation_renderer.dart';
import '../../domain/annotation.dart';
import '../theme/lydo_theme.dart';
import 'annotation_controller.dart';

const _bar = Color(0xFF1A2130);
const _barBorder = Color(0xFF2C3546);
const _onBar = Colors.white;
const _onBarMuted = Color(0xFFA3ACBD);

/// Pinta realces, traços e imagens da página (chamado pelo PdfViewer).
/// Texto e notas são widgets tocáveis (veja [pageAnnotationOverlays]).
void paintPageAnnotations(
  Canvas canvas,
  Rect pageRect,
  PdfPage page,
  Iterable<Annotation> list,
  AnnotationImageCache images,
) =>
    paintAnnotations(canvas, pageRect: pageRect, page: page, annotations: list, images: images.images);

/// Caixas de texto e notas como widgets por cima da página (dá para tocar e editar).
List<Widget> pageAnnotationOverlays({
  required Rect pageRectInViewer,
  required PdfPage page,
  required Iterable<Annotation> list,
  required ValueChanged<Annotation> onTap,
}) {
  final scale = pageRectInViewer.width / page.width;
  final widgets = <Widget>[];
  for (final a in list) {
    final anchor = a.anchor;
    if (anchor == null) continue;
    final pos = PdfPoint(anchor.x, anchor.y).toOffset(page: page, scaledPageSize: pageRectInViewer.size);
    switch (a.type) {
      case AnnotationType.text:
        widgets.add(Positioned(
          left: pos.dx,
          top: pos.dy,
          child: GestureDetector(
            onTap: () => onTap(a),
            child: Text(
              a.text,
              style: TextStyle(color: Color(a.color), fontSize: a.width * scale, height: 1.2),
              textScaler: TextScaler.noScaling,
            ),
          ),
        ));
      case AnnotationType.note:
        const size = 30.0;
        widgets.add(Positioned(
          left: pos.dx - size / 2,
          top: pos.dy - size / 2,
          child: GestureDetector(
            onTap: () => onTap(a),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Color(a.color),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 2))],
              ),
              child: const Icon(Icons.chat_bubble_outline, size: 18, color: Color(0xFF1F2937)),
            ),
          ),
        ));
      default:
        break;
    }
  }
  return widgets;
}

/// Converte o toque na tela em (página, ponto na página).
typedef PageHit = ({int page, APoint point});
typedef PageHitTester = PageHit? Function(Offset local);

/// Captura os gestos de desenho quando há uma ferramenta ativa.
/// Sem ferramenta, esta camada não existe e a página rola normalmente.
class AnnotationGestureLayer extends StatelessWidget {
  const AnnotationGestureLayer({
    super.key,
    required this.controller,
    required this.hitTest,
    required this.onStrokeEnd,
    required this.onPlace,
  });

  final AnnotationController controller;
  final PageHitTester hitTest;
  final VoidCallback onStrokeEnd;

  /// Toque com Texto, Nota ou Borracha.
  final void Function(AnnotationTool tool, PageHit hit) onPlace;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AnnotationTool?>(
      valueListenable: controller.tool,
      builder: (context, tool, _) {
        if (tool == null) return const SizedBox.shrink();
        final draws = tool == AnnotationTool.highlight || tool == AnnotationTool.pen;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: draws
              ? (d) {
                  final hit = hitTest(d.localPosition);
                  if (hit != null) controller.beginStroke(hit.page, hit.point, d.localPosition);
                }
              : null,
          onPanUpdate: draws
              ? (d) {
                  final hit = hitTest(d.localPosition);
                  if (hit != null) controller.extendStroke(hit.page, hit.point, d.localPosition);
                }
              : null,
          onPanEnd: draws ? (_) => onStrokeEnd() : null,
          onPanCancel: draws ? controller.cancelStroke : null,
          onTapUp: (d) {
            final hit = hitTest(d.localPosition);
            if (hit == null) return;
            if (draws) {
              // Toque simples com caneta = ponto; com realce = marca a palavra.
              controller.beginStroke(hit.page, hit.point, d.localPosition);
              onStrokeEnd();
            } else {
              onPlace(tool, hit);
            }
          },
          child: RepaintBoundary(
            child: ValueListenableBuilder<List<Offset>>(
              valueListenable: controller.draft,
              builder: (_, points, _) => CustomPaint(
                size: Size.infinite,
                painter: _DraftPainter(
                  points: points,
                  color: Color(controller.color),
                  highlight: tool == AnnotationTool.highlight,
                  size: controller.size.value,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DraftPainter extends CustomPainter {
  _DraftPainter({required this.points, required this.color, required this.highlight, required this.size});
  final List<Offset> points;
  final Color color;
  final bool highlight;
  final StrokeSize size;

  @override
  void paint(Canvas canvas, Size s) {
    if (points.isEmpty) return;
    final base = switch (size) { StrokeSize.thin => 0.6, StrokeSize.medium => 1.0, StrokeSize.thick => 1.6 };
    final paint = Paint()
      ..color = highlight ? color.withValues(alpha: 0.45) : color
      ..style = PaintingStyle.stroke
      ..strokeWidth = (highlight ? 18 : 3) * base
      ..strokeCap = highlight ? StrokeCap.square : StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_DraftPainter old) =>
      old.points != points || old.color != color || old.highlight != highlight || old.size != size;
}

/// Paleta (cores + espessura + desfazer) e ferramentas do modo Anotar.
class AnnotationToolbar extends StatelessWidget {
  const AnnotationToolbar({super.key, required this.controller, required this.onMore});
  final AnnotationController controller;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<AnnotationTool?>(
              valueListenable: controller.tool,
              builder: (_, tool, _) => tool == null || tool == AnnotationTool.eraser
                  ? _Hint(tool: tool)
                  : _Palette(controller: controller, tool: tool),
            ),
            const SizedBox(height: 10),
            _Tools(controller: controller, onMore: onMore),
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.tool});
  final AnnotationTool? tool;

  @override
  Widget build(BuildContext context) {
    final text = tool == AnnotationTool.eraser
        ? 'Toque numa anotação para apagar'
        : 'Sem ferramenta: a página rola e dá zoom normalmente';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _bar,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _barBorder),
      ),
      child: Text(text, style: const TextStyle(color: _onBarMuted, fontSize: 14)),
    );
  }
}

class _Palette extends StatelessWidget {
  const _Palette({required this.controller, required this.tool});
  final AnnotationController controller;
  final AnnotationTool tool;

  @override
  Widget build(BuildContext context) {
    final colors = AnnotationPalette.forTool(tool);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _bar,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: _barBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ValueListenableBuilder<int>(
            valueListenable: controller.colorIndex,
            builder: (_, selected, _) => Row(
              children: [
                for (var i = 0; i < colors.length; i++)
                  GestureDetector(
                    onTap: () => controller.colorIndex.value = i,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(colors[i]),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: i == selected ? Colors.white : Colors.white24,
                          width: i == selected ? 3 : 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(width: 1, height: 28, color: _barBorder, margin: const EdgeInsets.symmetric(horizontal: 10)),
          ValueListenableBuilder<StrokeSize>(
            valueListenable: controller.size,
            builder: (_, selected, _) => Row(
              children: [
                for (final s in StrokeSize.values)
                  GestureDetector(
                    onTap: () => controller.size.value = s,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 46,
                      height: 34,
                      decoration: BoxDecoration(
                        color: s == selected ? LydoColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Container(
                        width: 24,
                        height: switch (s) { StrokeSize.thin => 2, StrokeSize.medium => 4, StrokeSize.thick => 7 },
                        decoration: BoxDecoration(color: _onBar, borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: controller.canUndo,
            builder: (_, can, _) => IconButton(
              tooltip: 'Desfazer',
              onPressed: can ? controller.undo : null,
              icon: Icon(Icons.undo, color: can ? _onBar : Colors.white24),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tools extends StatelessWidget {
  const _Tools({required this.controller, required this.onMore});
  final AnnotationController controller;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    Widget item(AnnotationTool? t, IconData icon, String label, AnnotationTool? current, VoidCallback onTap) {
      final active = t != null && t == current;
      return Expanded(
        child: Material(
          color: active ? LydoColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: SizedBox(
              height: 64,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: _onBar, size: 26),
                  const SizedBox(height: 4),
                  Text(label, style: const TextStyle(color: _onBar, fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: _bar,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _barBorder),
      ),
      child: ValueListenableBuilder<AnnotationTool?>(
        valueListenable: controller.tool,
        builder: (_, current, _) => Row(
          children: [
            item(AnnotationTool.highlight, Icons.border_color_outlined, 'Realçar', current,
                () => controller.selectTool(AnnotationTool.highlight)),
            item(AnnotationTool.pen, Icons.gesture, 'Caneta', current,
                () => controller.selectTool(AnnotationTool.pen)),
            item(AnnotationTool.text, Icons.text_fields, 'Texto', current,
                () => controller.selectTool(AnnotationTool.text)),
            item(AnnotationTool.note, Icons.chat_bubble_outline, 'Nota', current,
                () => controller.selectTool(AnnotationTool.note)),
            item(current == AnnotationTool.eraser ? AnnotationTool.eraser : null, Icons.more_horiz, 'Mais',
                current, onMore),
          ],
        ),
      ),
    );
  }
}
