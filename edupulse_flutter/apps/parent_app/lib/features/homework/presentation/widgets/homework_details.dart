import 'package:flutter/material.dart';
import 'package:edupulse_localization/edupulse_localization.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../../domain/entities/homework.dart';
import 'attachment_tile.dart';

class HomeworkDetails extends StatelessWidget {
  final HomeworkEntity homework;

  const HomeworkDetails({super.key, required this.homework});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final local = EduLocalization.of(context);
    final spacing =
        theme.extension<AppSpacing>() ?? const AppSpacing.standard();
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    final dueStr = DateFormat('EEEE, MMMM d, y').format(homework.dueDate);

    final priorityColor = switch (homework.priority) {
      HomeworkPriority.high => Colors.red,
      HomeworkPriority.normal => Colors.blue,
      HomeworkPriority.low => Colors.grey,
    };

    return Container(
      padding: EdgeInsets.all(spacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(radius.lg),
          topRight: Radius.circular(radius.lg),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.only(bottom: spacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  homework.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                margin: EdgeInsets.only(left: spacing.sm),
                padding: EdgeInsets.symmetric(
                  horizontal: spacing.sm,
                  vertical: spacing.xs,
                ),
                decoration: BoxDecoration(
                  color: priorityColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(radius.xs),
                  border: Border.all(
                    color: priorityColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  homework.priority.name.toUpperCase(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: priorityColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.md),
          Card(
            color: theme.colorScheme.secondaryContainer,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius.sm),
            ),
            child: Padding(
              padding: EdgeInsets.all(spacing.md),
              child: Row(
                children: [
                  Icon(
                    Icons.event_note,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                  SizedBox(width: spacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        local?.translate('due_date') ?? 'Due Date',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer
                              .withValues(alpha: 0.7),
                        ),
                      ),
                      Text(
                        dueStr,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: spacing.lg),
          Text(
            homework.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              height: 1.4,
            ),
          ),
          SizedBox(height: spacing.lg),
          if (homework.attachmentUrl.isNotEmpty) ...[
            Text(
              local?.translate('attachments') ?? 'Attachments',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: spacing.sm),
            AttachmentTile(url: homework.attachmentUrl),
            SizedBox(height: spacing.md),
          ],
        ],
      ),
    );
  }
}
