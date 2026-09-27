import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edupulse_network/edupulse_network.dart';
import 'package:admin_portal/features/school_setup/presentation/providers/school_setup_providers.dart';
import 'package:admin_portal/features/results/data/models/examination_models.dart';
import 'package:admin_portal/features/results/presentation/providers/examination_providers.dart';

class MockExamCycleApiClient extends BaseApiClient {
  final List<Map<String, dynamic>> calls = [];

  MockExamCycleApiClient() : super(Dio());

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    calls.add({'method': 'GET', 'path': path, 'query': queryParameters});

    if (path.contains('/papers')) {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'paper-math-1',
            'examination_id': 'cycle-123',
            'subject_id': 'sub-math',
            'subject_name': 'Mathematics',
            'subject_code': 'MATH',
            'paper_name': 'Mathematics Standard',
            'paper_code': 'MATH-101',
            'default_max_marks': 100,
            'default_pass_marks': 35,
            'default_duration_minutes': 180,
            'order_index': 0,
            'class_configs': [
              {
                'id': 'cfg-1',
                'exam_paper_id': 'paper-math-1',
                'class_id': 'cls-5',
                'class_name': 'Class 5',
                'maximum_marks': 50,
                'pass_marks': 18,
                'duration_minutes': 120,
              },
              {
                'id': 'cfg-2',
                'exam_paper_id': 'paper-math-1',
                'class_id': 'cls-10',
                'class_name': 'Class 10',
                'maximum_marks': 100,
                'pass_marks': 35,
                'duration_minutes': 180,
              },
            ],
          }
        ]
      }));
    }

    if (path == '/examinations') {
      return ApiResult.success(mapper({
        'data': [
          {
            'id': 'cycle-123',
            'exam_name': 'Quarterly Examination 2026',
            'exam_type': 'QUARTERLY',
            'start_date': '2026-10-01',
            'end_date': '2026-10-15',
            'status': 'DRAFT',
            'participating_class_ids': ['cls-5', 'cls-6', 'cls-7', 'cls-8', 'cls-9', 'cls-10'],
            'papers': [],
            'schedules': [],
          }
        ]
      }));
    }

    return ApiResult.success(mapper({'data': []}));
  }

  @override
  Future<ApiResult<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    calls.add({'method': 'POST', 'path': path, 'data': data, 'query': queryParameters});

    if (path.contains('/classes')) {
      return ApiResult.success(mapper({
        'data': {
          'id': 'cycle-123',
          'exam_name': 'Quarterly Examination 2026',
          'exam_type': 'QUARTERLY',
          'start_date': '2026-10-01',
          'end_date': '2026-10-15',
          'status': 'DRAFT',
          'participating_class_ids': (data as Map<String, dynamic>)['class_ids'] ?? [],
          'schedules': [],
          'papers': [],
        }
      }));
    }

    if (path.contains('/papers')) {
      final req = data as Map<String, dynamic>;
      return ApiResult.success(mapper({
        'data': {
          'id': 'paper-new-uuid',
          'examination_id': path.split('/')[2],
          'subject_id': req['subject_id'],
          'paper_name': req['paper_name'],
          'default_max_marks': req['default_max_marks'] ?? 100,
          'default_pass_marks': req['default_pass_marks'] ?? 35,
          'default_duration_minutes': req['default_duration_minutes'] ?? 180,
          'class_configs': [],
        }
      }));
    }

    if (path == '/examinations/wizard') {
      final req = data as Map<String, dynamic>;
      return ApiResult.success(mapper({
        'data': {
          'id': 'cycle-new-uuid',
          'exam_name': req['exam_name'],
          'exam_type': req['exam_type'],
          'start_date': req['start_date'],
          'end_date': req['end_date'],
          'status': 'DRAFT',
          'participating_class_ids': req['class_ids'] ?? [],
          'schedules': [],
          'papers': [],
        }
      }));
    }

    if (path.contains('preview')) {
      final req = data as Map<String, dynamic>;
      final bool excludeWknds = req['exclude_weekends'] ?? true;
      final schedules = [
        {
          'paper_id': 'paper-1',
          'paper_name': 'Mathematics',
          'session_name': 'Morning',
          'class_id': 'cls-5',
          'class_name': 'Class 5',
          'section_id': 'sec-a',
          'section_name': 'Section A',
          'subject_id': 'sub-math',
          'subject_name': 'Mathematics',
          'exam_date': excludeWknds ? '2026-10-05' : '2026-10-03',
          'day_name': excludeWknds ? 'Monday' : 'Saturday',
          'start_time': '09:00:00',
          'end_time': '12:00:00',
          'duration_minutes': 180,
          'max_marks': 50,
          'pass_marks': 18,
          'room_number': 'Hall 1',
          'conflict_status': 'OK',
        }
      ];
      return ApiResult.success(mapper({
        'data': {
          'total_slots': schedules.length,
          'has_conflicts': false,
          'conflict_count': 0,
          'schedules': schedules,
          'warnings': [],
        }
      }));
    }

    return ApiResult.success(mapper({'data': {}}));
  }

  @override
  Future<ApiResult<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) mapper,
  }) async {
    calls.add({'method': 'PUT', 'path': path, 'data': data, 'query': queryParameters});
    return ApiResult.success(mapper({'data': {}}));
  }
}

