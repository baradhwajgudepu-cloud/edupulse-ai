import 'school_onboarding_models.dart';

class SchoolOnboardingValidators {
  static final RegExp _emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  static final RegExp _dateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  static final RegExp _timeRegex = RegExp(r'^\d{2}:\d{2}(:\d{2})?$');

  static List<List<String>> parseCsv(String csvText) {
    final List<List<String>> rows = [];
    final List<String> lines = csvText.split(RegExp(r'\r?\n'));
    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      final List<String> row = [];
      final StringBuffer buffer = StringBuffer();
      bool inQuotes = false;

      for (int i = 0; i < line.length; i++) {
        final char = line[i];
        if (char == '"') {
          inQuotes = !inQuotes;
        } else if (char == ',' && !inQuotes) {
          row.add(_cleanCell(buffer.toString()));
          buffer.clear();
        } else {
          buffer.write(char);
        }
      }
      row.add(_cleanCell(buffer.toString()));
      rows.add(row);
    }
    return rows;
  }

  static String _cleanCell(String value) {
    var s = value.trim();
    if (s.startsWith('"') && s.endsWith('"') && s.length >= 2) {
      s = s.substring(1, s.length - 1);
    }
    return s.replaceAll('""', '"');
  }

  static List<String> getRequiredColumns(OnboardingStep step) {
    switch (step) {
      case OnboardingStep.school:
        return ['school_code', 'school_name', 'board', 'school_type', 'email', 'phone', 'status'];
      case OnboardingStep.academicYears:
        return ['school_code', 'academic_year_code', 'academic_year_name', 'start_date', 'end_date', 'status', 'is_current'];
      case OnboardingStep.classes:
        return ['academic_year_code', 'class_code', 'display_label', 'level', 'grade_category', 'max_capacity', 'status'];
      case OnboardingStep.sections:
        return ['class_code', 'section_code', 'section_name', 'capacity', 'room_number', 'display_sort_order', 'status'];
      case OnboardingStep.subjects:
        return ['subject_code', 'subject_name', 'category', 'subject_type', 'academic_year_code'];
      case OnboardingStep.teachers:
        return ['teacher_code', 'first_name', 'last_name', 'gender', 'date_of_birth', 'mobile', 'email', 'employee_code', 'designation', 'joining_date', 'status'];
      case OnboardingStep.guardians:
        return ['guardian_code', 'first_name', 'last_name', 'gender', 'date_of_birth', 'mobile', 'email', 'guardian_type', 'status'];
      case OnboardingStep.students:
        return ['admission_number', 'first_name', 'last_name', 'gender', 'date_of_birth', 'admission_date', 'roll_number', 'academic_year_code', 'class_code', 'section_code', 'status'];
      case OnboardingStep.relationships:
        return ['admission_number', 'guardian_code', 'relationship', 'is_primary', 'authorized_for_pickup', 'receives_notifications'];
      case OnboardingStep.teacherAssignments:
        return ['teacher_code', 'subject_code', 'class_code', 'section_code', 'academic_year_code'];
      case OnboardingStep.timetable:
        return ['academic_year_code', 'day_of_week', 'period_number', 'start_time', 'end_time', 'class_code', 'section_code', 'subject_code', 'teacher_code', 'room_number', 'period_type'];
      case OnboardingStep.syllabus:
        return ['academic_year_code', 'class_code', 'subject_code', 'syllabus_code', 'unit_name', 'chapter_name', 'topic_name'];
      case OnboardingStep.exams:
        return ['academic_year_code', 'exam_code', 'exam_name', 'exam_type', 'class_code', 'subject_code', 'exam_date', 'maximum_marks', 'duration_minutes'];
      default:
        return [];
    }
  }

  static OnboardingSheetData validateSheet(OnboardingStep step, String fileName, List<List<String>> csvRows) {
    if (csvRows.isEmpty) {
      return OnboardingSheetData(
        step: step,
        fileName: fileName,
        headers: [],
        rows: [],
        sheetErrorMessage: 'The uploaded file is empty.',
      );
    }

    final headers = csvRows.first.map((h) => h.toLowerCase().trim()).toList();
    final requiredColumns = getRequiredColumns(step);

    // Validate headers
    final List<String> headerErrors = [];
    for (final req in requiredColumns) {
      if (!headers.contains(req.toLowerCase())) {
        headerErrors.add('Missing required column header: "$req"');
      }
    }

    if (headerErrors.isNotEmpty) {
      return OnboardingSheetData(
        step: step,
        fileName: fileName,
        headers: headers,
        rows: [],
        sheetErrorMessage: headerErrors.join('; '),
      );
    }

    // Verify row duplicates within file
    final Set<String> uniqueKeys = {};
    final String keyColumnName = _getKeyColumn(step);

    final List<OnboardingParsedRow> parsedRows = [];

    for (int i = 1; i < csvRows.length; i++) {
      final csvRow = csvRows[i];
      if (csvRow.isEmpty || csvRow.every((cell) => cell.isEmpty)) continue;

      final Map<String, String> data = {};
      for (int hIdx = 0; hIdx < headers.length; hIdx++) {
        if (hIdx < csvRow.length) {
          data[headers[hIdx]] = csvRow[hIdx].trim();
        } else {
          data[headers[hIdx]] = '';
        }
      }

      final List<String> errors = [];
      final List<String> warnings = [];
      final List<String> duplicates = [];
      final List<String> unresolvedReferences = [];

      // Validate required fields
      for (final req in requiredColumns) {
        final val = data[req.toLowerCase()];
        if (val == null || val.isEmpty) {
          errors.add('Column "$req" is required and cannot be blank.');
        }
      }

      // Check key duplication inside sheet
      if (keyColumnName.isNotEmpty) {
        String keyValue = data[keyColumnName.toLowerCase()] ?? '';
        if (step == OnboardingStep.sections) {
          final classCode = data['class_code'] ?? '';
          keyValue = '$classCode-$keyValue';
        }
        if (keyValue.isNotEmpty) {
          if (uniqueKeys.contains(keyValue)) {
            final displayVal = step == OnboardingStep.sections ? keyValue.split('-').last : keyValue;
            duplicates.add('Duplicate record inside CSV sheet on $keyColumnName "$displayVal".');
          } else {
            uniqueKeys.add(keyValue);
          }
        }
      }

      // Apply entity-specific validators
      _validateRowValues(step, data, errors, warnings, unresolvedReferences);

      OnboardingRowStatus status = OnboardingRowStatus.valid;
      if (errors.isNotEmpty) {
        status = OnboardingRowStatus.error;
      } else if (duplicates.isNotEmpty) {
        status = OnboardingRowStatus.duplicate;
      } else if (unresolvedReferences.isNotEmpty) {
        status = OnboardingRowStatus.unresolved;
      } else if (warnings.isNotEmpty) {
        status = OnboardingRowStatus.warning;
      }

      parsedRows.add(OnboardingParsedRow(
        rowIndex: i + 1,
        data: data,
        errors: errors,
        warnings: warnings,
        duplicates: duplicates,
        unresolvedReferences: unresolvedReferences,
        status: status,
      ));
    }

    return OnboardingSheetData(
      step: step,
      fileName: fileName,
      headers: headers,
      rows: parsedRows,
    );
  }

  static String _getKeyColumn(OnboardingStep step) {
    switch (step) {
      case OnboardingStep.school:
        return 'school_code';
      case OnboardingStep.academicYears:
        return 'academic_year_code';
      case OnboardingStep.classes:
        return 'class_code';
      case OnboardingStep.sections:
        return 'section_code';
      case OnboardingStep.subjects:
        return 'subject_code';
      case OnboardingStep.teachers:
        return 'teacher_code';
      case OnboardingStep.guardians:
        return 'guardian_code';
      case OnboardingStep.students:
        return 'admission_number';
      case OnboardingStep.exams:
        return 'exam_code';
      default:
        return '';
    }
  }

  static void _validateRowValues(
    OnboardingStep step,
    Map<String, String> data,
    List<String> errors,
    List<String> warnings,
    List<String> unresolvedReferences,
  ) {
    // Email Checkers
    if (data.containsKey('email')) {
      final email = data['email'] ?? '';
      if (email.isNotEmpty && !_emailRegex.hasMatch(email)) {
        errors.add('Invalid email format (found: "$email")');
      }
    }
    if (data.containsKey('official_email')) {
      final email = data['official_email'] ?? '';
      if (email.isNotEmpty && !_emailRegex.hasMatch(email)) {
        errors.add('Invalid official email format (found: "$email")');
      }
    }

    // Date Checkers
    final dateFields = ['start_date', 'end_date', 'date_of_birth', 'joining_date', 'admission_date', 'exam_date'];
    for (final f in dateFields) {
      if (data.containsKey(f)) {
        final val = data[f] ?? '';
        if (val.isNotEmpty && !_dateRegex.hasMatch(val)) {
          errors.add('Column "$f" must match YYYY-MM-DD format (found: "$val")');
        }
      }
    }

    // Time Checkers
    final timeFields = ['start_time', 'end_time'];
    for (final f in timeFields) {
      if (data.containsKey(f)) {
        final val = data[f] ?? '';
        if (val.isNotEmpty && !_timeRegex.hasMatch(val)) {
          errors.add('Column "$f" must match HH:MM or HH:MM:SS format (found: "$val")');
        }
      }
    }

    // Boolean Checkers
    final boolFields = ['is_current', 'is_primary', 'authorized_for_pickup', 'receives_notifications'];
    for (final f in boolFields) {
      if (data.containsKey(f)) {
        final val = data[f]?.toLowerCase() ?? '';
        if (val.isNotEmpty && val != 'true' && val != 'false' && val != 'yes' && val != 'no') {
          errors.add('Column "$f" must be a boolean true/false or yes/no.');
        }
      }
    }

    // Specific Step logic
    switch (step) {
      case OnboardingStep.school:
        final board = data['board']?.toUpperCase() ?? '';
        if (board.isNotEmpty && board != 'CBSE' && board != 'ICSE' && board != 'STATE' && board != 'IB' && board != 'IGCSE') {
          warnings.add('Optional: Non-standard board registry type "$board".');
        }
        final schoolType = data['school_type'] ?? '';
        final validSchoolTypes = ['PRIMARY', 'HIGH_SCHOOL', 'JR_COLLEGE', 'DEGREE_COLLEGE', 'UNIVERSITY', 'OTHER'];
        if (schoolType.isEmpty) {
          errors.add('school_type is required.');
        } else if (!validSchoolTypes.contains(schoolType.toUpperCase())) {
          errors.add('school_type must be one of PRIMARY, HIGH_SCHOOL, JR_COLLEGE, DEGREE_COLLEGE, UNIVERSITY, or OTHER (found: "$schoolType").');
        }
        break;

      case OnboardingStep.academicYears:
        final code = data['academic_year_code'] ?? '';
        final codeRegex = RegExp(r'^AY[0-9]{4}(?:-[0-9]{4})?$');
        if (code.isEmpty) {
          errors.add('academic_year_code is required.');
        } else if (!codeRegex.hasMatch(code)) {
          errors.add('Academic year code must match pattern AYYYY-YYYY (found: "$code"). Example: AY2025-2026');
        }
        final status = data['status']?.toUpperCase() ?? '';
        if (status.isEmpty) {
          errors.add('status is required.');
        } else if (status != 'UPCOMING' && status != 'ACTIVE' && status != 'COMPLETED' && status != 'ARCHIVED') {
          errors.add('Status must be UPCOMING, ACTIVE, COMPLETED, or ARCHIVED (found: "$status")');
        }
        final schoolCode = data['school_code'] ?? '';
        if (schoolCode.isEmpty) {
          errors.add('school_code is required.');
        }
        break;

      case OnboardingStep.classes:
        final cap = int.tryParse(data['capacity'] ?? data['max_capacity'] ?? '');
        if (cap == null || cap <= 0) {
          errors.add('Capacity limits must be a positive integer.');
        }
        final level = int.tryParse(data['level'] ?? '');
        if (level == null || level <= 0) {
          errors.add('Class level index must be a positive integer.');
        }
        final cat = data['grade_category']?.toUpperCase() ?? '';
        if (cat.isNotEmpty && cat != 'PRE_PRIMARY' && cat != 'PRIMARY' && cat != 'MIDDLE' && cat != 'HIGH') {
          errors.add('grade_category must be PRE_PRIMARY, PRIMARY, MIDDLE, or HIGH (found: "$cat")');
        }
        final ayCode = data['academic_year_code'] ?? '';
        if (ayCode.isEmpty) {
          errors.add('academic_year_code is required.');
        }
        break;

      case OnboardingStep.sections:
        final cap = int.tryParse(data['capacity'] ?? '');
        if (cap == null || cap <= 0) {
          errors.add('Section capacity limit must be a positive integer.');
        }
        final classCode = data['class_code'] ?? '';
        if (classCode.isEmpty) {
          unresolvedReferences.add('Missing parent class reference.');
        }
        break;

      case OnboardingStep.subjects:
        final cat = data['category']?.toUpperCase() ?? '';
        if (cat.isNotEmpty && cat != 'CORE' && cat != 'ELECTIVE' && cat != 'LANGUAGE' && cat != 'OPTIONAL' && cat != 'LAB' && cat != 'SPORTS' && cat != 'ARTS' && cat != 'CO_CURRICULAR') {
          errors.add('Subject category must match enums (found: "$cat")');
        }
        final type = data['subject_type']?.toUpperCase() ?? '';
        if (type.isNotEmpty && type != 'THEORY' && type != 'PRACTICAL' && type != 'THEORY_PRACTICAL') {
          errors.add('Subject type must be THEORY, PRACTICAL, or THEORY_PRACTICAL (found: "$type")');
        }
        final ay = data['academic_year_code'] ?? '';
        if (ay.isEmpty) {
          unresolvedReferences.add('Missing academic year code reference.');
        }

        // Marks validation matching backend rules
        final theoryMarks = int.tryParse(data['theory_marks'] ?? '') ?? 0;
        final practicalMarks = int.tryParse(data['practical_marks'] ?? '') ?? 0;
        final passMarks = int.tryParse(data['pass_marks'] ?? '') ?? 0;

        if (type == 'THEORY' && practicalMarks > 0) {
          errors.add('Theory-only subjects cannot have practical marks.');
        }
        if (type == 'PRACTICAL' && theoryMarks > 0) {
          errors.add('Practical-only subjects cannot have theory marks.');
        }
        if (passMarks > (theoryMarks + practicalMarks)) {
          errors.add('Passing marks cannot exceed total theory and practical marks.');
        }
        break;

      case OnboardingStep.teachers:
        final gen = data['gender']?.toUpperCase() ?? '';
        if (gen.isNotEmpty && gen != 'MALE' && gen != 'FEMALE' && gen != 'OTHER') {
          errors.add('Gender must be MALE, FEMALE, or OTHER.');
        }

        final staffCode = data['staff_code'] ?? data['teacher_code'] ?? '';
        if (staffCode.isEmpty) {
          errors.add('staff_code is required for Teachers Roster.');
        }

        final officialEmail = data['official_email'] ?? data['email'] ?? '';
        if (officialEmail.isEmpty) {
          errors.add('official_email is required for Teachers Roster.');
        } else if (!_emailRegex.hasMatch(officialEmail)) {
          errors.add('Invalid official email format (found: "$officialEmail")');
        }

        final empType = data['employment_type'] ?? '';
        if (empType.isEmpty) {
          errors.add('employment_type is required for Teachers Roster.');
        } else {
          final empTypeUpper = empType.toUpperCase();
          if (empTypeUpper != 'FULL_TIME' && empTypeUpper != 'PART_TIME' && empTypeUpper != 'CONTRACT' && empTypeUpper != 'VISITING') {
            errors.add('Employment type must match enums (found: "$empTypeUpper")');
          }
        }
        break;

      case OnboardingStep.guardians:
        final gen = data['gender']?.toUpperCase() ?? '';
        if (gen.isNotEmpty && gen != 'MALE' && gen != 'FEMALE' && gen != 'OTHER') {
          errors.add('Gender must be MALE, FEMALE, or OTHER.');
        }
        final type = data['guardian_type'] ?? '';
        if (type.isEmpty) {
          errors.add('guardian_type is required for Parents & Guardians.');
        } else {
          final typeUpper = type.toUpperCase();
          if (typeUpper != 'FATHER' &&
              typeUpper != 'MOTHER' &&
              typeUpper != 'LEGAL_GUARDIAN' &&
              typeUpper != 'GRANDPARENT' &&
              typeUpper != 'UNCLE' &&
              typeUpper != 'AUNT' &&
              typeUpper != 'OTHER') {
            errors.add('Guardian type must match standard relationships (found: "$typeUpper")');
          }
        }
        break;

      case OnboardingStep.students:
        final gen = data['gender']?.toUpperCase() ?? '';
        if (gen.isNotEmpty && gen != 'MALE' && gen != 'FEMALE' && gen != 'OTHER') {
          errors.add('Gender must be MALE, FEMALE, or OTHER.');
        }
        final dob = data['date_of_birth'] ?? '';
        if (dob.isEmpty) {
          errors.add('date_of_birth is required for Students Register.');
        }
        final admDate = data['admission_date'] ?? '';
        if (admDate.isEmpty) {
          errors.add('admission_date is required for Students Register.');
        }
        final rollVal = data['roll_number'] ?? '';
        if (rollVal.isEmpty) {
          errors.add('roll_number is required for Students Register.');
        } else {
          final roll = int.tryParse(rollVal);
          if (roll == null || roll <= 0) {
            errors.add('Roll number must be a positive integer.');
          }
        }
        break;

      case OnboardingStep.relationships:
        final adm = data['admission_number'] ?? '';
        if (adm.isEmpty) {
          unresolvedReferences.add('Missing student admission number reference.');
        }
        final gCode = data['guardian_code'] ?? '';
        if (gCode.isEmpty) {
          unresolvedReferences.add('Missing guardian code link reference.');
        }
        break;

      case OnboardingStep.teacherAssignments:
        if ((data['teacher_code'] ?? '').isEmpty) {
          unresolvedReferences.add('Missing teacher assignment reference.');
        }
        if ((data['subject_code'] ?? '').isEmpty) {
          unresolvedReferences.add('Missing subject assignment reference.');
        }

        final assignmentType = data['assignment_type'] ?? '';
        if (assignmentType.isEmpty) {
          errors.add('assignment_type is required for Teacher Assignments.');
        } else {
          final typeUpper = assignmentType.toUpperCase();
          if (typeUpper != 'PRIMARY' && typeUpper != 'SECONDARY' && typeUpper != 'SUBSTITUTE') {
            errors.add('assignment_type must match enums (found: "$typeUpper")');
          }
        }

        final weeklyPeriodsRaw = data['weekly_periods'] ?? '';
        final parsedPeriods = double.tryParse(weeklyPeriodsRaw)?.toInt();
        if (weeklyPeriodsRaw.isEmpty || parsedPeriods == null) {
          errors.add('weekly_periods is required for Teacher Assignments.');
        }

        final effectiveFrom = data['effective_from'] ?? '';
        if (effectiveFrom.isEmpty) {
          errors.add('effective_from is required for Teacher Assignments.');
        }
        break;

      case OnboardingStep.timetable:
        final day = data['day_of_week']?.toUpperCase() ?? '';
        if (day.isNotEmpty && day != 'MONDAY' && day != 'TUESDAY' && day != 'WEDNESDAY' && day != 'THURSDAY' && day != 'FRIDAY' && day != 'SATURDAY' && day != 'SUNDAY') {
          errors.add('Timetable day must match standard weekdays (found: "$day")');
        }
        final period = int.tryParse(data['period_number'] ?? '');
        if (period == null || period <= 0) {
          errors.add('Period number must be a positive integer.');
        }

        final periodType = data['period_type'] ?? '';
        if (periodType.isEmpty) {
          errors.add('period_type is required for Timetable Slots.');
        } else {
          final typeUpper = periodType.toUpperCase();
          if (typeUpper != 'REGULAR' && typeUpper != 'LAB' && typeUpper != 'SPORTS' && typeUpper != 'LIBRARY' && typeUpper != 'BREAK' && typeUpper != 'EXAM') {
            errors.add('period_type must match enums (found: "$typeUpper")');
          }
        }
        break;

      case OnboardingStep.exams:
        final marks = int.tryParse(data['maximum_marks'] ?? '');
        if (marks == null || marks <= 0) {
          errors.add('Maximum marks must be a positive integer.');
        }
        final duration = int.tryParse(data['duration_minutes'] ?? '');
        if (duration == null || duration <= 0) {
          errors.add('Duration minutes must be a positive integer.');
        }
        final typeEx = data['exam_type'] ?? '';
        if (typeEx.isEmpty) {
          errors.add('exam_type is required for Exams & Documents.');
        } else {
          final typeUpper = typeEx.toUpperCase();
          if (typeUpper != 'UNIT_TEST' &&
              typeUpper != 'MONTHLY' &&
              typeUpper != 'QUARTERLY' &&
              typeUpper != 'HALF_YEARLY' &&
              typeUpper != 'PRE_FINAL' &&
              typeUpper != 'ANNUAL' &&
              typeUpper != 'SUPPLEMENTARY') {
            errors.add('Exam type must match enums: UNIT_TEST, MONTHLY, QUARTERLY, HALF_YEARLY, PRE_FINAL, ANNUAL, SUPPLEMENTARY (found: "$typeUpper")');
          }
        }
        final examDate = data['exam_date'] ?? '';
        if (examDate.isEmpty) {
          errors.add('exam_date is required for Exams & Documents.');
        }
        break;

      default:
        break;
    }
  }
}
