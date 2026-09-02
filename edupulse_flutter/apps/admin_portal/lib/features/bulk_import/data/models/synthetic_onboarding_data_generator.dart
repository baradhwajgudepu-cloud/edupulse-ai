import 'school_onboarding_models.dart';
import 'school_onboarding_validators.dart';

class SyntheticOnboardingDataGenerator {
  static const String defaultAyCode = 'AY2025-2026';
  static const String defaultAyName = 'Academic Year 2025-2026';

  static const List<String> teluguFirstNamesMale = [
    'Aarav', 'Abhinav', 'Aditya', 'Akhil', 'Anirudh', 'Arjun', 'Bhavan', 'Chaitanya',
    'Deepak', 'Dhanush', 'Eshwar', 'Ganesh', 'Goutham', 'Harsha', 'Hemant', 'Kalyan',
    'Karthik', 'Koushik', 'Lokesh', 'Manoj', 'Naveen', 'Nikhil', 'Pavan', 'Pranav',
    'Praneeth', 'Rahul', 'Rakesh', 'Rishi', 'Rohit', 'Sai', 'Sameer', 'Sandeep',
    'Santosh', 'Sarath', 'Satish', 'Shashi', 'Siddharth', 'Srikanth', 'Srinivas',
    'Surya', 'Tarun', 'Teja', 'Uday', 'Varun', 'Venkatesh', 'Vignesh', 'Vijay',
    'Vikram', 'Vinay', 'Vishnu', 'Yashwanth', 'Chandra', 'Madhav', 'Manish'
  ];

  static const List<String> teluguFirstNamesFemale = [
    'Aadhya', 'Aakanksha', 'Alekhya', 'Amrutha', 'Ananya', 'Anusha', 'Archana',
    'Bhavana', 'Bhavya', 'Chandana', 'Deepika', 'Divya', 'Geetha', 'Harini', 'Harshini',
    'Ishwarya', 'Jahnavi', 'Jyothi', 'Kavya', 'Keerthi', 'Krithi', 'Lavanya',
    'Madhuri', 'Manasa', 'Meghana', 'Navya', 'Niharika', 'Pallavi', 'Pavani',
    'Pooja', 'Pranathi', 'Pravallika', 'Pratyusha', 'Priyanka', 'Radhika', 'Ramya',
    'Rashmitha', 'Ruchitha', 'Sahithi', 'Sameera', 'Sandhya', 'Sanjana', 'Sharanya',
    'Shravani', 'Sindhu', 'Sirisha', 'Sneha', 'Spandana', 'Sravya', 'Sreeja',
    'Srini', 'Sruthi', 'Sucharitha', 'Suhasini', 'Supriya', 'Swathi', 'Tanmayi',
    'Tejaswi', 'Vaishnavi', 'Vandana', 'Varshini', 'Vennela', 'Yamini'
  ];

  static const List<String> teluguLastNames = [
    'Rao', 'Reddy', 'Sharma', 'Goud', 'Chowdary', 'Varma', 'Naidu', 'Gupta',
    'Murthy', 'Sastry', 'Babu', 'Yadav', 'Patel', 'Venkatesh', 'Vemula', 'Bandi',
    'Kandula', 'Gudepu', 'Singireddy', 'Pothula', 'Kondapalli', 'Malkapuram',
    'Chintala', 'Gaddam', 'Boddu', 'Maddela', 'Komati', 'Narra', 'Thota', 'Avula',
    'Siripuram', 'Yerra', 'Goli', 'Sunkari', 'Mothukuri', 'Dasari', 'Challa',
    'Boya', 'Kammari', 'Vangala', 'Nallam', 'Katakam', 'Gampa', 'Peddinti',
    'Komuravelli', 'Polisetty', 'Katta', 'Chilukuri', 'Medasani', 'Nimmagadda'
  ];

