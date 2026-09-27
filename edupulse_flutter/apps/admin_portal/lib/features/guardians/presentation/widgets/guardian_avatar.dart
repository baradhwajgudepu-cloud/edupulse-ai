import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../providers/guardian_providers.dart';

/// Reusable circular guardian avatar widget matching EduPulse Gemini visual system.
/// Displays actual profile photo (authenticated stream or external URL),
/// live preview bytes during upload/edit, or a clean single-initial fallback ('D' for Deepak Avula).
class GuardianAvatar extends ConsumerWidget {
  final String? guardianId;
  final String? schoolId;
  final String? photoUrl;
  final String? firstName;
  final String? lastName;
  final double radius;
  final String? version;
  final Uint8List? previewBytes;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const GuardianAvatar({
    super.key,
    this.guardianId,
    this.schoolId,
    this.photoUrl,
    this.firstName,
    this.lastName,
    this.radius = 24,
    this.version,
    this.previewBytes,
    this.backgroundColor,
    this.foregroundColor,
  });

  /// Derives initial uppercase letter from guardian name.
  /// Example: Deepak Avula -> D
  static String getInitial(String? firstName, String? lastName) {
    final first = (firstName ?? '').trim();
    if (first.isNotEmpty) {
      return first[0].toUpperCase();
    }
    final last = (lastName ?? '').trim();
    if (last.isNotEmpty) {
      return last[0].toUpperCase();
    }
    return 'G';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. If explicit preview bytes provided (e.g. file picker before save)
    if (previewBytes != null && previewBytes!.isNotEmpty) {
      return _buildImage(MemoryImage(previewBytes!), context);
    }

    // 2. If guardian has a photoUrl
    final url = photoUrl?.trim();
    if (url != null && url.isNotEmpty) {
      final isExternal = (url.startsWith('http://') || url.startsWith('https://')) &&
          !url.contains('/api/v1/guardians/');

      if (isExternal) {
        return _buildImage(NetworkImage(url), context);
      }

      // Internal authenticated photo stream
      if (guardianId != null && guardianId!.isNotEmpty && schoolId != null && schoolId!.isNotEmpty) {
        final photoBytesAsync = ref.watch(
          guardianAvatarBytesProvider(
            GuardianPhotoKey(
              guardianId: guardianId!,
              schoolId: schoolId!,
              version: version,
            ),
          ),
        );

        return photoBytesAsync.when(
          data: (bytes) {
            if (bytes != null && bytes.isNotEmpty) {
              return _buildImage(MemoryImage(bytes), context);
            }
            return _buildInitial(context);
          },
          loading: () => _buildInitial(context),
          error: (_, __) => _buildInitial(context),
        );
      }
    }

    // 3. Fallback initial avatar
    return _buildInitial(context);
  }

  Widget _buildInitial(BuildContext context) {
    final initial = getInitial(firstName, lastName);
    final bg = backgroundColor ?? EduPulseTheme.primaryTealDark;
    final fg = foregroundColor ?? Colors.white;

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.9,
        ),
      ),
    );
  }

  Widget _buildImage(ImageProvider imageProvider, BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: EduPulseTheme.primaryTeal.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor ?? EduPulseTheme.primaryTealDark,
        backgroundImage: imageProvider,
      ),
    );
  }
}
