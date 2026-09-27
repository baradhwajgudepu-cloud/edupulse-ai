import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../providers/student_providers.dart';

/// Reusable circular student avatar widget matching EduPulse Gemini visual system.
/// Displays actual profile photo (authenticated stream or external URL),
/// live preview bytes during upload/edit, or a clean initials avatar fallback.
class StudentAvatar extends ConsumerWidget {
  final String? studentId;
  final String? schoolId;
  final String? photoUrl;
  final String? firstName;
  final String? lastName;
  final double radius;
  final String? version;
  final Uint8List? previewBytes;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const StudentAvatar({
    super.key,
    this.studentId,
    this.schoolId,
    this.photoUrl,
    this.firstName,
    this.lastName,
    this.radius = 18,
    this.version,
    this.previewBytes,
    this.backgroundColor,
    this.foregroundColor,
  });

  /// Derives 2-letter uppercase initials from student name.
  /// Example: Jahnavi Avula -> JA
  static String getInitials(String? firstName, String? lastName) {
    final first = (firstName ?? '').trim();
    final last = (lastName ?? '').trim();

    if (first.isNotEmpty && last.isNotEmpty) {
      return (first[0] + last[0]).toUpperCase();
    }
    if (first.isNotEmpty) {
      return (first.length >= 2 ? first.substring(0, 2) : first).toUpperCase();
    }
    if (last.isNotEmpty) {
      return (last.length >= 2 ? last.substring(0, 2) : last).toUpperCase();
    }
    return 'ST';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. If explicit preview bytes provided (e.g. file picker before save)
    if (previewBytes != null && previewBytes!.isNotEmpty) {
      return _buildImage(MemoryImage(previewBytes!), context);
    }

    // 2. If student has a photoUrl
    final url = photoUrl?.trim();
    if (url != null && url.isNotEmpty) {
      // Check if external web URL
      final isExternal = (url.startsWith('http://') || url.startsWith('https://')) &&
          !url.contains('/api/v1/students/');

      if (isExternal) {
        return _buildImage(NetworkImage(url), context);
      }

      // Internal authenticated photo stream
      if (studentId != null && studentId!.isNotEmpty && schoolId != null && schoolId!.isNotEmpty) {
        final photoBytesAsync = ref.watch(
          studentAvatarBytesProvider(
            StudentPhotoKey(
              studentId: studentId!,
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
            return _buildInitials(context);
          },
          loading: () => _buildInitials(context),
          error: (_, __) => _buildInitials(context),
        );
      }
    }

    // 3. Fallback initials avatar
    return _buildInitials(context);
  }

  Widget _buildInitials(BuildContext context) {
    final initials = getInitials(firstName, lastName);
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
        initials,
        style: TextStyle(
          color: fg,
          fontSize: radius * 0.75,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
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
          color: EduPulseTheme.slate300,
          width: 1,
        ),
      ),
      child: ClipOval(
        child: Image(
          image: imageProvider,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildInitials(context),
        ),
      ),
    );
  }
}
