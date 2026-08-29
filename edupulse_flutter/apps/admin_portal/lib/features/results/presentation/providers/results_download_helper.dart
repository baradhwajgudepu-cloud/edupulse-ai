import 'results_download_stub.dart'
    if (dart.library.js_util) 'results_download_web.dart'
    if (dart.library.html) 'results_download_web.dart';

void downloadBytes(String fileName, List<int> bytes, String mimeType) {
  downloadBytesImpl(fileName, bytes, mimeType);
}

void viewBytes(List<int> bytes, String mimeType) {
  viewBytesImpl(bytes, mimeType);
}
