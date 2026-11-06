import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../theme/lydo_theme.dart';
import 'signature_pad_controller.dart';

/// Tela cheia para desenhar a assinatura.
///
/// Fecha com `Navigator.pop(context, bytes)` (PNG com fundo transparente)
/// ao tocar em "Usar assinatura"; sem assinatura, não fecha.
class SignaturePadPage extends StatefulWidget {
  const SignaturePadPage({super.key});

  @override
  State<SignaturePadPage> createState() => _SignaturePadPageState();
}

class _SignaturePadPageState extends State<SignaturePadPage> {
  final _controller = SignaturePadController();

  /// Tamanho da área de desenho, lido no layout para exportar o PNG.
  Size _areaSize = Size.zero;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Evita dois `pop` com toque duplo (o segundo fecharia o leitor).
  bool _closing = false;

  Future<void> _confirm() async {
    if (_closing) return;
    _closing = true;
    final bytes = await _controller.exportPng(size: _areaSize);
    if (!mounted || bytes == null) {
      _closing = false;
      return;
    }
    Navigator.of(context).pop<Uint8List>(bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Sua assinatura'),
        backgroundColor: Colors.white,
        foregroundColor: LydoColors.lightText,
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: _controller.isEmpty,
            builder: (context, empty, _) => IconButton(
              tooltip: 'Desfazer',
              icon: const Icon(Icons.undo),
              onPressed: empty ? null : _controller.undo,
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _controller.isEmpty,
            builder: (context, empty, _) => TextButton(
              onPressed: empty ? null : _controller.clear,
              child: const Text('Limpar'),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _areaSize = constraints.biggest;
                    return _DrawArea(controller: _controller);
                  },
                ),
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<bool>(
                valueListenable: _controller.isEmpty,
                builder: (context, empty, _) => SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: empty ? null : _confirm,
                    child: const Text('Usar assinatura'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Área de desenho: captura os gestos e pinta os traços sobre a linha-guia.
class _DrawArea extends StatelessWidget {
  const _DrawArea({required this.controller});

  final SignaturePadController controller;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (d) => controller.start(d.localPosition),
      onPanUpdate: (d) => controller.extend(d.localPosition),
      onPanEnd: (_) => controller.end(),
      onPanCancel: controller.end,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: LydoColors.lightBorder),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 24,
              right: 24,
              bottom: 56,
              child: Container(height: 1, color: const Color(0xFFCBD5E1)),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Text(
                'Assine acima da linha',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
            ),
            Positioned.fill(
              child: RepaintBoundary(
                child: ValueListenableBuilder<List<List<Offset>>>(
                  valueListenable: controller.strokes,
                  builder: (context, strokes, _) => CustomPaint(
                    painter: _StrokesPainter(strokes),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StrokesPainter extends CustomPainter {
  _StrokesPainter(this.strokes);

  final List<List<Offset>> strokes;

  static const _ink = Color(0xFF111827);
  static const _width = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = _width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    final dotPaint = Paint()
      ..color = _ink
      ..isAntiAlias = true;

    for (final stroke in strokes) {
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, _width / 2, dotPaint);
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final p in stroke.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _StrokesPainter oldDelegate) =>
      !identical(oldDelegate.strokes, strokes);
}
