import 'package:json_annotation/json_annotation.dart';
import 'task_model.dart';
import 'user_preferences.dart';

part 'schedule_model.g.dart';

@JsonSerializable()
class TimeBlock {
  final int? id;
  final DateTime startTime;
  final DateTime endTime;
  final int taskId;
  final String? taskTitle; // 캐시된 작업 제목
  final PriorityQuadrant priorityQuadrant;
  final String? reasoning; // AI가 제공한 스케줄링 이유
  final bool isCompleted;
  final DateTime createdAt;

  const TimeBlock({
    this.id,
    required this.startTime,
    required this.endTime,
    required this.taskId,
    this.taskTitle,
    required this.priorityQuadrant,
    this.reasoning,
    this.isCompleted = false,
    required this.createdAt,
  });

  /// 시간 블록의 지속 시간 (분 단위)
  int get durationInMinutes {
    return endTime.difference(startTime).inMinutes;
  }

  /// 시간 블록이 현재 진행 중인지 확인
  bool get isCurrentlyActive {
    DateTime now = DateTime.now();
    return now.isAfter(startTime) && now.isBefore(endTime);
  }

  /// 시간 블록이 과거인지 확인
  bool get isPast {
    return DateTime.now().isAfter(endTime);
  }

  /// 시간 블록이 미래인지 확인
  bool get isFuture {
    return DateTime.now().isBefore(startTime);
  }

  /// 시간 표시 (예: "09:00 - 11:00")
  String get timeDisplayString {
    String startHour = startTime.hour.toString().padLeft(2, '0');
    String startMinute = startTime.minute.toString().padLeft(2, '0');
    String endHour = endTime.hour.toString().padLeft(2, '0');
    String endMinute = endTime.minute.toString().padLeft(2, '0');

    return '$startHour:$startMinute - $endHour:$endMinute';
  }

