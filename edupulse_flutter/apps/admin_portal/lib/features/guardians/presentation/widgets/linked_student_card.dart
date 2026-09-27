import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:edupulse_ui/edupulse_ui.dart';
import 'package:admin_portal/core/routing/routes.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/students/data/models/student_models.dart';
import 'package:admin_portal/features/students/presentation/providers/student_providers.dart';
import 'package:admin_portal/features/students/presentation/widgets/student_avatar.dart';
import 'package:admin_portal/features/students/presentation/widgets/student_360_modal.dart';
import 'package:admin_portal/features/teachers/presentation/providers/teachers_providers.dart';

/// Interactive card component displaying a student linked to a guardian.
/// Replaces plain UUID tables with student identity, relationship badges,
/// current Class Teacher link, and 360 modal invocation.
class LinkedStudentCard extends ConsumerWidget {
  final StudentGuardianDto mapping;
  final String schoolId;
  final VoidCallback onEdit;
  final VoidCallback onUnlink;

  const LinkedStudentCard({
    super.key,
    required this.mapping,
    required this.schoolId,
    required this.onEdit,
    required this.onUnlink,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final studentSummary = mapping.student;
    final studentDetailAsync = studentSummary == null
        ? ref.watch(studentDetailProvider(mapping.studentId))
        : null;
    final studentDto = studentDetailAsync?.valueOrNull;

    final fullName = studentSummary?.fullName ?? (studentDto != null ? studentDto.fullName : 'Student ${mapping.studentId}');
    final admissionNo = studentSummary?.admissionNumber ?? studentDto?.admissionNumber ?? mapping.studentId;
    final rollNo = studentSummary?.rollNumber ?? studentDto?.rollNumber ?? '—';
    final classGrade = studentSummary?.className ?? studentDto?.className ?? 'Class';
    final sectionName = studentSummary?.sectionName ?? studentDto?.sectionName ?? '—';
    final academicYearName = studentSummary?.academicYearName ?? 'Academic Year';
    final photoUrl = studentSummary?.photoUrl ?? studentDto?.photoUrl;
    final firstName = studentSummary?.firstName ?? studentDto?.firstName ?? (fullName.isNotEmpty ? fullName.split(' ').first : 'S');
    final lastName = studentSummary?.lastName ?? studentDto?.lastName ?? '';
    final studentStatus = studentSummary?.status ?? studentDto?.status ?? 'ACTIVE';
    final admissionDate = studentSummary?.admissionDate ?? studentDto?.admissionDate;

    // Class Teacher Resolution
    String? classTeacherId = studentSummary?.classTeacherId;
    String? classTeacherName = studentSummary?.classTeacherName;

    if (classTeacherId == null) {
      final sectionId = studentSummary?.sectionId ?? studentDto?.sectionId;
      final classId = studentSummary?.classId ?? studentDto?.classId;
      if (sectionId != null && sectionId.isNotEmpty) {
        final assignmentsAsync = ref.watch(allTeacherAssignmentsProvider((
          schoolId: schoolId,
          academicYearId: ref.watch(selectedAcademicYearIdProvider),
          sectionId: sectionId,
          classId: classId,
          teacherId: null,
          subjectId: null,
          status: 'ACTIVE',
          search: null,
        )));
        final assignments = assignmentsAsync.valueOrNull ?? const [];
        for (final a in assignments) {
          if (a.isClassTeacher) {
            classTeacherId = a.teacherId;
            break;
          }
        }
        if (classTeacherId != null) {
          final currentTeacherId = classTeacherId;
          final teachersState = ref.watch(teachersListProvider);
          for (final t in teachersState.teachers) {
            if (t.id == currentTeacherId) {
              classTeacherName = t.fullName;
              break;
            }
          }
          if (classTeacherName == null) {
            final tDetail = ref.watch(teacherDetailProvider(currentTeacherId));
            classTeacherName = tDetail.valueOrNull?.fullName;
          }
        }
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? EduPulseTheme.slate800 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Avatar, Identity, Relationship, Actions
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StudentAvatar(
                studentId: mapping.studentId,
                schoolId: schoolId,
                photoUrl: photoUrl,
                firstName: firstName,
                lastName: lastName,
                radius: 26,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            fullName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : EduPulseTheme.slate900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(
                          label: mapping.relationship.toUpperCase(),
                          variant: StatusBadgeVariant.info,
                          size: StatusBadgeSize.sm,
                        ),
                        const SizedBox(width: 6),
                        StatusBadge(
                          label: studentStatus.toUpperCase(),
                          variant: studentStatus.toUpperCase() == 'ACTIVE'
                              ? StatusBadgeVariant.success
                              : StatusBadgeVariant.neutral,
                          size: StatusBadgeSize.sm,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      children: [
                        Text(
                          'Adm: $admissionNo',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                          ),
                        ),
                        if (admissionDate != null && admissionDate.isNotEmpty) ...[
                          Text('•', style: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
                          Text(
                            'Admitted: $admissionDate',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                        Text('•', style: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
                        Text(
                          'Roll #$rollNo',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        Text('•', style: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
                        Text(
                          mapping.studentId,
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$classGrade • Sec $sectionName  |  $academicYearName',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
              // Action buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: Key('edit_mapping_${mapping.id}'),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    tooltip: 'Edit Mapping',
                    onPressed: onEdit,
                  ),
                  IconButton(
                    key: Key('unlink_student_${mapping.id}'),
                    icon: const Icon(Icons.link_off_rounded, size: 18, color: EduPulseTheme.roseDanger),
                    tooltip: 'Unlink Student',
                    onPressed: onUnlink,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Row 2: Relationship Flags & Class Teacher Chip & 360 Action
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              // Relationship Tags
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (mapping.isPrimary)
                    const StatusBadge(
                      icon: Icon(Icons.check_circle, size: 12, color: Color(0xFF115E59)),
                      label: 'PRIMARY',
                      variant: StatusBadgeVariant.brand,
                      size: StatusBadgeSize.sm,
                    ),
                  if (mapping.canPickupStudent)
                    const StatusBadge(
                      icon: Icon(Icons.check_circle, size: 12, color: Color(0xFF065F46)),
                      label: 'CAN PICKUP',
                      variant: StatusBadgeVariant.success,
                      size: StatusBadgeSize.sm,
                    ),
                  if (mapping.receivesNotifications)
                    const StatusBadge(
                      icon: Icon(Icons.check_circle, size: 12, color: EduPulseTheme.slate700),
                      label: 'NOTIFICATIONS',
                      variant: StatusBadgeVariant.neutral,
                      size: StatusBadgeSize.sm,
                    ),
                ],
              ),

              // Right items: Class Teacher & View 360 button
              Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Class Teacher badge / navigation chip
                  if (classTeacherId != null)
                    InkWell(
                      key: Key('class_teacher_link_${mapping.studentId}'),
                      onTap: () {
                        context.push('${AppRoutes.teachers}/$classTeacherId?school_id=$schoolId');
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? EduPulseTheme.primaryTeal.withValues(alpha: 0.18) : const Color(0xFFE6FFFA),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: EduPulseTheme.primaryTeal.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.school_outlined, size: 13, color: EduPulseTheme.primaryTeal),
                            const SizedBox(width: 5),
                            Text(
                              'Class Teacher: ${classTeacherName ?? "Assigned"}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: EduPulseTheme.primaryTeal,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.open_in_new, size: 11, color: EduPulseTheme.primaryTeal),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? EduPulseTheme.slate700 : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_outline, size: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text(
                            'Class Teacher: Not Assigned',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // View Student 360 Action Button
                  FilledButton.tonalIcon(
                    key: Key('view_student_360_${mapping.studentId}'),
                    onPressed: () async {
                      try {
                        final StudentDto fetched;
                        if (studentDto != null) {
                          fetched = studentDto;
                        } else {
                          fetched = await ref.read(studentDetailProvider(mapping.studentId).future);
                        }
                        if (context.mounted) {
                          Student360Modal.show(context, student: fetched, schoolId: schoolId);
                        }
                      } catch (_) {
                        final fallbackStudent = StudentDto(
                          id: mapping.studentId,
                          tenantId: mapping.tenantId,
                          schoolId: schoolId,
                          academicYearId: ref.read(selectedAcademicYearIdProvider) ?? '',
                          classId: studentSummary?.classId ?? '',
                          sectionId: studentSummary?.sectionId ?? '',
                          firstName: studentSummary?.firstName ?? 'Student',
                          lastName: studentSummary?.lastName ?? '',
                          gender: 'MALE',
                          dateOfBirth: '2010-01-01',
                          admissionNumber: studentSummary?.admissionNumber ?? mapping.studentId,
                          rollNumber: studentSummary?.rollNumber ?? '1',
                          admissionDate: '2026-01-01',
                          status: 'ACTIVE',
                          isActive: true,
                          settings: const {},
                          aiMetrics: const {},
                          version: 1,
                          createdAt: '',
                          updatedAt: '',
                          className: studentSummary?.className,
                          sectionName: studentSummary?.sectionName,
                          photoUrl: studentSummary?.photoUrl,
                          address: const {},
                          medicalInformation: const {},
                        );
                        if (context.mounted) {
                          Student360Modal.show(context, student: fallbackStudent, schoolId: schoolId);
                        }
                      }
                    },
                    icon: const Icon(Icons.visibility_outlined, size: 14),
                    label: const Text('View Student 360'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
