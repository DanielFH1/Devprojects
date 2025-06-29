import 'package:json_annotation/json_annotation.dart';

part 'task_model.g.dart';

/// Eisenhower Matrix 사분면
enum PriorityQuadrant {
  @JsonValue(1)
  urgentImportant, // 사분면 1: 긴급하고 중요함 (즉시 해야 할 일)

  @JsonValue(2)
  notUrgentImportant, // 사분면 2: 긴급하지 않지만 중요함 (계획해서 할 일)

  @JsonValue(3)
  urgentNotImportant, // 사분면 3: 긴급하지만 중요하지 않음 (위임하거나 빨리 처리할 일)

  @JsonValue(4)
  notUrgentNotImportant, // 사분면 4: 긴급하지도 중요하지도 않음 (제거하거나 나중에 할 일)
}

/// PriorityQuadrant 확장
extension PriorityQuadrantExtension on PriorityQuadrant {
  String get description {
    switch (this) {
      case PriorityQuadrant.urgentImportant:
        return '긴급하고 중요함';
      case PriorityQuadrant.notUrgentImportant:
        return '중요함';
      case PriorityQuadrant.urgentNotImportant:
        return '긴급함';
      case PriorityQuadrant.notUrgentNotImportant:
        return '일반';
    }
  }
}

/// 작업 카테고리
enum TaskCategory {
  @JsonValue('work')
  work,

  @JsonValue('personal')
  personal,

  @JsonValue('health')
  health,

  @JsonValue('education')
  education,

  @JsonValue('family')
  family,

  @JsonValue('finance')
  finance,

  @JsonValue('other')
  other,
}

/// TaskCategory 확장
extension TaskCategoryExtension on TaskCategory {
  String get displayName {
    switch (this) {
      case TaskCategory.work:
        return '업무';
      case TaskCategory.personal:
        return '개인';
      case TaskCategory.health:
        return '건강';
      case TaskCategory.education:
        return '교육';
      case TaskCategory.family:
        return '가족';
      case TaskCategory.finance:
        return '재정';
      case TaskCategory.other:
        return '기타';
    }
  }
}

@JsonSerializable()
class Task {
  final int? id;
  final String title;
  final String? description;
  final DateTime? deadline;
  final int importanceLevel; // 1-10 스케일
  final int urgencyLevel; // 1-10 스케일
  final int completionPercentage; // 0-100%
  final int estimatedDuration; // 분 단위
  final TaskCategory category;
  final DateTime createdAt;
  final DateTime updatedAt;

  // AI가 계산한 우선순위 사분면
  final PriorityQuadrant? priorityQuadrant;

  // AI 스케줄링 관련
  final bool isScheduled;
  final DateTime? scheduledDate;
  final DateTime? scheduledStartTime;
  final DateTime? scheduledEndTime;

  const Task({
    this.id,
    required this.title,
    this.description,
    this.deadline,
    required this.importanceLevel,
    required this.urgencyLevel,
    this.completionPercentage = 0,
    required this.estimatedDuration,
    this.category = TaskCategory.other,
    required this.createdAt,
    required this.updatedAt,
    this.priorityQuadrant,
    this.isScheduled = false,
    this.scheduledDate,
    this.scheduledStartTime,
    this.scheduledEndTime,
  });

  /// Eisenhower Matrix 기반으로 우선순위 사분면 계산
  PriorityQuadrant calculatePriorityQuadrant() {
    bool isUrgent = urgencyLevel >= 7; // 7 이상을 긴급으로 분류
    bool isImportant = importanceLevel >= 7; // 7 이상을 중요로 분류

    if (isUrgent && isImportant) {
      return PriorityQuadrant.urgentImportant;
    } else if (!isUrgent && isImportant) {
      return PriorityQuadrant.notUrgentImportant;
    } else if (isUrgent && !isImportant) {
      return PriorityQuadrant.urgentNotImportant;
    } else {
      return PriorityQuadrant.notUrgentNotImportant;
    }
  }

