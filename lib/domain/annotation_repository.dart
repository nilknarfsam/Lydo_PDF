import '../core/result.dart';
import 'annotation.dart';

/// Anotações de cada documento (identificado pelo id da biblioteca).
abstract interface class AnnotationRepository {
  Future<Result<List<Annotation>>> load(String documentId);
  Future<Result<void>> save(String documentId, List<Annotation> annotations);
  Future<Result<void>> delete(String documentId);
}
