import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'school_logo_uploader.dart';

/// Reusable School Logo display widget that handles authentication, caching,
/// aspect-ratio preservation (BoxFit.contain), and graceful icon fallback.
class SchoolLogoWidget extends ConsumerWidget {
  final String schoolId;
  final String? logoUrl;
  final String? logoUpdatedAt;
  final double size;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;

  const SchoolLogoWidget({
    super.key,
    required this.schoolId,
    this.logoUrl,
    this.logoUpdatedAt,
    this.size = 32.0,
    this.borderRadius,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hasLogo = logoUrl != null && logoUrl!.trim().isNotEmpty;
    final r = borderRadius ?? BorderRadius.circular(size * 0.2);

    if (!hasLogo || schoolId.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor ?? theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
          borderRadius: r,
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.school_rounded,
          size: size * 0.6,
          color: theme.colorScheme.primary,
        ),
      );
    }

    final logoAsync = ref.watch(schoolLogoBytesProvider((
      schoolId: schoolId,
      version: logoUpdatedAt,
    )));

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: r,
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          width: 1.0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: logoAsync.when(
        data: (bytes) {
          if (bytes != null && bytes.isNotEmpty) {
            return Padding(
              padding: EdgeInsets.all(size * 0.08),
              child: Image.memory(
                bytes,
                width: size,
                height: size,
                fit: BoxFit.contain,
              ),
            );
          }
          return Icon(
            Icons.school_rounded,
            size: size * 0.6,
            color: theme.colorScheme.primary,
          );
        },
        loading: () => SizedBox(
          width: size * 0.45,
          height: size * 0.45,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: theme.colorScheme.primary,
          ),
        ),
        error: (_, __) => Icon(
          Icons.school_rounded,
          size: size * 0.6,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