  static const List<Map<String, String>> teacherProfiles = [
    {'code': 'TCH001', 'first': 'Dr. Sreenivas', 'last': 'Sharma', 'gender': 'MALE', 'dob': '1978-04-12', 'mob': '9848011221', 'email': 'sreenivas.sharma@telanganaschool.edu', 'emp': 'EMP101', 'desig': 'PRINCIPAL', 'join': '2015-06-01', 'mid': '', 'type': 'FULL_TIME'},
    {'code': 'TCH002', 'first': 'Ananya', 'last': 'Reddy', 'gender': 'FEMALE', 'dob': '1983-05-18', 'mob': '9848011222', 'email': 'ananya.reddy@telanganaschool.edu', 'emp': 'EMP102', 'desig': 'PGT', 'join': '2016-06-01', 'mid': '', 'type': 'FULL_TIME'},
    {'code': 'TCH003', 'first': 'Rajesh', 'last': 'Goud', 'gender': 'MALE', 'dob': '1985-11-23', 'mob': '9848011223', 'email': 'rajesh.goud@telanganaschool.edu', 'emp': 'EMP103', 'desig': 'PGT', 'join': '2017-06-01', 'mid': 'Kumar', 'type': 'FULL_TIME'},
    {'code': 'TCH004', 'first': 'Kavitha', 'last': 'Rao', 'gender': 'FEMALE', 'dob': '1988-08-14', 'mob': '9848011224', 'email': 'kavitha.rao@telanganaschool.edu', 'emp': 'EMP104', 'desig': 'PGT', 'join': '2017-06-01', 'mid': '', 'type': 'FULL_TIME'},
    {'code': 'TCH005', 'first': 'Venkat', 'last': 'Ramana', 'gender': 'MALE', 'dob': '1982-01-30', 'mob': '9848011225', 'email': 'venkat.ramana@telanganaschool.edu', 'emp': 'EMP105', 'desig': 'TGT', 'join': '2018-06-01', 'mid': '', 'type': 'FULL_TIME'},
    {'code': 'TCH006', 'first': 'Sunitha', 'last': 'Chowdary', 'gender': 'FEMALE', 'dob': '1990-03-25', 'mob': '9848011226', 'email': 'sunitha.chowdary@telanganaschool.edu', 'emp': 'EMP106', 'desig': 'TGT', 'join': '2018-06-01', 'mid': '', 'type': 'FULL_TIME'},
    {'code': 'TCH007', 'first': 'Madhav', 'last': 'Sastry', 'gender': 'MALE', 'dob': '1986-07-19', 'mob': '9848011227', 'email': 'madhav.sastry@telanganaschool.edu', 'emp': 'EMP107', 'desig': 'TGT', 'join': '2019-06-01', 'mid': '', 'type': 'FULL_TIME'},
    {'code': 'TCH008', 'first': 'Prathibha', 'last': 'Naidu', 'gender': 'FEMALE', 'dob': '1991-09-12', 'mob': '9848011228', 'email': 'prathibha.naidu@telanganaschool.edu', 'emp': 'EMP108', 'desig': 'TGT', 'join': '2019-06-01', 'mid': '', 'type': 'FULL_TIME'},
    {'code': 'TCH009', 'first': 'Karthik', 'last': 'Varma', 'gender': 'MALE', 'dob': '1987-12-05', 'mob': '9848011229', 'email': 'karthik.varma@telanganaschool.edu', 'emp': 'EMP109', 'desig': 'TGT', 'join': '2020-06-01', 'mid': '', 'type': 'FULL_TIME'},
    {'code': 'TCH010', 'first': 'Sandhya', 'last': 'Rani', 'gender': 'FEMALE', 'dob': '1992-06-22', 'mob': '9848011230', 'email': 'sandhya.rani@telanganaschool.edu', 'emp': 'EMP110', 'desig': 'TGT', 'join': '2020-06-01', 'mid': '', 'type': 'FULL_TIME'},
    {'code': 'TCH011', 'first': 'Ramesh', 'last': 'Yadav', 'gender': 'MALE', 'dob': '1984-10-15', 'mob': '9848011231', 'email': 'ramesh.yadav@telanganaschool.edu', 'emp': 'EMP111', 'desig': 'TGT', 'join': '2021-06-01', 'mid': '', 'type': 'FULL_TIME'},
    {'code': 'TCH012', 'first': 'Padmavathi', 'last': 'Gaddam', 'gender': 'FEMALE', 'dob': '1989-02-28', 'mob': '9848011232', 'email': 'padmavathi.gaddam@telanganaschool.edu', 'emp': 'EMP112', 'desig': 'TGT', 'join': '2021-06-01', 'mid': '', 'type': 'FULL_TIME'},
    {'code': 'TCH013', 'first': 'Sridhar', 'last': 'Babu', 'gender': 'MALE', 'dob': '1987-04-17', 'mob': '9848011233', 'email': 'sridhar.babu@telanganaschool.edu', 'emp': 'EMP113', 'desig': 'TGT', 'join': '2022-06-01', 'mid': '', 'type': 'FULL_TIME'},
    {'code': 'TCH014', 'first': 'Deepika', 'last': 'Kondapalli', 'gender': 'FEMALE', 'dob': '1993-08-11', 'mob': '9848011234', 'email': 'deepika.kondapalli@telanganaschool.edu', 'emp': 'EMP114', 'desig': 'TGT', 'join': '2022-06-01', 'mid': '', 'type': 'FULL_TIME'},
    {'code': 'TCH015', 'first': 'Naveen', 'last': 'Kumar', 'gender': 'MALE', 'dob': '1990-11-09', 'mob': '9848011235', 'email': 'naveen.kumar@telanganaschool.edu', 'emp': 'EMP115', 'desig': 'TGT', 'join': '2023-06-01', 'mid': '', 'type': 'FULL_TIME'},
    {'code': 'TCH016', 'first': 'Swapna', 'last': 'Boddu', 'gender': 'FEMALE', 'dob': '1994-05-16', 'mob': '9848011236', 'email': 'swapna.boddu@telanganaschool.edu', 'emp': 'EMP116', 'desig': 'TGT', 'join': '2023-06-01', 'mid': '', 'type': 'FULL_TIME'},
    {'code': 'TCH017', 'first': 'Santosh', 'last': 'Vemula', 'gender': 'MALE', 'dob': '1988-09-03', 'mob': '9848011237', 'email': 'santosh.vemula@telanganaschool.edu', 'emp': 'EMP117', 'desig': 'PRT', 'join': '2024-06-01', 'mid': '', 'type': 'FULL_TIME'},
    {'code': 'TCH018', 'first': 'Lavanya', 'last': 'Avula', 'gender': 'FEMALE', 'dob': '1995-01-21', 'mob': '9848011238', 'email': 'lavanya.avula@telanganaschool.edu', 'emp': 'EMP118', 'desig': 'PRT', 'join': '2024-06-01', 'mid': '', 'type': 'FULL_TIME'},
  ];

