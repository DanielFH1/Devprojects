import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'main_page.dart';

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '2025 대선 시뮬레이터',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3498DB)),
        useMaterial3: true,
        fontFamily: 'Noto Sans KR',
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontFamily: 'Inter'),
          displayMedium: TextStyle(fontFamily: 'Inter'),
          displaySmall: TextStyle(fontFamily: 'Inter'),
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      ),
      home: const MainPage(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
          child: child!,
        );
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
