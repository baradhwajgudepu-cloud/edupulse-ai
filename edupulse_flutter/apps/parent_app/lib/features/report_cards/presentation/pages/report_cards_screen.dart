import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:edupulse_auth/edupulse_auth.dart';
import 'package:edupulse_files/edupulse_files.dart';
import 'package:intl/intl.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import 'package:parent_app/features/homework/presentation/providers/homework_provider.dart';

String formatDate(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty || dateStr == 'N/A') return 'N/A';
  try {
    final parsed = DateTime.parse(dateStr);
    return DateFormat('dd MMM yyyy').format(parsed);
  } catch (_) {
    return dateStr;
  }
}

final reportCardProvider = FutureProvider.family<Map<String, dynamic>, ({String studentId, String academicYearId})>((ref, arg) async {
  final apiClient = ref.read(apiClientProvider);
  final result = await apiClient.get(
    '/report-cards/student/${arg.studentId}',
    queryParameters: {
      'academic_year_id': arg.academicYearId,
    },
    mapper: (json) => json as Map<String, dynamic>,
  );
  return result.when(
    onSuccess: (data) => data['data'] as Map<String, dynamic>,
    onFailure: (failure) => throw Exception(failure.message),
  );
});

class ReportCardsScreen extends ConsumerWidget {
  const ReportCardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    // Fetch active student from dashboard state
    String studentId = 'a8bc2968-3d0d-431d-ab06-b90f518a0801';
    String academicYearId = '113282c1-9831-4e54-a00e-1746d3c2829d';
    String studentName = 'Rahul Sharma';
    final dbState = ref.watch(dashboardStateProvider);
    if (dbState is DashboardSuccess) {
      final selected = dbState.data.selectedStudent;
      if (selected != null) {
        studentId = selected.id;
        academicYearId = selected.academicYearId;
        studentName = selected.fullName;
      }
    }

