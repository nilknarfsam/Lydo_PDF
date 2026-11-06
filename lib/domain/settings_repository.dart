import '../core/result.dart';
import 'app_settings.dart';

abstract interface class SettingsRepository {
  Future<Result<AppSettings>> load();
  Future<Result<void>> save(AppSettings settings);

  /// Espaço ocupado pelas cópias dos PDFs dentro do app, em bytes.
  Future<Result<int>> storageUsed();
}
