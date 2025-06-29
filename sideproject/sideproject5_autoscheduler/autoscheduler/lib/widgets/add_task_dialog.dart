import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/task_model.dart';

class AddTaskDialog extends StatefulWidget {
  final Function(Task) onTaskAdded;

  const AddTaskDialog({super.key, required this.onTaskAdded});

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _additionalInfoController = TextEditingController();

  int _importance = 5;
  int _urgency = 5;
  DateTime? _deadline;
  TaskCategory _category = TaskCategory.personal;
  int _estimatedDuration = 60; // 기본 1시간

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _additionalInfoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.add_task,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '새로운 할 일 추가',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 할일 이름
                      _buildSectionTitle('할 일 이름 *'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          hintText: '무엇을 해야 하나요?',
                          prefixIcon: const Icon(Icons.title),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '할 일 이름을 입력해주세요';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // 중요도
                      _buildSectionTitle('중요도'),
                      const SizedBox(height: 8),
                      _buildSliderCard(
                        value: _importance,
                        onChanged:
                            (value) => setState(() => _importance = value),
                        icon: Icons.star,
                        color: Colors.amber,
                        label: '중요도',
                        minLabel: '1 (중요하지 않음)',
                        maxLabel: '10 (매우 중요)',
                      ),
                      const SizedBox(height: 20),

                      // 긴급도
                      _buildSectionTitle('긴급도'),
                      const SizedBox(height: 8),
                      _buildSliderCard(
                        value: _urgency,
                        onChanged: (value) => setState(() => _urgency = value),
                        icon: Icons.access_time,
                        color: Colors.red,
                        label: '긴급도',
                        minLabel: '1 (급하지 않음)',
                        maxLabel: '10 (매우 급함)',
                      ),
                      const SizedBox(height: 24),

                      // 카테고리
                      _buildSectionTitle('카테고리'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<TaskCategory>(
                        value: _category,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.category),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest,
                        ),
                        items:
                            TaskCategory.values.map((category) {
                              return DropdownMenuItem(
                                value: category,
                                child: Text(category.displayName),
                              );
                            }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _category = value);
                          }
                        },
                      ),
                      const SizedBox(height: 20),

                      // 예상 시간
                      _buildSectionTitle('예상 시간 (분)'),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: _estimatedDuration.toString(),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.timer),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest,
                        ),
                        onChanged: (value) {
                          final duration = int.tryParse(value);
                          if (duration != null && duration > 0) {
                            _estimatedDuration = duration;
                          }
                        },
                      ),
                      const SizedBox(height: 24),

                      // 데드라인
                      _buildSectionTitle('데드라인'),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _selectDeadline(context),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: theme.colorScheme.outline,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: theme.colorScheme.surfaceContainerHighest,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _deadline == null
                                    ? '데드라인 선택 (선택사항)'
                                    : '${_deadline!.year}년 ${_deadline!.month}월 ${_deadline!.day}일',
                                style: TextStyle(
                                  color:
                                      _deadline == null
                                          ? theme.colorScheme.onSurfaceVariant
                                          : theme.colorScheme.onSurface,
                                ),
                              ),
                              const Spacer(),
                              if (_deadline != null)
                                IconButton(
                                  onPressed:
                                      () => setState(() => _deadline = null),
                                  icon: const Icon(Icons.clear),
                                  iconSize: 20,
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // AI를 위한 추가 정보
                      _buildSectionTitle('AI가 알아야 하는 추가 정보 (선택사항)'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _additionalInfoController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: '예: 오전에 집중력이 좋음, 다른 회의와 겹치지 않았으면 함, 등',
                          prefixIcon: const Icon(Icons.psychology),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Buttons
            Container(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _addTask,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('추가하기'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  Widget _buildSliderCard({
    required int value,
    required ValueChanged<int> onChanged,
    required IconData icon,
    required Color color,
    required String label,
    required String minLabel,
    required String maxLabel,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                value.toString(),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  minLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.start,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                child: Text(
                  maxLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Slider(
            value: value.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            onChanged: (newValue) => onChanged(newValue.round()),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDeadline(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            datePickerTheme: DatePickerThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _deadline = picked;
      });
    }
  }

  void _addTask() {
    if (_formKey.currentState!.validate()) {
      final task = Task(
        title: _titleController.text.trim(),
        description:
            _additionalInfoController.text.trim().isEmpty
                ? null
                : _additionalInfoController.text.trim(),
        importanceLevel: _importance,
        urgencyLevel: _urgency,
        deadline: _deadline,
        category: _category,
        estimatedDuration: _estimatedDuration,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        completionPercentage: 0,
      );

      widget.onTaskAdded(task);
      Navigator.of(context).pop();
    }
  }
}