  static Map<OnboardingStep, String> generateAllCsvs({
    String? schoolCode,
    String? schoolName,
    String? schoolEmail,
    String? board,
  }) {
    final sCode = (schoolCode != null && schoolCode.isNotEmpty) ? schoolCode : 'TS001';
    final sName = (schoolName != null && schoolName.isNotEmpty) ? schoolName : 'Telangana Model School & Junior College';
    final sEmail = (schoolEmail != null && schoolEmail.isNotEmpty) ? schoolEmail : 'principal.ts001@telanganaschool.edu';
    final sBoard = (board != null && board.isNotEmpty) ? board : 'CBSE';

    final result = <OnboardingStep, String>{};

    result[OnboardingStep.school] = _generateSchoolCsv(sCode, sName, sEmail, sBoard);
    result[OnboardingStep.academicYears] = _generateAcademicYearsCsv(sCode);
    result[OnboardingStep.classes] = _generateClassesCsv();
    result[OnboardingStep.sections] = _generateSectionsCsv();
    result[OnboardingStep.subjects] = _generateSubjectsCsv();
    result[OnboardingStep.teachers] = _generateTeachersCsv();
    result[OnboardingStep.guardians] = _generateGuardiansCsv();
    result[OnboardingStep.students] = _generateStudentsCsv();
    result[OnboardingStep.relationships] = _generateRelationshipsCsv();
    result[OnboardingStep.teacherAssignments] = _generateTeacherAssignmentsCsv();
    result[OnboardingStep.timetable] = _generateTimetableCsv();
    result[OnboardingStep.syllabus] = _generateSyllabusCsv();
    result[OnboardingStep.exams] = _generateExamsCsv();

    _validateCardinalities(result);

    return result;
  }

