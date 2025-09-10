class TimerModel {
  final String id;
  final String name;
  final String description;
  final int totalSeconds;
  final DateTime createdAt;
  int remainingSeconds;
  bool isActive;

  TimerModel({
    required this.id,
    required this.name,
    required this.description,
    required this.totalSeconds,
    required this.createdAt,
    required this.remainingSeconds,
    this.isActive = true,
  });

  factory TimerModel.fromJson(Map<String, dynamic> json) {
    return TimerModel(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      totalSeconds: json['total_seconds'],
      createdAt: DateTime.parse(json['created_at']),
      remainingSeconds: json['remaining_seconds'],
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'total_seconds': totalSeconds,
      'created_at': createdAt.toIso8601String(),
      'remaining_seconds': remainingSeconds,
      'is_active': isActive,
    };
  }

  String get formattedTime {
    final hours = remainingSeconds ~/ 3600;
    final minutes = (remainingSeconds % 3600) ~/ 60;
    final seconds = remainingSeconds % 60;
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  bool get isFinished => remainingSeconds <= 0;
} 