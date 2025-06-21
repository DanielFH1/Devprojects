// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Task _$TaskFromJson(Map<String, dynamic> json) => Task(
  id: (json['id'] as num?)?.toInt(),
  title: json['title'] as String,
  description: json['description'] as String?,
  deadline:
      json['deadline'] == null
          ? null
          : DateTime.parse(json['deadline'] as String),
  importanceLevel: (json['importanceLevel'] as num).toInt(),
  urgencyLevel: (json['urgencyLevel'] as num).toInt(),
  completionPercentage: (json['completionPercentage'] as num?)?.toInt() ?? 0,
  estimatedDuration: (json['estimatedDuration'] as num).toInt(),
  category:
      $enumDecodeNullable(_$TaskCategoryEnumMap, json['category']) ??
      TaskCategory.other,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  priorityQuadrant: $enumDecodeNullable(
    _$PriorityQuadrantEnumMap,
    json['priorityQuadrant'],
  ),
  isScheduled: json['isScheduled'] as bool? ?? false,
  scheduledDate:
      json['scheduledDate'] == null
          ? null
          : DateTime.parse(json['scheduledDate'] as String),
  scheduledStartTime:
      json['scheduledStartTime'] == null
          ? null
          : DateTime.parse(json['scheduledStartTime'] as String),
  scheduledEndTime:
      json['scheduledEndTime'] == null
          ? null
          : DateTime.parse(json['scheduledEndTime'] as String),
);

Map<String, dynamic> _$TaskToJson(Task instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'description': instance.description,
  'deadline': instance.deadline?.toIso8601String(),
  'importanceLevel': instance.importanceLevel,
  'urgencyLevel': instance.urgencyLevel,
  'completionPercentage': instance.completionPercentage,
  'estimatedDuration': instance.estimatedDuration,
  'category': _$TaskCategoryEnumMap[instance.category]!,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'priorityQuadrant': _$PriorityQuadrantEnumMap[instance.priorityQuadrant],
  'isScheduled': instance.isScheduled,
  'scheduledDate': instance.scheduledDate?.toIso8601String(),
  'scheduledStartTime': instance.scheduledStartTime?.toIso8601String(),
  'scheduledEndTime': instance.scheduledEndTime?.toIso8601String(),
};

const _$TaskCategoryEnumMap = {
  TaskCategory.work: 'work',
  TaskCategory.personal: 'personal',
  TaskCategory.health: 'health',
  TaskCategory.education: 'education',
  TaskCategory.family: 'family',
  TaskCategory.finance: 'finance',
  TaskCategory.other: 'other',
};

const _$PriorityQuadrantEnumMap = {
  PriorityQuadrant.urgentImportant: 1,
  PriorityQuadrant.notUrgentImportant: 2,
  PriorityQuadrant.urgentNotImportant: 3,
  PriorityQuadrant.notUrgentNotImportant: 4,
};
