import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_preferences.dart';
import '../services/database_service.dart';
import '../services/ai_scheduler_service.dart';
import '../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameController = TextEditingController();
  final _additionalInfoController = TextEditingController();
  bool _isLoading = false;
  bool _apiConnectionStatus = false;

  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
    _checkAPIConnection();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _additionalInfoController.dispose();
    super.dispose();
  }

  Future<void> _loadUserPreferences() async {
    final appState = context.read<AppState>();
    if (appState.userPreferences != null) {
      _nameController.text = appState.userPreferences!.userName;
      _additionalInfoController.text =
          appState.userPreferences!.additionalInfo ?? '';
    }
  }

  Future<void> _checkAPIConnection() async {
    try {
      await AISchedulerService().initialize();
      setState(() {
        _apiConnectionStatus = true;
      });
    } catch (e) {
      setState(() {
        _apiConnectionStatus = false;
      });
    }
  }

  Future<void> _updateUserPreferences() async {
    final appState = context.read<AppState>();
    final currentPrefs = appState.userPreferences;

    if (currentPrefs == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      UserPreferences updatedPrefs = currentPrefs.copyWith(
        userName:
            _nameController.text.trim().isNotEmpty
                ? _nameController.text.trim()
                : '사용자',
        additionalInfo:
            _additionalInfoController.text.trim().isNotEmpty
                ? _additionalInfoController.text.trim()
                : null,
        updatedAt: DateTime.now(),
      );

      await DatabaseService().updateUserPreferences(updatedPrefs);
      appState.updateUserPreferences(updatedPrefs);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 설정이 저장되었습니다!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('설정 저장 중 오류가 발생했습니다: $e')));
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        title: Text(
          '설정',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon:
                  _isLoading
                      ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.primary,
                        ),
                      )
                      : Icon(Icons.save, color: theme.colorScheme.primary),
              onPressed: _isLoading ? null : _updateUserPreferences,
              tooltip: '설정 저장',
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          final userPrefs = appState.userPreferences;

          if (userPrefs == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildProfileSection(userPrefs),
                const SizedBox(height: 20),
                _buildWorkStyleSection(userPrefs, appState),
                const SizedBox(height: 20),
                _buildWorkingHoursSection(userPrefs, appState),
                const SizedBox(height: 20),
                _buildProductivitySection(userPrefs, appState),
                const SizedBox(height: 20),
                _buildAppearanceSection(userPrefs, appState),
                const SizedBox(height: 20),
                _buildAISection(),
                const SizedBox(height: 20),
                _buildDataSection(),
                const SizedBox(height: 100), // 여백
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final sectionColor = color ?? theme.colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: sectionColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: sectionColor, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: sectionColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection(UserPreferences userPrefs) {
    return _buildSectionCard(
      title: '프로필',
      icon: Icons.person,
      children: [
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: '이름',
            hintText: '어떻게 불러드릴까요?',
            prefixIcon: const Icon(Icons.account_circle),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }

  Widget _buildWorkStyleSection(UserPreferences userPrefs, AppState appState) {
    return _buildSectionCard(
      title: '나의 작업 스타일',
      icon: Icons.psychology,
      color: Colors.purple,
      children: [
        Text(
          '💡 AI가 더 정확한 스케줄링을 위해 알아야 할 정보들',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 16),

        // 생산성 피크 시간
        _buildSubSection(
          '⏰ 집중이 가장 잘 되는 시간대',
          child: _buildProductivityPeakSelector(userPrefs, appState),
        ),
        const SizedBox(height: 20),

        // 추가 정보 입력
        _buildSubSection(
          '✍️ AI가 알아야 하는 추가 정보 (선택사항)',
          child: TextFormField(
            controller: _additionalInfoController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: '''예시:
• 오전에 집중력이 높음
• 회의는 오후에 선호
• 짧은 작업을 먼저 처리하는 것을 좋아함
• 창의적인 작업은 조용한 환경에서
• 반복적인 작업은 음악과 함께''',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 작업 스타일 체크박스들
        _buildWorkStylePreferences(userPrefs, appState),
      ],
    );
  }

  Widget _buildSubSection(String title, {required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildProductivityPeakSelector(
    UserPreferences userPrefs,
    AppState appState,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          ProductivityPeak.values.map((peak) {
            final isSelected = userPrefs.productivityPeak == peak;
            return ChoiceChip(
              label: Text(peak.displayName),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  _updateSinglePreference(
                    appState,
                    userPrefs.copyWith(productivityPeak: peak),
                  );
                }
              },
              selectedColor: Theme.of(context).colorScheme.primaryContainer,
              labelStyle: TextStyle(
                color:
                    isSelected
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onSurface,
              ),
            );
          }).toList(),
    );
  }

  Widget _buildWorkStylePreferences(
    UserPreferences userPrefs,
    AppState appState,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '🎯 작업 선호도',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        _buildPreferenceSlider(
          '🔄 반복 작업 vs 창의적 작업',
          '반복적',
          '창의적',
          userPrefs.creativityPreference.toDouble(),
          (value) => _updateSinglePreference(
            appState,
            userPrefs.copyWith(creativityPreference: value.round()),
          ),
        ),
        const SizedBox(height: 16),
        _buildPreferenceSlider(
          '👥 협업 vs 개인 작업',
          '개인적',
          '협업적',
          userPrefs.collaborationPreference.toDouble(),
          (value) => _updateSinglePreference(
            appState,
            userPrefs.copyWith(collaborationPreference: value.round()),
          ),
        ),
        const SizedBox(height: 16),
        _buildPreferenceSlider(
          '⚡ 짧은 작업 vs 긴 작업',
          '짧은 작업',
          '긴 작업',
          userPrefs.taskLengthPreference.toDouble(),
          (value) => _updateSinglePreference(
            appState,
            userPrefs.copyWith(taskLengthPreference: value.round()),
          ),
        ),
      ],
    );
  }

  Widget _buildPreferenceSlider(
    String title,
    String leftLabel,
    String rightLabel,
    double value,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              leftLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Expanded(
              child: Slider(
                value: value,
                min: 1,
                max: 10,
                divisions: 9,
                onChanged: onChanged,
              ),
            ),
            Text(
              rightLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWorkingHoursSection(
    UserPreferences userPrefs,
    AppState appState,
  ) {
    return _buildSectionCard(
      title: '근무 시간',
      icon: Icons.schedule,
      color: Colors.blue,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTimeSelector(
                '시작 시간',
                userPrefs.workingHoursStart,
                (time) => _updateSinglePreference(
                  appState,
                  userPrefs.copyWith(workingHoursStart: time),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTimeSelector(
                '종료 시간',
                userPrefs.workingHoursEnd,
                (time) => _updateSinglePreference(
                  appState,
                  userPrefs.copyWith(workingHoursEnd: time),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildNumberSelector(
                '하루 사용 가능 시간',
                userPrefs.availableHoursPerDay,
                1,
                16,
                '시간',
                (value) => _updateSinglePreference(
                  appState,
                  userPrefs.copyWith(availableHoursPerDay: value),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildNumberSelector(
                '하루 최대 작업 수',
                userPrefs.dailyTaskLimit,
                1,
                20,
                '개',
                (value) => _updateSinglePreference(
                  appState,
                  userPrefs.copyWith(dailyTaskLimit: value),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeSelector(
    String label,
    String currentTime,
    ValueChanged<String> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _selectTime(currentTime, onChanged),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.access_time,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(currentTime),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNumberSelector(
    String label,
    int currentValue,
    int min,
    int max,
    String unit,
    ValueChanged<int> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed:
                    currentValue > min
                        ? () => onChanged(currentValue - 1)
                        : null,
                icon: const Icon(Icons.remove),
                iconSize: 20,
              ),
              Text(
                '$currentValue$unit',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed:
                    currentValue < max
                        ? () => onChanged(currentValue + 1)
                        : null,
                icon: const Icon(Icons.add),
                iconSize: 20,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProductivitySection(
    UserPreferences userPrefs,
    AppState appState,
  ) {
    return _buildSectionCard(
      title: '생산성 설정',
      icon: Icons.trending_up,
      color: Colors.green,
      children: [
        Text(
          '현재 생산성 피크: ${userPrefs.productivityPeakDisplayName}',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lightbulb, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '생산성 팁',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '• 중요한 작업은 집중력이 높은 시간대에 배치됩니다\n'
                '• 짧은 휴식을 포함한 현실적인 스케줄을 제공합니다\n'
                '• 마감일과 우선순위를 고려한 최적화된 순서를 제안합니다',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAppearanceSection(UserPreferences userPrefs, AppState appState) {
    return _buildSectionCard(
      title: '모양',
      icon: Icons.palette,
      color: Colors.indigo,
      children: [
        SwitchListTile(
          title: const Text('다크 모드'),
          subtitle: const Text('어두운 테마 사용'),
          value: appState.isDarkMode,
          onChanged: (value) {
            appState.toggleDarkMode();
            _updateSinglePreference(
              appState,
              userPrefs.copyWith(isDarkMode: value),
            );
          },
          secondary: Icon(
            appState.isDarkMode ? Icons.dark_mode : Icons.light_mode,
            color: Colors.indigo,
          ),
        ),
      ],
    );
  }

  Widget _buildAISection() {
    return _buildSectionCard(
      title: 'AI 설정',
      icon: Icons.psychology,
      color: Colors.orange,
      children: [
        ListTile(
          leading: Icon(
            _apiConnectionStatus ? Icons.check_circle : Icons.error,
            color: _apiConnectionStatus ? Colors.green : Colors.red,
          ),
          title: Text(_apiConnectionStatus ? 'AI 연결 상태: 정상' : 'AI 연결 상태: 오류'),
          subtitle: Text(
            _apiConnectionStatus
                ? 'o3-mini 모델을 사용하여 스케줄링이 가능합니다.'
                : 'API 키를 확인해주세요.',
          ),
          trailing: IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkAPIConnection,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'AI 스케줄링이란?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '• Eisenhower Matrix를 기반으로 작업의 중요도와 긴급도를 분석\n'
                '• 개인의 생산성 패턴과 선호도를 고려한 최적화\n'
                '• 마감일과 예상 소요시간을 반영한 현실적인 스케줄링',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDataSection() {
    return _buildSectionCard(
      title: '데이터 관리',
      icon: Icons.storage,
      color: Colors.red,
      children: [
        ListTile(
          leading: const Icon(Icons.download, color: Colors.blue),
          title: const Text('데이터 내보내기'),
          subtitle: const Text('작업과 설정을 JSON 파일로 내보내기'),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('데이터 내보내기 기능은 곧 추가됩니다!')),
            );
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.delete_forever, color: Colors.red),
          title: const Text('모든 데이터 삭제'),
          subtitle: const Text('모든 작업과 설정을 삭제합니다'),
          onTap: () => _showDeleteAllDataDialog(),
        ),
      ],
    );
  }

  Future<void> _selectTime(
    String currentTime,
    ValueChanged<String> onChanged,
  ) async {
    final parts = currentTime.split(':');
    final currentHour = int.parse(parts[0]);
    final currentMinute = int.parse(parts[1]);

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: currentHour, minute: currentMinute),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
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
      final formattedTime =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      onChanged(formattedTime);
    }
  }

  Future<void> _updateSinglePreference(
    AppState appState,
    UserPreferences newPrefs,
  ) async {
    try {
      await DatabaseService().updateUserPreferences(newPrefs);
      appState.updateUserPreferences(newPrefs);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('설정 업데이트 중 오류: $e')));
      }
    }
  }

  void _showDeleteAllDataDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.red),
                SizedBox(width: 8),
                Text('모든 데이터 삭제'),
              ],
            ),
            content: const Text(
              '정말로 모든 작업과 설정을 삭제하시겠습니까?\n\n이 작업은 되돌릴 수 없습니다.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('데이터 삭제 기능은 곧 추가됩니다!')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('삭제'),
              ),
            ],
          ),
    );
  }
}
