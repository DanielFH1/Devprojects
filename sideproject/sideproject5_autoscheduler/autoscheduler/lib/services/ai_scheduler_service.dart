import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../models/task_model.dart';
import '../models/user_preferences.dart';
import '../models/schedule_model.dart';

class AISchedulerService {
  static final AISchedulerService _instance = AISchedulerService._internal();
  factory AISchedulerService() => _instance;
  AISchedulerService._internal();

  Dio? _dio;
  String _apiKey = '';
  String _model = 'gpt-4o-mini';
  int _maxTokens = 1500;
  double _temperature = 0.3;

  /// 서비스 초기화
  Future<void> initialize() async {
    try {
      // 로케일 데이터 초기화
      await initializeDateFormatting('ko_KR', null);

      // 환경변수 로드 (웹에서는 실패할 수 있음)
      try {
        await dotenv.load();
      } catch (e) {
        debugPrint('환경변수 로드 실패: $e');
        // 웹에서는 환경변수 대신 기본값 사용
      }

      _apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
      _model = dotenv.env['OPENAI_MODEL'] ?? 'gpt-4o-mini';
      _maxTokens = int.parse(dotenv.env['OPENAI_MAX_TOKENS'] ?? '1500');
      _temperature = double.parse(dotenv.env['OPENAI_TEMPERATURE'] ?? '0.3');

      // 웹이나 API 키가 없는 경우에도 기본 설정으로 초기화
      _dio = Dio(
        BaseOptions(
          baseUrl: 'https://api.openai.com/v1',
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

      // 인터셉터 추가 (로깅 및 에러 처리)
      _dio?.interceptors.add(
        LogInterceptor(
          requestBody: false, // 웹에서는 로깅 최소화
          responseBody: false,
          logPrint: (obj) => debugPrint('[AI Service] $obj'),
        ),
      );

      if (_apiKey.isEmpty) {
        debugPrint('OpenAI API 키가 설정되지 않았습니다. AI 기능이 제한됩니다.');
      }
    } catch (e) {
      debugPrint('AI 서비스 초기화 실패: $e');
      if (kIsWeb) {
        debugPrint('웹에서는 API 키 없이 작동합니다.');
      }
    }
  }

  /// AI를 사용하여 작업들을 자동으로 스케줄링
  Future<SchedulingResponse> scheduleTasksWithAI({
    required List<Task> tasks,
    required UserPreferences userPreferences,
    DateTime? startDate,
    int daysToSchedule = 7,
  }) async {
    try {
      startDate ??= DateTime.now();

      // 스케줄링 요청 생성
      SchedulingRequest request = SchedulingRequest(
        tasks: tasks,
        userPreferences: userPreferences,
        startDate: startDate,
        daysToSchedule: daysToSchedule,
        currentDateTime: DateTime.now(),
      );

      // AI 프롬프트 생성
      String prompt = _generateSchedulingPrompt(request);

      // OpenAI API 호출
      Map<String, dynamic> aiResponse = await _callOpenAI(prompt);

      // AI 응답 파싱
      SchedulingResponse response = _parseAIResponse(
        aiResponse,
        startDate,
        daysToSchedule,
      );

      return response;
    } catch (e) {
      debugPrint('AI 스케줄링 오류: $e');
      // 오류 발생 시 기본 스케줄링 사용
      return _generateFallbackSchedule(
        tasks,
        userPreferences,
        startDate!,
        daysToSchedule,
      );
    }
  }

  /// AI 프롬프트 생성
  String _generateSchedulingPrompt(SchedulingRequest request) {
    return '''
당신은 전문적인 생산성 컨설턴트입니다. Eisenhower Matrix를 기반으로 작업들을 최적으로 스케줄링해주세요.

# 사용자 정보
- 근무시간: ${request.userPreferences.workingHoursStart} - ${request.userPreferences.workingHoursEnd}
- 생산성 피크: ${request.userPreferences.productivityPeakDisplayName}
- 하루 사용 가능 시간: ${request.userPreferences.availableHoursPerDay}시간
- 하루 최대 작업 수: ${request.userPreferences.dailyTaskLimit}개

# 스케줄링할 작업들
${_formatTasksForPrompt(request.tasks)}

# 스케줄링 기간
시작일: ${request.startDate.toIso8601String().split('T')[0]}
기간: ${request.daysToSchedule}일간

# 요구사항
1. Eisenhower Matrix 사분면에 따라 우선순위 설정:
   - 사분면 1 (긴급하고 중요): 즉시 스케줄링, 최우선
   - 사분면 2 (중요하지만 긴급하지 않음): 계획적 스케줄링
   - 사분면 3 (긴급하지만 중요하지 않음): 빠른 시간에 처리
   - 사분면 4 (긴급하지도 중요하지도 않음): 여유 시간에 배치

2. 마감일이 가까운 작업일수록 우선순위 높게 설정
3. 사용자의 생산성 피크 시간대에 중요한 작업 배치
4. 예상 소요시간을 고려하여 현실적인 스케줄링
5. 하루 작업량이 과도하지 않도록 분산

다음 JSON 형식으로 응답해주세요:
{
  "schedules": [
    {
      "date": "YYYY-MM-DD",
      "time_blocks": [
        {
          "start_time": "HH:MM",
          "end_time": "HH:MM",
          "task_id": 숫자,
          "priority_quadrant": 1-4,
          "reasoning": "스케줄링 이유"
        }
      ]
    }
  ],
  "general_recommendations": [
    "생산성 향상을 위한 일반적인 조언들"
  ],
  "confidence": 0.0-1.0
}

한국어로 reasoning과 recommendations를 작성해주세요.
''';
  }

  /// 작업들을 프롬프트용으로 포맷팅
  String _formatTasksForPrompt(List<Task> tasks) {
    StringBuffer buffer = StringBuffer();

    for (Task task in tasks) {
      buffer.writeln('작업 ID: ${task.id}');
      buffer.writeln('제목: ${task.title}');
      if (task.description != null && task.description!.isNotEmpty) {
        buffer.writeln('설명: ${task.description}');
      }
      buffer.writeln('중요도: ${task.importanceLevel}/10');
      buffer.writeln('긴급도: ${task.urgencyLevel}/10');
      buffer.writeln('예상 소요시간: ${task.estimatedDuration}분');
      buffer.writeln('카테고리: ${task.categoryDisplayName}');
      buffer.writeln('완료율: ${task.completionPercentage}%');
      if (task.deadline != null) {
        buffer.writeln(
          '마감일: ${task.deadline!.toIso8601String().split('T')[0]}',
        );
      }
      buffer.writeln('우선순위 사분면: ${task.priorityQuadrantDescription}');
      buffer.writeln('---');
    }

    return buffer.toString();
  }

  /// OpenAI API 호출
  Future<Map<String, dynamic>> _callOpenAI(String prompt) async {
    if (_dio == null) {
      throw Exception('AI 서비스가 초기화되지 않았습니다.');
    }

    try {
      final response = await _dio!.post(
        '/chat/completions',
        data: {
          'model': _model,
          'messages': [
            {
              'role': 'system',
              'content':
                  '당신은 전문적인 생산성 컨설턴트이며 Eisenhower Matrix를 사용하여 작업을 스케줄링하는 전문가입니다.',
            },
            {'role': 'user', 'content': prompt},
          ],
          'max_tokens': _maxTokens,
          'temperature': _temperature,
          'response_format': {'type': 'json_object'},
        },
      );

      if (response.statusCode == 200) {
        String content = response.data['choices'][0]['message']['content'];
        return json.decode(content);
      } else {
        throw Exception('OpenAI API 오류: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('OpenAI API 호출 실패: $e');
      rethrow;
    }
  }

  /// AI 응답 파싱
  SchedulingResponse _parseAIResponse(
    Map<String, dynamic> aiResponse,
    DateTime startDate,
    int daysToSchedule,
  ) {
    try {
      List<DailySchedule> schedules = [];

      if (aiResponse['schedules'] != null) {
        for (var scheduleData in aiResponse['schedules']) {
          List<TimeBlock> timeBlocks = [];

          if (scheduleData['time_blocks'] != null) {
            for (var blockData in scheduleData['time_blocks']) {
              DateTime date = DateTime.parse(scheduleData['date']);
              List<String> startParts = blockData['start_time'].split(':');
              List<String> endParts = blockData['end_time'].split(':');

              DateTime startTime = DateTime(
                date.year,
                date.month,
                date.day,
                int.parse(startParts[0]),
                int.parse(startParts[1]),
              );

              DateTime endTime = DateTime(
                date.year,
                date.month,
                date.day,
                int.parse(endParts[0]),
                int.parse(endParts[1]),
              );

              timeBlocks.add(
                TimeBlock(
                  startTime: startTime,
                  endTime: endTime,
                  taskId: blockData['task_id'],
                  priorityQuadrant:
                      PriorityQuadrant.values[blockData['priority_quadrant'] -
                          1],
                  reasoning: blockData['reasoning'] ?? '',
                  createdAt: DateTime.now(),
                ),
              );
            }
          }

          schedules.add(
            DailySchedule(
              date: DateTime.parse(scheduleData['date']),
              timeBlocks: timeBlocks,
              isAiGenerated: true,
              totalScheduledHours: timeBlocks.fold(
                0.0,
                (sum, block) => sum + (block.durationInMinutes / 60.0),
              ),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
        }
      }

      List<String> recommendations = [];
      if (aiResponse['general_recommendations'] != null) {
        recommendations = List<String>.from(
          aiResponse['general_recommendations'],
        );
      }

      double confidence = (aiResponse['confidence'] ?? 0.8).toDouble();

      return SchedulingResponse(
        schedules: schedules,
        generalRecommendations: recommendations,
        confidence: confidence,
        generatedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('AI 응답 파싱 오류: $e');
      throw Exception('AI 응답을 파싱하는 중 오류가 발생했습니다: $e');
    }
  }

  /// AI 실패 시 기본 스케줄링 생성
  SchedulingResponse _generateFallbackSchedule(
    List<Task> tasks,
    UserPreferences userPreferences,
    DateTime startDate,
    int daysToSchedule,
  ) {
    List<DailySchedule> schedules = [];

    // 작업들을 우선순위 점수로 정렬
    List<Task> sortedTasks = List.from(tasks);
    sortedTasks.sort(
      (a, b) =>
          b.calculatePriorityScore().compareTo(a.calculatePriorityScore()),
    );

    // 간단한 기본 스케줄링 로직
    for (int day = 0; day < daysToSchedule; day++) {
      DateTime currentDate = startDate.add(Duration(days: day));
      List<TimeBlock> timeBlocks = [];

      // 하루에 최대 4개 작업만 배치 (기본값)
      int tasksPerDay = (userPreferences.dailyTaskLimit / 2).round();
      int taskIndex = day * tasksPerDay;

      List<String> startParts = userPreferences.workingHoursStart.split(':');
      int currentHour = int.parse(startParts[0]);
      int currentMinute = int.parse(startParts[1]);

      for (
        int i = 0;
        i < tasksPerDay && taskIndex + i < sortedTasks.length;
        i++
      ) {
        Task task = sortedTasks[taskIndex + i];

        DateTime startTime = DateTime(
          currentDate.year,
          currentDate.month,
          currentDate.day,
          currentHour,
          currentMinute,
        );

        DateTime endTime = startTime.add(
          Duration(minutes: task.estimatedDuration),
        );

        timeBlocks.add(
          TimeBlock(
            startTime: startTime,
            endTime: endTime,
            taskId: task.id!,
            taskTitle: task.title,
            priorityQuadrant: task.calculatePriorityQuadrant(),
            reasoning: '기본 스케줄링: ${task.priorityQuadrantDescription}',
            createdAt: DateTime.now(),
          ),
        );

        // 다음 작업을 위해 시간 업데이트 (30분 여유 추가)
        DateTime nextStart = endTime.add(const Duration(minutes: 30));
        currentHour = nextStart.hour;
        currentMinute = nextStart.minute;
      }

      schedules.add(
        DailySchedule(
          date: currentDate,
          timeBlocks: timeBlocks,
          aiRecommendations: ['AI 스케줄링을 사용할 수 없어 기본 스케줄링을 적용했습니다.'],
          isAiGenerated: false,
          totalScheduledHours: timeBlocks.fold(
            0.0,
            (sum, block) => sum + (block.durationInMinutes / 60.0),
          ),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    }

    return SchedulingResponse(
      schedules: schedules,
      generalRecommendations: [
        'AI 스케줄링 서비스에 일시적인 문제가 있어 기본 스케줄링을 적용했습니다.',
        '나중에 다시 AI 스케줄링을 시도해보세요.',
        '작업의 우선순위와 마감일을 고려하여 수동으로 조정하세요.',
      ],
      confidence: 0.6,
      generatedAt: DateTime.now(),
    );
  }

  /// 단일 작업에 대한 AI 분석 및 추천
  Future<Map<String, String>> getTaskRecommendations(Task task) async {
    try {
      String prompt = '''
다음 작업에 대해 분석하고 추천사항을 제공해주세요:

작업: ${task.title}
${task.description != null ? '설명: ${task.description}' : ''}
중요도: ${task.importanceLevel}/10
긴급도: ${task.urgencyLevel}/10
예상 소요시간: ${task.estimatedDuration}분
카테고리: ${task.categoryDisplayName}
${task.deadline != null ? '마감일: ${task.deadline!.toIso8601String().split('T')[0]}' : ''}

다음 JSON 형식으로 응답해주세요:
{
  "priority_analysis": "우선순위 분석",
  "time_recommendation": "시간 관리 추천",
  "approach_suggestion": "접근 방법 제안"
}

모든 내용을 한국어로 작성해주세요.
''';

      Map<String, dynamic> response = await _callOpenAI(prompt);

      return {
        'priority_analysis':
            response['priority_analysis'] ?? '분석 결과를 불러올 수 없습니다.',
        'time_recommendation':
            response['time_recommendation'] ?? '추천사항을 불러올 수 없습니다.',
        'approach_suggestion':
            response['approach_suggestion'] ?? '제안사항을 불러올 수 없습니다.',
      };
    } catch (e) {
      debugPrint('작업 추천 분석 실패: $e');
      return {
        'priority_analysis': '현재 AI 분석을 사용할 수 없습니다.',
        'time_recommendation': '나중에 다시 시도해주세요.',
        'approach_suggestion': '수동으로 작업을 계획해보세요.',
      };
    }
  }

  /// API 연결 상태 확인
  Future<bool> checkAPIConnection() async {
    if (_dio == null) {
      debugPrint('API 연결 확인 실패: Dio가 초기화되지 않았습니다.');
      return false;
    }

    try {
      final response = await _dio!.get('/models');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('API 연결 확인 실패: $e');
      return false;
    }
  }
}
