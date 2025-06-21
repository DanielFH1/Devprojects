import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import '../models/task_model.dart';
import '../services/database_service.dart';
import '../main.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late final ValueNotifier<List<Task>> _selectedEvents;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Task>> _events = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));
    _loadEvents();
  }

  @override
  void dispose() {
    _selectedEvents.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 이번 달과 다음 달의 모든 작업 로드
      DateTime startOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
      DateTime endOfMonth = DateTime(
        _focusedDay.year,
        _focusedDay.month + 2,
        0,
      );

      List<Task> allTasks = await DatabaseService().getAllTasks();

      // 날짜별로 작업들을 그룹화
      Map<DateTime, List<Task>> events = {};

      for (Task task in allTasks) {
        DateTime? eventDate;

        if (task.scheduledDate != null) {
          eventDate = DateTime(
            task.scheduledDate!.year,
            task.scheduledDate!.month,
            task.scheduledDate!.day,
          );
        } else if (task.deadline != null) {
          eventDate = DateTime(
            task.deadline!.year,
            task.deadline!.month,
            task.deadline!.day,
          );
        }

        if (eventDate != null &&
            eventDate.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
            eventDate.isBefore(endOfMonth.add(const Duration(days: 1)))) {
          if (events[eventDate] != null) {
            events[eventDate]!.add(task);
          } else {
            events[eventDate] = [task];
          }
        }
      }

      setState(() {
        _events = events;
        _isLoading = false;
      });

      // 선택된 날짜의 이벤트 업데이트
      _selectedEvents.value = _getEventsForDay(_selectedDay!);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('일정을 불러오는 중 오류가 발생했습니다: $e')));
      }
    }
  }

  List<Task> _getEventsForDay(DateTime day) {
    DateTime dateKey = DateTime(day.year, day.month, day.day);
    return _events[dateKey] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });

      _selectedEvents.value = _getEventsForDay(selectedDay);
      context.read<AppState>().setSelectedDate(selectedDay);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('캘린더'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime.now();
                _selectedDay = DateTime.now();
              });
              _selectedEvents.value = _getEventsForDay(DateTime.now());
              context.read<AppState>().setSelectedDate(DateTime.now());
            },
            tooltip: '오늘로 이동',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEvents,
            tooltip: '새로고침',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  Card(
                    margin: const EdgeInsets.all(8),
                    child: TableCalendar<Task>(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      calendarFormat: _calendarFormat,
                      eventLoader: _getEventsForDay,
                      startingDayOfWeek: StartingDayOfWeek.monday,
                      locale: 'ko_KR',

                      // 스타일 설정
                      calendarStyle: CalendarStyle(
                        outsideDaysVisible: false,
                        weekendTextStyle: TextStyle(color: Colors.red[400]),
                        holidayTextStyle: TextStyle(color: Colors.red[400]),
                        selectedDecoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        todayDecoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        markerDecoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary,
                          shape: BoxShape.circle,
                        ),
                        markersMaxCount: 3,
                      ),

                      headerStyle: HeaderStyle(
                        formatButtonVisible: true,
                        titleCentered: true,
                        formatButtonShowsNext: false,
                        formatButtonDecoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        formatButtonTextStyle: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),

                      selectedDayPredicate: (day) {
                        return isSameDay(_selectedDay, day);
                      },

                      onDaySelected: _onDaySelected,

                      onFormatChanged: (format) {
                        if (_calendarFormat != format) {
                          setState(() {
                            _calendarFormat = format;
                          });
                        }
                      },

                      onPageChanged: (focusedDay) {
                        _focusedDay = focusedDay;
                        _loadEvents(); // 새 달로 이동할 때 이벤트 다시 로드
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ValueListenableBuilder<List<Task>>(
                      valueListenable: _selectedEvents,
                      builder: (context, value, _) {
                        return _buildEventsList(value);
                      },
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildEventsList(List<Task> events) {
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              '선택한 날짜에 일정이 없습니다',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final task = events[index];
        return _buildTaskCard(task);
      },
    );
  }

  Widget _buildTaskCard(Task task) {
    Color priorityColor = _getPriorityColor(task.calculatePriorityQuadrant());

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Container(
          width: 4,
          height: double.infinity,
          decoration: BoxDecoration(
            color: priorityColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
            color:
                task.isCompleted
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.description != null && task.description!.isNotEmpty) ...[
              Text(
                task.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
            ],
            Row(
              children: [
                Icon(
                  _getPriorityIcon(task.calculatePriorityQuadrant()),
                  size: 16,
                  color: priorityColor,
                ),
                const SizedBox(width: 4),
                Text(
                  task.priorityQuadrantDescription,
                  style: TextStyle(
                    fontSize: 12,
                    color: priorityColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (task.estimatedDuration > 0) ...[
                  Icon(
                    Icons.schedule,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${task.estimatedDuration}분',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing:
            task.isCompleted
                ? Icon(Icons.check_circle, color: Colors.green[600])
                : IconButton(
                  icon: const Icon(Icons.check_circle_outline),
                  onPressed: () => _toggleTaskCompletion(task),
                  tooltip: '완료 표시',
                ),
        onTap: () {
          // TODO: 작업 상세 보기 또는 편집
          _showTaskDetails(task);
        },
      ),
    );
  }

  void _showTaskDetails(Task task) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(task.title),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (task.description != null &&
                    task.description!.isNotEmpty) ...[
                  const Text(
                    '📝 설명:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(task.description!),
                  const SizedBox(height: 12),
                ],
                Text('📊 우선순위: ${task.priorityQuadrantDescription}'),
                Text('⏱️ 예상 소요시간: ${task.estimatedDuration}분'),
                Text('📁 카테고리: ${task.categoryDisplayName}'),
                Text('✅ 진행률: ${task.completionPercentage}%'),
                if (task.deadline != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '📅 마감일: ${task.deadline!.toLocal().toString().split(' ')[0]}',
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('닫기'),
            ),
            if (!task.isCompleted)
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _toggleTaskCompletion(task);
                },
                child: const Text('완료'),
              ),
          ],
        );
      },
    );
  }

  Future<void> _toggleTaskCompletion(Task task) async {
    try {
      bool newCompletionStatus = !task.isCompleted;
      await DatabaseService().toggleTaskCompletion(
        task.id!,
        newCompletionStatus,
      );
      await _loadEvents();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newCompletionStatus ? '작업이 완료되었습니다! 🎉' : '작업이 미완료로 변경되었습니다.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('작업 상태 변경 중 오류가 발생했습니다: $e')));
      }
    }
  }

  Color _getPriorityColor(PriorityQuadrant quadrant) {
    switch (quadrant) {
      case PriorityQuadrant.urgentImportant:
        return Colors.red;
      case PriorityQuadrant.notUrgentImportant:
        return Colors.blue;
      case PriorityQuadrant.urgentNotImportant:
        return Colors.orange;
      case PriorityQuadrant.notUrgentNotImportant:
        return Colors.grey;
    }
  }

  IconData _getPriorityIcon(PriorityQuadrant quadrant) {
    switch (quadrant) {
      case PriorityQuadrant.urgentImportant:
        return Icons.warning;
      case PriorityQuadrant.notUrgentImportant:
        return Icons.star;
      case PriorityQuadrant.urgentNotImportant:
        return Icons.flash_on;
      case PriorityQuadrant.notUrgentNotImportant:
        return Icons.list;
    }
  }
}
