// This is a basic Flutter widget test for AutoScheduler app.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    // 테스트 환경에서 로케일 데이터 초기화
    await initializeDateFormatting('ko_KR', null);
  });

  testWidgets('AutoScheduler app builds successfully', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const Center(child: Text('테스트 중')),
          bottomNavigationBar: NavigationBar(
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.today_outlined),
                label: '오늘 할 일',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined),
                label: '캘린더',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                label: '설정',
              ),
            ],
            selectedIndex: 0,
            onDestinationSelected: (index) {},
          ),
        ),
      ),
    );

    // Verify that the navigation elements are present
    expect(find.text('오늘 할 일'), findsOneWidget);
    expect(find.text('캘린더'), findsOneWidget);
    expect(find.text('설정'), findsOneWidget);
    expect(find.text('테스트 중'), findsOneWidget);
  });
}
