import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sharetime/providers/timer_provider.dart';
import 'package:sharetime/screens/home_screen.dart';
import 'package:sharetime/screens/create_timer_screen.dart';
import 'package:sharetime/screens/join_timer_screen.dart';
import 'package:sharetime/screens/timer_view_screen.dart';

void main() {
  runApp(const ShareTimeApp());
}

class ShareTimeApp extends StatelessWidget {
  const ShareTimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => TimerProvider(),
      child: MaterialApp(
        title: 'ShareTime',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          brightness: Brightness.light,
          fontFamily: 'Roboto',
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            centerTitle: true,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.blue, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const HomeScreen(),
          '/create': (context) => const CreateTimerScreen(),
          '/join': (context) => const JoinTimerScreen(),
          '/timer': (context) => const TimerViewScreen(),
        },
      ),
    );
  }
}
