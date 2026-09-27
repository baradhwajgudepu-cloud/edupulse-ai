import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:edupulse_theme/edupulse_theme.dart';
import 'package:edupulse_assets/edupulse_assets.dart';
import '../../../../core/routing/routes.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: theme.colorScheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.login);
            }
          },
        ),
        title: isMobile
            ? const Text('Privacy Policy')
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.primaryContainer,
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Image.asset(
                      EduPulseAssets.mark,
                      package: EduPulseAssets.package,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'EduPulse AI',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: isMobile
                ? IconButton(
                    icon: const Icon(Icons.login_rounded),
                    tooltip: 'Sign In',
                    onPressed: () => context.go(AppRoutes.login),
                  )
                : TextButton.icon(
                    onPressed: () => context.go(AppRoutes.login),
                    icon: const Icon(Icons.login_rounded, size: 18),
                    label: const Text('Return to Sign In'),
                  ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ListView(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 20.0 : 36.0,
              vertical: 24.0,
            ),
            children: [
              // Hero Header Card
              Container(
                padding: EdgeInsets.all(isMobile ? 20.0 : 32.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                      theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(radius.lg),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runSpacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'LEGAL & COMPLIANCE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        Text(
                          'Last Updated: September 13, 2026',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'EduPulse AI Privacy Policy',
                      style: (isMobile
                              ? theme.textTheme.headlineSmall
                              : theme.textTheme.headlineMedium)
                          ?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Transparent data governance and strict role-based privacy for students, parents, teachers, and school administrators across our multi-tenant educational intelligence platform.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Section 1: Overview & Multi-Tenant Architecture
              _buildSection(
                context,
                icon: Icons.shield_outlined,
                title: '1. Introduction & Multi-Tenant Architecture',
                content:
                    'EduPulse AI ("we", "our", or "Platform") provides advanced school administrative management, artificial intelligence-assisted learning analytics, attendance tracking, and educational workflows. '
                    'This Privacy Policy outlines how personal, academic, and administrative information is gathered, processed, secured, and isolated.\n\n'
                    'Our architecture enforces multi-tenant and school-level context isolation at the database, network, and application layers. Every request is verified with strict tenant and school scope headers (`X-Tenant-ID`, `X-School-ID`). Data belonging to one educational institution is never shared, merged, or made accessible to another.',
              ),

              // Section 2: Student Data Privacy
              _buildSection(
                context,
                icon: Icons.school_outlined,
                title: '2. Student Personal & Academic Data',
                content:
                    'We collect and process student information strictly on behalf of the authorized educational institution for educational administration:\n\n'
                    '• Demographics & Identity: Student full name, admission number, roll number, class and section enrollment, date of birth, gender, blood group, and emergency contact details.\n'
                    '• Academic History & Results: Examination marks, assignments, report cards, teacher feedback, promotion status, and academic growth assessments.\n'
                    '• Attendance Records: Daily attendance status (Present, Absent, Late, Excused), check-in timestamps, and leave requests.\n'
                    '• Concessions & Scholarships: Entitlements applied toward institutional tuition and term fees.\n\n'
                    'Student data is never sold, leased, or monetized for advertising. All processing complies with applicable student privacy regulations including FERPA, COPPA, and DPDP 2023 principles.',
              ),

              // Section 3: Parent & Guardian Data Privacy
              _buildSection(
                context,
                icon: Icons.family_restroom_outlined,
                title: '3. Parent & Guardian Information',
                content:
                    'To foster transparent communication and student security, we collect:\n\n'
                    '• Contact & Identity: Full name, relationship to student (Father, Mother, Legal Guardian), primary phone number, email address, and home address.\n'
                    '• Authorization Flags: Authorizations designating pickup permissions, primary guardian status, and emergency notification recipients.\n'
                    '• Communication Records: SMS, email, and portal notifications regarding attendance alerts, academic circulars, fee dues, and urgent school notices.\n\n'
                    'Parents have the right to view, verify, and request corrections to their child\'s personal records and linked guardian profiles through the authorized school administration.',
              ),

              // Section 4: Teacher & Staff Data Privacy
              _buildSection(
                context,
                icon: Icons.badge_outlined,
                title: '4. Teacher & Staff Information',
                content:
                    'Teacher and staff information processed within EduPulse AI includes:\n\n'
                    '• Professional Profiles: Employee code, staff biometric ID, department, designation, qualifications, official email address, and verified phone number.\n'
                    '• Academic Allocations: Subject assignments, class teacher duties, timetable schedules, and classroom lesson plans.\n'
                    '• Operational Activity: Timestamped audit logs recording marks entry, attendance marking, student notes, and examination evaluations.\n\n'
                    'Staff performance metrics and access permissions are managed exclusively by the school\'s appointed administrative authority.',
              ),

              // Section 5: Principal & Administrator Governance
              _buildSection(
                context,
                icon: Icons.admin_panel_settings_outlined,
                title: '5. Principal & Administrative Accounts',
                content:
                    'School Principals, System Administrators, and Tenant Executives maintain elevated governance credentials:\n\n'
                    '• Account Credentials: Cryptographically salted and hashed passwords (Argon2id/bcrypt), multi-factor authentication tokens, and session identifiers.\n'
                    '• Administrative Audit Trail: Immutable logging of administrative actions, including user provisioning, role assignments, student status alterations, fee structure creation, and locked attendance unlocks.\n'
                    '• Context Enforcement: Administrators operate within their authorized tenant and campus boundaries. Zero cross-tenant data leakage is permitted.',
              ),

              // Section 6: Attendance Records & Geofencing
              _buildSection(
                context,
                icon: Icons.how_to_reg_outlined,
                title: '6. Attendance Records & Campus Geofencing',
                content:
                    'Attendance tracking is core to student safety and regulatory compliance:\n\n'
                    '• Record Lifecycle: Daily session states (Draft, Submitted, Approved, Locked) preventing unauthorized retroactive tampering.\n'
                    '• Audit Logging of Corrections: When an authorized user updates an attendance record, EduPulse AI logs the editor identity, edit timestamp, previous status, updated status, and reason for change.\n'
                    '• Geofencing Technology: When mobile attendance verification is enabled, location coordinates (latitude and longitude) are verified against the registered school campus perimeter. Geolocation data is used exclusively to validate on-campus attendance at the moment of capture; off-campus movements or background locations are never tracked.',
              ),

              // Section 7: Academic Results, Marks & AI Intelligence
              _buildSection(
                context,
                icon: Icons.auto_awesome_outlined,
                title: '7. Academic Analytics & Artificial Intelligence',
                content:
                    'EduPulse AI utilizes machine learning models to identify academic trends and early risk indicators:\n\n'
                    '• Localized Inference: AI predictive analytics (attendance drop alerts, subject difficulty analysis) operate strictly within tenant-scoped data.\n'
                    '• No Model Training on Private Data: Customer institutional data, student identifiable marks, and parent information are NEVER used to train public or foundational AI models.\n'
                    '• Discretionary Insights: AI recommendations serve as decision-support tools for educators and administrators, not autonomous disciplinary determinations.',
              ),

              // Section 8: Fee Management & Financial Security
              _buildSection(
                context,
                icon: Icons.receipt_long_outlined,
                title: '8. Fee Payments & Financial Data',
                content:
                    'Fee tracking, payments, and receipt generation adhere to strict financial standards:\n\n'
                    '• Financial Ledgers: Fee assignments, installment schedules, concession entitlements, late fines, collected amounts, and outstanding balance ledgers.\n'
                    '• Payment Details: Transaction reference codes, payment date, method (UPI, Net Banking, Card, Cheque, Cash), and cashier notes.\n'
                    '• Cardholder Protection: We do NOT store sensitive payment card numbers (PAN), CVVs, or bank net-banking passwords. Online transactions are handled through PCI-DSS compliant certified payment gateways.',
              ),

              // Section 9: Security Infrastructure & Data Storage
              _buildSection(
                context,
                icon: Icons.lock_outline_rounded,
                title: '9. Security Controls & Data Protection',
                content:
                    'We employ defense-in-depth technical, physical, and administrative safeguards:\n\n'
                    '• Encryption: AES-256 encryption at rest across all database volumes, file storage, and backups. TLS 1.3 encryption in transit for all network traffic.\n'
                    '• Access Controls: Granular Role-Based Access Control (RBAC) ensuring users only see data commensurate with their verified institutional role.\n'
                    '• Resilience & Protection: Continuous automated threat detection, rate limiting against brute-force attacks, automated session expiration, and DDoS mitigation.',
              ),

              // Section 10: Data Retention & User Rights
              _buildSection(
                context,
                icon: Icons.delete_sweep_outlined,
                title: '10. Data Retention, Portability & Deletion',
                content:
                    'We preserve educational records in accordance with institutional policy and statutory retention regulations:\n\n'
                    '• Data Portability: Authorized administrators can export student registers, marks reports, attendance logs, and fee ledgers in standardized formats (CSV, Excel, PDF).\n'
                    '• Permanent Purge (Right to be Forgotten): Upon verified institutional request or termination of service, tenant data is securely scrubbed and permanently deleted from production and backup storage within 30 days.\n'
                    '• Rectification: Data subjects may request correction of inaccurate records through their designated school administration.',
              ),

              // Section 11: Contact & DPO
              _buildSection(
                context,
                icon: Icons.contact_support_outlined,
                title: '11. Contact Our Data Protection Officer (DPO)',
                content:
                    'If you have questions, inquiries, or grievance requests concerning this Privacy Policy or your personal information, please contact our Data Governance team:\n\n'
                    'EduPulse AI Privacy & Security Office\n'
                    'Email: privacy@edupulse.ai\n'
                    'General Inquiries: support@edupulse.ai\n'
                    'Response Time: All data privacy inquiries receive an official response within 30 business days.',
              ),

              const SizedBox(height: 24),

              // Bottom Return to Sign In button
              Center(
                child: FilledButton.icon(
                  onPressed: () => context.go(AppRoutes.login),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Return to Admin Portal Sign In'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(radius.md),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // Bottom Legal Footer
              Divider(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  '© 2026 EduPulse AI. All rights reserved. • Version 1.0.0',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String content,
  }) {
    final theme = Theme.of(context);
    final radius = theme.extension<AppRadius>() ?? const AppRadius.standard();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(radius.md),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              content,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