void main() {
  group('Institutional Examination Cycle Models', () {
    test('ExamPaperModel and ExamPaperClassModel deserialize and serialize properly', () {
      final json = {
        'id': 'paper-101',
        'examination_id': 'cycle-2026',
        'subject_id': 'sub-sci',
        'subject_name': 'General Science',
        'subject_code': 'SCI',
        'paper_name': 'Science Paper I',
        'paper_code': 'SCI-1',
        'default_max_marks': 80,
        'default_pass_marks': 28,
        'default_duration_minutes': 150,
        'order_index': 1,
        'class_configs': [
          {
            'id': 'cfg-5',
            'exam_paper_id': 'paper-101',
            'class_id': 'cls-5',
            'class_name': 'Class 5',
            'maximum_marks': 50,
            'pass_marks': 18,
            'duration_minutes': 120,
          },
          {
            'id': 'cfg-10',
            'exam_paper_id': 'paper-101',
            'class_id': 'cls-10',
            'class_name': 'Class 10',
            'maximum_marks': 80,
            'pass_marks': 28,
            'duration_minutes': 150,
          }
        ],
      };

      final paper = ExamPaperModel.fromJson(json);

      expect(paper.id, 'paper-101');
      expect(paper.paperName, 'Science Paper I');
      expect(paper.defaultMaxMarks, 80);
      expect(paper.classConfigs.length, 2);

      // Verify Class 5 override
      final c5Config = paper.configForClass('cls-5');
      expect(c5Config, isNotNull);
      expect(c5Config!.maximumMarks, 50);
      expect(paper.maxMarksForClass('cls-5'), 50);
      expect(paper.durationForClass('cls-5'), 120);

      // Verify unconfigured class falls back to defaults
      expect(paper.maxMarksForClass('cls-unconfigured'), 80);
      expect(paper.durationForClass('cls-unconfigured'), 150);

      // Verify round-trip toJson
      final exportedJson = paper.toJson();
      expect(exportedJson['paper_name'], 'Science Paper I');
      expect((exportedJson['class_configs'] as List).length, 2);
    });

    test('ExaminationModel cycle getters calculate correct metrics', () {
      const exam = ExaminationModel(
        id: 'cycle-2026',
        tenantId: 'tenant-123',
        schoolId: 'school-123',
        academicYearId: 'ay-2026',
        examName: 'Annual Examinations 2026',
        examType: 'ANNUAL',
        startDate: '2026-03-01',
        endDate: '2026-03-20',
        status: ExamStatusEnum.published,
        participatingClassIds: ['cls-1', 'cls-2', 'cls-3', 'cls-4'],
        participatingClassNames: ['Class 1', 'Class 2', 'Class 3', 'Class 4'],
        papers: const [
          ExamPaperModel(
            id: 'p1',
            examinationId: 'cycle-2026',
            paperName: 'Math',
            subjectId: 'sub-math',
            defaultMaxMarks: 100,
            defaultPassMarks: 35,
          ),
          ExamPaperModel(
            id: 'p2',
            examinationId: 'cycle-2026',
            paperName: 'English',
            subjectId: 'sub-eng',
            defaultMaxMarks: 100,
            defaultPassMarks: 35,
          ),
        ],
      );

      expect(exam.isCycleModel, isTrue);
      expect(exam.effectiveClassIds.length, 4);
      expect(exam.papersCount, 2);
      expect(exam.formatClassScope(null), 'Classes 1–4');
    });
  });

  group('Examination Cycle State Notifiers', () {
    late ProviderContainer container;
    late MockExamCycleApiClient mockClient;

    setUp(() {
      mockClient = MockExamCycleApiClient();
      container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(mockClient),
          selectedSchoolIdProvider.overrideWith((ref) => 'school-test-uuid'),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('ExamPapersNotifier loads cycle papers with class-level overrides', () async {
      final papersNotifier = container.read(examPapersProvider.notifier);
      await papersNotifier.loadPapers('cycle-123');

      final papersState = container.read(examPapersProvider);
      expect(papersState.isLoading, isFalse);
      expect(papersState.papers.length, 1);
      expect(papersState.papers.first.paperName, 'Mathematics Standard');
      expect(papersState.papers.first.classConfigs.length, 2);

      // Verify override values for Class 5
      expect(papersState.papers.first.maxMarksForClass('cls-5'), 50);
      expect(papersState.papers.first.maxMarksForClass('cls-10'), 100);
    });

    test('ExamPapersNotifier creates paper and dispatches correct backend request', () async {
      final papersNotifier = container.read(examPapersProvider.notifier);
      final ok = await papersNotifier.createPaper(
        'cycle-123',
        {
          'paper_name': 'Social Studies',
          'subject_id': 'sub-sst',
          'paper_code': 'SST-01',
          'default_max_marks': 80,
          'default_pass_marks': 28,
          'default_duration_minutes': 150,
        },
      );

      expect(ok, isTrue);
      expect(mockClient.calls.any((c) => c['method'] == 'POST' && c['path'] == '/examinations/cycle-123/papers'), isTrue);
    });

    test('ExaminationsNotifier updates participating classes for the cycle', () async {
      final examsNotifier = container.read(examinationsProvider.notifier);
      final ok = await examsNotifier.updateExaminationClasses(
        examId: 'cycle-123',
        classIds: ['cls-5', 'cls-6', 'cls-7', 'cls-8'],
      );

      expect(ok, isTrue);
      final postCall = mockClient.calls.firstWhere((c) => c['method'] == 'POST' && c['path'] == '/examinations/cycle-123/classes');
      expect((postCall['data'] as Map)['class_ids'], ['cls-5', 'cls-6', 'cls-7', 'cls-8']);
    });

    test('BulkTimetableGeneratorNotifier previews schedule with excludeWeekends = true (Monday)', () async {
      final generatorNotifier = container.read(bulkTimetableGeneratorProvider.notifier);
      final ok = await generatorNotifier.generatePreview(
        examinationId: 'cycle-123',
        classIds: ['cls-5', 'cls-10'],
        startDate: '2026-10-01',
        endDate: '2026-10-15',
        gapDays: 1,
        excludeWeekends: true,
        schedulingStrategy: 'DIFFICULTY_BALANCED',
      );

      final preview = container.read(bulkTimetableGeneratorProvider).preview;
      expect(ok, isTrue);
      expect(preview, isNotNull);
      expect(preview!.totalSlots, 1);
      expect(preview.hasConflicts, isFalse);
      expect(preview.conflictCount, 0);

      // With excludeWeekends=true, slot is on Monday, not weekend
      final slot = preview.schedules.first;
      expect(slot.examDate, '2026-10-05');
      expect(slot.dayName, 'Monday');
      expect(slot.durationMinutes, 180);
      expect(slot.conflictStatus, 'OK');

      final postCall = mockClient.calls.firstWhere((c) => c['path'].toString().contains('preview'));
      expect((postCall['data'] as Map)['scheduling_strategy'], 'DIFFICULTY_BALANCED');
      expect((postCall['data'] as Map)['exclude_weekends'], true);
      expect((postCall['data'] as Map)['gap_days'], 1);
    });

    test('BulkTimetableGeneratorNotifier previews schedule with excludeWeekends = false (Saturday permitted)', () async {
      final generatorNotifier = container.read(bulkTimetableGeneratorProvider.notifier);
      final ok = await generatorNotifier.generatePreview(
        examinationId: 'cycle-123',
        classIds: ['cls-5', 'cls-10'],
        startDate: '2026-10-01',
        endDate: '2026-10-15',
        gapDays: 1,
        excludeWeekends: false,
        schedulingStrategy: 'ONE_PAPER_PER_DAY',
      );

      final preview = container.read(bulkTimetableGeneratorProvider).preview;
      expect(ok, isTrue);
      expect(preview, isNotNull);

      // With excludeWeekends=false, Saturday is permitted
      final slot = preview!.schedules.first;
      expect(slot.examDate, '2026-10-03');
      expect(slot.dayName, 'Saturday');
      expect(slot.durationMinutes, 180);
    });
  });
}