  static const Map<OnboardingStep, int> expectedCounts = {
    OnboardingStep.school: 1,
    OnboardingStep.academicYears: 1,
    OnboardingStep.classes: 6,
    OnboardingStep.sections: 12,
    OnboardingStep.subjects: 6,
    OnboardingStep.teachers: 18,
    OnboardingStep.guardians: 360,
    OnboardingStep.students: 360,
    OnboardingStep.relationships: 360,
    OnboardingStep.teacherAssignments: 72,
    OnboardingStep.timetable: 360,
    OnboardingStep.syllabus: 114,
    OnboardingStep.exams: 36,
  };

  static void _validateCardinalities(Map<OnboardingStep, String> csvMap) {
    for (final entry in expectedCounts.entries) {
      final step = entry.key;
      final expected = entry.value;
      final csvText = csvMap[step];
      if (csvText == null) {
        throw StateError('Missing generated CSV for step ${step.label}');
      }
      final parsed = SchoolOnboardingValidators.parseCsv(csvText);
      final dataRowCount = parsed.isEmpty ? 0 : parsed.length - 1;
      if (dataRowCount != expected) {
        throw StateError(
          'Synthetic CSV cardinality mismatch for ${step.label}: expected $expected rows but parsed $dataRowCount rows.',
        );
      }
    }
  }

  static String _generateSchoolCsv(String code, String name, String email, String board) {
    final buffer = StringBuffer();
    buffer.write('school_code,school_name,board,school_type,email,phone,status,address,city,state,postal_code\n');
    buffer.write('$code,$name,$board,HIGH_SCHOOL,$email,+91-9848011000,ACTIVE,Survey No 142 Cyberabad Knowledge City,Hyderabad,Telangana,500081\n');
    return buffer.toString();
  }

  static String _generateAcademicYearsCsv(String schoolCode) {
    final buffer = StringBuffer();
    buffer.write('school_code,academic_year_code,academic_year_name,start_date,end_date,status,is_current\n');
    buffer.write('$schoolCode,$defaultAyCode,$defaultAyName,2025-06-01,2026-04-30,ACTIVE,true\n');
    return buffer.toString();
  }

  static String _generateClassesCsv() {
    final buffer = StringBuffer();
    buffer.write('academic_year_code,class_code,display_label,level,grade_category,max_capacity,status\n');
    buffer.write('$defaultAyCode,C5,Class 5,5,MIDDLE,60,ACTIVE\n');
    buffer.write('$defaultAyCode,C6,Class 6,6,MIDDLE,60,ACTIVE\n');
    buffer.write('$defaultAyCode,C7,Class 7,7,MIDDLE,60,ACTIVE\n');
    buffer.write('$defaultAyCode,C8,Class 8,8,MIDDLE,60,ACTIVE\n');
    buffer.write('$defaultAyCode,C9,Class 9,9,HIGH,60,ACTIVE\n');
    buffer.write('$defaultAyCode,C10,Class 10,10,HIGH,60,ACTIVE\n');
    return buffer.toString();
  }

  static String _generateSectionsCsv() {
    final buffer = StringBuffer();
    buffer.write('class_code,section_code,section_name,capacity,room_number,display_sort_order,status,academic_year_code\n');
    int room = 101;
    for (int lvl = 5; lvl <= 10; lvl++) {
      buffer.write('C$lvl,A,Section A,30,${room++},1,ACTIVE,$defaultAyCode\n');
      buffer.write('C$lvl,B,Section B,30,${room++},2,ACTIVE,$defaultAyCode\n');
    }
    return buffer.toString();
  }

  static String _generateSubjectsCsv() {
    final buffer = StringBuffer();
    buffer.write('subject_code,subject_name,category,subject_type,academic_year_code,theory_marks,practical_marks,pass_marks,credit_hours,weekly_periods,display_order\n');
    buffer.write('MATH101,Mathematics,CORE,THEORY_PRACTICAL,$defaultAyCode,80,20,33,4,6,1\n');
    buffer.write('ENG101,English Language,LANGUAGE,THEORY,$defaultAyCode,100,0,33,4,5,2\n');
    buffer.write('TEL101,Telugu Regional Language,LANGUAGE,THEORY,$defaultAyCode,100,0,33,4,5,3\n');
    buffer.write('HIN101,Hindi Second Language,LANGUAGE,THEORY,$defaultAyCode,100,0,33,3,4,4\n');
    buffer.write('SCI101,General Science,CORE,THEORY_PRACTICAL,$defaultAyCode,70,30,33,4,6,5\n');
    buffer.write('SOC101,Social Studies,CORE,THEORY,$defaultAyCode,100,0,33,4,4,6\n');
    return buffer.toString();
  }

