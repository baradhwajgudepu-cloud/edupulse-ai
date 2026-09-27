// Strongly typed models for Attendance-Based Teacher Payroll, Policies, and AI Insights.

class PayrollPolicyDto {
  final String id;
  final String schoolId;
  final String policyName;
  final String calculationBasis; // WORKING_DAYS, CALENDAR_DAYS, FIXED_30_DAYS
  final int standardWorkingDays;
  final String dailyRateFormula;
  final double halfDayDeductionFactor;
  final double unpaidLeaveDeductionFactor;
  final int lateGraceCount;
  final double lateDeductionFactor;
  final bool isActive;

  const PayrollPolicyDto({
    required this.id,
    required this.schoolId,
    required this.policyName,
    required this.calculationBasis,
    required this.standardWorkingDays,
    required this.dailyRateFormula,
    required this.halfDayDeductionFactor,
    required this.unpaidLeaveDeductionFactor,
    required this.lateGraceCount,
    required this.lateDeductionFactor,
    required this.isActive,
  });

  factory PayrollPolicyDto.fromJson(Map<String, dynamic> json) {
    return PayrollPolicyDto(
      id: json['id']?.toString() ?? '',
      schoolId: json['school_id']?.toString() ?? '',
      policyName: json['policy_name']?.toString() ?? 'Standard Policy',
      calculationBasis: json['calculation_basis']?.toString() ?? 'WORKING_DAYS',
      standardWorkingDays: (json['standard_working_days'] as num?)?.toInt() ?? 24,
      dailyRateFormula: json['daily_rate_formula']?.toString() ?? 'GROSS_DIVIDED_BY_WORKING_DAYS',
      halfDayDeductionFactor: (json['half_day_deduction_factor'] as num?)?.toDouble() ?? 0.50,
      unpaidLeaveDeductionFactor: (json['unpaid_leave_deduction_factor'] as num?)?.toDouble() ?? 1.00,
      lateGraceCount: (json['late_grace_count'] as num?)?.toInt() ?? 3,
      lateDeductionFactor: (json['late_deduction_factor'] as num?)?.toDouble() ?? 0.25,
      isActive: json['is_active'] ?? true,
    );
  }
}

class TeacherPayrollProfileDto {
  final String id;
  final String schoolId;
  final String teacherId;
  final String teacherName;
  final String teacherCode;
  final String? designation;
  final String? department;
  final double monthlyGrossSalary;
  final double basicSalary;
  final double hraAllowance;
  final double specialAllowance;
  final double otherAllowances;
  final double providentFundDeduction;
  final double taxDeduction;
  final double otherDeductions;
  final int paidLeaveQuotaPerYear;
  final String? bankAccountNumber;
  final String? bankIfsc;
  final String? bankName;
  final String effectiveFrom;
  final bool isActive;

  const TeacherPayrollProfileDto({
    required this.id,
    required this.schoolId,
    required this.teacherId,
    required this.teacherName,
    required this.teacherCode,
    this.designation,
    this.department,
    required this.monthlyGrossSalary,
    required this.basicSalary,
    required this.hraAllowance,
    required this.specialAllowance,
    required this.otherAllowances,
    required this.providentFundDeduction,
    required this.taxDeduction,
    required this.otherDeductions,
    required this.paidLeaveQuotaPerYear,
    this.bankAccountNumber,
    this.bankIfsc,
    this.bankName,
    required this.effectiveFrom,
    required this.isActive,
  });

  factory TeacherPayrollProfileDto.fromJson(Map<String, dynamic> json) {
    return TeacherPayrollProfileDto(
      id: json['id']?.toString() ?? '',
      schoolId: json['school_id']?.toString() ?? '',
      teacherId: json['teacher_id']?.toString() ?? '',
      teacherName: json['teacher_name']?.toString() ?? 'Faculty Member',
      teacherCode: json['teacher_code']?.toString() ?? 'N/A',
      designation: json['designation']?.toString(),
      department: json['department']?.toString(),
      monthlyGrossSalary: (json['monthly_gross_salary'] as num?)?.toDouble() ?? 0.0,
      basicSalary: (json['basic_salary'] as num?)?.toDouble() ?? 0.0,
      hraAllowance: (json['hra_allowance'] as num?)?.toDouble() ?? 0.0,
      specialAllowance: (json['special_allowance'] as num?)?.toDouble() ?? 0.0,
      otherAllowances: (json['other_allowances'] as num?)?.toDouble() ?? 0.0,
      providentFundDeduction: (json['provident_fund_deduction'] as num?)?.toDouble() ?? 0.0,
      taxDeduction: (json['tax_deduction'] as num?)?.toDouble() ?? 0.0,
      otherDeductions: (json['other_deductions'] as num?)?.toDouble() ?? 0.0,
      paidLeaveQuotaPerYear: (json['paid_leave_quota_per_year'] as num?)?.toInt() ?? 12,
      bankAccountNumber: json['bank_account_number']?.toString(),
      bankIfsc: json['bank_ifsc']?.toString(),
      bankName: json['bank_name']?.toString(),
      effectiveFrom: json['effective_from']?.toString() ?? '',
      isActive: json['is_active'] ?? true,
    );
  }
}

