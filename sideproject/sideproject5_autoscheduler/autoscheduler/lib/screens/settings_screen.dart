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
    super.dispose();
  }

  Future<void> _loadUserPreferences() async {
    final appState = context.read<AppState>();
    if (appState.userPreferences != null) {
      _nameController.text = appState.userPreferences!.userName;
    }
  }

  Future<void> _checkAPIConnection() async {
    try {
      bool status = await AISchedulerService().checkAPIConnection();
      setState(() {
        _apiConnectionStatus = status;
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
        updatedAt: DateTime.now(),
      );

      await DatabaseService().updateUserPreferences(updatedPrefs);
      appState.updateUserPreferences(updatedPrefs);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('설정이 저장되었습니다.')));
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _updateUserPreferences,
            tooltip: '설정 저장',
          ),
        ],
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          final userPrefs = appState.userPreferences;

          if (userPrefs == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildProfileSection(userPrefs),
              const SizedBox(height: 16),
              _buildWorkingHoursSection(userPrefs, appState),
              const SizedBox(height: 16),
              _buildProductivitySection(userPrefs, appState),
              const SizedBox(height: 16),
              _buildAppearanceSection(userPrefs, appState),
              const SizedBox(height: 16),
              _buildNotificationSection(userPrefs, appState),
              const SizedBox(height: 16),
              _buildAISection(),
              const SizedBox(height: 16),
              _buildDataSection(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProfileSection(UserPreferences userPrefs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.person,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '프로필',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '이름',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.account_circle),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkingHoursSection(
    UserPreferences userPrefs,
    AppState appState,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '근무 시간',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: const Text('시작 시간'),
                    subtitle: Text(userPrefs.workingHoursStart),
                    trailing: const Icon(Icons.access_time),
                    onTap:
                        () => _selectTime(
                          context,
                          userPrefs.workingHoursStart,
                          (newTime) => _updateWorkingHours(
                            appState,
                            newTime,
                            userPrefs.workingHoursEnd,
                          ),
                        ),
                  ),
                ),
                Expanded(
                  child: ListTile(
                    title: const Text('종료 시간'),
                    subtitle: Text(userPrefs.workingHoursEnd),
                    trailing: const Icon(Icons.access_time),
                    onTap:
                        () => _selectTime(
                          context,
                          userPrefs.workingHoursEnd,
                          (newTime) => _updateWorkingHours(
                            appState,
                            userPrefs.workingHoursStart,
                            newTime,
                          ),
                        ),
                  ),
                ),
              ],
            ),
            ListTile(
              title: const Text('하루 사용 가능 시간'),
              subtitle: Text('${userPrefs.availableHoursPerDay}시간'),
              trailing: SizedBox(
                width: 100,
                child: Slider(
                  value: userPrefs.availableHoursPerDay.toDouble(),
                  min: 1,
                  max: 16,
                  divisions: 15,
                  label: '${userPrefs.availableHoursPerDay}시간',
                  onChanged:
                      (value) => _updateAvailableHours(appState, value.round()),
                ),
              ),
            ),
            ListTile(
              title: const Text('하루 최대 작업 수'),
              subtitle: Text('${userPrefs.dailyTaskLimit}개'),
              trailing: SizedBox(
                width: 100,
                child: Slider(
                  value: userPrefs.dailyTaskLimit.toDouble(),
                  min: 1,
                  max: 20,
                  divisions: 19,
                  label: '${userPrefs.dailyTaskLimit}개',
                  onChanged:
                      (value) => _updateTaskLimit(appState, value.round()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductivitySection(
    UserPreferences userPrefs,
    AppState appState,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.trending_up,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '생산성 설정',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('생산성 피크 시간'),
              subtitle: Text(userPrefs.productivityPeakDisplayName),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => _showProductivityPeakDialog(appState),
            ),
            SwitchListTile(
              title: const Text('AI 자동 스케줄링'),
              subtitle: const Text('작업들을 AI가 자동으로 최적 시간에 배치'),
              value: userPrefs.autoScheduling,
              onChanged: (value) => _updateAutoScheduling(appState, value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppearanceSection(UserPreferences userPrefs, AppState appState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.palette,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '모양',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('다크 모드'),
              subtitle: const Text('어두운 테마 사용'),
              value: userPrefs.darkMode,
              onChanged: (value) => _updateDarkMode(appState, value),
              secondary: Icon(
                userPrefs.darkMode ? Icons.dark_mode : Icons.light_mode,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSection(
    UserPreferences userPrefs,
    AppState appState,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.notifications,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '알림',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('알림 사용'),
              subtitle: const Text('작업 시작 전 알림 받기'),
              value: userPrefs.notificationsEnabled,
              onChanged: (value) => _updateNotifications(appState, value),
            ),
            if (userPrefs.notificationsEnabled)
              ListTile(
                title: const Text('알림 시간'),
                subtitle: Text('작업 시작 ${userPrefs.reminderMinutesBefore}분 전'),
                trailing: SizedBox(
                  width: 100,
                  child: Slider(
                    value: userPrefs.reminderMinutesBefore.toDouble(),
                    min: 5,
                    max: 60,
                    divisions: 11,
                    label: '${userPrefs.reminderMinutesBefore}분',
                    onChanged:
                        (value) => _updateReminderTime(appState, value.round()),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAISection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'AI 설정',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('API 연결 상태'),
              subtitle: Text(_apiConnectionStatus ? '연결됨' : '연결 실패'),
              trailing: Icon(
                _apiConnectionStatus ? Icons.check_circle : Icons.error,
                color: _apiConnectionStatus ? Colors.green : Colors.red,
              ),
              onTap: _checkAPIConnection,
            ),
            ListTile(
              title: const Text('연결 테스트'),
              subtitle: const Text('OpenAI API 연결 상태 확인'),
              trailing: const Icon(Icons.wifi_protected_setup),
              onTap: _checkAPIConnection,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.storage,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '데이터 관리',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('데이터 초기화'),
              subtitle: const Text('모든 작업과 일정 데이터 삭제 (설정 제외)'),
              trailing: const Icon(Icons.delete_forever, color: Colors.red),
              onTap: _showClearDataDialog,
            ),
            ListTile(
              title: const Text('앱 정보'),
              subtitle: const Text('버전 정보 및 라이선스'),
              trailing: const Icon(Icons.info),
              onTap: _showAboutDialog,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectTime(
    BuildContext context,
    String currentTime,
    Function(String) onTimeSelected,
  ) async {
    List<String> timeParts = currentTime.split(':');
    TimeOfDay initialTime = TimeOfDay(
      hour: int.parse(timeParts[0]),
      minute: int.parse(timeParts[1]),
    );

    final TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (selectedTime != null) {
      String formattedTime =
          '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
      onTimeSelected(formattedTime);
    }
  }

  void _updateWorkingHours(
    AppState appState,
    String startTime,
    String endTime,
  ) async {
    final userPrefs = appState.userPreferences;
    if (userPrefs == null) return;

    UserPreferences updatedPrefs = userPrefs.copyWith(
      workingHoursStart: startTime,
      workingHoursEnd: endTime,
      updatedAt: DateTime.now(),
    );

    await DatabaseService().updateUserPreferences(updatedPrefs);
    appState.updateUserPreferences(updatedPrefs);
  }

  void _updateAvailableHours(AppState appState, int hours) async {
    final userPrefs = appState.userPreferences;
    if (userPrefs == null) return;

    UserPreferences updatedPrefs = userPrefs.copyWith(
      availableHoursPerDay: hours,
      updatedAt: DateTime.now(),
    );

    await DatabaseService().updateUserPreferences(updatedPrefs);
    appState.updateUserPreferences(updatedPrefs);
  }

  void _updateTaskLimit(AppState appState, int limit) async {
    final userPrefs = appState.userPreferences;
    if (userPrefs == null) return;

    UserPreferences updatedPrefs = userPrefs.copyWith(
      dailyTaskLimit: limit,
      updatedAt: DateTime.now(),
    );

    await DatabaseService().updateUserPreferences(updatedPrefs);
    appState.updateUserPreferences(updatedPrefs);
  }

  void _updateDarkMode(AppState appState, bool darkMode) async {
    final userPrefs = appState.userPreferences;
    if (userPrefs == null) return;

    UserPreferences updatedPrefs = userPrefs.copyWith(
      darkMode: darkMode,
      updatedAt: DateTime.now(),
    );

    await DatabaseService().updateUserPreferences(updatedPrefs);
    appState.updateUserPreferences(updatedPrefs);
  }

  void _updateAutoScheduling(AppState appState, bool autoScheduling) async {
    final userPrefs = appState.userPreferences;
    if (userPrefs == null) return;

    UserPreferences updatedPrefs = userPrefs.copyWith(
      autoScheduling: autoScheduling,
      updatedAt: DateTime.now(),
    );

    await DatabaseService().updateUserPreferences(updatedPrefs);
    appState.updateUserPreferences(updatedPrefs);
  }

  void _updateNotifications(AppState appState, bool enabled) async {
    final userPrefs = appState.userPreferences;
    if (userPrefs == null) return;

    UserPreferences updatedPrefs = userPrefs.copyWith(
      notificationsEnabled: enabled,
      updatedAt: DateTime.now(),
    );

    await DatabaseService().updateUserPreferences(updatedPrefs);
    appState.updateUserPreferences(updatedPrefs);
  }

  void _updateReminderTime(AppState appState, int minutes) async {
    final userPrefs = appState.userPreferences;
    if (userPrefs == null) return;

    UserPreferences updatedPrefs = userPrefs.copyWith(
      reminderMinutesBefore: minutes,
      updatedAt: DateTime.now(),
    );

    await DatabaseService().updateUserPreferences(updatedPrefs);
    appState.updateUserPreferences(updatedPrefs);
  }

  void _showProductivityPeakDialog(AppState appState) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('생산성 피크 시간'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children:
                ProductivityPeak.values.map((peak) {
                  return RadioListTile<ProductivityPeak>(
                    title: Text(_getProductivityPeakName(peak)),
                    value: peak,
                    groupValue: appState.userPreferences?.productivityPeak,
                    onChanged: (value) {
                      Navigator.of(context).pop();
                      if (value != null) {
                        _updateProductivityPeak(appState, value);
                      }
                    },
                  );
                }).toList(),
          ),
        );
      },
    );
  }

  String _getProductivityPeakName(ProductivityPeak peak) {
    switch (peak) {
      case ProductivityPeak.morning:
        return '오전형 (아침에 집중력이 좋음)';
      case ProductivityPeak.afternoon:
        return '오후형 (오후에 집중력이 좋음)';
      case ProductivityPeak.evening:
        return '저녁형 (저녁에 집중력이 좋음)';
      case ProductivityPeak.allDay:
        return '하루종일 (시간대 상관없음)';
    }
  }

  void _updateProductivityPeak(AppState appState, ProductivityPeak peak) async {
    final userPrefs = appState.userPreferences;
    if (userPrefs == null) return;

    UserPreferences updatedPrefs = userPrefs.copyWith(
      productivityPeak: peak,
      updatedAt: DateTime.now(),
    );

    await DatabaseService().updateUserPreferences(updatedPrefs);
    appState.updateUserPreferences(updatedPrefs);
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('⚠️ 데이터 초기화'),
          content: const Text(
            '모든 작업과 일정 데이터가 영구적으로 삭제됩니다.\n'
            '이 작업은 되돌릴 수 없습니다.\n\n'
            '정말로 진행하시겠습니까?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                navigator.pop();
                try {
                  await DatabaseService().clearAllData();
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(content: Text('데이터가 초기화되었습니다.')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(content: Text('데이터 초기화 중 오류가 발생했습니다: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'AI 스마트 일정 관리',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.auto_awesome, size: 48),
      children: [
        const Text('Eisenhower Matrix 기반 AI 자동 스케줄링 앱'),
        const SizedBox(height: 16),
        const Text('• OpenAI GPT-4o mini 사용'),
        const Text('• 우선순위 기반 작업 관리'),
        const Text('• 지능형 시간 배분'),
        const Text('• 개인 맞춤 생산성 최적화'),
      ],
    );
  }
}
