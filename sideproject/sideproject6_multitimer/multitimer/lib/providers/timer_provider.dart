import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sharetime/models/timer_model.dart';
import 'package:sharetime/services/api_service.dart';

class TimerProvider with ChangeNotifier {
  TimerModel? _currentTimer;
  Timer? _timer;
  bool _isLoading = false;
  String? _error;

  TimerModel? get currentTimer => _currentTimer;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasActiveTimer => _currentTimer != null && _currentTimer!.isActive;

  // 타이머 생성
  Future<bool> createTimer({
    required String name,
    required String description,
    required int totalSeconds,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await ApiService.createTimer(
        name: name,
        description: description,
        totalSeconds: totalSeconds,
      );

      _currentTimer = TimerModel(
        id: result['id'],
        name: name,
        description: description,
        totalSeconds: totalSeconds,
        createdAt: DateTime.now(),
        remainingSeconds: totalSeconds,
      );

      _startTimer();
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // 타이머 조인
  Future<bool> joinTimer(String timerId) async {
    _setLoading(true);
    _clearError();

    try {
      _currentTimer = await ApiService.getTimer(timerId);
      _startTimer();
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // 타이머 시작
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentTimer != null && _currentTimer!.isActive) {
        if (_currentTimer!.remainingSeconds > 0) {
          _currentTimer!.remainingSeconds--;
          notifyListeners();
        } else {
          _currentTimer!.isActive = false;
          timer.cancel();
          notifyListeners();
        }
      }
    });
  }

  // 타이머 일시정지/재시작
  void toggleTimer() {
    if (_currentTimer != null) {
      _currentTimer!.isActive = !_currentTimer!.isActive;
      if (_currentTimer!.isActive) {
        _startTimer();
      } else {
        _timer?.cancel();
      }
      notifyListeners();
    }
  }

  // 타이머 리셋
  void resetTimer() {
    if (_currentTimer != null) {
      _currentTimer!.remainingSeconds = _currentTimer!.totalSeconds;
      _currentTimer!.isActive = true;
      _startTimer();
      notifyListeners();
    }
  }

  // 타이머 정리
  void clearTimer() {
    _timer?.cancel();
    _currentTimer = null;
    _clearError();
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
} 