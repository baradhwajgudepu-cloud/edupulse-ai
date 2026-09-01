import 'dart:io';
import 'package:path_provider/path_provider.dart';

class StorageManager {
  const StorageManager();

  Future<String> getDownloadsDirectoryPath() async {
    // 1. Android documents directory using path_provider
    if (Platform.isAndroid) {
      final directory = await getApplicationDocumentsDirectory();
      final targetPath = '${directory.path}/EduPulse';
      final targetDir = Directory(targetPath);
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
      return targetDir.path;
    }

    // 2. Windows and developer desktop platforms
    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile != null) {
      final winDownloadDir = Directory('$userProfile/Downloads/EduPulse');
      if (!await winDownloadDir.exists()) {
        await winDownloadDir.create(recursive: true);
      }
      return winDownloadDir.path;
    }

    // 3. System temp directory fallback
    final tempDir = Directory.systemTemp;
    return tempDir.path;
  }

  Future<bool> fileExists(String path) async {
    return File(path).exists();
  }
}
