import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:edupulse_files/edupulse_files.dart';

void main() {
  late HttpServer server;
  late String baseUrl;

  setUpAll(() async {
    // Bind to a local port
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUrl = 'http://localhost:${server.port}';

    // Start listening
    server.listen((HttpRequest request) {
      final path = request.uri.path;

      if (path == '/valid.pdf') {
        request.response
          ..headers.contentType = ContentType('application', 'pdf')
          ..headers.add('content-length', '15')
          ..statusCode = HttpStatus.ok
          ..add(Uint8List.fromList([37, 80, 68, 70, 45, 49, 46, 52, 10, 37, 37, 69, 79, 70, 10])) // %PDF-1.4\n%%EOF\n
          ..close();
      } else if (path == '/receipt.pdf') {
        request.response
          ..headers.contentType = ContentType('application', 'pdf')
          ..headers.add('content-length', '15')
          ..statusCode = HttpStatus.ok
          ..add(Uint8List.fromList([37, 80, 68, 70, 45, 49, 46, 52, 10, 37, 37, 69, 79, 70, 10])) // %PDF-1.4\n%%EOF\n
          ..close();
      } else if (path == '/empty.pdf') {
        request.response
          ..headers.contentType = ContentType('application', 'pdf')
          ..headers.add('content-length', '0')
          ..statusCode = HttpStatus.ok
          ..close();
      } else if (path == '/json_error.pdf') {
        request.response
          ..headers.contentType = ContentType('application', 'json')
          ..statusCode = HttpStatus.badRequest
          ..write('{"success":false,"message":"Error"}')
          ..close();
      } else if (path == '/html.pdf') {
        request.response
          ..headers.contentType = ContentType('text', 'html')
          ..statusCode = HttpStatus.ok
          ..write('<html><body>Not a PDF</body></html>')
          ..close();
      } else if (path == '/403.pdf') {
        request.response
          ..statusCode = HttpStatus.forbidden
          ..close();
      } else {
        request.response
          ..statusCode = HttpStatus.notFound
          ..close();
      }
    });
  });

  tearDownAll(() async {
    await server.close();
  });

  test('Valid PDF response -> save -> success', () async {
    const service = FileDownloadService(StorageManager());
    final result = await service.downloadFile(
      url: '$baseUrl/valid.pdf',
      filename: 'test_valid.pdf',
    );
    expect(result.isSuccess, true);
    final filePath = result.dataOrNull!;
    final file = File(filePath);
    expect(await file.exists(), true);
    expect(await file.length(), 15);
    
    // Clean up
    await file.delete();
  });

  test('Valid Receipt PDF response -> save -> success', () async {
    const service = FileDownloadService(StorageManager());
    final result = await service.downloadFile(
      url: '$baseUrl/receipt.pdf',
      filename: 'test_receipt.pdf',
    );
    expect(result.isSuccess, true);
    final filePath = result.dataOrNull!;
    final file = File(filePath);
    expect(await file.exists(), true);
    
    // Clean up
    await file.delete();
  });

  test('Empty response -> fail', () async {
    const service = FileDownloadService(StorageManager());
    final result = await service.downloadFile(
      url: '$baseUrl/empty.pdf',
      filename: 'test_empty.pdf',
    );
    expect(result.isFailure, true);
  });

  test('JSON error response -> fail -> do not create PDF', () async {
    const service = FileDownloadService(StorageManager());
    final result = await service.downloadFile(
      url: '$baseUrl/json_error.pdf',
      filename: 'test_json_error.pdf',
    );
    expect(result.isFailure, true);
    
    // Ensure file doesn't exist
    final dir = await const StorageManager().getDownloadsDirectoryPath();
    final file = File('$dir/test_json_error.pdf');
    expect(await file.exists(), false);
  });

  test('HTML response -> fail', () async {
    const service = FileDownloadService(StorageManager());
    final result = await service.downloadFile(
      url: '$baseUrl/html.pdf',
      filename: 'test_html.pdf',
    );
    expect(result.isFailure, true);
  });

  test('HTTP 403 Forbidden -> fail -> do not save as PDF', () async {
    const service = FileDownloadService(StorageManager());
    final result = await service.downloadFile(
      url: '$baseUrl/403.pdf',
      filename: 'test_403.pdf',
    );
    expect(result.isFailure, true);
    
    final dir = await const StorageManager().getDownloadsDirectoryPath();
    final file = File('$dir/test_403.pdf');
    expect(await file.exists(), false);
  });

  group('StorageManager tests', () {
    test('getDownloadsDirectoryPath returns a valid, writable path', () async {
      const storage = StorageManager();
      final path = await storage.getDownloadsDirectoryPath();
      expect(path, isNotEmpty);
      expect(path.contains('/storage/emulated/0/Documents'), false);
      expect(path.contains('/storage/emulated/0/Download'), false);

      final dir = Directory(path);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      expect(await dir.exists(), true);

      // Verify file write/read back
      final testFile = File('$path/storage_manager_test.txt');
      await testFile.writeAsString('EduPulse Test');
      expect(await testFile.exists(), true);
      expect(await testFile.readAsString(), 'EduPulse Test');

      // Clean up
      await testFile.delete();
    });
  });
}
