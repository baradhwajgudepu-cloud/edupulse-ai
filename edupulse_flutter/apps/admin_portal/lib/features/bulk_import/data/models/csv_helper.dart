import 'bulk_import_models.dart';

class CsvHelper {
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

  static List<ParsedRow> validateCsv(
    List<List<String>> csvRows,
    ImportType type, {
    Set<String> existingAdmissionNumbers = const {},
    Set<String> existingRollSectionKeys = const {},
  }) {
    if (csvRows.isEmpty) {
      return [];
    }

    final headers = csvRows.first.map((h) => h.toLowerCase().trim()).toList();
    final List<ParsedRow> parsedRows = [];

    // Set of required fields per type
    final requiredColumns = getRequiredColumns(type);
    final validColumns = _getValidColumns(type);

    // Header validations
    final List<String> headerErrors = [];
    final List<String> headerWarnings = [];

    // Check for missing required columns
    for (final req in requiredColumns) {
      if (!headers.contains(req.toLowerCase())) {
        headerErrors.add('Missing required column header: "$req"');
      }
    }

    // Custom header checks for students: class and section fields
    if (type == ImportType.students) {
      final hasClassId = headers.contains('class_id');
      final hasClassName = headers.contains('class_name');
      final hasClassCode = headers.contains('class_code');
      if (!hasClassId && !hasClassName && !hasClassCode) {
        headerErrors.add('Missing required column header for Class. Please supply "class_id", "class_name", or "class_code".');
      }

      final hasSectionId = headers.contains('section_id');
      final hasSectionName = headers.contains('section_name');
      final hasSectionCode = headers.contains('section_code');
      if (!hasSectionId && !hasSectionName && !hasSectionCode) {
        headerErrors.add('Missing required column header for Section. Please supply "section_id", "section_name", or "section_code".');
      }
    }

    // Check for duplicate columns
    final seenHeaders = <String>{};
    for (final h in headers) {
      if (seenHeaders.contains(h)) {
        headerErrors.add('Duplicate column header detected: "$h"');
      }
      seenHeaders.add(h);
    }

    // Check for unexpected columns
    for (final h in headers) {
      if (!validColumns.map((c) => c.toLowerCase()).contains(h)) {
        headerWarnings.add('Unexpected column header: "$h"');
      }
    }

    // If headers themselves have blocking errors, mark everything as error
    if (headerErrors.isNotEmpty) {
      return [
        ParsedRow(
          rowIndex: 1,
          data: {},
          errors: headerErrors,
          warnings: headerWarnings,
          status: ImportRowStatus.error,
        )
      ];
    }

    // Process data rows
    final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    final dateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    final hexColorRegex = RegExp(r'^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$');
    final codeRegex = RegExp(r'^[A-Z0-9_]+$');

    // Duplicate tracking inside file
    final seenAdmissionNumbers = <String>{};
    final seenRollSectionKeys = <String>{};
    final seenCodes = <String>{};

    for (int i = 1; i < csvRows.length; i++) {
      final rawRow = csvRows[i];
      // Skip empty or mismatching length rows gracefully
      if (rawRow.isEmpty || rawRow.join('').trim().isEmpty) continue;

      final Map<String, String> rowData = {};
      for (int colIdx = 0; colIdx < headers.length; colIdx++) {
        if (colIdx < rawRow.length) {
          rowData[headers[colIdx]] = rawRow[colIdx];
        } else {
          rowData[headers[colIdx]] = '';
        }
      }

      final List<String> rowErrors = [];
      final List<String> rowWarnings = [];

      // Validate required field values are not empty
      for (final req in requiredColumns) {
        final val = rowData[req.toLowerCase()] ?? '';
        if (val.trim().isEmpty) {
          rowErrors.add('Required field "$req" cannot be empty');
        }
      }

      // Perform entity-specific validations
      if (type == ImportType.students) {
        // Gender
        final gender = (rowData['gender'] ?? '').toUpperCase();
        if (gender.isNotEmpty && gender != 'MALE' && gender != 'FEMALE' && gender != 'OTHER') {
          rowErrors.add('Gender must be MALE, FEMALE, or OTHER');
        }

        // Dates
        final dob = rowData['date_of_birth'] ?? '';
        if (dob.isNotEmpty && (!dateRegex.hasMatch(dob) || DateTime.tryParse(dob) == null)) {
          rowErrors.add('Date of birth must be in YYYY-MM-DD format');
        }
        final admDate = rowData['admission_date'] ?? '';
        if (admDate.isNotEmpty && (!dateRegex.hasMatch(admDate) || DateTime.tryParse(admDate) == null)) {
          rowErrors.add('Admission date must be in YYYY-MM-DD format');
        }

        final classId = (rowData['class_id'] ?? '').trim();
        final className = (rowData['class_name'] ?? '').trim();
        final classCode = (rowData['class_code'] ?? '').trim();

        if (classId.isNotEmpty) {
          if (!uuidRegex.hasMatch(classId)) {
            rowErrors.add('class_id must be a valid UUID');
          }
        } else {
          if (className.isEmpty && classCode.isEmpty) {
            rowErrors.add('Class identifier (class_id, class_name, or class_code) is required.');
          }
        }

        final sectionId = (rowData['section_id'] ?? '').trim();
        final sectionName = (rowData['section_name'] ?? '').trim();
        final sectionCode = (rowData['section_code'] ?? '').trim();

        if (sectionId.isNotEmpty) {
          if (!uuidRegex.hasMatch(sectionId)) {
            rowErrors.add('section_id must be a valid UUID');
          }
        } else {
          if (sectionName.isEmpty && sectionCode.isEmpty) {
            rowErrors.add('Section identifier (section_id, section_name, or section_code) is required.');
          }
        }

        final ayId = rowData['academic_year_id'] ?? '';
        if (ayId.isNotEmpty && !uuidRegex.hasMatch(ayId)) {
          rowErrors.add('academic_year_id must be a valid UUID');
        }

        // File duplicates checks
        final admNo = rowData['admission_number'] ?? '';
        if (admNo.isNotEmpty) {
          if (seenAdmissionNumbers.contains(admNo)) {
            rowErrors.add('Duplicate admission_number "$admNo" within this CSV');
          } else if (existingAdmissionNumbers.contains(admNo)) {
            rowErrors.add('Student with admission number "$admNo" already exists.');
          }
          seenAdmissionNumbers.add(admNo);
        }
        final rollNo = rowData['roll_number'] ?? '';
        if (rollNo.isNotEmpty && sectionId.isNotEmpty) {
          final rollSectionKey = '$rollNo|$sectionId';
          if (seenRollSectionKeys.contains(rollSectionKey)) {
            rowErrors.add('Student with roll number $rollNo already exists in this section.');
          } else if (existingRollSectionKeys.contains(rollSectionKey)) {
            rowErrors.add('Student with roll number $rollNo already exists in this section.');
          }
          seenRollSectionKeys.add(rollSectionKey);
        }
      } else if (type == ImportType.guardians) {
        // Type
        final gType = (rowData['guardian_type'] ?? '').toUpperCase();
        const validTypes = {'FATHER', 'MOTHER', 'LEGAL_GUARDIAN', 'GRANDPARENT', 'UNCLE', 'AUNT', 'OTHER'};
        if (gType.isNotEmpty && !validTypes.contains(gType)) {
          rowErrors.add('guardian_type must be FATHER, MOTHER, LEGAL_GUARDIAN, GRANDPARENT, UNCLE, AUNT, or OTHER');
        }

        // Gender
        final gender = (rowData['gender'] ?? '').toUpperCase();
        if (gender.isNotEmpty && gender != 'MALE' && gender != 'FEMALE' && gender != 'OTHER') {
          rowErrors.add('Gender must be MALE, FEMALE, or OTHER');
        }

        // Date of birth
        final dob = rowData['date_of_birth'] ?? '';
        if (dob.isNotEmpty && (!dateRegex.hasMatch(dob) || DateTime.tryParse(dob) == null)) {
          rowErrors.add('Date of birth must be in YYYY-MM-DD format');
        }
      } else if (type == ImportType.classes) {
        // Code pattern
        final code = rowData['code'] ?? '';
        if (code.isNotEmpty && !codeRegex.hasMatch(code)) {
          rowErrors.add('Code must match pattern ^[A-Z0-9_]+\$ (uppercase alphanumeric and underscores)');
        }
        if (code.isNotEmpty) {
          if (seenCodes.contains(code)) {
            rowErrors.add('Duplicate class code "$code" within this CSV');
          }
          seenCodes.add(code);
        }

        // academic_year_id UUID check
        final ayId = rowData['academic_year_id'] ?? '';
        if (ayId.isNotEmpty && !uuidRegex.hasMatch(ayId)) {
          rowErrors.add('academic_year_id must be a valid UUID');
        }

        // Numeric checks
        final levelStr = rowData['level'] ?? '';
        if (levelStr.isNotEmpty) {
          final lvl = int.tryParse(levelStr);
          if (lvl == null || lvl < 0) {
            rowErrors.add('level must be a non-negative integer');
          }
        }
        final capStr = rowData['capacity'] ?? '';
        if (capStr.isNotEmpty) {
          final cap = int.tryParse(capStr);
          if (cap == null || cap < 1) {
            rowErrors.add('capacity must be a positive integer');
          }
        }
      } else if (type == ImportType.sections) {
        // Code pattern
        final code = rowData['code'] ?? '';
        if (code.isNotEmpty && !codeRegex.hasMatch(code)) {
          rowErrors.add('Code must match pattern ^[A-Z0-9_]+\$ (uppercase alphanumeric and underscores)');
        }

        // Class ID UUID
        final classId = rowData['class_id'] ?? '';
        if (classId.isNotEmpty && !uuidRegex.hasMatch(classId)) {
          rowErrors.add('class_id must be a valid UUID');
        }

        final ayId = rowData['academic_year_id'] ?? '';
        if (ayId.isNotEmpty && !uuidRegex.hasMatch(ayId)) {
          rowErrors.add('academic_year_id must be a valid UUID');
        }

        // Numeric checks
        final capStr = rowData['capacity'] ?? '';
        if (capStr.isNotEmpty) {
          final cap = int.tryParse(capStr);
          if (cap == null || cap < 1) {
            rowErrors.add('capacity must be a positive integer');
          }
        }
      } else if (type == ImportType.subjects) {
        // Category check
        final cat = (rowData['category'] ?? '').toUpperCase();
        const validCats = {'CORE', 'ELECTIVE', 'LANGUAGE', 'OPTIONAL', 'LAB', 'SPORTS', 'ARTS', 'CO_CURRICULAR'};
        if (cat.isNotEmpty && !validCats.contains(cat)) {
          rowErrors.add('category must be CORE, ELECTIVE, LANGUAGE, OPTIONAL, LAB, SPORTS, ARTS, or CO_CURRICULAR');
        }

        // Type check
        final sType = (rowData['subject_type'] ?? '').toUpperCase();
        if (sType.isNotEmpty && sType != 'THEORY' && sType != 'PRACTICAL' && sType != 'THEORY_PRACTICAL') {
          rowErrors.add('subject_type must be THEORY, PRACTICAL, or THEORY_PRACTICAL');
        }

        // Numeric checks
        for (final field in ['credit_hours', 'weekly_periods', 'theory_marks', 'practical_marks', 'pass_marks']) {
          final val = rowData[field] ?? '';
          if (val.isNotEmpty) {
            final parsed = int.tryParse(val);
            if (parsed == null || parsed < 0) {
              rowErrors.add('$field must be a non-negative integer');
            }
          }
        }

        // Hex color check
        final color = rowData['display_color'] ?? '';
        if (color.isNotEmpty && !hexColorRegex.hasMatch(color)) {
          rowErrors.add('display_color must be a valid hex color code (e.g. #FF5733)');
        }

        final ayId = rowData['academic_year_id'] ?? '';
        if (ayId.isNotEmpty && !uuidRegex.hasMatch(ayId)) {
          rowErrors.add('academic_year_id must be a valid UUID');
        }
      }

      ImportRowStatus status = ImportRowStatus.valid;
      if (rowErrors.isNotEmpty) {
        final hasDuplicate = rowErrors.any((e) =>
            e.toLowerCase().contains('duplicate') ||
            e.toLowerCase().contains('already exists'));
        status = hasDuplicate ? ImportRowStatus.duplicate : ImportRowStatus.error;
      } else if (rowWarnings.isNotEmpty) {
        status = ImportRowStatus.warning;
      }

      parsedRows.add(
        ParsedRow(
          rowIndex: i + 1,
          data: rowData,
          errors: rowErrors,
          warnings: rowWarnings,
          status: status,
        ),
      );
    }

    return parsedRows;
  }