class TeacherPayrollItemDto {
  final String id;
  final String schoolId;
  final String teacherId;
  final String teacherName;
  final String teacherCode;
  final String? designation;
  final String? department;
  final int month;
  final int year;
  final String calculationDate;

  final int calendarDays;
  final int applicableWorkingDays;
  final double presentDays;
  final double approvedLeaveDays;
  final int halfDays;
  final double unpaidAbsenceDays;
  final int holidaysCount;
  final int onDutyDays;
  final int lateDays;
  final int unmarkedDays;

  final double grossSalary;
  final double dailyRate;
  final double attendanceDeductions;
  final double statutoryDeductions;
  final double manualAdjustments;
  final String? adjustmentReason;
  final double netPayable;

  final String? aiExplanation;
  final List<String> aiAnomalies;
  final String status; // DRAFT, REVIEWED, APPROVED, DISBURSED
  final String? calculatedByName;
  final String? approvedByName;
  final DateTime? approvedAt;

  const TeacherPayrollItemDto({
    required this.id,
    required this.schoolId,
    required this.teacherId,
    required this.teacherName,
    required this.teacherCode,
    this.designation,
    this.department,
    required this.month,
    required this.year,
    required this.calculationDate,
    required this.calendarDays,
    required this.applicableWorkingDays,
    required this.presentDays,
    required this.approvedLeaveDays,
    required this.halfDays,
    required this.unpaidAbsenceDays,
    required this.holidaysCount,
    required this.onDutyDays,
    required this.lateDays,
    required this.unmarkedDays,
    required this.grossSalary,
    required this.dailyRate,
    required this.attendanceDeductions,
    required this.statutoryDeductions,
    required this.manualAdjustments,
    this.adjustmentReason,
    required this.netPayable,
    this.aiExplanation,
    required this.aiAnomalies,
    required this.status,
    this.calculatedByName,
    this.approvedByName,
    this.approvedAt,
  });