  /// copyWith 메서드
  TimeBlock copyWith({
    int? id,
    DateTime? startTime,
    DateTime? endTime,
    int? taskId,
    String? taskTitle,
    PriorityQuadrant? priorityQuadrant,
    String? reasoning,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return TimeBlock(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      taskId: taskId ?? this.taskId,
      taskTitle: taskTitle ?? this.taskTitle,
      priorityQuadrant: priorityQuadrant ?? this.priorityQuadrant,
      reasoning: reasoning ?? this.reasoning,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// JSON 변환 메서드들
  factory TimeBlock.fromJson(Map<String, dynamic> json) =>
      _$TimeBlockFromJson(json);
  Map<String, dynamic> toJson() => _$TimeBlockToJson(this);

  @override
  String toString() {
    return 'TimeBlock(taskId: $taskId, time: $timeDisplayString)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TimeBlock && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

@JsonSerializable()
class DailySchedule {
  final int? id;
  final DateTime date;
  final List<TimeBlock> timeBlocks;
  final List<String> aiRecommendations; // AI가 제공한 일반적인 조언들
  final bool isAiGenerated;
  final double totalScheduledHours;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DailySchedule({
    this.id,
    required this.date,
    required this.timeBlocks,
    this.aiRecommendations = const [],
    this.isAiGenerated = false,
    required this.totalScheduledHours,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 오늘 날짜로 빈 스케줄 생성
  factory DailySchedule.empty(DateTime date) {
    DateTime now = DateTime.now();
    return DailySchedule(
      date: date,
      timeBlocks: [],
      totalScheduledHours: 0.0,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// 완료된 작업의 수
  int get completedTasksCount {
    return timeBlocks.where((block) => block.isCompleted).length;
  }

  /// 전체 작업의 수
  int get totalTasksCount {
    return timeBlocks.length;
  }

  /// 완료율 (0.0 - 1.0)
  double get completionRate {
    if (totalTasksCount == 0) return 0.0;
    return completedTasksCount / totalTasksCount;
  }

  /// 완료율 백분율 (0 - 100)
  int get completionPercentage {
    return (completionRate * 100).round();
  }

  /// 날짜 표시 문자열 (예: "2024년 3월 15일")
  String get dateDisplayString {
    List<String> months = [
      '1월',
      '2월',
      '3월',
      '4월',
      '5월',
      '6월',
      '7월',
      '8월',
      '9월',
      '10월',
      '11월',
      '12월',
    ];
    return '${date.year}년 ${months[date.month - 1]} ${date.day}일';
  }

  /// 우선순위별로 시간 블록 그룹화
  Map<PriorityQuadrant, List<TimeBlock>> get timeBlocksByPriority {
    Map<PriorityQuadrant, List<TimeBlock>> grouped = {};

    for (PriorityQuadrant quadrant in PriorityQuadrant.values) {
      grouped[quadrant] =
          timeBlocks
              .where((block) => block.priorityQuadrant == quadrant)
              .toList();
    }

    return grouped;
  }

  /// 현재 진행 중인 작업
  TimeBlock? get currentActiveBlock {
    try {
      return timeBlocks.firstWhere((block) => block.isCurrentlyActive);
    } catch (e) {
      return null;
    }
  }

  /// 다음 예정된 작업
  TimeBlock? get nextScheduledBlock {
    List<TimeBlock> futureBlocks =
        timeBlocks.where((block) => block.isFuture).toList();

    if (futureBlocks.isEmpty) return null;

    futureBlocks.sort((a, b) => a.startTime.compareTo(b.startTime));
    return futureBlocks.first;
  }

  /// copyWith 메서드
  DailySchedule copyWith({
    int? id,
    DateTime? date,
    List<TimeBlock>? timeBlocks,
    List<String>? aiRecommendations,
    bool? isAiGenerated,
    double? totalScheduledHours,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DailySchedule(
      id: id ?? this.id,
      date: date ?? this.date,
      timeBlocks: timeBlocks ?? this.timeBlocks,
      aiRecommendations: aiRecommendations ?? this.aiRecommendations,
      isAiGenerated: isAiGenerated ?? this.isAiGenerated,
      totalScheduledHours: totalScheduledHours ?? this.totalScheduledHours,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// JSON 변환 메서드들
  factory DailySchedule.fromJson(Map<String, dynamic> json) =>
      _$DailyScheduleFromJson(json);
  Map<String, dynamic> toJson() => _$DailyScheduleToJson(this);

  @override
  String toString() {
    return 'DailySchedule(date: $dateDisplayString, tasks: $totalTasksCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DailySchedule && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// AI 스케줄링 요청을 위한 데이터 클래스
@JsonSerializable()
class SchedulingRequest {
  final List<Task> tasks;
  final UserPreferences userPreferences;
  final DateTime startDate;
  final int daysToSchedule;
  final DateTime currentDateTime;

  const SchedulingRequest({
    required this.tasks,
    required this.userPreferences,
    required this.startDate,
    this.daysToSchedule = 7,
    required this.currentDateTime,
  });

  /// OpenAI API로 전송할 JSON 형태로 변환
  Map<String, dynamic> toOpenAIJson() {
    return {
      'tasks':
          tasks
              .map(
                (task) => {
                  'id': task.id,
                  'title': task.title,
                  'deadline': task.deadline?.toIso8601String(),
                  'importance': task.importanceLevel,
                  'urgency': task.urgencyLevel,
                  'estimated_duration': task.estimatedDuration,
                  'completion_percentage': task.completionPercentage,
                  'category': task.category.name,
                },
              )
              .toList(),
      'user_preferences': {
        'working_hours':
            '${userPreferences.workingHoursStart}-${userPreferences.workingHoursEnd}',
        'productivity_peak': userPreferences.productivityPeak.name,
        'available_hours_per_day': userPreferences.availableHoursPerDay,
        'daily_task_limit': userPreferences.dailyTaskLimit,
      },
      'scheduling_parameters': {
        'start_date': startDate.toIso8601String(),
        'days_to_schedule': daysToSchedule,
        'current_date': currentDateTime.toIso8601String(),
      },
    };
  }

  /// JSON 변환 메서드들
  factory SchedulingRequest.fromJson(Map<String, dynamic> json) =>
      _$SchedulingRequestFromJson(json);
  Map<String, dynamic> toJson() => _$SchedulingRequestToJson(this);
}

/// AI 스케줄링 응답을 위한 데이터 클래스
@JsonSerializable()
class SchedulingResponse {
  final List<DailySchedule> schedules;
  final List<String> generalRecommendations;
  final double confidence; // AI 예측 신뢰도 (0.0 - 1.0)
  final DateTime generatedAt;

  const SchedulingResponse({
    required this.schedules,
    required this.generalRecommendations,
    this.confidence = 0.8,
    required this.generatedAt,
  });

  /// JSON 변환 메서드들
  factory SchedulingResponse.fromJson(Map<String, dynamic> json) =>
      _$SchedulingResponseFromJson(json);
  Map<String, dynamic> toJson() => _$SchedulingResponseToJson(this);
}
