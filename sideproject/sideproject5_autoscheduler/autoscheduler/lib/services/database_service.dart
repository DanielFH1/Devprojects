import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart';
import '../models/task_model.dart';
import '../models/user_preferences.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static dynamic _database;
  bool _isInitialized = false;

  /// 데이터베이스 초기화
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 웹이 아닌 플랫폼에서는 FFI 초기화
      if (!kIsWeb) {
        // 데스크톱 플랫폼에서 sqflite_common_ffi 초기화
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }

      await database; // 데이터베이스 생성
      _isInitialized = true;
    } catch (e) {
      debugPrint('데이터베이스 초기화 실패: $e');
      // 웹에서는 메모리 기반 데이터베이스 사용
      if (kIsWeb) {
        // 웹에서는 데이터베이스 없이 메모리에서 작동
        _isInitialized = true;
      }
    }
  }

  Future<dynamic> get database async {
    if (_database != null) return _database!;

    // 웹에서는 예외 발생 시 null 반환
    if (kIsWeb) {
      throw UnsupportedError('웹에서는 SQLite 데이터베이스가 지원되지 않습니다.');
    }

    _database = await _initDatabase();
    return _database!;
  }

  Future<dynamic> _initDatabase() async {
    String databasesPath = await getDatabasesPath();
    String path = join(databasesPath, 'autoscheduler.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(dynamic db, int version) async {
    // Tasks 테이블 생성
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        deadline TEXT,
        importance_level INTEGER NOT NULL,
        urgency_level INTEGER NOT NULL,
        completion_percentage INTEGER DEFAULT 0,
        estimated_duration INTEGER NOT NULL,
        category TEXT NOT NULL,
        priority_quadrant INTEGER,
        is_scheduled INTEGER DEFAULT 0,
        scheduled_date TEXT,
        scheduled_start_time TEXT,
        scheduled_end_time TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // User Preferences 테이블 생성
    await db.execute('''
      CREATE TABLE user_preferences (
        id INTEGER PRIMARY KEY,
        user_name TEXT NOT NULL,
        working_hours_start TEXT NOT NULL,
        working_hours_end TEXT NOT NULL,
        productivity_peak TEXT NOT NULL,
        daily_task_limit INTEGER NOT NULL,
        dark_mode INTEGER DEFAULT 0,
        notifications_enabled INTEGER DEFAULT 1,
        reminder_minutes_before INTEGER DEFAULT 15,
        language TEXT DEFAULT 'ko',
        auto_scheduling INTEGER DEFAULT 1,
        available_hours_per_day INTEGER DEFAULT 8,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Time Blocks 테이블 생성
    await db.execute('''
      CREATE TABLE time_blocks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        task_id INTEGER NOT NULL,
        task_title TEXT,
        priority_quadrant INTEGER NOT NULL,
        reasoning TEXT,
        is_completed INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE
      )
    ''');

    // Daily Schedules 테이블 생성
    await db.execute('''
      CREATE TABLE daily_schedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL UNIQUE,
        ai_recommendations TEXT,
        is_ai_generated INTEGER DEFAULT 0,
        total_scheduled_hours REAL DEFAULT 0.0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 기본 사용자 설정 삽입
    await _insertDefaultUserPreferences(db);
  }

  Future<void> _onUpgrade(dynamic db, int oldVersion, int newVersion) async {
    // 버전 업그레이드 시 필요한 마이그레이션 로직
  }

  Future<void> _insertDefaultUserPreferences(dynamic db) async {
    DateTime now = DateTime.now();
    await db.insert('user_preferences', {
      'id': 1,
      'user_name': '사용자',
      'working_hours_start': '09:00',
      'working_hours_end': '18:00',
      'productivity_peak': 'morning',
      'daily_task_limit': 8,
      'dark_mode': 0,
      'notifications_enabled': 1,
      'reminder_minutes_before': 15,
      'language': 'ko',
      'auto_scheduling': 1,
      'available_hours_per_day': 8,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
  }

  // ================ Task 관련 메서드들 ================

  /// 작업 생성
  Future<int> insertTask(Task task) async {
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final tasksJson = prefs.getString('tasks') ?? '[]';
        final List<dynamic> tasksList = json.decode(tasksJson);

        // 새 ID 생성 (기존 최대 ID + 1)
        int newId = 1;
        if (tasksList.isNotEmpty) {
          final maxId = tasksList
              .map((t) => t['id'] as int? ?? 0)
              .reduce((a, b) => a > b ? a : b);
          newId = maxId + 1;
        }

        final taskWithId = task.copyWith(id: newId);
        tasksList.add(taskWithId.toJson());
        await prefs.setString('tasks', json.encode(tasksList));
        return newId;
      } catch (e) {
        debugPrint('웹에서 작업 저장 실패: $e');
        return -1;
      }
    }

    try {
      final db = await database;
      return await db.insert('tasks', _taskToMap(task));
    } catch (e) {
      debugPrint('데이터베이스 삽입 실패: $e');
      return -1;
    }
  }

  /// 모든 작업 조회
  Future<List<Task>> getAllTasks() async {
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final tasksJson = prefs.getString('tasks') ?? '[]';
        final List<dynamic> tasksList = json.decode(tasksJson);
        return tasksList.map((json) => Task.fromJson(json)).toList();
      } catch (e) {
        debugPrint('웹에서 작업 조회 실패: $e');
        return [];
      }
    }

    try {
      final db = await database;
      final maps = await db.query('tasks', orderBy: 'created_at DESC');
      return maps.map((map) => _mapToTask(map)).toList();
    } catch (e) {
      debugPrint('데이터베이스 조회 실패: $e');
      return [];
    }
  }

  /// 특정 날짜의 작업 조회
  Future<List<Task>> getTasksByDate(DateTime date) async {
    final db = await database;
    String dateStr = date.toIso8601String().split('T')[0];
    final maps = await db.query(
      'tasks',
      where: 'scheduled_date LIKE ?',
      whereArgs: ['$dateStr%'],
      orderBy: 'scheduled_start_time ASC',
    );
    return maps.map((map) => _mapToTask(map)).toList();
  }

  /// 완료되지 않은 작업 조회
  Future<List<Task>> getIncompleteTasks() async {
    final db = await database;
    final maps = await db.query(
      'tasks',
      where: 'completion_percentage < ?',
      whereArgs: [100],
      orderBy: 'deadline ASC',
    );
    return maps.map((map) => _mapToTask(map)).toList();
  }

  /// 작업 업데이트
  Future<int> updateTask(Task task) async {
    final db = await database;
    return await db.update(
      'tasks',
      _taskToMap(task),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  /// 작업 삭제
  Future<int> deleteTask(int id) async {
    final db = await database;
    return await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  /// 작업 완료 토글
  Future<int> toggleTaskCompletion(int taskId, bool isCompleted) async {
    final db = await database;
    return await db.update(
      'tasks',
      {
        'completion_percentage': isCompleted ? 100 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  // ================ UserPreferences 관련 메서드들 ================

  /// 사용자 설정 조회
  Future<UserPreferences?> getUserPreferences() async {
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final prefsJson = prefs.getString('user_preferences');
        if (prefsJson != null) {
          return UserPreferences.fromJson(json.decode(prefsJson));
        }

        // 웹에서 기본 사용자 설정 생성
        final defaultPrefs = UserPreferences(
          id: 1,
          userName: '사용자',
          workingHoursStart: '09:00',
          workingHoursEnd: '18:00',
          productivityPeak: ProductivityPeak.morning,
          dailyTaskLimit: 8,
          isDarkMode: false,
          notificationsEnabled: true,
          reminderMinutesBefore: 15,
          language: 'ko',
          autoScheduling: true,
          availableHoursPerDay: 8,
          creativityPreference: 5,
          collaborationPreference: 5,
          taskLengthPreference: 5,
          additionalInfo: null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await prefs.setString(
          'user_preferences',
          json.encode(defaultPrefs.toJson()),
        );
        return defaultPrefs;
      } catch (e) {
        debugPrint('웹에서 사용자 설정 조회 실패: $e');
        return null;
      }
    }

    try {
      final db = await database;
      final maps = await db.query(
        'user_preferences',
        where: 'id = ?',
        whereArgs: [1],
      );
      if (maps.isEmpty) return null;
      return _mapToUserPreferences(maps.first);
    } catch (e) {
      debugPrint('데이터베이스에서 사용자 설정 조회 실패: $e');
      return null;
    }
  }

  /// 사용자 설정 업데이트
  Future<int> updateUserPreferences(UserPreferences preferences) async {
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'user_preferences',
          json.encode(preferences.toJson()),
        );
        return 1; // 성공을 나타내는 값
      } catch (e) {
        debugPrint('웹에서 사용자 설정 업데이트 실패: $e');
        return 0;
      }
    }

    final db = await database;
    return await db.update(
      'user_preferences',
      _userPreferencesToMap(preferences),
      where: 'id = ?',
      whereArgs: [1],
    );
  }

  // ================ 데이터 변환 헬퍼 메서드들 ================

  Map<String, dynamic> _taskToMap(Task task) {
    return {
      'id': task.id,
      'title': task.title,
      'description': task.description,
      'deadline': task.deadline?.toIso8601String(),
      'importance_level': task.importanceLevel,
      'urgency_level': task.urgencyLevel,
      'completion_percentage': task.completionPercentage,
      'estimated_duration': task.estimatedDuration,
      'category': task.category.name,
      'priority_quadrant': task.priorityQuadrant?.index,
      'is_scheduled': task.isScheduled ? 1 : 0,
      'scheduled_date': task.scheduledDate?.toIso8601String(),
      'scheduled_start_time': task.scheduledStartTime?.toIso8601String(),
      'scheduled_end_time': task.scheduledEndTime?.toIso8601String(),
      'created_at': task.createdAt.toIso8601String(),
      'updated_at': task.updatedAt.toIso8601String(),
    };
  }

  Task _mapToTask(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      deadline:
          map['deadline'] != null ? DateTime.parse(map['deadline']) : null,
      importanceLevel: map['importance_level'],
      urgencyLevel: map['urgency_level'],
      completionPercentage: map['completion_percentage'] ?? 0,
      estimatedDuration: map['estimated_duration'],
      category: TaskCategory.values.firstWhere(
        (c) => c.name == map['category'],
      ),
      priorityQuadrant:
          map['priority_quadrant'] != null
              ? PriorityQuadrant.values[map['priority_quadrant']]
              : null,
      isScheduled: (map['is_scheduled'] ?? 0) == 1,
      scheduledDate:
          map['scheduled_date'] != null
              ? DateTime.parse(map['scheduled_date'])
              : null,
      scheduledStartTime:
          map['scheduled_start_time'] != null
              ? DateTime.parse(map['scheduled_start_time'])
              : null,
      scheduledEndTime:
          map['scheduled_end_time'] != null
              ? DateTime.parse(map['scheduled_end_time'])
              : null,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  Map<String, dynamic> _userPreferencesToMap(UserPreferences preferences) {
    return {
      'id': preferences.id ?? 1,
      'user_name': preferences.userName,
      'working_hours_start': preferences.workingHoursStart,
      'working_hours_end': preferences.workingHoursEnd,
      'productivity_peak': preferences.productivityPeak.name,
      'daily_task_limit': preferences.dailyTaskLimit,
      'dark_mode': preferences.darkMode ? 1 : 0,
      'notifications_enabled': preferences.notificationsEnabled ? 1 : 0,
      'reminder_minutes_before': preferences.reminderMinutesBefore,
      'language': preferences.language,
      'auto_scheduling': preferences.autoScheduling ? 1 : 0,
      'available_hours_per_day': preferences.availableHoursPerDay,
      'created_at': preferences.createdAt.toIso8601String(),
      'updated_at': preferences.updatedAt.toIso8601String(),
    };
  }

  UserPreferences _mapToUserPreferences(Map<String, dynamic> map) {
    return UserPreferences(
      id: map['id'],
      userName: map['user_name'],
      workingHoursStart: map['working_hours_start'],
      workingHoursEnd: map['working_hours_end'],
      productivityPeak: ProductivityPeak.values.firstWhere(
        (p) => p.name == map['productivity_peak'],
      ),
      dailyTaskLimit: map['daily_task_limit'],
      darkMode: (map['dark_mode'] ?? 0) == 1,
      notificationsEnabled: (map['notifications_enabled'] ?? 1) == 1,
      reminderMinutesBefore: map['reminder_minutes_before'] ?? 15,
      language: map['language'] ?? 'ko',
      autoScheduling: (map['auto_scheduling'] ?? 1) == 1,
      availableHoursPerDay: map['available_hours_per_day'] ?? 8,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  /// 데이터베이스 닫기
  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  /// 데이터베이스 초기화 (개발/테스트용)
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('tasks');
    await db.delete('time_blocks');
    await db.delete('daily_schedules');
    // 사용자 설정은 유지
  }
}
