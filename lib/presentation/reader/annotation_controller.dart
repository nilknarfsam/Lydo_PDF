import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/result.dart';
import '../../domain/annotation.dart';
import '../../domain/annotation_repository.dart';

enum AnnotationTool { highlight, pen, text, note, eraser }

enum StrokeSize { thin, medium, thick }

/// Cores da paleta (4 por ferramenta, como na referência).
abstract final class AnnotationPalette {
  static const highlight = [0xFFFFD43B, 0xFF69DB7C, 0xFFF783AC, 0xFF74C0FC];
  static const ink = [0xFF111827, 0xFF2F6BF6, 0xFFE5484D, 0xFF2B8A3E];

  static List<int> forTool(AnnotationTool? tool) =>
      tool == AnnotationTool.highlight || tool == AnnotationTool.note ? highlight : ink;
}

/// Estado do modo Anotar: ferramenta, cor, espessura, lista de anotações,
/// desfazer/refazer e o traço que está sendo desenhado agora.
class AnnotationController {
  AnnotationController({required this.documentId, required this.repository});

  final String documentId;
  final AnnotationRepository repository;

  /// Avisado sempre que as anotações mudam (o leitor redesenha as páginas).
  VoidCallback? onChanged;

  final annotations = ValueNotifier<List<Annotation>>(const []);
  final tool = ValueNotifier<AnnotationTool?>(AnnotationTool.highlight);
  final colorIndex = ValueNotifier(0);
  final size = ValueNotifier(StrokeSize.medium);
  final canUndo = ValueNotifier(false);
  final canRedo = ValueNotifier(false);

  /// Traço em andamento, em coordenadas da tela (desenhado por cima do PDF).
  final draft = ValueNotifier<List<Offset>>(const []);

  final _undo = <List<Annotation>>[];
  final _redo = <List<Annotation>>[];
  final _textCache = <int, List<ARect>>{};
  int? _draftPage;
  final _draftPoints = <APoint>[];
  int _seq = 0;

  int get color => AnnotationPalette.forTool(tool.value)[colorIndex.value];

  Iterable<Annotation> onPage(int page) => annotations.value.where((a) => a.page == page);

  Future<String?> load() async {
    final r = await repository.load(documentId);
    switch (r) {
      case Ok(:final value):
        annotations.value = value;
        onChanged?.call();
        return null;
      case Err(:final failure):
        return failure.message;
    }
  }

  /// Toca na ferramenta já ativa → solta (volta a rolar a página).
  void selectTool(AnnotationTool t) => tool.value = tool.value == t ? null : t;

  // ---------- Desenho (realce e caneta) ----------

  void beginStroke(int page, APoint p, Offset screen) {
    _draftPage = page;
    _draftPoints
      ..clear()
      ..add(p);
    draft.value = [screen];
  }

  void extendStroke(int page, APoint p, Offset screen) {
    if (_draftPage != page) return; // o traço não pula de página
    if (_draftPoints.isNotEmpty && _draftPoints.last.distanceTo(p) < 0.8) return;
    _draftPoints.add(p);
    draft.value = [...draft.value, screen];
  }

  Future<void> endStroke(PdfDocument? document) async {
    final page = _draftPage;
    final points = List<APoint>.of(_draftPoints);
    _draftPage = null;
    _draftPoints.clear();
    draft.value = const [];
    if (page == null || points.isEmpty) return;

    switch (tool.value) {
      case AnnotationTool.highlight:
        final chars = await _charRects(document, page);
        final rects = highlightRects(
          charRects: chars,
          start: points.first,
          end: points.last,
          fallbackHeight: _highlightHeight,
        );
        if (rects.isEmpty) return;
        _add(Annotation(
          id: _newId(),
          type: AnnotationType.highlight,
          page: page,
          color: color,
          createdAt: DateTime.now(),
          rects: rects,
        ));
      case AnnotationTool.pen:
        _add(Annotation(
          id: _newId(),
          type: AnnotationType.ink,
          page: page,
          color: color,
          createdAt: DateTime.now(),
          width: _penWidth,
          points: _simplify(points),
        ));
      default:
        break;
    }
  }

  void cancelStroke() {
    _draftPage = null;
    _draftPoints.clear();
    draft.value = const [];
  }

