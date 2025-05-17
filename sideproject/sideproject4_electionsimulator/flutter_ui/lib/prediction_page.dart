import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PredictionPage extends StatefulWidget {
  final ThemeMode? themeMode;
  final VoidCallback? onToggleTheme;
  const PredictionPage({super.key, this.themeMode, this.onToggleTheme});
  @override
  State<PredictionPage> createState() => _PredictionPageState();
}

class _PredictionPageState extends State<PredictionPage> {
  Map<String, dynamic>? candidateStats;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    fetchPredictionData();
  }

  Future<void> fetchPredictionData() async {
    try {
      final uri = Uri.base.resolve('/news');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newsData = data['data'];

        if (newsData == null) {
          throw Exception('뉴스 데이터가 없습니다.');
        }

        setState(() {
          candidateStats = newsData['candidate_stats'];
          isLoading = false;
        });
      } else {
        setState(() {
          error = '서버 오류: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = '데이터 불러오기 실패: $e';
        isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _calculatePredictions() {
    if (candidateStats == null) return [];

    final candidates = ['이재명', '김문수', '이준석'];
    final colors = {
      '이재명': const Color(0xFF1877F2),
      '김문수': const Color(0xFFEF3340),
      '이준석': const Color(0xFFFF9900),
    };

    // 1. 각 후보별 점수 계산
    final scores = <String, double>{};
    for (final name in candidates) {
      final stats = candidateStats![name] as Map<String, dynamic>;
      final positive = stats['긍정'] as int;
      final negative = stats['부정'] as int;
      final neutral = stats['중립'] as int;
      final score = positive * 1.5 + neutral + negative * 0.5;
      scores[name] = score;
    }

    // 2. 전체 점수 합
    final totalScore = scores.values.fold(0.0, (a, b) => a + b);

    // 3. 각 후보의 득표율(%) 계산 (정규화)
    return candidates.map((name) {
      final percent =
          totalScore == 0 ? 0.0 : (scores[name]! / totalScore) * 100;
      return {
        'name': name,
        'color': colors[name],
        'percent': double.parse(percent.toStringAsFixed(1)),
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final candidates = _calculatePredictions();

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Text(error!, style: const TextStyle(color: Colors.red)),
      );
    }

    final total = candidates.fold(
      0.0,
      (sum, c) => sum + (c['percent'] as double),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 예측 최종 득표율'),
        backgroundColor: isDark ? const Color(0xFF232A36) : Colors.white,
        elevation: isDark ? 0.5 : 2,
        shadowColor: isDark ? Colors.black26 : Colors.black12,
        surfaceTintColor: isDark ? null : Colors.white,
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
              color: isDark ? Colors.white : Colors.black87,
            ),
            onPressed: widget.onToggleTheme,
            tooltip: isDark ? '라이트모드' : '다크모드',
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  '2025년 6월 3일 대선날 AI 예측 최종 득표율',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 파이차트
                    SizedBox(
                      width: 220,
                      height: 220,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                          sections: List.generate(candidates.length, (i) {
                            final c = candidates[i];
                            return PieChartSectionData(
                              color: c['color'] as Color,
                              value: c['percent'] as double,
                              title: '${c['name']}\n${c['percent']}%',
                              radius: 60,
                              titleStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                    // AI 분석 요약
                    Expanded(
                      child: Card(
                        color:
                            isDark
                                ? const Color(0xFF232A36)
                                : const Color(0xFFF5F6FA),
                        elevation: 0,
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(
                            'AI는 최근 뉴스, 감성 분석, 여론 흐름을 종합해 이재명 후보가 근소한 차이로 선두를 유지할 것으로 예측합니다. 김문수 후보는 보수층 결집에 힘입어 강한 추격을 보이고 있으며, 이준석 후보는 젊은 층과 개혁 성향 유권자에게서 꾸준한 지지를 받고 있습니다.',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // 히스토그램
                SizedBox(
                  height: 140,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: 50,
                      barTouchData: BarTouchData(enabled: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= candidates.length)
                                return const SizedBox();
                              return Text(
                                candidates[idx]['name'] as String,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              );
                            },
                          ),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(candidates.length, (i) {
                        final c = candidates[i];
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: c['percent'] as double,
                              color: c['color'] as Color,
                              width: 32,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
