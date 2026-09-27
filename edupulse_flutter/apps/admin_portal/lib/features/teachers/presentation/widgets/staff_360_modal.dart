import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import '../../data/models/teachers_models.dart';

/// Staff 360 Detail Modal matching the Gemini AI Studio UX prototype.
/// Displays comprehensive operational details for a staff member using real data only.
class Staff360Modal extends StatelessWidget {
  final TeacherDto teacher;
  final String schoolId;
  final VoidCallback? onEdit;
  final VoidCallback? onToggleStatus;
  final VoidCallback? onResetPassword;
  final VoidCallback? onViewFullProfile;

  const Staff360Modal({
    super.key,
    required this.teacher,
    required this.schoolId,
    this.onEdit,
    this.onToggleStatus,
    this.onResetPassword,
    this.onViewFullProfile,
  });

  static Future<void> show(
    BuildContext context, {
    required TeacherDto teacher,
    required String schoolId,
    VoidCallback? onEdit,
    VoidCallback? onToggleStatus,
    VoidCallback? onResetPassword,
    VoidCallback? onViewFullProfile,
  }) {
    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;
    final maxH = (screenH * 0.92).clamp(400.0, 720.0);

    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: screenW < 768 ? 12 : 24,
          vertical: screenH < 768 ? 12 : 24,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 620, maxHeight: maxH),
          child: Staff360Modal(
            teacher: teacher,
            schoolId: schoolId,
            onEdit: onEdit,
            onToggleStatus: onToggleStatus,
            onResetPassword: onResetPassword,
            onViewFullProfile: onViewFullProfile,
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return Colors.green;
      case 'ON_LEAVE':
        return Colors.amber.shade700;
      case 'RETIRED':
        return Colors.blueGrey;
      case 'INACTIVE':
      default:
        return Colors.red;
    }
  }

  String _formatINR(double amount) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final t = teacher;
    final statusColor = _getStatusColor(t.status);

    final initials = (t.firstName.isNotEmpty ? t.firstName[0].toUpperCase() : '') +
        (t.lastName.isNotEmpty ? t.lastName[0].toUpperCase() : '');

    return Container(
      decoration: BoxDecoration(
        color: isDark ? EduPulseTheme.slate900 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header Bar with Avatar, Name, Code & Close Button
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      foregroundColor: theme.colorScheme.onPrimaryContainer,
                      backgroundImage: (t.photoUrl != null && t.photoUrl!.isNotEmpty)
                          ? NetworkImage(t.photoUrl!)
                          : null,
                      child: (t.photoUrl == null || t.photoUrl!.isEmpty)
                          ? Text(
                              initials.isNotEmpty ? initials : 'ST',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? EduPulseTheme.slate900 : Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              t.fullName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              t.status,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${t.designation ?? "Faculty Member"} • ${t.department ?? "General Academics"}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Employee Code: ${t.employeeCode.isNotEmpty ? t.employeeCode : t.staffCode}',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // 2. Scrollable Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Operational Overview Grid (Real Data Only)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? EduPulseTheme.slate800 : EduPulseTheme.slate50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? EduPulseTheme.slate700 : EduPulseTheme.slate200,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoCell(
                                label: 'Department',
                                value: t.department ?? 'N/A',
                                icon: Icons.business_outlined,
                                theme: theme,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildInfoCell(
                                label: 'Employment Type',
                                value: t.employmentType.replaceAll('_', ' '),
                                icon: Icons.work_outline,
                                theme: theme,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoCell(
                                label: 'Monthly Base Salary',
                                value: t.salary != null && t.salary! > 0
                                    ? _formatINR(t.salary!)
                                    : 'Not Specified',
                                icon: Icons.payments_outlined,
                                theme: theme,
                                isBold: t.salary != null && t.salary! > 0,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildInfoCell(
                                label: 'Joining Date',
                                value: t.joiningDate.isNotEmpty ? t.joiningDate : 'N/A',
                                icon: Icons.calendar_today_outlined,
                                theme: theme,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Contact Verification Panel
                  Text(
                    'Contact & Verification',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
                    ),
                    child: Column(
                      children: [
                        _buildContactRow(
                          icon: Icons.email_outlined,
                          label: 'Official Email',
                          value: t.officialEmail,
                          theme: theme,
                        ),
                        const SizedBox(height: 8),
                        _buildContactRow(
                          icon: Icons.phone_outlined,
                          label: 'Mobile Number',
                          value: t.mobile,
                          theme: theme,
                        ),
                        if (t.personalEmail != null && t.personalEmail!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildContactRow(
                            icon: Icons.alternate_email,
                            label: 'Personal Email',
                            value: t.personalEmail!,
                            theme: theme,
                          ),
                        ],
                        if (t.emergencyContactName != null && t.emergencyContactName!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _buildContactRow(
                            icon: Icons.emergency_outlined,
                            label: 'Emergency Contact',
                            value: '${t.emergencyContactName} (${t.emergencyContactRelation ?? "Relation"}) • ${t.emergencyContactMobile ?? ""}',
                            theme: theme,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Academic Qualifications & Background
                  if ((t.qualification != null && t.qualification!.isNotEmpty) ||
                      (t.specialization != null && t.specialization!.isNotEmpty) ||
                      (t.experienceYears != null && t.experienceYears! > 0)) ...[
                    Text(
                      'Qualifications & Experience',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (t.qualification != null && t.qualification!.isNotEmpty)
                            _buildDetailRow(label: 'Highest Qualification', value: t.qualification!),
                          if (t.specialization != null && t.specialization!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            _buildDetailRow(label: 'Specialization', value: t.specialization!),
                          ],
                          if (t.experienceYears != null && t.experienceYears! > 0) ...[
                            const SizedBox(height: 6),
                            _buildDetailRow(label: 'Experience', value: '${t.experienceYears} Years'),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const Divider(height: 1),

          // 3. Footer Action Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                if (onViewFullProfile != null)
                  TextButton.icon(
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Full Profile'),
                    onPressed: onViewFullProfile,
                  )
                else
                  const SizedBox.shrink(),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (onResetPassword != null && t.status != 'RETIRED') ...[
                      OutlinedButton.icon(
                        icon: const Icon(Icons.lock_reset, size: 16),
                        label: const Text('Reset Password'),
                        onPressed: onResetPassword,
                      ),
                    ],
                    if (onEdit != null && t.status != 'RETIRED') ...[
                      ElevatedButton.icon(
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Edit Staff'),
                        onPressed: onEdit,
                      ),
                    ],
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCell({
    required String label,
    required String value,
    required IconData icon,
    required ThemeData theme,
    bool isBold = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildContactRow({
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow({required String label, required String value}) {
    return Row(
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