  static String _generateTeachersCsv() {
    final buffer = StringBuffer();
    buffer.write('teacher_code,first_name,last_name,gender,date_of_birth,mobile,email,employee_code,designation,joining_date,status,middle_name,employment_type\n');
    for (final t in teacherProfiles) {
      final code = t['code'];
      final first = t['first'];
      final last = t['last'];
      final gender = t['gender'];
      final dob = t['dob'];
      final mob = t['mob'];
      final email = t['email'];
      final emp = t['emp'];
      final desig = t['desig'];
      final join = t['join'];
      final mid = t['mid'];
      final type = t['type'];
      buffer.write('$code,$first,$last,$gender,$dob,$mob,$email,$emp,$desig,$join,ACTIVE,$mid,$type\n');
    }
    return buffer.toString();
  }

  static const Map<int, int> _classBirthYears = {
    5: 2014,
    6: 2013,
    7: 2012,
    8: 2011,
    9: 2010,
    10: 2009,
  };

  static String _generateGuardiansCsv() {
    final buffer = StringBuffer();
    buffer.write('guardian_code,first_name,last_name,gender,date_of_birth,mobile,email,guardian_type,status\n');
    int count = 0;
    for (int lvl = 5; lvl <= 10; lvl++) {
      final bYear = _classBirthYears[lvl]!;
      for (final _ in ['A', 'B']) {
        for (int roll = 1; roll <= 30; roll++) {
          count++;
          final grdCode = 'GRD${count.toString().padLeft(3, '0')}';
          final isFather = (count % 3 != 0);
          final grdType = isFather ? 'FATHER' : 'MOTHER';
          final grdGender = isFather ? 'MALE' : 'FEMALE';
          final firstNameList = isFather ? teluguFirstNamesMale : teluguFirstNamesFemale;
          final grdFirst = firstNameList[(count * 7) % firstNameList.length];
          final grdLast = teluguLastNames[(count - 1) % teluguLastNames.length];
          final grdBirthYear = bYear - 28 - (count % 8);
          final grdDob = '$grdBirthYear-${((count % 12) + 1).toString().padLeft(2, '0')}-${((count % 28) + 1).toString().padLeft(2, '0')}';
          final grdMob = '9849${count.toString().padLeft(6, '0')}';
          final grdEmail = 'parent.${grdFirst.toLowerCase()}.${grdLast.toLowerCase()}$count@telanganaparents.org';

          buffer.write('$grdCode,$grdFirst,$grdLast,$grdGender,$grdDob,$grdMob,$grdEmail,$grdType,ACTIVE\n');
        }
      }
    }
    return buffer.toString();
  }

  static String _generateStudentsCsv() {
    final buffer = StringBuffer();
    buffer.write('admission_number,first_name,last_name,gender,date_of_birth,admission_date,roll_number,academic_year_code,class_code,section_code,status\n');
    int count = 0;
    for (int lvl = 5; lvl <= 10; lvl++) {
      final bYear = _classBirthYears[lvl]!;
      final cCode = 'C$lvl';
      for (final secCode in ['A', 'B']) {
        for (int roll = 1; roll <= 30; roll++) {
          count++;
          final admNo = 'ADM2025${count.toString().padLeft(3, '0')}';
          final isMale = (count % 2 == 1);
          final stuGender = isMale ? 'MALE' : 'FEMALE';
          final firstNameList = isMale ? teluguFirstNamesMale : teluguFirstNamesFemale;
          final stuFirst = firstNameList[(count * 3) % firstNameList.length];
          final stuLast = teluguLastNames[(count - 1) % teluguLastNames.length];
          final stuDob = '$bYear-${((count % 12) + 1).toString().padLeft(2, '0')}-${((count % 28) + 1).toString().padLeft(2, '0')}';

          buffer.write('$admNo,$stuFirst,$stuLast,$stuGender,$stuDob,2025-06-01,$roll,$defaultAyCode,$cCode,$secCode,ACTIVE\n');
        }
      }
    }
    return buffer.toString();
  }

