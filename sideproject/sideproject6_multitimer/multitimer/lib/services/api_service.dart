import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sharetime/models/timer_model.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:8000'; // Python FastAPI 서버 주소

  // 타이머 생성
  static Future<Map<String, dynamic>> createTimer({
    required String name,
    required String description,
    required int totalSeconds,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/timers'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': name,
          'description': description,
          'total_seconds': totalSeconds,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to create timer: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // 타이머 조회
  static Future<TimerModel> getTimer(String timerId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/timers/$timerId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return TimerModel.fromJson(data);
      } else {
        throw Exception('Failed to get timer: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // 타이머 업데이트
  static Future<void> updateTimer(String timerId, int remainingSeconds) async {
    try {
      await http.put(
        Uri.parse('$baseUrl/timers/$timerId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'remaining_seconds': remainingSeconds,
        }),
      );
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // 타이머 삭제
  static Future<void> deleteTimer(String timerId) async {
    try {
      await http.delete(
        Uri.parse('$baseUrl/timers/$timerId'),
      );
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
} 