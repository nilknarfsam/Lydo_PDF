import 'dart:io';
import 'dart:ui' as ui;

import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import '../core/result.dart';

/// Capa (página 1) de cada PDF guardada como PNG em `<docs>/covers/`.
///
/// Abrir o PDF inteiro só para desenhar a capa é lento em arquivos grandes;
/// assim a capa é gerada uma vez e depois só lida do disco. O nome do PNG
/// vem do nome do arquivo do PDF, então um PDF reorganizado (arquivo novo)
/// ganha capa nova sozinho.
class CoverCacheService {
  CoverCacheService({Future<Directory> Function()? baseDir})
      : _baseDir = baseDir ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _baseDir;

  /// Largura da capa em pixels (sobra para a capa grande da grade).
  static const coverWidth = 320;

  /// Pedidos em andamento ou prontos, para não gerar a mesma capa duas vezes.
  final _pending = <String, Future<Result<File>>>{};

  Future<Result<File>> coverFor(String pdfPath) {
    final future = _pending[pdfPath] ??= _load(pdfPath);
    // Falhou: esquece, para tentar de novo da próxima vez.
    future.then((r) {
      if (r is Err<File>) _pending.remove(pdfPath);
    });
    return future;
  }

  /// Apaga a capa guardada de um PDF (ex.: documento removido da biblioteca).
  Future<void> remove(String pdfPath) async {
    _pending.remove(pdfPath);
    try {
      final file = await _fileFor(pdfPath);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Capa é só cache: se não der para apagar, não atrapalha nada.
    }
  }

  Future<File> _fileFor(String pdfPath) async {
    final name = pdfPath.split(RegExp(r'[\\/]')).last.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
    return File('${(await _baseDir()).path}/covers/$name.png');
  }

  Future<Result<File>> _load(String pdfPath) async {
    try {
      final file = await _fileFor(pdfPath);
      if (await file.exists()) return Ok(file);
      await file.parent.create(recursive: true);

      final doc = await PdfDocument.openFile(pdfPath);
      try {
        final page = doc.pages.first;
        final width = coverWidth;
        final height = (coverWidth * page.height / page.width).round();
        final image = await page.renderForDisplay(
          width: width,
          height: height,
          fullWidth: width.toDouble(),
          fullHeight: height.toDouble(),
          backgroundColor: 0xFFFFFFFF,
        );
        if (image == null) {
          return const Err(AppFailure(FailureKind.unknown, 'Não foi possível gerar a capa.'));
        }
        try {
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          if (png == null) {
            return const Err(AppFailure(FailureKind.unknown, 'Não foi possível gerar a capa.'));
          }
          // Grava num temporário e renomeia: nunca fica um PNG pela metade.
          final tmp = File('${file.path}.tmp');
          await tmp.writeAsBytes(png.buffer.asUint8List(), flush: true);
          await tmp.rename(file.path);
          return Ok(file);
        } finally {
          image.dispose();
        }
      } finally {
        await doc.dispose();
      }
    } catch (e) {
      return Err(AppFailure(FailureKind.unknown, 'Não foi possível gerar a capa.', e));
    }
  }
}
