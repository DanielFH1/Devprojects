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

class _PredictionPageState extends State<PredictionPage>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? candidateStats;
  bool isLoading = true;
  String? error;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  bool _isHoveringRefresh = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _controller.forward();
    fetchPredictionData();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> fetchPredictionData() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

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

  Future<void> _refreshData() async {
    try {
      final uri = Uri.base.resolve('/refresh');
      final response = await http.post(uri);

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('데이터 새로고침이 시작되었습니다. 잠시만 기다려주세요.')),
          );
        }
        await Future.delayed(const Duration(seconds: 5));
        await fetchPredictionData();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('새로고침 요청이 실패했습니다.')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('오류가 발생했습니다: $e')));
      }
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    if (isLoading) {
      return Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF181C23) : const Color(0xFFF7F8FA),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF181C23) : const Color(0xFFF7F8FA),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                error!,
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: fetchPredictionData,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    final total = candidates.fold(
      0.0,
      (sum, c) => sum + (c['percent'] as double),
    );

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF181C23) : const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: Text(
          'AI 예측 최종 득표율',
          style: TextStyle(
            fontSize: isMobile ? 18 : 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF232A36) : Colors.white,
        elevation: isDark ? 0.5 : 2,
        shadowColor: isDark ? Colors.black26 : Colors.black12,
        surfaceTintColor: isDark ? null : Colors.white,
        actions: [
          MouseRegion(
            onEnter: (_) => setState(() => _isHoveringRefresh = true),
            onExit: (_) => setState(() => _isHoveringRefresh = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              transform:
                  Matrix4.identity()
                    ..translate(0.0, _isHoveringRefresh ? -2.0 : 0.0),
              child: IconButton(
                icon: Icon(
                  Icons.refresh_rounded,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                onPressed: _refreshData,
                tooltip: '데이터 새로고침',
              ),
            ),
          ),
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
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16.0 : 32.0,
              vertical: 24.0,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 예측 제목
                    Card(
                      color: isDark ? const Color(0xFF232A36) : Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: (isDark
                                            ? Colors.white
                                            : Colors.black)
                                        .withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.analytics_outlined,
                                    color:
                                        isDark ? Colors.white : Colors.black87,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '2025년 6월 3일 대선날 AI 예측 최종 득표율',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '기준: ${DateTime.now().toString().substring(0, 10)}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color:
                                              isDark
                                                  ? Colors.white70
                                                  : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // 파이차트와 분석 요약
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 파이차트
                        Hero(
                          tag: 'prediction_chart',
                          child: Card(
                            color:
                                isDark ? const Color(0xFF232A36) : Colors.white,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: SizedBox(
                                width: 220,
                                height: 220,
                                child: PieChart(
                                  PieChartData(
                                    sectionsSpace: 2,
                                    centerSpaceRadius: 40,
                                    sections: List.generate(candidates.length, (
                                      i,
                                    ) {
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
                            ),
                          ),
                        ),
                        // AI 분석 요약
                        Expanded(
                          child: Card(
                            color:
                                isDark ? const Color(0xFF232A36) : Colors.white,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: (isDark
                                                  ? Colors.white
                                                  : Colors.black)
                                              .withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.psychology_outlined,
                                          color:
                                              isDark
                                                  ? Colors.white
                                                  : Colors.black87,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      const Text(
                                        'AI 분석 요약',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'AI는 최근 뉴스, 감성 분석, 여론 흐름을 종합해 이재명 후보가 근소한 차이로 선두를 유지할 것으로 예측합니다. 김문수 후보는 보수층 결집에 힘입어 강한 추격을 보이고 있으며, 이준석 후보는 젊은 층과 개혁 성향 유권자에게서 꾸준한 지지를 받고 있습니다.',
                                    style: TextStyle(
                                      fontSize: 15,
                                      height: 1.6,
                                      color:
                                          isDark
                                              ? Colors.white70
                                              : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // 히스토그램
                    Card(
                      color: isDark ? const Color(0xFF232A36) : Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: (isDark
                                            ? Colors.white
                                            : Colors.black)
                                        .withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.bar_chart_rounded,
                                    color:
                                        isDark ? Colors.white : Colors.black87,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Text(
                                  '득표율 비교',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
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
                                          if (idx < 0 ||
                                              idx >= candidates.length)
                                            return const SizedBox();
                                          return Text(
                                            candidates[idx]['name'] as String,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  isDark
                                                      ? Colors.white
                                                      : Colors.black87,
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
                                  barGroups: List.generate(candidates.length, (
                                    i,
                                  ) {
                                    final c = candidates[i];
                                    return BarChartGroupData(
                                      x: i,
                                      barRods: [
                                        BarChartRodData(
                                          toY: c['percent'] as double,
                                          color: c['color'] as Color,
                                          width: 32,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
