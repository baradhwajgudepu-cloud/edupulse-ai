import 'package:flutter/material.dart';

class MarksValidationBanner extends StatelessWidget {
  final Map<String, String> validationErrors;

  const MarksValidationBanner({
    super.key,
    required this.validationErrors,
  });

  @override
  Widget build(BuildContext context) {
    if (validationErrors.isEmpty) return const SizedBox.shrink();
    
    final theme = Theme.of(context);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.errorContainer,
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${validationErrors.length} validation error(s) found. Please correct them before saving.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
