/// Resultado tipado: toda função de repositório devolve sucesso ou falha,
/// em vez de deixar exceção subir até a UI.
sealed class Result<T> {
  const Result();

  const factory Result.ok(T value) = Ok<T>;
  const factory Result.error(AppFailure failure) = Err<T>;
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);
  final AppFailure failure;
}

enum FailureKind { fileNotFound, importFailed, storage, unknown }

class AppFailure {
  const AppFailure(this.kind, this.message, [this.cause]);

  final FailureKind kind;

  /// Mensagem pronta para mostrar ao usuário (pt-BR).
  final String message;
  final Object? cause;

  @override
  String toString() => 'AppFailure($kind, $message, $cause)';
}
