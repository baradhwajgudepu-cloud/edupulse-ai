class CurriculumStatusModel {
  final bool isPopulated;
  final bool verifiedCurriculumAvailable;
  final String board;
  final String? state;
  final String? academicYearName;
  final String? source;
  final String? sourceVersion;
  final String? verificationStatus;
  final String? derivedFrom;
  final int totalSubjectsWithSyllabus;
  final int totalChapters;
  final int totalTopics;
  final String statusBadge;
  final String message;

  const CurriculumStatusModel({
    required this.isPopulated,
    required this.verifiedCurriculumAvailable,
    required this.board,
    this.state,
    this.academicYearName,
    this.source,
    this.sourceVersion,
    this.verificationStatus,
    this.derivedFrom,
    required this.totalSubjectsWithSyllabus,
    required this.totalChapters,
    required this.totalTopics,
    required this.statusBadge,
    required this.message,
  });

  factory CurriculumStatusModel.fromJson(Map<String, dynamic> json) {
    return CurriculumStatusModel(
      isPopulated: json['is_populated'] as bool? ?? false,
      verifiedCurriculumAvailable: json['verified_curriculum_available'] as bool? ?? false,
      board: json['board'] as String? ?? 'Not Configured',
      state: json['state'] as String?,
      academicYearName: json['academic_year_name'] as String?,
      source: json['source'] as String?,
      sourceVersion: json['source_version'] as String?,
      verificationStatus: json['verification_status'] as String?,
      derivedFrom: json['derived_from'] as String?,
      totalSubjectsWithSyllabus: (json['total_subjects_with_syllabus'] as num?)?.toInt() ?? 0,
      totalChapters: (json['total_chapters'] as num?)?.toInt() ?? 0,
      totalTopics: (json['total_topics'] as num?)?.toInt() ?? 0,
      statusBadge: json['status_badge'] as String? ?? 'UNAVAILABLE',
      message: json['message'] as String? ?? '',
    );
  }

  factory CurriculumStatusModel.empty() {
    return const CurriculumStatusModel(
      isPopulated: false,
      verifiedCurriculumAvailable: false,
      board: 'Not Configured',
      totalSubjectsWithSyllabus: 0,
      totalChapters: 0,
      totalTopics: 0,
      statusBadge: 'UNAVAILABLE',
      message: 'Curriculum not evaluated',
    );
  }
}

class CurriculumPopulateResultModel {
  final bool success;
  final String message;
  final String board;
  final String? state;
  final String academicYearName;
  final int totalClassesProcessed;
  final int totalSubjectsMatched;
  final int totalChaptersPopulated;
  final int totalTopicsPopulated;
  final String source;
  final String sourceVersion;
  final String verificationStatus;

  const CurriculumPopulateResultModel({
    required this.success,
    required this.message,
    required this.board,
    this.state,
    required this.academicYearName,
    required this.totalClassesProcessed,
    required this.totalSubjectsMatched,
    required this.totalChaptersPopulated,
    required this.totalTopicsPopulated,
    required this.source,
    required this.sourceVersion,
    required this.verificationStatus,
  });

  factory CurriculumPopulateResultModel.fromJson(Map<String, dynamic> json) {
    return CurriculumPopulateResultModel(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      board: json['board'] as String? ?? '',
      state: json['state'] as String?,
      academicYearName: json['academic_year_name'] as String? ?? '',
      totalClassesProcessed: (json['total_classes_processed'] as num?)?.toInt() ?? 0,
      totalSubjectsMatched: (json['total_subjects_matched'] as num?)?.toInt() ?? 0,
      totalChaptersPopulated: (json['total_chapters_populated'] as num?)?.toInt() ?? 0,
      totalTopicsPopulated: (json['total_topics_populated'] as num?)?.toInt() ?? 0,
      source: json['source'] as String? ?? '',
      sourceVersion: json['source_version'] as String? ?? '',
      verificationStatus: json['verification_status'] as String? ?? 'VERIFIED',
    );
  }
}

class CurriculumChapterItemModel {
  final String id;
  final String classId;
  final String subjectId;
  final String syllabusCode;
  final String unitName;
  final String chapterName;
  final String topicName;
  final String? description;
  final int sequenceOrder;
  final int estimatedPeriods;
  final String coverageStatus;
  final String lifecycleStatus;
  final String? source;
  final String? sourceVersion;
  final String? verificationStatus;
  final bool isCustom;

  const CurriculumChapterItemModel({
    required this.id,
    required this.classId,
    required this.subjectId,
    required this.syllabusCode,
    required this.unitName,
    required this.chapterName,
    required this.topicName,
    this.description,
    required this.sequenceOrder,
    this.estimatedPeriods = 4,
    required this.coverageStatus,
    this.lifecycleStatus = 'PLANNED',
    this.source,
    this.sourceVersion,
    this.verificationStatus,
    required this.isCustom,
  });

