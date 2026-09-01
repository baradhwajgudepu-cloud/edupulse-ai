import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_files/edupulse_files.dart';

class DownloadAttachmentUseCase {
  final FileDownloadService _fileDownloadService;

  const DownloadAttachmentUseCase(this._fileDownloadService);

  Future<ApiResult<String>> call({
    required String url,
    String? filename,
    Map<String, String>? headers,
    void Function(int received, int total)? onProgress,
  }) {
    return _fileDownloadService.downloadFile(
      url: url,
      filename: filename,
      headers: headers,
      onProgress: onProgress,
    );
  }
}
