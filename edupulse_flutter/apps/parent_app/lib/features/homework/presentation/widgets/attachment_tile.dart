import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_localization/edupulse_localization.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../providers/homework_provider.dart';

class AttachmentTile extends ConsumerStatefulWidget {
  final String url;

  const AttachmentTile({super.key, required this.url});

  @override
  ConsumerState<AttachmentTile> createState() => _AttachmentTileState();
}

class _AttachmentTileState extends ConsumerState<AttachmentTile> {
  bool _isDownloading = false;

  Future<void> _download() async {
    setState(() {
      _isDownloading = true;
    });

    final local = EduLocalization.of(context);
    final downloadUsecase = ref.read(downloadAttachmentUseCaseProvider);
    final result = await downloadUsecase(url: widget.url);

    if (mounted) {
      setState(() {
        _isDownloading = false;
      });

      result.when(
        onSuccess: (filePath) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                local?.translate('download_success') ??
                    'Attachment downloaded successfully.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        onFailure: (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(failure.message),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final local = EduLocalization.of(context);
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    final filename = widget.url.split('/').lastOrNull ?? 'attachment.pdf';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius.xs),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      child: ListTile(
        leading: Icon(
          Icons.insert_drive_file_outlined,
          color: theme.colorScheme.primary,
        ),
        title: Text(
          filename,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: _isDownloading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : IconButton(
                icon: const Icon(Icons.download),
                onPressed: _download,
                tooltip: local?.translate('download') ?? 'Download',
              ),
      ),
    );
  }
}