  // ---------- Texto e nota ----------

  void addText(int page, APoint at, String text) {
    if (text.trim().isEmpty) return;
    _add(Annotation(
      id: _newId(),
      type: AnnotationType.text,
      page: page,
      color: color,
      createdAt: DateTime.now(),
      width: _fontSize,
      points: [at],
      text: text.trim(),
    ));
  }

  void addNote(int page, APoint at, String text) {
    if (text.trim().isEmpty) return;
    _add(Annotation(
      id: _newId(),
      type: AnnotationType.note,
      page: page,
      color: color,
      createdAt: DateTime.now(),
      points: [at],
      text: text.trim(),
    ));
  }

  void updateText(Annotation a, String text) {
    if (text.trim().isEmpty) return remove(a);
    _replace(a.id, a.copyWith(text: text.trim()));
  }

  // ---------- Borracha, desfazer ----------

  /// Borracha: apaga a anotação mais recente sob o toque.
  bool eraseAt(int page, APoint p) {
    final hit = onPage(page).toList().reversed.where((a) => a.hitTest(p)).firstOrNull;
    if (hit == null) return false;
    remove(hit);
    return true;
  }

  void remove(Annotation a) => _commit(annotations.value.where((x) => x.id != a.id).toList());

  void clearPage(int page) => _commit(annotations.value.where((a) => a.page != page).toList());

  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(annotations.value);
    _apply(_undo.removeLast());
  }

  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(annotations.value);
    _apply(_redo.removeLast());
  }

  // ---------- Internos ----------

  double get _penWidth => switch (size.value) {
        StrokeSize.thin => 1.2,
        StrokeSize.medium => 2.4,
        StrokeSize.thick => 4.5,
      };

  double get _highlightHeight => switch (size.value) {
        StrokeSize.thin => 8,
        StrokeSize.medium => 14,
        StrokeSize.thick => 22,
      };

  double get _fontSize => switch (size.value) {
        StrokeSize.thin => 11,
        StrokeSize.medium => 15,
        StrokeSize.thick => 22,
      };

  String _newId() => '${DateTime.now().microsecondsSinceEpoch}_${_seq++}';

  void _add(Annotation a) => _commit([...annotations.value, a]);

  void _replace(String id, Annotation a) =>
      _commit([for (final x in annotations.value) x.id == id ? a : x]);

  void _commit(List<Annotation> next) {
    _undo.add(annotations.value);
    if (_undo.length > 100) _undo.removeAt(0);
    _redo.clear();
    _apply(next);
  }

  void _apply(List<Annotation> next) {
    annotations.value = List.unmodifiable(next);
    canUndo.value = _undo.isNotEmpty;
    canRedo.value = _redo.isNotEmpty;
    onChanged?.call();
    unawaited(repository.save(documentId, annotations.value));
  }

  /// Caixas das letras da página (carregadas uma vez e guardadas).
  Future<List<ARect>> _charRects(PdfDocument? document, int page) async {
    final cached = _textCache[page];
    if (cached != null) return cached;
    if (document == null || page < 1 || page > document.pages.length) return const [];
    try {
      final text = await document.pages[page - 1].loadStructuredText(ensureLoaded: true);
      final rects = [for (final r in text.charRects) ARect(r.left, r.top, r.right, r.bottom)];
      return _textCache[page] = rects;
    } catch (_) {
      return _textCache[page] = const []; // página sem texto → faixa reta
    }
  }

  /// Tira pontos quase alinhados para o traço ficar leve no arquivo.
  static List<APoint> _simplify(List<APoint> pts) {
    if (pts.length < 3) return pts;
    final out = <APoint>[pts.first];
    for (var i = 1; i < pts.length - 1; i++) {
      final a = out.last, b = pts[i], c = pts[i + 1];
      final cross = ((b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)).abs();
      final len = math.max(a.distanceTo(c), 0.001);
      if (cross / len > 0.25) out.add(b);
    }
    out.add(pts.last);
    return out;
  }

  void dispose() {
    for (final n in <ChangeNotifier>[annotations, tool, colorIndex, size, canUndo, canRedo, draft]) {
      n.dispose();
    }
  }
}