  factory TeacherPayrollItemDto.fromJson(Map<String, dynamic> json) {
    return TeacherPayrollItemDto(
      id: json['id']?.toString() ?? '',
      schoolId: json['school_id']?.toString() ?? '',
      teacherId: json['teacher_id']?.toString() ?? '',
      teacherName: json['teacher_name']?.toString() ?? 'Teacher',
      teacherCode: json['teacher_code']?.toString() ?? 'N/A',
      designation: json['designation']?.toString(),
      department: json['department']?.toString(),
      month: (json['month'] as num?)?.toInt() ?? 1,
      year: (json['year'] as num?)?.toInt() ?? 2026,
      calculationDate: json['calculation_date']?.toString() ?? '',
      calendarDays: (json['calendar_days'] as num?)?.toInt() ?? 30,
      applicableWorkingDays: (json['applicable_working_days'] as num?)?.toInt() ?? 24,
      presentDays: (json['present_days'] as num?)?.toDouble() ?? 0.0,
      approvedLeaveDays: (json['approved_leave_days'] as num?)?.toDouble() ?? 0.0,
      halfDays: (json['half_days'] as num?)?.toInt() ?? 0,
      unpaidAbsenceDays: (json['unpaid_absence_days'] as num?)?.toDouble() ?? 0.0,
      holidaysCount: (json['holidays_count'] as num?)?.toInt() ?? 0,
      onDutyDays: (json['on_duty_days'] as num?)?.toInt() ?? 0,
      lateDays: (json['late_days'] as num?)?.toInt() ?? 0,
      unmarkedDays: (json['unmarked_days'] as num?)?.toInt() ?? 0,
      grossSalary: (json['gross_salary'] as num?)?.toDouble() ?? 0.0,
      dailyRate: (json['daily_rate'] as num?)?.toDouble() ?? 0.0,
      attendanceDeductions: (json['attendance_deductions'] as num?)?.toDouble() ?? 0.0,
      statutoryDeductions: (json['statutory_deductions'] as num?)?.toDouble() ?? 0.0,
      manualAdjustments: (json['manual_adjustments'] as num?)?.toDouble() ?? 0.0,
      adjustmentReason: json['adjustment_reason']?.toString(),
      netPayable: (json['net_payable'] as num?)?.toDouble() ?? 0.0,
      aiExplanation: json['ai_explanation']?.toString(),
      aiAnomalies: (json['ai_anomalies'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      status: json['status']?.toString() ?? 'DRAFT',
      calculatedByName: json['calculated_by_name']?.toString(),
      approvedByName: json['approved_by_name']?.toString(),
      approvedAt: json['approved_at'] != null ? DateTime.tryParse(json['approved_at'].toString()) : null,
    );
  }
}

class MonthlyPayrollSummaryDto {
  final String schoolId;
  final int month;
  final int year;
  final String policyName;
  final int totalTeachers;
  final int draftCount;
  final int approvedCount;
  final double totalGrossDisbursement;
  final double totalAttendanceDeductions;
  final double totalStatutoryDeductions;
  final double totalNetPayable;
  final List<TeacherPayrollItemDto> items;

  const MonthlyPayrollSummaryDto({
    required this.schoolId,
    required this.month,
    required this.year,
    required this.policyName,
    required this.totalTeachers,
    required this.draftCount,
    required this.approvedCount,
    required this.totalGrossDisbursement,
    required this.totalAttendanceDeductions,
    required this.totalStatutoryDeductions,
    required this.totalNetPayable,
    required this.items,
  });

  factory MonthlyPayrollSummaryDto.fromJson(Map<String, dynamic> json) {
    return MonthlyPayrollSummaryDto(
      schoolId: json['school_id']?.toString() ?? '',
      month: (json['month'] as num?)?.toInt() ?? 1,
      year: (json['year'] as num?)?.toInt() ?? 2026,
      policyName: json['policy_name']?.toString() ?? 'Policy',
      totalTeachers: (json['total_teachers'] as num?)?.toInt() ?? 0,
      draftCount: (json['draft_count'] as num?)?.toInt() ?? 0,
      approvedCount: (json['approved_count'] as num?)?.toInt() ?? 0,
      totalGrossDisbursement: (json['total_gross_disbursement'] as num?)?.toDouble() ?? 0.0,
      totalAttendanceDeductions: (json['total_attendance_deductions'] as num?)?.toDouble() ?? 0.0,
      totalStatutoryDeductions: (json['total_statutory_deductions'] as num?)?.toDouble() ?? 0.0,
      totalNetPayable: (json['total_net_payable'] as num?)?.toDouble() ?? 0.0,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => TeacherPayrollItemDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class PayrollAuditLogDto {
  final String id;
  final String teacherName;
  final String action;
  final String? actorName;
  final double? previousNetPay;
  final double? revisedNetPay;
  final double? deltaAmount;
  final String? notes;
  final DateTime createdAt;

  const PayrollAuditLogDto({
    required this.id,
    required this.teacherName,
    required this.action,
    this.actorName,
    this.previousNetPay,
    this.revisedNetPay,
    this.deltaAmount,
    this.notes,
    required this.createdAt,
  });

  factory PayrollAuditLogDto.fromJson(Map<String, dynamic> json) {
    return PayrollAuditLogDto(
      id: json['id']?.toString() ?? '',
      teacherName: json['teacher_name']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      actorName: json['actor_name']?.toString(),
      previousNetPay: (json['previous_net_pay'] as num?)?.toDouble(),
      revisedNetPay: (json['revised_net_pay'] as num?)?.toDouble(),
      deltaAmount: (json['delta_amount'] as num?)?.toDouble(),
      notes: json['notes']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class PayrollImpactAlertDto {
  final bool hasImpact;
  final int affectedMonth;
  final int affectedYear;
  final String? payrollId;
  final String? payrollStatus;
  final String teacherName;
  final double previousDeduction;
  final double revisedDeduction;
  final double deltaAmount;
  final String explanation;

  const PayrollImpactAlertDto({
    required this.hasImpact,
    required this.affectedMonth,
    required this.affectedYear,
    this.payrollId,
    this.payrollStatus,
    required this.teacherName,
    required this.previousDeduction,
    required this.revisedDeduction,
    required this.deltaAmount,
    required this.explanation,
  });

  factory PayrollImpactAlertDto.fromJson(Map<String, dynamic> json) {
    return PayrollImpactAlertDto(
      hasImpact: json['has_impact'] == true,
      affectedMonth: (json['affected_month'] as num?)?.toInt() ?? 1,
      affectedYear: (json['affected_year'] as num?)?.toInt() ?? 2026,
      payrollId: json['payroll_id']?.toString(),
      payrollStatus: json['payroll_status']?.toString(),
      teacherName: json['teacher_name']?.toString() ?? '',
      previousDeduction: (json['previous_deduction'] as num?)?.toDouble() ?? 0.0,
      revisedDeduction: (json['revised_deduction'] as num?)?.toDouble() ?? 0.0,
      deltaAmount: (json['delta_amount'] as num?)?.toDouble() ?? 0.0,
      explanation: json['explanation']?.toString() ?? '',
    );
  }
}