  static String _generateRelationshipsCsv() {
    final buffer = StringBuffer();
    buffer.write('admission_number,guardian_code,relationship,is_primary,authorized_for_pickup,receives_notifications\n');
    int count = 0;
    for (int lvl = 5; lvl <= 10; lvl++) {
      for (final _ in ['A', 'B']) {
        for (int roll = 1; roll <= 30; roll++) {
          count++;
          final admNo = 'ADM2025${count.toString().padLeft(3, '0')}';
          final grdCode = 'GRD${count.toString().padLeft(3, '0')}';
          final isFather = (count % 3 != 0);
          final rel = isFather ? 'FATHER' : 'MOTHER';
          buffer.write('$admNo,$grdCode,$rel,true,true,true\n');
        }
      }
    }
    return buffer.toString();
  }

  static const Map<String, List<String>> _teacherSubjectMap = {
    'MATH101': ['TCH002', 'TCH002', 'TCH002', 'TCH002', 'TCH003', 'TCH003', 'TCH003', 'TCH003', 'TCH016', 'TCH016', 'TCH016', 'TCH016'],
    'ENG101':  ['TCH004', 'TCH004', 'TCH004', 'TCH004', 'TCH005', 'TCH005', 'TCH005', 'TCH005', 'TCH017', 'TCH017', 'TCH017', 'TCH017'],
    'TEL101':  ['TCH006', 'TCH006', 'TCH006', 'TCH006', 'TCH007', 'TCH007', 'TCH007', 'TCH007', 'TCH018', 'TCH018', 'TCH018', 'TCH018'],
    'HIN101':  ['TCH008', 'TCH008', 'TCH008', 'TCH008', 'TCH009', 'TCH009', 'TCH009', 'TCH009', 'TCH001', 'TCH001', 'TCH001', 'TCH001'],
    'SCI101':  ['TCH010', 'TCH010', 'TCH010', 'TCH010', 'TCH011', 'TCH011', 'TCH011', 'TCH011', 'TCH014', 'TCH014', 'TCH014', 'TCH014'],
    'SOC101':  ['TCH012', 'TCH012', 'TCH012', 'TCH012', 'TCH013', 'TCH013', 'TCH013', 'TCH013', 'TCH015', 'TCH015', 'TCH015', 'TCH015'],
  };

  static String _generateTeacherAssignmentsCsv() {
    final buffer = StringBuffer();
    buffer.write('teacher_code,subject_code,class_code,section_code,academic_year_code,assignment_type,weekly_periods,effective_from\n');
    final subjects = ['MATH101', 'ENG101', 'TEL101', 'HIN101', 'SCI101', 'SOC101'];
    int secIdx = 0;
    for (int lvl = 5; lvl <= 10; lvl++) {
      final cCode = 'C$lvl';
      for (final secCode in ['A', 'B']) {
        for (final sCode in subjects) {
          final tCode = _teacherSubjectMap[sCode]![secIdx];
          final weeklyP = (sCode == 'MATH101' || sCode == 'SCI101') ? '6' : ((sCode == 'ENG101' || sCode == 'TEL101') ? '5' : '4');
          buffer.write('$tCode,$sCode,$cCode,$secCode,$defaultAyCode,PRIMARY,$weeklyP,2025-06-01\n');
        }
        secIdx++;
      }
    }
    return buffer.toString();
  }

  static const List<Map<String, String>> _periodsTimeSlots = [
    {'p': '1', 'start': '09:00:00', 'end': '09:45:00'},
    {'p': '2', 'start': '09:45:00', 'end': '10:30:00'},
    {'p': '3', 'start': '10:45:00', 'end': '11:30:00'},
    {'p': '4', 'start': '11:30:00', 'end': '12:15:00'},
    {'p': '5', 'start': '13:00:00', 'end': '13:45:00'},
    {'p': '6', 'start': '13:45:00', 'end': '14:30:00'},
  ];

  static const List<String> _days = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY'];