  static List<String> getRequiredColumns(ImportType type) {
    switch (type) {
      case ImportType.students:
        return [
          'first_name',
          'last_name',
          'gender',
          'date_of_birth',
          'admission_number',
          'roll_number',
          'admission_date',
          'academic_year_id',
        ];
      case ImportType.guardians:
        return ['guardian_type', 'first_name', 'last_name', 'gender', 'date_of_birth', 'mobile'];
      case ImportType.classes:
        return ['name', 'code', 'level', 'capacity', 'academic_year_id'];
      case ImportType.sections:
        return ['name', 'code', 'capacity', 'class_id', 'academic_year_id'];
      case ImportType.subjects:
        return ['subject_code', 'subject_name', 'category', 'subject_type', 'academic_year_id'];
    }
  }

  static List<String> _getValidColumns(ImportType type) {
    switch (type) {
      case ImportType.students:
        return [
          'first_name',
          'middle_name',
          'last_name',
          'gender',
          'date_of_birth',
          'blood_group',
          'aadhaar_number',
          'emis_number',
          'mobile',
          'phone',
          'email',
          'photo_url',
          'admission_number',
          'roll_number',
          'admission_date',
          'academic_year_id',
          'class_id',
          'section_id',
          'class_name',
          'class_code',
          'section_name',
          'section_code',
          'father_name',
          'mother_name',
          'address',
          'status',
        ];
      case ImportType.guardians:
        return [
          'guardian_type',
          'first_name',
          'middle_name',
          'last_name',
          'gender',
          'date_of_birth',
          'aadhaar_number',
          'pan_number',
          'occupation',
          'qualification',
          'organization',
          'annual_income',
          'mobile',
          'alternate_mobile',
          'email',
        ];
      case ImportType.classes:
        return ['name', 'display_name', 'code', 'level', 'category', 'stream', 'description', 'capacity', 'promotion_order', 'next_class_id', 'academic_year_id'];
      case ImportType.sections:
        return ['name', 'code', 'capacity', 'room_number', 'sort_order', 'description', 'class_id', 'academic_year_id'];
      case ImportType.subjects:
        return [
          'subject_code',
          'subject_name',
          'short_name',
          'category',
          'subject_type',
          'description',
          'credit_hours',
          'weekly_periods',
          'theory_marks',
          'practical_marks',
          'pass_marks',
          'display_color',
          'display_order',
          'academic_year_id'
        ];
    }
  }
}