  /// 우선순위 점수 계산 (스케줄링용)
  double calculatePriorityScore() {
    double baseScore = (importanceLevel * 0.6) + (urgencyLevel * 0.4);

    // 마감일이 가까울수록 점수 증가
    if (deadline != null) {
      DateTime now = DateTime.now();
      Duration timeToDeadline = deadline!.difference(now);
      double daysToDeadline = timeToDeadline.inDays.toDouble();

      if (daysToDeadline <= 1) {
        baseScore += 3; // 하루 이내
      } else if (daysToDeadline <= 3) {
        baseScore += 2; // 3일 이내
      } else if (daysToDeadline <= 7) {
        baseScore += 1; // 일주일 이내
      }
    }

    return baseScore;
  }

  /// 작업 완료 여부
  bool get isCompleted => completionPercentage >= 100;

  /// 실제 우선순위 사분면 (null이면 계산해서 반환)
  PriorityQuadrant get actualPriorityQuadrant =>
      priorityQuadrant ?? calculatePriorityQuadrant();

  /// 마감일까지 남은 시간 (분 단위)
  int? get minutesToDeadline {
    if (deadline == null) return null;
    return deadline!.difference(DateTime.now()).inMinutes;
  }

  /// 우선순위 사분면의 한국어 설명
  String get priorityQuadrantDescription {
    PriorityQuadrant quadrant = priorityQuadrant ?? calculatePriorityQuadrant();
    switch (quadrant) {
      case PriorityQuadrant.urgentImportant:
        return '긴급하고 중요함 (즉시 처리)';
      case PriorityQuadrant.notUrgentImportant:
        return '중요함 (계획해서 처리)';
      case PriorityQuadrant.urgentNotImportant:
        return '긴급함 (빠르게 처리)';
      case PriorityQuadrant.notUrgentNotImportant:
        return '일반 (여유 시간에 처리)';
    }
  }

  /// 카테고리의 한국어 표시명
  String get categoryDisplayName {
    switch (category) {
      case TaskCategory.work:
        return '업무';
      case TaskCategory.personal:
        return '개인';
      case TaskCategory.health:
        return '건강';
      case TaskCategory.education:
        return '교육';
      case TaskCategory.family:
        return '가족';
      case TaskCategory.finance:
        return '재정';
      case TaskCategory.other:
        return '기타';
    }
  }

  /// copyWith 메서드
  Task copyWith({
    int? id,
    String? title,
    String? description,
    DateTime? deadline,
    int? importanceLevel,
    int? urgencyLevel,
    int? completionPercentage,
    int? estimatedDuration,
    TaskCategory? category,
    DateTime? createdAt,
    DateTime? updatedAt,
    PriorityQuadrant? priorityQuadrant,
    bool? isScheduled,
    DateTime? scheduledDate,
    DateTime? scheduledStartTime,
    DateTime? scheduledEndTime,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      deadline: deadline ?? this.deadline,
      importanceLevel: importanceLevel ?? this.importanceLevel,
      urgencyLevel: urgencyLevel ?? this.urgencyLevel,
      completionPercentage: completionPercentage ?? this.completionPercentage,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      priorityQuadrant: priorityQuadrant ?? this.priorityQuadrant,
      isScheduled: isScheduled ?? this.isScheduled,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      scheduledStartTime: scheduledStartTime ?? this.scheduledStartTime,
      scheduledEndTime: scheduledEndTime ?? this.scheduledEndTime,
    );
  }

  /// JSON 변환 메서드들
  factory Task.fromJson(Map<String, dynamic> json) => _$TaskFromJson(json);
  Map<String, dynamic> toJson() => _$TaskToJson(this);

  @override
  String toString() {
    return 'Task(id: $id, title: $title, category: $category, priority: $priorityQuadrant, completion: $completionPercentage%, scheduled: $isScheduled)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Task && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
