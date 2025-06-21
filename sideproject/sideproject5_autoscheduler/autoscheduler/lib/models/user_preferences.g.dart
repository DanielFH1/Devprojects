// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_preferences.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserPreferences _$UserPreferencesFromJson(
  Map<String, dynamic> json,
) => UserPreferences(
  id: (json['id'] as num?)?.toInt(),
  userName: json['userName'] as String? ?? '사용자',
  workingHoursStart: json['workingHoursStart'] as String? ?? '09:00',
  workingHoursEnd: json['workingHoursEnd'] as String? ?? '18:00',
  productivityPeak:
      $enumDecodeNullable(
        _$ProductivityPeakEnumMap,
        json['productivityPeak'],
      ) ??
      ProductivityPeak.morning,
  dailyTaskLimit: (json['dailyTaskLimit'] as num?)?.toInt() ?? 8,
  darkMode: json['darkMode'] as bool? ?? false,
  notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
  reminderMinutesBefore: (json['reminderMinutesBefore'] as num?)?.toInt() ?? 15,
  language: json['language'] as String? ?? 'ko',
  autoScheduling: json['autoScheduling'] as bool? ?? true,
  availableHoursPerDay: (json['availableHoursPerDay'] as num?)?.toInt() ?? 8,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$UserPreferencesToJson(UserPreferences instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userName': instance.userName,
      'workingHoursStart': instance.workingHoursStart,
      'workingHoursEnd': instance.workingHoursEnd,
      'productivityPeak': _$ProductivityPeakEnumMap[instance.productivityPeak]!,
      'dailyTaskLimit': instance.dailyTaskLimit,
      'darkMode': instance.darkMode,
      'notificationsEnabled': instance.notificationsEnabled,
      'reminderMinutesBefore': instance.reminderMinutesBefore,
      'language': instance.language,
      'autoScheduling': instance.autoScheduling,
      'availableHoursPerDay': instance.availableHoursPerDay,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

const _$ProductivityPeakEnumMap = {
  ProductivityPeak.morning: 'morning',
  ProductivityPeak.afternoon: 'afternoon',
  ProductivityPeak.evening: 'evening',
  ProductivityPeak.allDay: 'allDay',
};
