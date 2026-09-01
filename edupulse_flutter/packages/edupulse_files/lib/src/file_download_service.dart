import 'dart:io';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_core/edupulse_core.dart';
import 'storage_manager.dart';

class FileDownloadService {
  final StorageManager _storageManager;
  final Dio? _dio;

  const FileDownloadService(this._storageManager, [this._dio]);

  Dio get dio => _dio ?? Dio();

  Future<ApiResult<String>> downloadFile({
    required String url,
    String? filename,
    Map<String, String>? headers,
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      final dir = await _storageManager.getDownloadsDirectoryPath();
      final finalFilename = filename ??
          (url.split('/').lastOrNull?.split('?').firstOrNull ?? 'document.pdf');
      final savePath = '$dir/$finalFilename';

      EduLogger.i('[FileDownloadService] Resolved Storage Path: $dir (File filename: $finalFilename)');

      // Perform request using the injected or default Dio client
      final currentDio = dio;
      
      // Safety/Development logging (no sensitive credentials/tokens logged)
      final uri = Uri.tryParse(url);
      final host = uri?.host ?? 'unknown';
      final path = uri?.path ?? url;
      EduLogger.i('[FileDownloadService] Downloading from Path: $path | Host: $host');

      final response = await currentDio.get<List<int>>(
        url,
        options: Options(
          headers: headers,
          responseType: ResponseType.bytes,
        ),
        onReceiveProgress: onProgress,
      );

      final contentType = response.headers.value('content-type');
      final byteLength = response.data?.length ?? 0;
      EduLogger.i('[FileDownloadService] Download response: Status: ${response.statusCode} | Content-Type: $contentType | Byte Length: $byteLength');

      if (contentType != null && contentType.contains('application/json')) {
        final bodyString = String.fromCharCodes(response.data!);
        return ApiResult.failure(ApiFailure(
          message: 'Backend returned validation error: $bodyString',
          type: ApiFailureType.unknown,
        ));
      }

      if (response.statusCode != 200) {
        return ApiResult.failure(ApiFailure(
          message: 'Server returned HTTP ${response.statusCode}',
          type: ApiFailureType.unknown,
        ));
      }

      final fileBytes = response.data!;
      if (fileBytes.isEmpty) {
        return const ApiResult.failure(ApiFailure(
          message: 'Downloaded file is empty (0 bytes).',
          type: ApiFailureType.unknown,
        ));
      }

      // Check if it is supposed to be a PDF
      final isPdf = finalFilename.toLowerCase().endsWith('.pdf');
      if (isPdf) {
        final isReceipt = finalFilename.toLowerCase().contains('receipt');
        final errorMsg = isReceipt
            ? 'Receipt could not be downloaded because the server did not return a valid PDF.'
            : 'The report card file could not be opened.';

        // PDF Validation: Response bytes must start with %PDF- (HEX: 25 50 44 46 2D)
        if (fileBytes.length < 5 ||
            fileBytes[0] != 37 || // %
            fileBytes[1] != 80 || // P
            fileBytes[2] != 68 || // D
            fileBytes[3] != 70 || // F
            fileBytes[4] != 45) { // -
          _logPdfValidationFailed(url, response.statusCode, contentType, fileBytes, 'Invalid or missing PDF signature.');
          return ApiResult.failure(ApiFailure(
            message: errorMsg,
            type: ApiFailureType.unknown,
          ));
        }
      }

      // Ensure directory exists and write bytes
      final file = File(savePath);
      final parentDir = file.parent;
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
      }
      await file.writeAsBytes(fileBytes);
      EduLogger.i('[FileDownloadService] File created and written successfully at: $savePath');

      // Verify file exists and has size > 0
      if (!await file.exists()) {
        return const ApiResult.failure(ApiFailure(
          message: 'Failed to save downloaded file on disk.',
          type: ApiFailureType.unknown,
        ));
      }

      final fileSize = await file.length();
      if (fileSize == 0) {
        return const ApiResult.failure(ApiFailure(
          message: 'Saved file on disk is empty (0 bytes).',
          type: ApiFailureType.unknown,
        ));
      }

      // Read back the saved file and verify the signature remains correct
      final savedFileBytes = await file.readAsBytes();
      if (isPdf) {
        if (savedFileBytes.length < 5 ||
            savedFileBytes[0] != 37 ||
            savedFileBytes[1] != 80 ||
            savedFileBytes[2] != 68 ||
            savedFileBytes[3] != 70 ||
            savedFileBytes[4] != 45) {
          return const ApiResult.failure(ApiFailure(
            message: 'Saved file validation failed. The file is corrupted.',
            type: ApiFailureType.unknown,
          ));
        }
      }

      // Determine MIME type
      String mimeType = 'application/octet-stream';
      if (savePath.toLowerCase().endsWith('.pdf')) {
        mimeType = 'application/pdf';
      } else if (savePath.toLowerCase().endsWith('.png')) {
        mimeType = 'image/png';
      } else if (savePath.toLowerCase().endsWith('.jpg') || savePath.toLowerCase().endsWith('.jpeg')) {
        mimeType = 'image/jpeg';
      }

      // Server Content-Length consistency logging
      final serverContentLengthStr = response.headers.value('content-length');
      final bytesReceived = fileBytes.length;
      final bytesWritten = fileBytes.length;
      final bytesReadBack = savedFileBytes.length;

      EduLogger.i('--- CONTENT-LENGTH / BYTES CONSISTENCY ---');
      EduLogger.i('Server Content-Length: $serverContentLengthStr');
      EduLogger.i('Bytes received by Flutter: $bytesReceived');
      EduLogger.i('Bytes written to file: $bytesWritten');
      EduLogger.i('Bytes read back from file: $bytesReadBack');
      EduLogger.i('------------------------------------------');

      // Detailed logging for auditing (Verification logs)
      EduLogger.i('--- DOWNLOAD VERIFICATION SUCCESS ---');
      EduLogger.i('Download URL: $url');
      EduLogger.i('Response status: ${response.statusCode}');
      EduLogger.i('Content-Type: $contentType');
      EduLogger.i('Bytes received: ${fileBytes.length}');
      EduLogger.i('Saved file path: $savePath');
      EduLogger.i('File size: $fileSize bytes');
      EduLogger.i('MIME type: $mimeType');
      EduLogger.i('--------------------------------------');

      return ApiResult.success(savePath);
    } on DioException catch (e) {
      String message = 'Unable to download the report card. Please check your connection.';
      if (e.response != null) {
        final statusCode = e.response?.statusCode;
        if (statusCode == 401) {
          message = 'Your session has expired. Please log in again.';
        } else if (statusCode == 403) {
          message = 'You are not authorized to access this report card.';
        } else if (statusCode == 404) {
          message = 'Report card not found.';
        } else {
          try {
            final data = e.response?.data;
            if (data is List<int>) {
              final bodyString = String.fromCharCodes(data);
              message = 'Failed to download: $bodyString';
            } else {
              message = 'Failed to download: ${data.toString()}';
            }
          } catch (_) {}
        }
      }
      return ApiResult.failure(ApiFailure(
        message: message,
        type: ApiFailureType.unknown,
      ));
    } catch (e) {
      return ApiResult.failure(ApiFailure(
        message: 'Failed to download file: ${e.toString()}',
        type: ApiFailureType.unknown,
      ));
    }
  }

  void _logPdfValidationFailed(
    String url,
    int? status,
    String? contentType,
    List<int> bytes,
    String reason,
  ) {
    final firstBytes = bytes.take(20).toList();
    final hexSignature = firstBytes
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' ');
    final asciiSignature = String.fromCharCodes(
        firstBytes.map((b) => (b >= 32 && b <= 126) ? b : 46));

    EduLogger.e('PDF VALIDATION FAILED');
    EduLogger.e('Expected PDF signature: %PDF-');
    EduLogger.e('Actual response signature: (HEX) $hexSignature');
    EduLogger.e('Actual response signature: (ASCII) $asciiSignature');
    EduLogger.e('HTTP status: $status');
    EduLogger.e('Content-Type: $contentType');
    EduLogger.e('Byte count: ${bytes.length}');
    EduLogger.e('Reason: $reason');
  }
}