  static String _generateTimetableCsv() {
    final buffer = StringBuffer();
    buffer.write('academic_year_code,day_of_week,period_number,start_time,end_time,class_code,section_code,subject_code,teacher_code,room_number,period_type\n');

    final baseSubjectSchedule = [
      ['MATH101', 'ENG101', 'TEL101', 'SCI101', 'SOC101', 'HIN101'],
      ['ENG101', 'MATH101', 'SCI101', 'TEL101', 'HIN101', 'SOC101'],
      ['SCI101', 'TEL101', 'MATH101', 'ENG101', 'SOC101', 'MATH101'],
      ['TEL101', 'SCI101', 'ENG101', 'MATH101', 'HIN101', 'SCI101'],
      ['SOC101', 'HIN101', 'SCI101', 'TEL101', 'MATH101', 'ENG101'],
    ];

    int secIdx = 0;
    int room = 101;
    for (int lvl = 5; lvl <= 10; lvl++) {
      final cCode = 'C$lvl';
      for (final secCode in ['A', 'B']) {
        final roomStr = 'Room ${room++}';
        for (int dayIdx = 0; dayIdx < _days.length; dayIdx++) {
          final dayName = _days[dayIdx];
          for (int pIdx = 0; pIdx < 6; pIdx++) {
            final periodInfo = _periodsTimeSlots[pIdx];
            final subj = baseSubjectSchedule[(dayIdx + secIdx) % 5][pIdx];
            final tCode = _teacherSubjectMap[subj]![secIdx];
            final pNo = periodInfo['p'];
            final pStart = periodInfo['start'];
            final pEnd = periodInfo['end'];

            buffer.write('$defaultAyCode,$dayName,$pNo,$pStart,$pEnd,$cCode,$secCode,$subj,$tCode,$roomStr,REGULAR\n');
          }
        }
        secIdx++;
      }
    }
    return buffer.toString();
  }

