import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/task_model.dart';
import '../services/database_service.dart';
import '../services/ai_scheduler_service.dart';
import '../widgets/add_task_dialog.dart';
import '../main.dart';

class TodayTasksScreen extends StatefulWidget {
  const TodayTasksScreen({super.key});

  @override
  State<TodayTasksScreen> createState() => _TodayTasksScreenState();
}

class _TodayTasksScreenState extends State<TodayTasksScreen> {
  List<Task> _todayTasks = [];
  List<Task> _allTasks = [];
  List<Task> _pendingTasks = []; // 추가 대기 중인 할일들
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

  Future<void> _addTaskToList(Task task) async {
    setState(() {
      _pendingTasks.add(task);
    });

    // 개별 할일 저장도 가능하도록
    try {
      await DatabaseService().insertTask(task);
      await _loadTasks(); // 목록 새로고침

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 할일이 추가되었습니다!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('할일 추가 중 오류: $e')));
      }
    }
  }

  Future<void> _scheduleWithAI() async {
    final userPreferences = context.read<AppState>().userPreferences;
    if (userPreferences == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('설정 탭에서 사용자 설정을 먼저 완료해주세요.')),
      );
      return;
    }

    setState(() {
      _isAiScheduling = true;
    });

    try {
      // 대기 중인 할일들과 기존 미완료 할일들을 합쳐서 AI 스케줄링
      List<Task> tasksToSchedule = [..._pendingTasks, ..._allTasks];

      if (tasksToSchedule.isEmpty) {
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

      // 대기 중인 할일들을 먼저 데이터베이스에 저장
      for (Task task in _pendingTasks) {
        await DatabaseService().insertTask(task);
      }

      final response = await AISchedulerService().scheduleTasksWithAI(
        tasks: tasksToSchedule,
        userPreferences: userPreferences,
        startDate: DateTime.now(),
        daysToSchedule: 7,
      );

      // 대기 목록 초기화
      setState(() {
        _pendingTasks.clear();
      });

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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.auto_awesome,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              const Text('AI 스케줄링 완료'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${response.schedules.length}일간의 스케줄이 생성되었습니다.',
                        ),
                      ),
                    ],
                  ),
                ),
                if (response.generalRecommendations.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    '💡 AI 추천사항',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...response.generalRecommendations.map(
                    (rec) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('•', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(rec)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.psychology,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text('신뢰도: ${(response.confidence * 100).toInt()}%'),
                    ],
                  ),
                ),
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
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        title: Column(
          children: [
            Text(
              '오늘 할 일',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              dateFormat.format(now),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (_allTasks.isNotEmpty || _pendingTasks.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon:
                    _isAiScheduling
                        ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.primary,
                          ),
                        )
                        : Icon(
                          Icons.auto_awesome,
                          color: theme.colorScheme.primary,
                        ),
                onPressed: _isAiScheduling ? null : _scheduleWithAI,
                tooltip: 'AI 자동 스케줄링',
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                ),
              ),
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
              : RefreshIndicator(onRefresh: _loadTasks, child: _buildBody()),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTaskDialog(),
        tooltip: '새 작업 추가',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (_todayTasks.isEmpty && _pendingTasks.isEmpty) {
      return _buildEmptyState();
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildGreetingCard(),
        const SizedBox(height: 24),

        // 대기 중인 할일들 표시
        if (_pendingTasks.isNotEmpty) ...[
          _buildSectionHeader(
            '추가된 할일 (${_pendingTasks.length})',
            subtitle: 'AI 스케줄링 버튼을 눌러 최적의 시간을 배정받으세요',
            icon: Icons.schedule,
            color: Colors.orange,
          ),
          const SizedBox(height: 16),
          ..._pendingTasks.map((task) => _buildTaskCard(task, isPending: true)),
          const SizedBox(height: 24),

          // AI 스케줄링 버튼
          Container(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isAiScheduling ? null : _scheduleWithAI,
              icon:
                  _isAiScheduling
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.auto_awesome),
              label: Text(
                _isAiScheduling ? 'AI가 스케줄링 중...' : '🤖 AI로 최적의 시간 배정하기',
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor:
                    Theme.of(context).colorScheme.onPrimaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],

        // 오늘 예정된 할일들
        if (_todayTasks.isNotEmpty) ...[
          _buildSectionHeader(
            '오늘 예정된 할일 (${_todayTasks.length})',
            subtitle: '우선순위별로 정리된 오늘의 작업들',
            icon: Icons.today,
            color: Colors.blue,
          ),
          const SizedBox(height: 16),
          ..._buildTasksByPriority(),
        ],

        const SizedBox(height: 100), // FAB을 위한 여백
      ],
    );
  }

  Widget _buildSectionHeader(
    String title, {
    String? subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTasksByPriority() {
    // 우선순위별로 그룹화
    Map<PriorityQuadrant, List<Task>> tasksByPriority = {};
    for (var task in _todayTasks) {
      final quadrant = task.actualPriorityQuadrant;
      if (!tasksByPriority.containsKey(quadrant)) {
        tasksByPriority[quadrant] = [];
      }
      tasksByPriority[quadrant]!.add(task);
    }

    List<Widget> widgets = [];
    for (var quadrant in PriorityQuadrant.values) {
      final tasks = tasksByPriority[quadrant] ?? [];
      if (tasks.isNotEmpty) {
        widgets.add(_buildPrioritySection(quadrant, tasks));
        widgets.add(const SizedBox(height: 16));
      }
    }
    return widgets;
  }

  Widget _buildPrioritySection(PriorityQuadrant quadrant, List<Task> tasks) {
    final (color, icon) = _getPriorityStyle(quadrant);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                quadrant.description,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...tasks.map((task) => _buildTaskCard(task)),
      ],
    );
  }

  (Color, IconData) _getPriorityStyle(PriorityQuadrant quadrant) {
    switch (quadrant) {
      case PriorityQuadrant.urgentImportant:
        return (Colors.red, Icons.warning);
      case PriorityQuadrant.notUrgentImportant:
        return (Colors.blue, Icons.star);
      case PriorityQuadrant.urgentNotImportant:
        return (Colors.orange, Icons.access_time);
      case PriorityQuadrant.notUrgentNotImportant:
        return (Colors.green, Icons.low_priority);
    }
  }

  Widget _buildTaskCard(Task task, {bool isPending = false}) {
    final theme = Theme.of(context);
    final (priorityColor, priorityIcon) = _getPriorityStyle(
      task.actualPriorityQuadrant,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side:
              isPending
                  ? BorderSide(color: Colors.orange.withOpacity(0.5), width: 2)
                  : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration:
                            task.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                      ),
                    ),
                  ),
                  if (isPending)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '대기중',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildInfoChip(
                    icon: priorityIcon,
                    label: task.actualPriorityQuadrant.description,
                    color: priorityColor,
                  ),
                  const SizedBox(width: 8),
                  _buildInfoChip(
                    icon: Icons.category,
                    label: task.categoryDisplayName,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  _buildInfoChip(
                    icon: Icons.timer,
                    label: '${task.estimatedDuration}분',
                    color: Colors.grey[600]!,
                  ),
                ],
              ),
              if (task.deadline != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '마감: ${DateFormat('M/d').format(task.deadline!)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
              if (task.description?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text(
                  task.description!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddTaskDialog() {
    showDialog(
      context: context,
      builder: (context) => AddTaskDialog(onTaskAdded: _addTaskToList),
    );
  }

  Widget _buildGreetingCard() {
    final userPreferences = context.watch<AppState>().userPreferences;
    final userName = userPreferences?.userName ?? '사용자';
    final completedCount = _todayTasks.where((task) => task.isCompleted).length;
    final totalCount = _todayTasks.length;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.primaryContainer.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getGreetingMessage(userName),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (totalCount > 0) ...[
                    Text(
                      '오늘 $totalCount개 중 $completedCount개 완료',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: totalCount > 0 ? completedCount / totalCount : 0,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimaryContainer.withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                        minHeight: 8,
                      ),
                    ),
                  ] else ...[
                    Text(
                      '새로운 할일을 추가해보세요!',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.onPrimaryContainer.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _getGreetingEmoji(),
                style: const TextStyle(fontSize: 32),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.task_alt,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '오늘 할 일이 없습니다',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              '새로운 작업을 추가하거나\nAI 스케줄링을 사용해보세요',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 32),
            if (_allTasks.isNotEmpty)
              ElevatedButton.icon(
                onPressed: _scheduleWithAI,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('AI 자동 스케줄링'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getGreetingMessage(String userName) {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return '좋은 아침이에요, $userName님!';
    } else if (hour < 18) {
      return '좋은 오후에요, $userName님!';
    } else {
      return '좋은 저녁이에요, $userName님!';
    }
  }

  String _getGreetingEmoji() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return '🌅';
    } else if (hour < 18) {
      return '☀️';
    } else {
      return '🌙';
    }
  }
}