  factory CurriculumChapterItemModel.fromJson(Map<String, dynamic> json) {
    return CurriculumChapterItemModel(
      id: json['id'] as String? ?? '',
      classId: json['class_id'] as String? ?? '',
      subjectId: json['subject_id'] as String? ?? '',
      syllabusCode: json['syllabus_code'] as String? ?? '',
      unitName: json['unit_name'] as String? ?? '',
      chapterName: json['chapter_name'] as String? ?? '',
      topicName: json['topic_name'] as String? ?? '',
      description: json['description'] as String?,
      sequenceOrder: (json['sequence_order'] as num?)?.toInt() ?? 1,
      estimatedPeriods: (json['estimated_periods'] as num?)?.toInt() ?? 4,
      coverageStatus: json['coverage_status'] as String? ?? 'PENDING',
      lifecycleStatus: json['lifecycle_status'] as String? ?? 'PLANNED',
      source: json['source'] as String?,
      sourceVersion: json['source_version'] as String?,
      verificationStatus: json['verification_status'] as String? ?? 'VERIFIED',
      isCustom: json['is_custom'] as bool? ?? false,
    );
  }
}

class SyllabusHierarchyTopic {
  final String id;
  final String syllabusCode;
  final String topicName;
  final String? description;
  final int sequenceOrder;
  final int estimatedPeriods;
  final String coverageStatus;
  final String lifecycleStatus;
  final bool isCustom;
  final String? source;
  final String? verificationStatus;

  const SyllabusHierarchyTopic({
    required this.id,
    required this.syllabusCode,
    required this.topicName,
    this.description,
    required this.sequenceOrder,
    required this.estimatedPeriods,
    required this.coverageStatus,
    required this.lifecycleStatus,
    required this.isCustom,
    this.source,
    this.verificationStatus,
  });
}

class SyllabusHierarchyChapter {
  final String chapterName;
  final String unitName;
  final String subjectId;
  final int sequenceOrder;
  final int estimatedPeriods;
  final List<SyllabusHierarchyTopic> topics;

  const SyllabusHierarchyChapter({
    required this.chapterName,
    required this.unitName,
    required this.subjectId,
    required this.sequenceOrder,
    required this.estimatedPeriods,
    required this.topics,
  });

  int get totalEstimatedPeriods {
    if (topics.isEmpty) return estimatedPeriods;
    return topics.fold<int>(0, (sum, t) => sum + t.estimatedPeriods);
  }

  double get completionPercentage {
    if (topics.isEmpty) return 0.0;
    final completed = topics.where((t) => t.coverageStatus == 'COMPLETED').length;
    return (completed / topics.length) * 100.0;
  }
}

class SyllabusHierarchyUnit {
  final String unitName;
  final String subjectId;
  final List<SyllabusHierarchyChapter> chapters;

  const SyllabusHierarchyUnit({
    required this.unitName,
    required this.subjectId,
    required this.chapters,
  });

  int get totalEstimatedPeriods =>
      chapters.fold<int>(0, (sum, c) => sum + c.totalEstimatedPeriods);

  int get totalTopics =>
      chapters.fold<int>(0, (sum, c) => sum + c.topics.length);

  double get completionPercentage {
    if (totalTopics == 0) return 0.0;
    int completedCount = 0;
    for (final c in chapters) {
      completedCount += c.topics.where((t) => t.coverageStatus == 'COMPLETED').length;
    }
    return (completedCount / totalTopics) * 100.0;
  }
}

class SyllabusHierarchySubject {
  final String subjectId;
  final String subjectName;
  final List<SyllabusHierarchyUnit> units;

  const SyllabusHierarchySubject({
    required this.subjectId,
    required this.subjectName,
    required this.units,
  });

  int get totalUnits => units.length;

  int get totalChapters =>
      units.fold<int>(0, (sum, u) => sum + u.chapters.length);

  int get totalTopics =>
      units.fold<int>(0, (sum, u) => sum + u.totalTopics);

  int get totalEstimatedPeriods =>
      units.fold<int>(0, (sum, u) => sum + u.totalEstimatedPeriods);

  double get completionPercentage {
    if (totalTopics == 0) return 0.0;
    int completedCount = 0;
    for (final u in units) {
      for (final c in u.chapters) {
        completedCount += c.topics.where((t) => t.coverageStatus == 'COMPLETED').length;
      }
    }
    return (completedCount / totalTopics) * 100.0;
  }