  static String _generateSyllabusCsv() {
    final buffer = StringBuffer();
    buffer.write('academic_year_code,class_code,subject_code,syllabus_code,unit_name,chapter_name,topic_name,description,sequence_order\n');

    final mathTopics = [
      {'code': '01', 'u': 'Number Systems & Real Numbers', 'ch': 'Real Numbers & Rational Arithmetic', 't': 'Fundamental Theorem of Arithmetic', 'd': 'Properties of positive integers and primes'},
      {'code': '02', 'u': 'Polynomials & Algebraic Expressions', 'ch': 'Quadratic Polynomials', 't': 'Geometric Meaning of Zeros', 'd': 'Graphing and algebraic zeros of polynomials'},
      {'code': '03', 'u': 'Linear Equations in Two Variables', 'ch': 'Pair of Linear Equations', 't': 'Algebraic Methods of Solution', 'd': 'Substitution and elimination techniques'},
      {'code': '04', 'u': 'Geometry & Coordinate Geometry', 'ch': 'Triangles and Similarity', 't': 'Criteria for Similarity of Triangles', 'd': 'AAA SAS SSS theorem proofs'},
    ];

    final engTopics = [
      {'code': '01', 'u': 'Reading Comprehension', 'ch': 'Prose & Narrative Texts', 't': 'Analytical Reading & Inferences', 'd': 'Contextual meaning and vocabulary building'},
      {'code': '02', 'u': 'Writing Skills', 'ch': 'Formal Letters & Notices', 't': 'Format and Cohesive Writing', 'd': 'Official communication drafting guidelines'},
      {'code': '03', 'u': 'Grammar & Mechanics', 'ch': 'Tenses & Voice Transformation', 't': 'Active and Passive Voice Concord', 'd': 'Sentence restructuring and correction'},
    ];

    final telTopics = [
      {'code': '01', 'u': 'Pracheena Kavitvam', 'ch': 'Kavya Parichayam', 't': 'Padya Bhavam & Chandassu', 'd': 'Classical poetry meters and aesthetic meaning'},
      {'code': '02', 'u': 'Vachana Sahityam', 'ch': 'Kathaanikalu', 't': 'Samaja Chaitanyam', 'd': 'Contemporary short stories and prose analysis'},
      {'code': '03', 'u': 'Vyakaranam', 'ch': 'Sandhulu & Samasalu', 't': 'Tatpurusha & Dvigu Samasalu', 'd': 'Grammar synthesis and morphological analysis'},
    ];

    final hinTopics = [
      {'code': '01', 'u': 'Gadya Khand', 'ch': 'Premchand ki Kahaniya', 't': 'Do Bailon ki Katha', 'd': 'Story analysis and character motivations'},
      {'code': '02', 'u': 'Kavya Khand', 'ch': 'Kabir ki Sakhiyan', 't': 'Sakhi evam Sabad', 'd': 'Spiritual verses and poetic devices'},
      {'code': '03', 'u': 'Vyakaran', 'ch': 'Vakya Bhed & Upsarg-Pratyay', 't': 'Rachna ke Aadhar par Vakya', 'd': 'Syntactic structures and affixation'},
    ];

    final sciTopics = [
      {'code': '01', 'u': 'Chemical Substances & Reactions', 'ch': 'Chemical Equations', 't': 'Types of Chemical Reactions', 'd': 'Combination decomposition displacement redox'},
      {'code': '02', 'u': 'World of Living', 'ch': 'Life Processes', 't': 'Nutrition and Respiration Mechanisms', 'd': 'Autotrophic/heterotrophic energy synthesis'},
      {'code': '03', 'u': 'Natural Phenomena', 'ch': 'Light - Reflection and Refraction', 't': 'Spherical Mirrors and Lens Formula', 'd': 'Ray diagrams and optical calculations'},
    ];

    final socTopics = [
      {'code': '01', 'u': 'India & The Contemporary World', 'ch': 'Nationalism in India', 't': 'The Non-Cooperation Movement', 'd': 'Historical phases of Indian freedom struggle'},
      {'code': '02', 'u': 'Resources and Development', 'ch': 'Land and Soil Resources', 't': 'Soil Classification and Conservation', 'd': 'Resource planning in India'},
      {'code': '03', 'u': 'Democratic Politics', 'ch': 'Power Sharing & Federalism', 't': 'Forms of Power Sharing', 'd': 'Federal structures and local self-government'},
    ];

    final topicMap = {
      'MATH101': {'prefix': 'MATH', 'topics': mathTopics},
      'ENG101':  {'prefix': 'ENG1', 'topics': engTopics},
      'TEL101':  {'prefix': 'TEL1', 'topics': telTopics},
      'HIN101':  {'prefix': 'HIN1', 'topics': hinTopics},
      'SCI101':  {'prefix': 'SCI1', 'topics': sciTopics},
      'SOC101':  {'prefix': 'SOC1', 'topics': socTopics},
    };

    for (int lvl = 5; lvl <= 10; lvl++) {
      final cCode = 'C$lvl';
      for (final sCode in ['MATH101', 'ENG101', 'TEL101', 'HIN101', 'SCI101', 'SOC101']) {
        final cfg = topicMap[sCode]!;
        final prefix = cfg['prefix'] as String;
        final list = cfg['topics'] as List<Map<String, String>>;
        int seq = 1;
        for (final item in list) {
          final sylCode = 'SYL_${cCode}_${prefix}_${item['code']}';
          final u = item['u']!;
          final ch = item['ch']!;
          final t = item['t']!;
          final d = item['d']!;
          buffer.write('$defaultAyCode,$cCode,$sCode,$sylCode,$u,$ch,$t,$d,$seq\n');
          seq++;
        }
      }
    }
    return buffer.toString();
  }

  static String _generateExamsCsv() {
    final buffer = StringBuffer();
    buffer.write('academic_year_code,exam_code,exam_name,exam_type,class_code,subject_code,exam_date,maximum_marks,duration_minutes\n');
    final subjects = [
      {'code': 'MATH101', 'name': 'Mathematics', 'day': '15'},
      {'code': 'ENG101', 'name': 'English Language', 'day': '16'},
      {'code': 'TEL101', 'name': 'Telugu Regional Language', 'day': '17'},
      {'code': 'HIN101', 'name': 'Hindi Second Language', 'day': '18'},
      {'code': 'SCI101', 'name': 'General Science', 'day': '19'},
      {'code': 'SOC101', 'name': 'Social Studies', 'day': '20'},
    ];

    for (int lvl = 5; lvl <= 10; lvl++) {
      final cCode = 'C$lvl';
      for (final sub in subjects) {
        final sCode = sub['code']!;
        final sName = sub['name']!;
        final sDay = sub['day']!;
        final examCode = 'EXAM_Q1_${cCode}_$sCode';
        final examName = 'Quarterly Examination 2025 - $cCode $sName';
        final examDate = '2025-09-$sDay';
        buffer.write('$defaultAyCode,$examCode,$examName,QUARTERLY,$cCode,$sCode,$examDate,100,180\n');
      }
    }
    return buffer.toString();
  }
}
