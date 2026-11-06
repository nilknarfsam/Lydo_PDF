import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ffi/ffi.dart';
import 'package:pdfium_dart/pdfium_dart.dart' as pdfium;
import 'package:pdfrx/pdfrx.dart';

import '../core/annotation_renderer.dart';
import '../core/result.dart';
import '../domain/annotation.dart';
import '../domain/page_plan.dart';

/// Camada desenhada de uma página, pronta para entrar no PDF.
class _Overlay {
  _Overlay(this.width, this.height, this.bgra, this.matrix);
  final int width;
  final int height;
  final Uint8List bgra;

  /// a, b, c, d, e, f: leva o quadrado unitário da imagem para a página.
  final List<double> matrix;
}

/// Edição do arquivo PDF: reorganizar páginas e gravar anotações dentro dele.
class PdfEditService {
  /// Pixels por ponto PDF da camada de anotações (2 ≈ 144 dpi)…
  static const _scale = 2.0;

  /// …limitado a ~4 megapixels por página (16 MB), para páginas grandes (A3, plantas).
  static const _maxPixels = 4000000;

  /// Gera um PDF novo com as anotações gravadas.
  ///
  /// - Realces viram **anotações de realce do próprio PDF** (o Adobe e outros
  ///   leitores reconhecem, e o texto não escurece).
  /// - Caneta, texto, notas, imagens e assinaturas viram **uma imagem
  ///   transparente** por cima da página: o texto original continua
  ///   selecionável e pesquisável.
  ///
  /// Processa uma página por vez para não estourar a memória em PDFs grandes.
  Future<Result<Uint8List>> exportWithAnnotations({
    required String path,
    required List<Annotation> annotations,
  }) async {
    PdfDocument? doc;
    final images = AnnotationImageCache();
    try {
      doc = await PdfDocument.openFile(path);
      final byPage = <int, List<Annotation>>{};
      for (final a in annotations) {
        if (a.page >= 1 && a.page <= doc.pages.length) (byPage[a.page] ??= []).add(a);
      }

      for (final MapEntry(key: pageNumber, value: list) in byPage.entries) {
        final page = doc.pages[pageNumber - 1];
        for (final a in list) {
          if (a.assetPath != null) await images.load(a.assetPath!);
        }
        final highlights = list.where((a) => a.type == AnnotationType.highlight).toList();
        final others = list.where((a) => a.type != AnnotationType.highlight).toList();
        final overlay = others.isEmpty ? null : await _renderOverlay(page, others, images);
        await doc.useNativeDocumentHandle(
          (handle) => _writePage(handle, pageNumber - 1, overlay, highlights),
        );
      }
      return Result.ok(await doc.encodePdf());
    } catch (e) {
      return Result.error(AppFailure(FailureKind.unknown, 'Não foi possível gerar o PDF anotado.', e));
    } finally {
      images.dispose();
      await doc?.dispose();
    }
  }

  /// Aplica o novo arranjo de páginas e grava em [targetPath].
  Future<Result<void>> applyPagePlan({
    required String sourcePath,
    required String targetPath,
    required PagePlan plan,
  }) async {
    PdfDocument? doc;
    final temp = File('$targetPath.tmp');
    try {
      doc = await PdfDocument.openFile(sourcePath);
      final source = doc.pages;
      doc.pages = [
        for (final s in plan.slots)
          s.quarterTurns == 0
              ? source[s.sourcePage - 1]
              : source[s.sourcePage - 1].rotatedBy(PdfPageRotation.values[s.quarterTurns % 4]),
      ];
      await temp.writeAsBytes(await doc.encodePdf(), flush: true);
      await temp.rename(targetPath);
      return const Result.ok(null);
    } catch (e) {
      try {
        if (await temp.exists()) await temp.delete();
      } catch (_) {}
      return Result.error(AppFailure(FailureKind.unknown, 'Não foi possível reorganizar as páginas.', e));
    } finally {
      await doc?.dispose();
    }
  }

