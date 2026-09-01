enum ConcessionType {
  FIXED,
  PERCENTAGE;

  String toJson() => name;
  static ConcessionType fromJson(String val) => ConcessionType.values.firstWhere((e) => e.name == val);
}

enum FineType {
  FIXED,
  PERCENTAGE,
  DAILY_FIXED;

  String toJson() => name;
  static FineType fromJson(String val) => FineType.values.firstWhere((e) => e.name == val);
}

class FeeType {
  final String id;
  final String tenantId;
  final String name;
  final String code;
  final String? description;
  final bool isSystem;
  final DateTime createdAt;
  final DateTime updatedAt;

  FeeType({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.code,
    this.description,
    required this.isSystem,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FeeType.fromJson(Map<String, dynamic> json) {
    return FeeType(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
      description: json['description'] as String?,
      isSystem: json['is_system'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'code': code,
      'description': description,
      'is_system': isSystem,
    };
  }
}

class Scholarship {
  final String id;
  final String tenantId;
  final String schoolId;
  final String name;
  final ConcessionType concessionType;
  final double value;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  Scholarship({
    required this.id,
    required this.tenantId,
    required this.schoolId,
    required this.name,
    required this.concessionType,
    required this.value,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Scholarship.fromJson(Map<String, dynamic> json) {
    return Scholarship(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      schoolId: json['school_id'] as String,
      name: json['name'] as String,
      concessionType: ConcessionType.fromJson(json['concession_type'] as String),
      value: (json['value'] as num).toDouble(),
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'concession_type': concessionType.toJson(),
      'value': value,
      'description': description,
    };
  }
}

class FineRule {
  final String id;
  final String tenantId;
  final String feeStructureId;
  final int gracePeriodDays;
  final FineType fineType;
  final double fineValue;

  FineRule({
    required this.id,
    required this.tenantId,
    required this.feeStructureId,
    required this.gracePeriodDays,
    required this.fineType,
    required this.fineValue,
  });

  factory FineRule.fromJson(Map<String, dynamic> json) {
    return FineRule(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      feeStructureId: json['fee_structure_id'] as String,
      gracePeriodDays: json['grace_period_days'] as int,
      fineType: FineType.fromJson(json['fine_type'] as String),
      fineValue: (json['fine_value'] as num).toDouble(),
    );
  }
}

class FineRuleInput {
  final int gracePeriodDays;
  final FineType fineType;
  final double fineValue;

  FineRuleInput({
    required this.gracePeriodDays,
    required this.fineType,
    required this.fineValue,
  });

  Map<String, dynamic> toJson() {
    return {
      'grace_period_days': gracePeriodDays,
      'fine_type': fineType.toJson(),
      'fine_value': fineValue,
    };
  }
}

class FeeStructure {
  final String id;
  final String tenantId;
  final String schoolId;
  final String feeTypeId;
  final String academicYearId;
  final String? classId;
  final double amount;
  final DateTime dueDate;
  final String? description;
  final FineRule? fineRule;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;

  FeeStructure({
    required this.id,
    required this.tenantId,
    required this.schoolId,
    required this.feeTypeId,
    required this.academicYearId,
    this.classId,
    required this.amount,
    required this.dueDate,
    this.description,
    this.fineRule,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FeeStructure.fromJson(Map<String, dynamic> json) {
    return FeeStructure(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      schoolId: json['school_id'] as String,
      feeTypeId: json['fee_type_id'] as String,
      academicYearId: json['academic_year_id'] as String,
      classId: json['class_id'] as String?,
      amount: (json['amount'] as num).toDouble(),
      dueDate: DateTime.parse(json['due_date'] as String),
      description: json['description'] as String?,
      fineRule: json['fine_rule'] != null
          ? FineRule.fromJson(json['fine_rule'] as Map<String, dynamic>)
          : null,
      version: json['version'] as int? ?? 1,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson({FineRuleInput? fineRuleInput}) {
    final Map<String, dynamic> data = {
      'fee_type_id': feeTypeId,
      'academic_year_id': academicYearId,
      'class_id': classId,
      'amount': amount,
      'due_date': '${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}',
      'description': description,
    };
    if (fineRuleInput != null) {
      data['fine_rule'] = fineRuleInput.toJson();
    }
    return data;
  }
}

class OutstandingClassMetric {
  final String className;
  final double outstandingAmount;

  OutstandingClassMetric({
    required this.className,
    required this.outstandingAmount,
  });

  factory OutstandingClassMetric.fromJson(Map<String, dynamic> json) {
    return OutstandingClassMetric(
      className: json['class_name'] as String? ?? 'Unknown Class',
      outstandingAmount: (json['outstanding_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DashboardMetrics {
  final double todayCollection;
  final double monthCollection;
  final double pendingDues;
  final double collectionPercentage;
  final int defaultersCount;
  final List<OutstandingClassMetric> topOutstandingClasses;

  DashboardMetrics({
    required this.todayCollection,
    required this.monthCollection,
    required this.pendingDues,
    required this.collectionPercentage,
    required this.defaultersCount,
    required this.topOutstandingClasses,
  });

  factory DashboardMetrics.fromJson(Map<String, dynamic> json) {
    final outstandingList = json['top_outstanding_classes'] as List<dynamic>? ?? [];
    return DashboardMetrics(
      todayCollection: (json['today_collection'] as num?)?.toDouble() ?? 0.0,
      monthCollection: (json['month_collection'] as num?)?.toDouble() ?? 0.0,
      pendingDues: (json['pending_dues'] as num?)?.toDouble() ?? 0.0,
      collectionPercentage: (json['collection_percentage'] as num?)?.toDouble() ?? 0.0,
      defaultersCount: (json['defaulters_count'] as num?)?.toInt() ?? 0,
      topOutstandingClasses: outstandingList.map((e) => OutstandingClassMetric.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class CollectionAnalytics {
  final double predictedCollectionNext30Days;
  final Map<String, double> historicalTrend;

  CollectionAnalytics({
    required this.predictedCollectionNext30Days,
    required this.historicalTrend,
  });

  factory CollectionAnalytics.fromJson(Map<String, dynamic> json) {
    final trendMap = json['historical_trend'] as Map<String, dynamic>? ?? {};
    return CollectionAnalytics(
      predictedCollectionNext30Days: (json['predicted_collection_next_30_days'] as num?)?.toDouble() ?? 0.0,
      historicalTrend: trendMap.map((key, val) => MapEntry(key, (val as num).toDouble())),
    );
  }
}

enum FeeAssignmentStatus {
  UNPAID,
  PARTIALLY_PAID,
  PAID;

  static FeeAssignmentStatus fromJson(String val) => FeeAssignmentStatus.values.firstWhere((e) => e.name == val);
}

class StudentFeeAssignment {
  final String id;
  final String tenantId;
  final String studentId;
  final String feeStructureId;
  final String academicYearId;
  final double assignedAmount;
  final String? scholarshipId;
  final double discountAmount;
  final double fineAmount;
  final double paidAmount;
  final FeeAssignmentStatus status;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;

  StudentFeeAssignment({
    required this.id,
    required this.tenantId,
    required this.studentId,
    required this.feeStructureId,
    required this.academicYearId,
    required this.assignedAmount,
    this.scholarshipId,
    required this.discountAmount,
    required this.fineAmount,
    required this.paidAmount,
    required this.status,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StudentFeeAssignment.fromJson(Map<String, dynamic> json) {
    return StudentFeeAssignment(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      studentId: json['student_id'] as String,
      feeStructureId: json['fee_structure_id'] as String,
      academicYearId: json['academic_year_id'] as String,
      assignedAmount: (json['assigned_amount'] as num).toDouble(),
      scholarshipId: json['scholarship_id'] as String?,
      discountAmount: (json['discount_amount'] as num).toDouble(),
      fineAmount: (json['fine_amount'] as num).toDouble(),
      paidAmount: (json['paid_amount'] as num).toDouble(),
      status: FeeAssignmentStatus.fromJson(json['status'] as String),
      version: json['version'] as int? ?? 1,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class FeePaymentAllocation {
  final String assignmentId;
  final double amountAllocated;

  FeePaymentAllocation({
    required this.assignmentId,
    required this.amountAllocated,
  });

  factory FeePaymentAllocation.fromJson(Map<String, dynamic> json) {
    return FeePaymentAllocation(
      assignmentId: json['assignment_id'] as String,
      amountAllocated: (json['amount_allocated'] as num).toDouble(),
    );
  }
}

enum PaymentStatus {
  COMPLETED,
  CANCELLED;

  static PaymentStatus fromJson(String val) => PaymentStatus.values.firstWhere((e) => e.name == val);
}

enum PaymentMethod {
  CASH,
  CHEQUE,
  BANK_TRANSFER,
  ONLINE;

  static PaymentMethod fromJson(String val) => PaymentMethod.values.firstWhere((e) => e.name == val);
}

class FeePayment {
  final String id;
  final String tenantId;
  final String studentId;
  final String academicYearId;
  final double amountPaid;
  final DateTime paymentDate;
  final PaymentMethod paymentMethod;
  final PaymentStatus status;
  final String? transactionReference;
  final String? receiptNumber;
  final String? remarks;
  final String? cancelReason;
  final String? cancelledBy;
  final DateTime? cancelledAt;
  final List<FeePaymentAllocation> allocations;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;

  FeePayment({
    required this.id,
    required this.tenantId,
    required this.studentId,
    required this.academicYearId,
    required this.amountPaid,
    required this.paymentDate,
    required this.paymentMethod,
    required this.status,
    this.transactionReference,
    this.receiptNumber,
    this.remarks,
    this.cancelReason,
    this.cancelledBy,
    this.cancelledAt,
    required this.allocations,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FeePayment.fromJson(Map<String, dynamic> json) {
    final allocList = json['allocations'] as List<dynamic>? ?? [];
    return FeePayment(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      studentId: json['student_id'] as String,
      academicYearId: json['academic_year_id'] as String,
      amountPaid: (json['amount_paid'] as num).toDouble(),
      paymentDate: DateTime.parse(json['payment_date'] as String),
      paymentMethod: PaymentMethod.fromJson(json['payment_method'] as String),
      status: PaymentStatus.fromJson(json['status'] as String),
      transactionReference: json['transaction_reference'] as String?,
      receiptNumber: json['receipt_number'] as String?,
      remarks: json['remarks'] as String?,
      cancelReason: json['cancel_reason'] as String?,
      cancelledBy: json['cancelled_by'] as String?,
      cancelledAt: json['cancelled_at'] != null ? DateTime.parse(json['cancelled_at'] as String) : null,
      allocations: allocList.map((e) => FeePaymentAllocation.fromJson(e as Map<String, dynamic>)).toList(),
      version: json['version'] as int? ?? 1,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class StudentLedger {
  final String studentId;
  final double openingBalance;
  final List<StudentFeeAssignment> assignments;
  final List<Scholarship> scholarships;
  final List<FeePayment> payments;
  final double closingBalance;

  StudentLedger({
    required this.studentId,
    required this.openingBalance,
    required this.assignments,
    required this.scholarships,
    required this.payments,
    required this.closingBalance,
  });

  factory StudentLedger.fromJson(Map<String, dynamic> json) {
    final assignList = json['assignments'] as List<dynamic>? ?? [];
    final scholarshipList = json['scholarships'] as List<dynamic>? ?? [];
    final paymentList = json['payments'] as List<dynamic>? ?? [];

    return StudentLedger(
      studentId: json['student_id'] as String,
      openingBalance: (json['opening_balance'] as num?)?.toDouble() ?? 0.0,
      assignments: assignList.map((e) => StudentFeeAssignment.fromJson(e as Map<String, dynamic>)).toList(),
      scholarships: scholarshipList.map((e) => Scholarship.fromJson(e as Map<String, dynamic>)).toList(),
      payments: paymentList.map((e) => FeePayment.fromJson(e as Map<String, dynamic>)).toList(),
      closingBalance: (json['closing_balance'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class OutstandingFeeReportItem {
  final String studentId;
  final String studentName;
  final String admissionNumber;
  final String classId;
  final String className;
  final String sectionId;
  final String sectionName;
  final String feeStructureId;
  final String feeTypeId;
  final String feeTypeName;
  final double assignedAmount;
  final double discountAmount;
  final double fineAmount;
  final double paidAmount;
  final double outstandingAmount;
  final DateTime dueDate;
  final String status;

  OutstandingFeeReportItem({
    required this.studentId,
    required this.studentName,
    required this.admissionNumber,
    required this.classId,
    required this.className,
    required this.sectionId,
    required this.sectionName,
    required this.feeStructureId,
    required this.feeTypeId,
    required this.feeTypeName,
    required this.assignedAmount,
    required this.discountAmount,
    required this.fineAmount,
    required this.paidAmount,
    required this.outstandingAmount,
    required this.dueDate,
    required this.status,
  });

  factory OutstandingFeeReportItem.fromJson(Map<String, dynamic> json) {
    return OutstandingFeeReportItem(
      studentId: json['student_id'] as String,
      studentName: json['student_name'] as String,
      admissionNumber: json['admission_number'] as String,
      classId: json['class_id'] as String,
      className: json['class_name'] as String,
      sectionId: json['section_id'] as String,
      sectionName: json['section_name'] as String,
      feeStructureId: json['fee_structure_id'] as String,
      feeTypeId: json['fee_type_id'] as String,
      feeTypeName: json['fee_type_name'] as String,
      assignedAmount: (json['assigned_amount'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0.0,
      fineAmount: (json['fine_amount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0.0,
      outstandingAmount: (json['outstanding_amount'] as num?)?.toDouble() ?? 0.0,
      dueDate: DateTime.parse(json['due_date'] as String),
      status: json['status'] as String,
    );
  }
}
