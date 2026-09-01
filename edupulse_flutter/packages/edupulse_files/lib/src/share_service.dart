import 'package:edupulse_core/edupulse_core.dart';

class ShareService {
  const ShareService();

  Future<void> shareFile(String path, {String? title}) async {
    EduLogger.i('Sharing file at path: $path, title: $title');
  }
}
