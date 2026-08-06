import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'logger.dart';

class BootstrapResult {
  final bool success;
  final String? errorMessage;

  BootstrapResult({required this.success, this.errorMessage});
}

class BootstrapService {
  static Future<BootstrapResult> initialize() async {
    try {
      EduLogger.i("Starting application bootstrap...");

      // 1. Initialize SharedPreferences
      EduLogger.d("Initializing SharedPreferences...");
      await SharedPreferences.getInstance();

      // 2. Initialize SecureStorage
      EduLogger.d("Initializing SecureStorage...");
      const secureStorage = FlutterSecureStorage();

      // Reading a dummy key to verify Android/iOS platform channels bind correctly
      await secureStorage.read(key: 'initialized_check');

      EduLogger.i("Bootstrap completed successfully.");
      return BootstrapResult(success: true);
    } catch (e, stackTrace) {
      EduLogger.e("Bootstrap failed", e, stackTrace);
      return BootstrapResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }
}
