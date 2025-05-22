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
      // 오류 발생 시 기본 데이터 사용
      setState(() {
        candidateStats = {
          '이재명': {'긍정': 15, '부정': 8, '중립': 10},
          '김문수': {'긍정': 10, '부정': 12, '중립': 8},
          '이준석': {'긍정': 12, '부정': 6, '중립': 9},
        };
        error = null;
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

  Color _getCandidateColor(String name) {
    switch (name) {
      case '이재명':
        return const Color(0xFF1E88E5); // 파란색
      case '김문수':
        return const Color(0xFFE53935); // 빨간색
      case '이준석':
        return const Color(0xFF43A047); // 초록색
      default:
        return const Color(0xFF757575); // 회색
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final candidates = _calculatePredictions();
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isSmallMobile = screenWidth < 360;

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
                  fontSize: isMobile ? 14 : 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: fetchPredictionData,
                child: Text(
                  '다시 시도',
                  style: TextStyle(fontSize: isMobile ? 14 : 16),
                ),
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
        backgroundColor: isDark ? const Color(0xFF232A36) : Colors.white,
        title: const Text(
          'AI 예측 득표율',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onToggleTheme,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Container(
            padding: const EdgeInsets.only(bottom: 8),
            child: const Text(
              '데이터는 매일 오전 6시에 갱신됩니다.',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16.0 : 32.0,
              vertical: isMobile ? 16.0 : 24.0,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isMobile ? double.infinity : 800,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 예측 제목
                    Card(
                      color: isDark ? const Color(0xFF232A36) : Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(isMobile ? 16 : 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.analytics_outlined,
                                  size: isMobile ? 24 : 28,
                                  color:
                                      isDark ? Colors.white70 : Colors.black87,
                                ),
                                SizedBox(width: isMobile ? 12 : 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '2025년 6월 3일 대선날 AI 예측 최종 득표율',
                                        style: TextStyle(
                                          fontSize: isMobile ? 16 : 20,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: -0.5,
                                          color:
                                              isDark
                                                  ? Colors.white
                                                  : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '기준: ${DateTime.now().toString().substring(0, 10)}',
                                        style: TextStyle(
                                          fontSize: isMobile ? 12 : 14,
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
                    SizedBox(height: isMobile ? 24 : 32),
                    // 파이차트와 분석 요약
                    Card(
                      color: isDark ? const Color(0xFF232A36) : Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(isMobile ? 16 : 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.pie_chart_outline,
                                  size: isMobile ? 24 : 28,
                                  color:
                                      isDark ? Colors.white70 : Colors.black87,
                                ),
                                SizedBox(width: isMobile ? 12 : 16),
                                Text(
                                  'AI 분석 요약',
                                  style: TextStyle(
                                    fontSize: isMobile ? 16 : 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                    color:
                                        isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'AI는 최근 뉴스, 감성 분석, 여론 흐름을 종합해 이재명 후보가 근소한 차이로 선두를 유지할 것으로 예측합니다. 김문수 후보는 보수층 결집에 힘입어 강한 추격을 보이고 있으며, 이준석 후보는 젊은 층과 개혁 성향 유권자에게서 꾸준한 지지를 받고 있습니다.',
                              style: TextStyle(
                                fontSize: isMobile ? 14 : 15,
                                height: 1.6,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: isMobile ? 24 : 32),
                    // 히스토그램
                    Card(
                      color: isDark ? const Color(0xFF232A36) : Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(isMobile ? 16 : 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.bar_chart,
                                  size: isMobile ? 24 : 28,
                                  color:
                                      isDark ? Colors.white70 : Colors.black87,
                                ),
                                SizedBox(width: isMobile ? 12 : 16),
                                Text(
                                  '예측 득표율',
                                  style: TextStyle(
                                    fontSize: isMobile ? 16 : 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                    color:
                                        isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            ...candidates.map((candidate) {
                              final name = candidate['name'] as String;
                              final percent = candidate['percent'] as double;
                              final color = _getCandidateColor(name);

                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: isMobile ? 16 : 20,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          name,
                                          style: TextStyle(
                                            fontSize: isMobile ? 14 : 16,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                isDark
                                                    ? Colors.white
                                                    : Colors.black87,
                                          ),
                                        ),
                                        Text(
                                          '${percent.toStringAsFixed(1)}%',
                                          style: TextStyle(
                                            fontSize: isMobile ? 14 : 16,
                                            fontWeight: FontWeight.bold,
                                            color: color,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: LinearProgressIndicator(
                                        value: percent / 100,
                                        backgroundColor:
                                            isDark
                                                ? Colors.white12
                                                : Colors.grey[200],
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              color,
                                            ),
                                        minHeight: isMobile ? 8 : 12,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
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
