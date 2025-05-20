import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'news_page.dart';
import 'prediction_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 시스템 UI 설정
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // 앱 실행
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '대선 시뮬레이터',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF232A36)),
        useMaterial3: true,
        fontFamily: 'Noto Sans KR',
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontFamily: 'Inter'),
          displayMedium: TextStyle(fontFamily: 'Inter'),
          displaySmall: TextStyle(fontFamily: 'Inter'),
        ),
        // 반응형 설정 추가
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF232A36),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Noto Sans KR',
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontFamily: 'Inter'),
          displayMedium: TextStyle(fontFamily: 'Inter'),
          displaySmall: TextStyle(fontFamily: 'Inter'),
        ),
        // 반응형 설정 추가
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      ),
      themeMode: _themeMode,
      home: NewsPage(
        onToggleTheme: _toggleTheme,
        themeMode: _themeMode,
        onNavigatePrediction: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => PredictionPage(
                    themeMode: _themeMode,
                    onToggleTheme: _toggleTheme,
                  ),
            ),
          );
        },
      ),
      builder: (context, child) {
        // 전체 앱에 반응형 비율 설정 적용
        return MediaQuery(
          // 시스템 설정된 텍스트 크기를 무시하고 앱 내부에서 일관된 크기 제공
          data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
          child: child!,
        );
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
