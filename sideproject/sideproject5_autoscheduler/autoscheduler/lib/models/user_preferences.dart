import 'package:json_annotation/json_annotation.dart';

part 'user_preferences.g.dart';

/// 생산성 피크 타임
enum ProductivityPeak {
  @JsonValue('morning')
  morning,

  @JsonValue('afternoon')
  afternoon,

  @JsonValue('evening')
  evening,

  @JsonValue('allDay')
  allDay,
}

@JsonSerializable()
class UserPreferences {
  final int? id;
  final String userName;
  final String workingHoursStart; // 'HH:mm' 형식
  final String workingHoursEnd; // 'HH:mm' 형식
  final ProductivityPeak productivityPeak;
  final int dailyTaskLimit; // 하루 최대 작업 수
  final bool darkMode;
  final bool notificationsEnabled;
  final int reminderMinutesBefore; // 작업 시작 전 알림 시간 (분)
  final String language; // 언어 설정
  final bool autoScheduling; // AI 자동 스케줄링 사용 여부
  final int availableHoursPerDay; // 하루 사용 가능 시간 (시간)
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserPreferences({
    this.id,
    this.userName = '사용자',
    this.workingHoursStart = '09:00',
    this.workingHoursEnd = '18:00',
    this.productivityPeak = ProductivityPeak.morning,
    this.dailyTaskLimit = 8,
    this.darkMode = false,
    this.notificationsEnabled = true,
    this.reminderMinutesBefore = 15,
    this.language = 'ko',
    this.autoScheduling = true,
    this.availableHoursPerDay = 8,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 기본 설정으로 초기화
  factory UserPreferences.defaultSettings() {
    DateTime now = DateTime.now();
    return UserPreferences(createdAt: now, updatedAt: now);
  }

  /// 근무 시간 계산 (분 단위)
  int get workingMinutesPerDay {
    List<String> startParts = workingHoursStart.split(':');
    List<String> endParts = workingHoursEnd.split(':');

    int startMinutes =
        (int.parse(startParts[0]) * 60) + int.parse(startParts[1]);
    int endMinutes = (int.parse(endParts[0]) * 60) + int.parse(endParts[1]);

    return endMinutes - startMinutes;
  }

  /// 생산성 피크 시간대의 한국어 표시명
  String get productivityPeakDisplayName {
    switch (productivityPeak) {
      case ProductivityPeak.morning:
        return '오전형 (아침에 집중력이 좋음)';
      case ProductivityPeak.afternoon:
        return '오후형 (오후에 집중력이 좋음)';
      case ProductivityPeak.evening:
        return '저녁형 (저녁에 집중력이 좋음)';
      case ProductivityPeak.allDay:
        return '하루종일 (시간대 상관없음)';
    }
  }

  /// 근무 시간 표시 (한국어)
  String get workingHoursDisplayName {
    return '$workingHoursStart - $workingHoursEnd';
  }

  /// copyWith 메서드
  UserPreferences copyWith({
    int? id,
    String? userName,
    String? workingHoursStart,
    String? workingHoursEnd,
    ProductivityPeak? productivityPeak,
    int? dailyTaskLimit,
    bool? darkMode,
    bool? notificationsEnabled,
    int? reminderMinutesBefore,
    String? language,
    bool? autoScheduling,
    int? availableHoursPerDay,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserPreferences(
      id: id ?? this.id,
      userName: userName ?? this.userName,
      workingHoursStart: workingHoursStart ?? this.workingHoursStart,
      workingHoursEnd: workingHoursEnd ?? this.workingHoursEnd,
      productivityPeak: productivityPeak ?? this.productivityPeak,
      dailyTaskLimit: dailyTaskLimit ?? this.dailyTaskLimit,
      darkMode: darkMode ?? this.darkMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      reminderMinutesBefore:
          reminderMinutesBefore ?? this.reminderMinutesBefore,
      language: language ?? this.language,
      autoScheduling: autoScheduling ?? this.autoScheduling,
      availableHoursPerDay: availableHoursPerDay ?? this.availableHoursPerDay,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// JSON 변환 메서드들
  factory UserPreferences.fromJson(Map<String, dynamic> json) =>
      _$UserPreferencesFromJson(json);
  Map<String, dynamic> toJson() => _$UserPreferencesToJson(this);

  @override
  String toString() {
    return 'UserPreferences(userName: $userName, workingHours: $workingHoursDisplayName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserPreferences && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