  static List<SyllabusHierarchySubject> buildHierarchy({
    required List<CurriculumChapterItemModel> items,
    Map<String, String>? subjectNameMap,
  }) {
    final Map<String, Map<String, Map<String, List<CurriculumChapterItemModel>>>> grouped = {};

    for (final item in items) {
      final sId = item.subjectId.isEmpty ? 'general' : item.subjectId;
      final uName = item.unitName.isEmpty ? 'General Unit' : item.unitName;
      final cName = item.chapterName.isEmpty ? 'General Chapter' : item.chapterName;

      grouped.putIfAbsent(sId, () => {});
      grouped[sId]!.putIfAbsent(uName, () => {});
      grouped[sId]![uName]!.putIfAbsent(cName, () => []);
      grouped[sId]![uName]![cName]!.add(item);
    }

    final List<SyllabusHierarchySubject> subjectList = [];

    grouped.forEach((sId, unitMap) {
      final List<SyllabusHierarchyUnit> unitList = [];

      unitMap.forEach((uName, chapterMap) {
        final List<SyllabusHierarchyChapter> chapterList = [];

        chapterMap.forEach((cName, topicItems) {
          topicItems.sort((a, b) => a.sequenceOrder.compareTo(b.sequenceOrder));
          final topics = topicItems.map((ti) => SyllabusHierarchyTopic(
            id: ti.id,
            syllabusCode: ti.syllabusCode,
            topicName: ti.topicName,
            description: ti.description,
            sequenceOrder: ti.sequenceOrder,
            estimatedPeriods: ti.estimatedPeriods,
            coverageStatus: ti.coverageStatus,
            lifecycleStatus: ti.lifecycleStatus,
            isCustom: ti.isCustom,
            source: ti.source,
            verificationStatus: ti.verificationStatus,
          )).toList();

          final minSeq = topicItems.isNotEmpty ? topicItems.first.sequenceOrder : 1;
          final estPeriods = topics.fold<int>(0, (sum, t) => sum + t.estimatedPeriods);

          chapterList.add(SyllabusHierarchyChapter(
            chapterName: cName,
            unitName: uName,
            subjectId: sId,
            sequenceOrder: minSeq,
            estimatedPeriods: estPeriods,
            topics: topics,
          ));
        });

        chapterList.sort((a, b) => a.sequenceOrder.compareTo(b.sequenceOrder));

        unitList.add(SyllabusHierarchyUnit(
          unitName: uName,
          subjectId: sId,
          chapters: chapterList,
        ));
      });

      final displayName = subjectNameMap?[sId] ?? (sId == 'general' ? 'General' : 'Subject $sId');
      subjectList.add(SyllabusHierarchySubject(
        subjectId: sId,
        subjectName: displayName,
        units: unitList,
      ));
    });

    subjectList.sort((a, b) => a.subjectName.compareTo(b.subjectName));
    return subjectList;
  }
}

class AIDraftSyllabusTopicDto {
  final String unitName;
  final String chapterName;
  final String topicName;
  final String? description;
  final int sequenceOrder;
  final int estimatedPeriods;

  const AIDraftSyllabusTopicDto({
    required this.unitName,
    required this.chapterName,
    required this.topicName,
    this.description,
    this.sequenceOrder = 1,
    this.estimatedPeriods = 4,
  });

  factory AIDraftSyllabusTopicDto.fromJson(Map<String, dynamic> json) {
    return AIDraftSyllabusTopicDto(
      unitName: json['unit_name'] as String? ?? 'Unit 1',
      chapterName: json['chapter_name'] as String? ?? 'Chapter 1',
      topicName: json['topic_name'] as String? ?? 'Topic 1',
      description: json['description'] as String?,
      sequenceOrder: (json['sequence_order'] as num?)?.toInt() ?? 1,
      estimatedPeriods: (json['estimated_periods'] as num?)?.toInt() ?? 4,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'unit_name': unitName,
      'chapter_name': chapterName,
      'topic_name': topicName,
      'description': description,
      'sequence_order': sequenceOrder,
      'estimated_periods': estimatedPeriods,
    };
  }

  AIDraftSyllabusTopicDto copyWith({
    String? unitName,
    String? chapterName,
    String? topicName,
    String? description,
    int? sequenceOrder,
    int? estimatedPeriods,
  }) {
    return AIDraftSyllabusTopicDto(
      unitName: unitName ?? this.unitName,
      chapterName: chapterName ?? this.chapterName,
      topicName: topicName ?? this.topicName,
      description: description ?? this.description,
      sequenceOrder: sequenceOrder ?? this.sequenceOrder,
      estimatedPeriods: estimatedPeriods ?? this.estimatedPeriods,
    );
  }
}

class AIDraftSyllabusResponseDto {
  final String subjectId;
  final String subjectName;
  final String classId;
  final String className;
  final bool isAiDraft;
  final String status;
  final String disclaimer;
  final List<AIDraftSyllabusTopicDto> topics;

  const AIDraftSyllabusResponseDto({
    required this.subjectId,
    required this.subjectName,
    required this.classId,
    required this.className,
    required this.isAiDraft,
    required this.status,
    required this.disclaimer,
    required this.topics,
  });

  factory AIDraftSyllabusResponseDto.fromJson(Map<String, dynamic> json) {
    final list = json['topics'] as List<dynamic>? ?? [];
    return AIDraftSyllabusResponseDto(
      subjectId: json['subject_id'] as String? ?? '',
      subjectName: json['subject_name'] as String? ?? '',
      classId: json['class_id'] as String? ?? '',
      className: json['class_name'] as String? ?? '',
      isAiDraft: json['is_ai_draft'] as bool? ?? true,
      status: json['status'] as String? ?? 'AI GENERATED DRAFT',
      disclaimer: json['disclaimer'] as String? ?? '',
      topics: list.map((item) => AIDraftSyllabusTopicDto.fromJson(item as Map<String, dynamic>)).toList(),
    );
  }
}


