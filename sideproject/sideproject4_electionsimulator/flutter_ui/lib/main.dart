import 'package:flutter/material.dart';
import 'news_page.dart';
import 'prediction_page.dart';

void main() {
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
      debugShowCheckedModeBanner: false,
    );
  }
}