    final reportAsync = ref.watch(reportCardProvider((studentId: studentId, academicYearId: academicYearId)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Cards'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: reportAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: EdgeInsets.all(spacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assessment_outlined, size: 64, color: theme.colorScheme.outline),
                SizedBox(height: spacing.md),
                Text(
                  'No report cards published',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: spacing.xs),
                Text(
                  'There are no report cards published for the active student in this academic year.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        data: (card) {
          final status = card['status'] as String? ?? 'DRAFT';
          final publishedAtRaw = card['published_at'] as String? ?? 'N/A';
          final publishedAt = formatDate(publishedAtRaw);
          final aiMetrics = (card['ai_metrics'] as Map?) ?? {};
          final riskLevel = aiMetrics['risk_level'] as String? ?? 'LOW';
          final aiNarrative = aiMetrics['ai_narrative'] as String? ?? 'No analysis narrative has been generated yet.';

          final riskColor = riskLevel == 'HIGH'
              ? Colors.red
              : riskLevel == 'MEDIUM'
                  ? Colors.orange
                  : Colors.green;

          return RefreshIndicator(
            onRefresh: () => ref.refresh(reportCardProvider((studentId: studentId, academicYearId: academicYearId)).future),
            child: ListView(
              padding: EdgeInsets.all(spacing.md),
              children: [
                // Child Context Banner
                Container(
                  padding: EdgeInsets.all(spacing.sm),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(radius.sm),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.face_rounded, color: theme.colorScheme.onSecondaryContainer),
                      SizedBox(width: spacing.sm),
                      Text(
                        'Student: $studentName',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: spacing.md),

                // Report Card Details Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius.md)),
                  child: Padding(
                    padding: EdgeInsets.all(spacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Status',
                              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Chip(
                              label: Text(status),
                              backgroundColor: status == 'PUBLISHED' ? Colors.green.shade100 : Colors.orange.shade100,
                            ),
                          ],
                        ),
                        SizedBox(height: spacing.md),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Published Date', style: theme.textTheme.bodyMedium),
                            Text(publishedAt, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: spacing.md),

                // AI Narrative card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius.md)),
                  child: Padding(
                    padding: EdgeInsets.all(spacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.psychology_rounded, color: theme.colorScheme.primary),
                                STransition(width: spacing.sm),
                                Text(
                                  'EduPulse AI Insights',
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
                              decoration: BoxDecoration(
                                color: riskColor.withValues(alpha: 0.1),
                                border: Border.all(color: riskColor),
                                borderRadius: BorderRadius.circular(radius.sm),
                              ),
                              child: Text(
                                'Risk Level: $riskLevel',
                                style: TextStyle(color: riskColor, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: spacing.md),
                        Text(
                          aiNarrative,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: spacing.lg),

                // Download Card
                ReportCardDownloadWidget(
                  studentId: studentId,
                  schoolId: card['school_id'] as String? ?? '16730f87-bf8d-44e0-acf9-4b055a778b58',
                  studentName: studentName,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class STransition extends StatelessWidget {
  final double width;
  const STransition({super.key, required this.width});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: width);
  }
}

class ReportCardDownloadWidget extends ConsumerStatefulWidget {
  final String studentId;
  final String schoolId;
  final String studentName;

  const ReportCardDownloadWidget({
    super.key,
    required this.studentId,
    required this.schoolId,
    required this.studentName,
  });

  @override
  ConsumerState<ReportCardDownloadWidget> createState() => _ReportCardDownloadWidgetState();
}

class _ReportCardDownloadWidgetState extends ConsumerState<ReportCardDownloadWidget> {
  double _progress = 0.0;
  bool _isDownloading = false;
  String? _downloadedPath;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkFileExists();
  }

  Future<String> _getSavePath() async {
    final storage = ref.read(storageManagerProvider);
    final dir = await storage.getDownloadsDirectoryPath();
    final filename = 'EduPulse_ReportCard_${widget.studentName.replaceAll(' ', '_')}.pdf';
    return '$dir/$filename';
  }

  Future<void> _checkFileExists() async {
    final path = await _getSavePath();
    final exists = await File(path).exists();
    if (exists) {
      setState(() {
        _downloadedPath = path;
      });
    }
  }

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _errorMessage = null;
      _downloadedPath = null;
    });

    final config = ref.read(buildConfigProvider);
    final session = ref.read(sessionManagerProvider);
    final token = await session.getAccessToken();

    final cleanBaseUrl = config.apiBaseUrl.endsWith('/')
        ? config.apiBaseUrl.substring(0, config.apiBaseUrl.length - 1)
        : config.apiBaseUrl;
    final url = '$cleanBaseUrl/report-cards/download/${widget.studentId}?school_id=${widget.schoolId}';
    final headers = {
      'Authorization': 'Bearer $token',
      'X-Tenant-ID': config.tenantId,
      'X-School-ID': widget.schoolId,
    };

    final downloadUseCase = ref.read(downloadAttachmentUseCaseProvider);
    final filename = 'EduPulse_ReportCard_${widget.studentName.replaceAll(' ', '_')}.pdf';
    final result = await downloadUseCase(
      url: url,
      filename: filename,
      headers: headers,
      onProgress: (received, total) {
        if (total > 0) {
          setState(() {
            _progress = received / total;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _isDownloading = false;
      });

      result.when(
        onSuccess: (path) {
          setState(() {
            _downloadedPath = path;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Report card downloaded successfully'),
              action: SnackBarAction(
                label: 'Open',
                onPressed: _openFile,
              ),
            ),
          );
          _openFile(); // Automatically open file on success
        },
        onFailure: (failure) {
          setState(() {
            _errorMessage = failure.message;
          });
        },
      );
    }
  }

  Future<void> _openFile() async {
    if (_downloadedPath != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => FileViewer(
            path: _downloadedPath!,
            title: 'Report Card - ${widget.studentName}',
          ),
        ),
      );
    }
  }

  Future<void> _shareFile() async {
    if (_downloadedPath != null) {
      const share = ShareService();
      await share.shareFile(_downloadedPath!, title: 'Report Card');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sharing Report Card PDF...'),
        ),
      );
    }
  }

  void _showConflictDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('File Already Exists'),
        content: const Text('A report card for this student is already downloaded on your device. Would you like to open it or replace it with a new download?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _openFile();
            },
            child: const Text('Open'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _startDownload();
            },
            child: const Text('Replace'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius.md)),
      child: Padding(
        padding: EdgeInsets.all(spacing.md),
        child: Column(
          children: [
            const Icon(Icons.picture_as_pdf_rounded, size: 48, color: Colors.red),
            SizedBox(height: spacing.sm),
            Text(
              'Official Report Card Document',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: spacing.xs),
            Text(
              '${widget.studentName.replaceAll(' ', '_')}_ReportCard.pdf',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: spacing.md),

            if (_isDownloading) ...[
              LinearProgressIndicator(value: _progress),
              SizedBox(height: spacing.xs),
              Text(
                'Downloading: ${(_progress * 100).toStringAsFixed(0)}%',
                style: theme.textTheme.bodySmall,
              ),
            ] else if (_downloadedPath != null) ...[
              Container(
                padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green),
                  borderRadius: BorderRadius.circular(radius.sm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                    SizedBox(width: spacing.xs),
                    Text(
                      'Download complete',
                      style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),
              SizedBox(height: spacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _openFile,
                    icon: const Icon(Icons.menu_book_rounded),
                    label: const Text('Open'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                    ),
                  ),
                  SizedBox(width: spacing.sm),
                  OutlinedButton.icon(
                    onPressed: _shareFile,
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Share'),
                  ),
                  SizedBox(width: spacing.sm),
                  IconButton(
                    onPressed: _startDownload,
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Redownload',
                  ),
                ],
              ),
            ] else ...[
              if (_errorMessage != null) ...[
                Container(
                  padding: EdgeInsets.all(spacing.sm),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(radius.sm),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: spacing.md),
              ],
              ElevatedButton.icon(
                onPressed: () async {
                  final path = await _getSavePath();
                  final exists = await File(path).exists();
                  if (exists) {
                    _showConflictDialog();
                  } else {
                    _startDownload();
                  }
                },
                icon: const Icon(Icons.download_rounded),
                label: const Text('Download PDF Report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
