import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/database_service.dart';
import 'services/ai_scheduler_service.dart';
import 'screens/today_tasks_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/settings_screen.dart';
import 'models/user_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

    // 서비스 초기화 (에러가 발생해도 앱은 계속 실행)
    try {
      await DatabaseService().initialize(); // 데이터베이스 초기화
    } catch (e) {
      debugPrint('데이터베이스 초기화 오류: $e');
    }

    try {
      await AISchedulerService().initialize(); // AI 서비스 초기화
    } catch (e) {
      debugPrint('AI 서비스 초기화 오류: $e');
    }
  } catch (e) {
    debugPrint('초기화 오류: $e');
  }

  runApp(const AutoSchedulerApp());
}

class AutoSchedulerApp extends StatelessWidget {
  const AutoSchedulerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AppState())],
      child: Consumer<AppState>(
        builder: (context, appState, child) {
          return MaterialApp(
            title: 'AI 스마트 일정 관리',
            debugShowCheckedModeBanner: false,
            theme: _buildLightTheme(),
            darkTheme: _buildDarkTheme(),
            themeMode: appState.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: const MainScreen(),
          );
        },
      ),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF007AFF),
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardTheme(
        elevation: 2,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        shape: CircleBorder(),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0A84FF),
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardTheme(
        elevation: 2,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        shape: CircleBorder(),
      ),
    );
  }
}

class AppState extends ChangeNotifier {
  bool _isDarkMode = false;
  UserPreferences? _userPreferences;
  DateTime _selectedDate = DateTime.now();

  bool get isDarkMode => _isDarkMode;
  UserPreferences? get userPreferences => _userPreferences;
  DateTime get selectedDate => _selectedDate;

  void toggleDarkMode() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  void updateUserPreferences(UserPreferences preferences) {
    _userPreferences = preferences;
    _isDarkMode = preferences.darkMode;
    notifyListeners();
  }

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  Future<void> loadUserPreferences() async {
    try {
      UserPreferences? prefs = await DatabaseService().getUserPreferences();
      if (prefs != null) {
        updateUserPreferences(prefs);
      } else {
        // 기본 설정 생성
        UserPreferences defaultPrefs = UserPreferences.defaultSettings();
        await DatabaseService().updateUserPreferences(defaultPrefs);
        updateUserPreferences(defaultPrefs);
      }
    } catch (e) {
      debugPrint('사용자 설정 로드 오류: $e');
    }
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const TodayTasksScreen(),
      const CalendarScreen(),
      const SettingsScreen(),
    ];

    // 사용자 설정 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadUserPreferences();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: '오늘 할 일',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: '캘린더',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '설정',
          ),
        ],
      ),
    );
  }
}
