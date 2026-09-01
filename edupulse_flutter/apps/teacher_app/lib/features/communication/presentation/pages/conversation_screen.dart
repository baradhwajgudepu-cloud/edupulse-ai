import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:edupulse_models/edupulse_models.dart';
import 'package:go_router/go_router.dart';
import '../providers/communication_provider.dart';
import 'package:edupulse_api/edupulse_api.dart';
import 'package:edupulse_config/edupulse_config.dart';
import 'package:edupulse_network/edupulse_network.dart';

class TeacherConversationScreen extends ConsumerStatefulWidget {
  final String requestId;

  const TeacherConversationScreen({super.key, required this.requestId});

  @override
  ConsumerState<TeacherConversationScreen> createState() => _TeacherConversationScreenState();
}

class _TeacherConversationScreenState extends ConsumerState<TeacherConversationScreen> {
  final _replyController = TextEditingController();
  final _scrollController = ScrollController();

  String? _attachmentName;
  Uint8List? _attachmentBytes;
  String? _attachmentMime;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(teacherDetailsProvider(widget.requestId).notifier).fetchDetails();
      ref.read(teacherDetailsProvider(widget.requestId).notifier).fetchAiInsights();
    });
  }

  @override
  void dispose() {
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'doc', 'docx', 'xls', 'xlsx', 'txt'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          final sizeMb = file.size / (1024 * 1024);
          if (sizeMb > 10.0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('File size exceeds the 10MB limit.')),
            );
            return;
          }
          setState(() {
            _attachmentName = file.name;
            _attachmentBytes = file.bytes;
            _attachmentMime = _getMimeType(file.extension);
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    }
  }

  String _getMimeType(String? ext) {
    switch (ext?.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty && _attachmentBytes == null) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    final detailsNotifier = ref.read(teacherDetailsProvider(widget.requestId).notifier);
    final client = ref.read(communicationApiClientProvider);

    final msgResult = await client.replyToRequest(
      requestId: widget.requestId,
      message: text.isNotEmpty ? text : 'Sent an attachment.',
    );

    await msgResult.when(
      onSuccess: (msg) async {
        if (_attachmentBytes != null && _attachmentName != null) {
          await client.uploadAttachment(
            messageId: msg.id,
            fileName: _attachmentName!,
            fileBytes: _attachmentBytes!,
            mimeType: _attachmentMime ?? 'application/octet-stream',
          );
        }
        _replyController.clear();
        setState(() {
          _attachmentName = null;
          _attachmentBytes = null;
          _attachmentMime = null;
          _isSending = false;
        });
        detailsNotifier.fetchDetails();
        detailsNotifier.fetchAiInsights(); // Reload insights on reply
        
        Future.delayed(const Duration(milliseconds: 300), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      },
      onFailure: (failure) {
        setState(() {
          _isSending = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send reply: ${failure.message}')),
        );
      },
    );
  }

  Future<void> _updateRequestStatus(String status) async {
    final detailsNotifier = ref.read(teacherDetailsProvider(widget.requestId).notifier);
    await detailsNotifier.updateStatus(status);
    ref.read(teacherQueriesProvider.notifier).fetchRequests();
  }

  Future<void> _escalateRequest() async {
    final detailsNotifier = ref.read(teacherDetailsProvider(widget.requestId).notifier);
    await detailsNotifier.escalate();
    ref.read(teacherQueriesProvider.notifier).fetchRequests();
  }

  Future<void> _downloadFile(CommunicationAttachment att) async {
    final config = ref.read(buildConfigProvider);
    final url = '${config.apiBaseUrl}${att.fileUrl}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Downloading ${att.fileName} from $url...')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    final detailsState = ref.watch(teacherDetailsProvider(widget.requestId));

    if (detailsState.isLoading && detailsState.detail == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (detailsState.errorMessage != null && detailsState.detail == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Conversation Thread')),
        body: Center(child: Text(detailsState.errorMessage!)),
      );
    }

    final detail = detailsState.detail;
    if (detail == null) {
      return const Scaffold(
        body: Center(child: Text('Request not found.')),
      );
    }

    final req = detail.request;
    final messages = detail.messages;

    return Scaffold(
      appBar: AppBar(
        title: Text(req.subject, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          // Dynamic Actions Menu based on the request state
          _buildActionsMenu(req),
        ],
      ),
      body: Column(
        children: [
          // Header info
          Container(
            padding: EdgeInsets.all(spacing.md),
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Category: ${req.category}', style: theme.textTheme.bodySmall),
                    Text('Priority: ${req.priority}', style: theme.textTheme.bodySmall),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Status: ${req.status}', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                    Text('Recipient: ${req.recipientType}', style: theme.textTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ),

          // Messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.all(spacing.md),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                final isMe = msg.senderRole == 'TEACHER' || msg.senderRole == 'CLASS_TEACHER';

                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.only(bottom: spacing.md),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    padding: EdgeInsets.all(spacing.md),
                    decoration: BoxDecoration(
                      color: isMe 
                          ? theme.colorScheme.primary.withValues(alpha: 0.1) 
                          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(radius.md),
                        topRight: Radius.circular(radius.md),
                        bottomLeft: isMe ? Radius.circular(radius.md) : Radius.zero,
                        bottomRight: isMe ? Radius.zero : Radius.circular(radius.md),
                      ),
                      border: Border.all(
                        color: isMe 
                            ? theme.colorScheme.primary.withValues(alpha: 0.3) 
                            : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isMe ? 'You' : msg.senderRole,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isMe ? theme.colorScheme.primary : theme.colorScheme.outline,
                              ),
                            ),
                            Text(
                              _formatTime(msg.createdAt),
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 10,
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: spacing.xs),
                        Text(
                          msg.message,
                          style: theme.textTheme.bodyMedium,
                        ),
                        if (msg.attachments.isNotEmpty) ...[
                          SizedBox(height: spacing.sm),
                          const Divider(),
                          ...msg.attachments.map((att) {
                            return InkWell(
                              onTap: () => _downloadFile(att),
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: spacing.xs),
                                child: Row(
                                  children: [
                                    Icon(Icons.insert_drive_file_outlined, size: 16, color: theme.colorScheme.primary),
                                    SizedBox(width: spacing.xs),
                                    Expanded(
                                      child: Text(
                                        att.fileName,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.primary,
                                          decoration: TextDecoration.underline,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      '(${_formatBytes(att.fileSize)})',
                                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: theme.colorScheme.outline),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // AI Suggestions Panel
          if (req.status != 'RESOLVED' && detailsState.aiInsights != null)
            _buildAiSuggestionsPanel(detailsState.aiInsights!, spacing, radius, theme),

          // Input bar
          if (req.status != 'RESOLVED')
            Container(
              padding: EdgeInsets.all(spacing.sm),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_attachmentName != null)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
                        margin: EdgeInsets.only(bottom: spacing.xs),
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        child: Row(
                          children: [
                            const Icon(Icons.attach_file, size: 16),
                            SizedBox(width: spacing.xs),
                            Expanded(
                              child: Text(
                                _attachmentName!,
                                style: theme.textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                setState(() {
                                  _attachmentName = null;
                                  _attachmentBytes = null;
                                  _attachmentMime = null;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline_rounded),
                          onPressed: _pickAttachment,
                        ),
                        Expanded(
                          child: TextField(
                            controller: _replyController,
                            decoration: const InputDecoration(
                              hintText: 'Type your reply...',
                              border: InputBorder.none,
                            ),
                            maxLines: null,
                          ),
                        ),
                        _isSending
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : IconButton(
                                icon: Icon(Icons.send_rounded, color: theme.colorScheme.primary),
                                onPressed: _sendReply,
                              ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionsMenu(CommunicationRequest req) {
    final status = req.status.toUpperCase();
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'ESCALATE') {
          _escalateRequest();
        } else {
          _updateRequestStatus(value);
        }
      },
      itemBuilder: (context) {
        final List<PopupMenuEntry<String>> items = [];

        if (status == 'OPEN') {
          items.addAll([
            const PopupMenuItem(value: 'ACKNOWLEDGED', child: Text('Acknowledge Request')),
            const PopupMenuItem(value: 'IN_PROGRESS', child: Text('Mark In Progress')),
            const PopupMenuItem(value: 'RESOLVED', child: Text('Mark Resolved')),
          ]);
        } else if (status == 'ACKNOWLEDGED') {
          items.addAll([
            const PopupMenuItem(value: 'IN_PROGRESS', child: Text('Mark In Progress')),
            const PopupMenuItem(value: 'RESOLVED', child: Text('Mark Resolved')),
          ]);
        } else if (status == 'IN_PROGRESS' || status == 'REOPENED') {
          items.addAll([
            const PopupMenuItem(value: 'WAITING_FOR_PARENT', child: Text('Request Info (Waiting on Parent)')),
            const PopupMenuItem(value: 'ESCALATE', child: Text('Escalate to Principal')),
            const PopupMenuItem(value: 'RESOLVED', child: Text('Mark Resolved')),
          ]);
        } else if (status == 'WAITING_FOR_PARENT') {
          items.addAll([
            const PopupMenuItem(value: 'IN_PROGRESS', child: Text('Mark In Progress')),
            const PopupMenuItem(value: 'RESOLVED', child: Text('Mark Resolved')),
          ]);
        } else if (status == 'RESOLVED') {
          items.add(const PopupMenuItem(value: 'REOPENED', child: Text('Reopen Request')));
        }

        if (items.isEmpty) {
          items.add(const PopupMenuItem(enabled: false, child: Text('No actions available')));
        }

        return items;
      },
    );
  }

  Widget _buildAiSuggestionsPanel(
    Map<String, dynamic> insights,
    AppSpacing spacing,
    AppRadius radius,
    ThemeData theme,
  ) {
    final suggestions = insights['reply_suggestions'] as List? ?? [];
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(spacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 14, color: theme.colorScheme.primary),
              SizedBox(width: spacing.xs),
              Text(
                'AI Smart Replies (Sentiment: ${insights['sentiment'] ?? 'N/A'})',
                style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: spacing.sm),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: suggestions.length,
              separatorBuilder: (context, index) => SizedBox(width: spacing.sm),
              itemBuilder: (context, index) {
                final suggestion = suggestions[index] as String;
                return ActionChip(
                  label: Text(suggestion),
                  labelStyle: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                  onPressed: () {
                    setState(() {
                      _replyController.text = suggestion;
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }
}
