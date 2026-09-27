import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:edupulse_network/edupulse_network.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../providers/school_setup_providers.dart';

/// Provider to fetch authenticated school logo bytes with cache-busting version parameter.
final schoolLogoBytesProvider = FutureProvider.family<Uint8List?, ({String schoolId, String? version})>((ref, arg) async {
  final dio = ref.watch(dioProvider);
  try {
    final response = await dio.get<List<int>>(
      '/schools/${arg.schoolId}/logo',
      queryParameters: arg.version != null && arg.version!.isNotEmpty ? {'v': arg.version} : null,
      options: Options(responseType: ResponseType.bytes),
    );
    if (response.data != null && response.data!.isNotEmpty) {
      return Uint8List.fromList(response.data!);
    }
  } catch (e) {
    return null;
  }
  return null;
});

class SchoolLogoUploader extends ConsumerStatefulWidget {
  final String schoolId;
  final String? currentLogoUrl;
  final String? logoUpdatedAt;
  final String schoolName;
  final ValueChanged<String?>? onLogoChanged;

  const SchoolLogoUploader({
    super.key,
    required this.schoolId,
    this.currentLogoUrl,
    this.logoUpdatedAt,
    required this.schoolName,
    this.onLogoChanged,
  });

  @override
  ConsumerState<SchoolLogoUploader> createState() => _SchoolLogoUploaderState();
}

class _SchoolLogoUploaderState extends ConsumerState<SchoolLogoUploader> {
  bool _isLoading = false;
  String? _activeLogoUrl;
  String? _activeVersion;

  @override
  void initState() {
    super.initState();
    _activeLogoUrl = widget.currentLogoUrl;
    _activeVersion = widget.logoUpdatedAt;
  }

  @override
  void didUpdateWidget(covariant SchoolLogoUploader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentLogoUrl != widget.currentLogoUrl || oldWidget.logoUpdatedAt != widget.logoUpdatedAt) {
      setState(() {
        _activeLogoUrl = widget.currentLogoUrl;
        _activeVersion = widget.logoUpdatedAt;
      });
    }
  }

  Future<void> _handleUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to read selected image bytes.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (file.size > 5 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logo image must be smaller than 5 MB.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final newUrl = await ref.read(settingsNotifierProvider.notifier).uploadSchoolLogo(
        schoolId: widget.schoolId,
        fileBytes: file.bytes!,
        fileName: file.name,
      );

      if (mounted) {
        if (newUrl != null) {
          final nowVersion = DateTime.now().millisecondsSinceEpoch.toString();
          setState(() {
            _activeLogoUrl = newUrl;
            _activeVersion = nowVersion;
          });

          // Invalidate logo bytes cache for immediate live rendering
          ref.invalidate(schoolLogoBytesProvider);
          ref.invalidate(schoolDetailProvider(widget.schoolId));
          ref.read(schoolsListProvider.notifier).fetchSchools();

          widget.onLogoChanged?.call(newUrl);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('School logo uploaded successfully.'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          final err = ref.read(settingsNotifierProvider).error;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unable to upload school logo: ${err ?? "Please try again."}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to upload school logo. Please try again: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove School Logo'),
        content: Text('Are you sure you want to remove the logo for ${widget.schoolName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final success = await ref.read(settingsNotifierProvider.notifier).deleteSchoolLogo(
        schoolId: widget.schoolId,
      );

      if (mounted) {
        if (success) {
          setState(() {
            _activeLogoUrl = null;
            _activeVersion = null;
          });

          ref.invalidate(schoolLogoBytesProvider);
          ref.invalidate(schoolDetailProvider(widget.schoolId));
          ref.read(schoolsListProvider.notifier).fetchSchools();

          widget.onLogoChanged?.call(null);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('School logo removed successfully.'),
            ),
          );
        } else {
          final err = ref.read(settingsNotifierProvider).error;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to remove logo: $err'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove logo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasLogo = _activeLogoUrl != null && _activeLogoUrl!.trim().isNotEmpty;
    final logoAsync = hasLogo
        ? ref.watch(schoolLogoBytesProvider((
            schoolId: widget.schoolId,
            version: _activeVersion,
          )))
        : const AsyncValue<Uint8List?>.data(null);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield_outlined, color: theme.colorScheme.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  'School Logo',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'This logo will appear on report cards, official documents, and school-facing applications.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),

            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 540;

                final previewBox = Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: hasLogo ? theme.colorScheme.primary.withValues(alpha: 0.3) : theme.colorScheme.outlineVariant,
                      width: 1.5,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Center(
                    child: _isLoading
                        ? const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : hasLogo
                            ? logoAsync.when(
                                data: (bytes) {
                                  if (bytes != null && bytes.isNotEmpty) {
                                    return Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Image.memory(
                                        bytes,
                                        fit: BoxFit.contain,
                                      ),
                                    );
                                  }
                                  return Icon(Icons.school, size: 52, color: theme.colorScheme.primary);
                                },
                                loading: () => const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                error: (_, __) => Icon(Icons.broken_image, size: 44, color: Colors.grey.shade400),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.school_outlined, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 4),
                                  Text(
                                    'No Logo',
                                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                  ),
                );

                final detailsAndActions = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasLogo ? 'Current Logo Active' : 'No school logo uploaded',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: hasLogo ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Recommended: 1:1 aspect ratio, minimum 512×512.\nSupported formats: PNG, JPG, JPEG, WEBP (Max 5MB).',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        if (!hasLogo)
                          FilledButton.icon(
                            onPressed: _isLoading ? null : _handleUpload,
                            icon: const Icon(Icons.upload_file, size: 18),
                            label: const Text('Upload School Logo'),
                          )
                        else ...[
                          FilledButton.tonalIcon(
                            onPressed: _isLoading ? null : _handleUpload,
                            icon: const Icon(Icons.sync, size: 18),
                            label: const Text('Replace Logo'),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: theme.colorScheme.error,
                              side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5)),
                            ),
                            onPressed: _isLoading ? null : _handleDelete,
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Remove'),
                          ),
                        ],
                      ],
                    ),
                  ],
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: previewBox),
                      const SizedBox(height: 16),
                      detailsAndActions,
                    ],
                  );
                } else {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      previewBox,
                      const SizedBox(width: 24),
                      Expanded(child: detailsAndActions),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