  Future<_Overlay> _renderOverlay(PdfPage page, List<Annotation> list, AnnotationImageCache images) async {
    // Tamanho da página como aparece (já girada), dentro do limite de pixels.
    final area = page.width * page.height;
    final scale = math.min(_scale, math.sqrt(_maxPixels / area));
    final w = math.max(1, (page.width * scale).ceil());
    final h = math.max(1, (page.height * scale).ceil());

    final recorder = ui.PictureRecorder();
    paintAnnotations(
      ui.Canvas(recorder),
      pageRect: ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      page: page,
      annotations: list,
      images: images.images,
      includeTextAndNotes: true,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(w, h);
    picture.dispose();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    image.dispose();
    final bytes = data!.buffer.asUint8List();

    // RGBA → BGRA (formato do PDFium).
    for (var i = 0; i < bytes.length; i += 4) {
      final r = bytes[i];
      bytes[i] = bytes[i + 2];
      bytes[i + 2] = r;
    }

    // Onde ficam três cantos da imagem dentro da página (coordenadas do PDF).
    // Funciona para qualquer giro de página, pois quem converte é o próprio pdfrx.
    final size = ui.Size(w.toDouble(), h.toDouble());
    final bottomLeft = ui.Offset(0, size.height).toPdfPoint(page: page, scaledPageSize: size);
    final bottomRight = ui.Offset(size.width, size.height).toPdfPoint(page: page, scaledPageSize: size);
    final topLeft = ui.Offset.zero.toPdfPoint(page: page, scaledPageSize: size);
    return _Overlay(w, h, bytes, [
      bottomRight.x - bottomLeft.x,
      bottomRight.y - bottomLeft.y,
      topLeft.x - bottomLeft.x,
      topLeft.y - bottomLeft.y,
      bottomLeft.x,
      bottomLeft.y,
    ]);
  }

  /// Parte nativa de uma página: realces como anotações do PDF + a camada de imagem.
  static void _writePage(int nativeDocumentHandle, int pageIndex, _Overlay? overlay, List<Annotation> highlights) {
    final lib = pdfium.getPdfium(modulePath: Pdfrx.pdfiumModulePath);
    final document = pdfium.FPDF_DOCUMENT.fromAddress(nativeDocumentHandle);
    final page = lib.FPDF_LoadPage(document, pageIndex);
    if (page == ffi.nullptr) throw StateError('Página ${pageIndex + 1} não abriu.');
    try {
      for (final h in highlights) {
        _addHighlight(lib, page, h);
      }
      if (overlay != null) _addOverlay(lib, document, page, overlay, pageIndex);
    } finally {
      lib.FPDF_ClosePage(page);
    }
  }

  static void _addHighlight(pdfium.PDFium lib, pdfium.FPDF_PAGE page, Annotation h) {
    if (h.rects.isEmpty) return;
    final annot = lib.FPDFPage_CreateAnnot(page, pdfium.FPDF_ANNOT_HIGHLIGHT);
    if (annot == ffi.nullptr) return;
    final quad = calloc<pdfium.FS_QUADPOINTSF>();
    final rect = calloc<pdfium.FS_RECTF>();
    try {
      final c = h.color;
      lib.FPDFAnnot_SetColor(
        annot,
        pdfium.FPDFANNOT_COLORTYPE.FPDFANNOT_COLORTYPE_Color,
        (c >> 16) & 0xFF,
        (c >> 8) & 0xFF,
        c & 0xFF,
        255,
      );
      var bounds = h.rects.first;
      for (final r in h.rects) {
        // Ordem usada pelo Acrobat: topo-esquerda, topo-direita, base-esquerda, base-direita.
        quad.ref
          ..x1 = r.left
          ..y1 = r.top
          ..x2 = r.right
          ..y2 = r.top
          ..x3 = r.left
          ..y3 = r.bottom
          ..x4 = r.right
          ..y4 = r.bottom;
        lib.FPDFAnnot_AppendAttachmentPoints(annot, quad);
        bounds = bounds.expandToInclude(r);
      }
      rect.ref
        ..left = bounds.left
        ..top = bounds.top
        ..right = bounds.right
        ..bottom = bounds.bottom;
      lib.FPDFAnnot_SetRect(annot, rect);
    } finally {
      calloc.free(quad);
      calloc.free(rect);
      lib.FPDFPage_CloseAnnot(annot);
    }
  }

  static void _addOverlay(
    pdfium.PDFium lib,
    pdfium.FPDF_DOCUMENT document,
    pdfium.FPDF_PAGE page,
    _Overlay o,
    int pageIndex,
  ) {
    final buffer = calloc<ffi.Uint8>(o.bgra.length);
    final pages = calloc<pdfium.FPDF_PAGE>(1);
    pdfium.FPDF_BITMAP bitmap = ffi.nullptr;
    try {
      buffer.asTypedList(o.bgra.length).setAll(0, o.bgra);
      bitmap = lib.FPDFBitmap_CreateEx(o.width, o.height, pdfium.FPDFBitmap_BGRA, buffer.cast(), o.width * 4);
      if (bitmap == ffi.nullptr) throw StateError('Sem memória para a página ${pageIndex + 1}.');
      final imageObject = lib.FPDFPageObj_NewImageObj(document);
      if (imageObject == ffi.nullptr) throw StateError('Falha ao criar a imagem da página ${pageIndex + 1}.');
      pages[0] = page;
      if (lib.FPDFImageObj_SetBitmap(pages, 1, imageObject, bitmap) == 0) {
        lib.FPDFPageObj_Destroy(imageObject);
        throw StateError('Falha ao criar a imagem da página ${pageIndex + 1}.');
      }
      final m = o.matrix;
      lib.FPDFImageObj_SetMatrix(imageObject, m[0], m[1], m[2], m[3], m[4], m[5]);
      lib.FPDFPage_InsertObject(page, imageObject); // a página passa a ser dona do objeto
      if (lib.FPDFPage_GenerateContent(page) == 0) {
        throw StateError('Falha ao gravar a página ${pageIndex + 1}.');
      }
    } finally {
      if (bitmap != ffi.nullptr) lib.FPDFBitmap_Destroy(bitmap);
      calloc.free(buffer);
      calloc.free(pages);
    }
  }
}
