import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/task_model.dart';
import '../services/database_service.dart';
import '../services/ai_scheduler_service.dart';
import '../main.dart';

class TodayTasksScreen extends StatefulWidget {
  const TodayTasksScreen({super.key});

  @override
  State<TodayTasksScreen> createState() => _TodayTasksScreenState();
}

class _TodayTasksScreenState extends State<TodayTasksScreen> {
  List<Task> _todayTasks = [];
  List<Task> _allTasks = [];
  bool _isLoading = false;
  bool _isAiScheduling = false;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 오늘 날짜의 작업들 로드
      DateTime today = DateTime.now();
      List<Task> todayTasks = await DatabaseService().getTasksByDate(today);
      List<Task> allTasks = await DatabaseService().getIncompleteTasks();

      setState(() {
        _todayTasks = todayTasks;
        _allTasks = allTasks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('작업을 불러오는 중 오류가 발생했습니다: $e')));
      }
    }
  }

  Future<void> _scheduleWithAI() async {
    final userPreferences = context.read<AppState>().userPreferences;
    if (userPreferences == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('사용자 설정을 먼저 완료해주세요.')));
      return;
    }

    setState(() {
      _isAiScheduling = true;
    });

    try {
      List<Task> incompleteTasks = await DatabaseService().getIncompleteTasks();

      if (incompleteTasks.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('스케줄링할 작업이 없습니다.')));
        }
        setState(() {
          _isAiScheduling = false;
        });
        return;
      }

      final response = await AISchedulerService().scheduleTasksWithAI(
        tasks: incompleteTasks,
        userPreferences: userPreferences,
        startDate: DateTime.now(),
        daysToSchedule: 7,
      );

      // AI 스케줄링 결과를 표시
      if (mounted) {
        _showSchedulingResults(response);
      }

      // 작업 목록 새로고침
      await _loadTasks();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('AI 스케줄링 중 오류가 발생했습니다: $e')));
      }
    } finally {
      setState(() {
        _isAiScheduling = false;
      });
    }
  }

  void _showSchedulingResults(dynamic response) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('🤖 AI 스케줄링 완료'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('✅ ${response.schedules.length}일간의 스케줄이 생성되었습니다.'),
                const SizedBox(height: 16),
                if (response.generalRecommendations.isNotEmpty) ...[
                  const Text(
                    '💡 AI 추천사항:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...response.generalRecommendations.map(
                    (rec) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $rec'),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text('신뢰도: ${(response.confidence * 100).toInt()}%'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final dateFormat = DateFormat('M월 d일 EEEE', 'ko_KR');

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text('오늘 할 일'),
            Text(
              dateFormat.format(now),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          if (_allTasks.isNotEmpty)
            IconButton(
              icon:
                  _isAiScheduling
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.auto_awesome),
              onPressed: _isAiScheduling ? null : _scheduleWithAI,
              tooltip: 'AI 자동 스케줄링',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTasks,
            tooltip: '새로고침',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _loadTasks,
                child:
                    _todayTasks.isEmpty
                        ? _buildEmptyState()
                        : ListView(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          children: [
                            _buildGreetingCard(),
                            const SizedBox(height: 16),
                            const Center(
                              child: Text(
                                '오늘 할 일 목록',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 80), // FAB을 위한 여백
                          ],
                        ),
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: 작업 추가 화면으로 이동
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('작업 추가 기능은 곧 추가됩니다!')));
        },
        tooltip: '새 작업 추가',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildGreetingCard() {
    final userPreferences = context.watch<AppState>().userPreferences;
    final userName = userPreferences?.userName ?? '사용자';
    final completedCount = _todayTasks.where((task) => task.isCompleted).length;
    final totalCount = _todayTasks.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getGreetingMessage(userName),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (totalCount > 0) ...[
                    Text(
                      '오늘 $totalCount개 중 $completedCount개 완료',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: totalCount > 0 ? completedCount / totalCount : 0,
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ] else ...[
                    Text(
                      '오늘 계획된 작업이 없습니다',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.emoji_emotions, size: 40, color: Colors.amber),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.task_alt,
            size: 80,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            '오늘 할 일이 없습니다',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            '새로운 작업을 추가하거나\nAI 스케줄링을 사용해보세요',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          if (_allTasks.isNotEmpty)
            ElevatedButton.icon(
              onPressed: _scheduleWithAI,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('AI 자동 스케줄링'),
            ),
        ],
      ),
    );
  }

  String _getGreetingMessage(String userName) {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return '좋은 아침이에요, $userName님! 🌅';
    } else if (hour < 18) {
      return '좋은 오후에요, $userName님! ☀️';
    } else {
      return '좋은 저녁이에요, $userName님! 🌙';
    }
  }
}
