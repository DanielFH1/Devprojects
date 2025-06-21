// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schedule_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TimeBlock _$TimeBlockFromJson(Map<String, dynamic> json) => TimeBlock(
  id: (json['id'] as num?)?.toInt(),
  startTime: DateTime.parse(json['startTime'] as String),
  endTime: DateTime.parse(json['endTime'] as String),
  taskId: (json['taskId'] as num).toInt(),
  taskTitle: json['taskTitle'] as String?,
  priorityQuadrant: $enumDecode(
    _$PriorityQuadrantEnumMap,
    json['priorityQuadrant'],
  ),
  reasoning: json['reasoning'] as String?,
  isCompleted: json['isCompleted'] as bool? ?? false,
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$TimeBlockToJson(TimeBlock instance) => <String, dynamic>{
  'id': instance.id,
  'startTime': instance.startTime.toIso8601String(),
  'endTime': instance.endTime.toIso8601String(),
  'taskId': instance.taskId,
  'taskTitle': instance.taskTitle,
  'priorityQuadrant': _$PriorityQuadrantEnumMap[instance.priorityQuadrant]!,
  'reasoning': instance.reasoning,
  'isCompleted': instance.isCompleted,
  'createdAt': instance.createdAt.toIso8601String(),
};

const _$PriorityQuadrantEnumMap = {
  PriorityQuadrant.urgentImportant: 1,
  PriorityQuadrant.notUrgentImportant: 2,
  PriorityQuadrant.urgentNotImportant: 3,
  PriorityQuadrant.notUrgentNotImportant: 4,
};

DailySchedule _$DailyScheduleFromJson(Map<String, dynamic> json) =>
    DailySchedule(
      id: (json['id'] as num?)?.toInt(),
      date: DateTime.parse(json['date'] as String),
      timeBlocks:
          (json['timeBlocks'] as List<dynamic>)
              .map((e) => TimeBlock.fromJson(e as Map<String, dynamic>))
              .toList(),
      aiRecommendations:
          (json['aiRecommendations'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      isAiGenerated: json['isAiGenerated'] as bool? ?? false,
      totalScheduledHours: (json['totalScheduledHours'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$DailyScheduleToJson(DailySchedule instance) =>
    <String, dynamic>{
      'id': instance.id,
      'date': instance.date.toIso8601String(),
      'timeBlocks': instance.timeBlocks,
      'aiRecommendations': instance.aiRecommendations,
      'isAiGenerated': instance.isAiGenerated,
      'totalScheduledHours': instance.totalScheduledHours,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

SchedulingRequest _$SchedulingRequestFromJson(Map<String, dynamic> json) =>
    SchedulingRequest(
      tasks:
          (json['tasks'] as List<dynamic>)
              .map((e) => Task.fromJson(e as Map<String, dynamic>))
              .toList(),
      userPreferences: UserPreferences.fromJson(
        json['userPreferences'] as Map<String, dynamic>,
      ),
      startDate: DateTime.parse(json['startDate'] as String),
      daysToSchedule: (json['daysToSchedule'] as num?)?.toInt() ?? 7,
      currentDateTime: DateTime.parse(json['currentDateTime'] as String),
    );

Map<String, dynamic> _$SchedulingRequestToJson(SchedulingRequest instance) =>
    <String, dynamic>{
      'tasks': instance.tasks,
      'userPreferences': instance.userPreferences,
      'startDate': instance.startDate.toIso8601String(),
      'daysToSchedule': instance.daysToSchedule,
      'currentDateTime': instance.currentDateTime.toIso8601String(),
    };

SchedulingResponse _$SchedulingResponseFromJson(Map<String, dynamic> json) =>
    SchedulingResponse(
      schedules:
          (json['schedules'] as List<dynamic>)
              .map((e) => DailySchedule.fromJson(e as Map<String, dynamic>))
              .toList(),
      generalRecommendations:
          (json['generalRecommendations'] as List<dynamic>)
              .map((e) => e as String)
              .toList(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.8,
      generatedAt: DateTime.parse(json['generatedAt'] as String),
    );

Map<String, dynamic> _$SchedulingResponseToJson(SchedulingResponse instance) =>
    <String, dynamic>{
      'schedules': instance.schedules,
      'generalRecommendations': instance.generalRecommendations,
      'confidence': instance.confidence,
      'generatedAt': instance.generatedAt.toIso8601String(),
    };
