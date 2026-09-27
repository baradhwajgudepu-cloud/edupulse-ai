import 'web_download_stub.dart'
    if (dart.library.js_util) 'web_download_web.dart'
    if (dart.library.html) 'web_download_web.dart';

void downloadCsvFile(String fileName, String csvContent) {
  downloadFileImpl(fileName, csvContent);
}

void downloadBinaryFile(String fileName, List<int> bytes, {String mimeType = 'application/pdf'}) {
  downloadBinaryFileImpl(fileName, bytes, mimeType);
}

void printReceiptHtml(String htmlContent) {
  printReceiptHtmlImpl(htmlContent);
}
