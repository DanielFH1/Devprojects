import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

import 'prediction_page.dart';
import 'news_page.dart';

/// 메인 페이지 - 대선 시뮬레이터 홈
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with TickerProviderStateMixin {
  // === 상태 변수 ===
  Map<String, dynamic>? _trendData;
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _refreshTimer;

  // 애니메이션 컨트롤러
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // === 설정 ===
  static const String baseUrl =
      'https://sideproject4-electionsimulator.onrender.com';
  static const Duration refreshInterval = Duration(minutes: 30);
  static const Duration animationDuration = Duration(milliseconds: 800);

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadTrendData();
    _startPeriodicRefresh();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  // === 애니메이션 초기화 ===
  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: animationDuration,
      vsync: this,
    );

    _slideController = AnimationController(
      duration: animationDuration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );
  }

  // === 데이터 로딩 ===
  Future<void> _loadTrendData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // 캐시 업데이트 먼저 시도
      await _updateCache();

      // 트렌드 데이터 가져오기
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/trend-summary'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _trendData = data;
          _isLoading = false;
        });

        // 애니메이션 시작
        _fadeController.forward();
        _slideController.forward();
      } else {
        throw Exception('서버 응답 오류: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = '데이터를 불러오는 중 오류가 발생했습니다: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateCache() async {
    try {
      await http
          .post(
            Uri.parse('$baseUrl/api/update-cache'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      // 캐시 업데이트 실패는 무시 (메인 데이터 로딩에 영향 없음)
      debugPrint('캐시 업데이트 실패: $e');
    }
  }

  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(refreshInterval, (timer) {
      if (mounted) {
        _loadTrendData();
      }
    });
  }

  // === UI 빌드 메서드 ===
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        '2025 대선 시뮬레이터',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
      ),
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF2C3E50),
      elevation: 0,
      centerTitle: true,
      actions: [
        IconButton(
          icon:
              _isLoading
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Icon(Icons.refresh),
          onPressed: _isLoading ? null : _loadTrendData,
          tooltip: '새로고침',
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading && _trendData == null) {
      return _buildLoadingWidget();
    }

    if (_errorMessage != null && _trendData == null) {
      return _buildErrorWidget();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeSection(),
              const SizedBox(height: 24),
              _buildTrendSummaryCard(),
              const SizedBox(height: 24),
              _buildCandidateStatsCard(),
              const SizedBox(height: 24),
              _buildNavigationCards(),
              const SizedBox(height: 16),
              _buildLastUpdateInfo(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3498DB)),
          ),
          SizedBox(height: 16),
          Text(
            '최신 데이터를 불러오는 중...',
            style: TextStyle(fontSize: 16, color: Color(0xFF7F8C8D)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Color(0xFFE74C3C)),
            const SizedBox(height: 16),
            Text(
              '데이터 로딩 실패',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: const Color(0xFFE74C3C),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? '알 수 없는 오류가 발생했습니다.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF7F8C8D), fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadTrendData,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3498DB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3498DB), Color(0xFF2980B9)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3498DB).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '2025 대선 시뮬레이터',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '실시간 뉴스 분석을 통한 대선 트렌드 예측',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.trending_up, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                '총 ${_trendData?['total_articles'] ?? 0}개 기사 분석',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrendSummaryCard() {
    final trendSummary = _trendData?['trend_summary'] ?? '트렌드 분석 중...';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3498DB).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.analytics,
                    color: Color(0xFF3498DB),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  '트렌드 분석',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE9ECEF), width: 1),
              ),
              child: Text(
                trendSummary,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  color: Color(0xFF495057),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCandidateStatsCard() {
    final candidateStats =
        _trendData?['candidate_stats'] as Map<String, dynamic>?;

    if (candidateStats == null) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF27AE60).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.people,
                    color: Color(0xFF27AE60),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  '후보자별 언론 동향',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...candidateStats.entries
                .map((entry) => _buildCandidateStatRow(entry.key, entry.value))
                .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCandidateStatRow(String candidate, Map<String, dynamic> stats) {
    final positive = stats['긍정'] ?? 0;
    final negative = stats['부정'] ?? 0;
    final neutral = stats['중립'] ?? 0;
    final total = positive + negative + neutral;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9ECEF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                candidate,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              Text(
                '총 $total건',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF7F8C8D),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (total > 0) ...[
            _buildSentimentBar(positive, negative, neutral, total),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSentimentLabel('긍정', positive, const Color(0xFF27AE60)),
                _buildSentimentLabel('중립', neutral, const Color(0xFF95A5A6)),
                _buildSentimentLabel('부정', negative, const Color(0xFFE74C3C)),
              ],
            ),
          ] else
            const Text(
              '관련 뉴스가 없습니다',
              style: TextStyle(
                color: Color(0xFF95A5A6),
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSentimentBar(
    int positive,
    int negative,
    int neutral,
    int total,
  ) {
    final positiveRatio = positive / total;
    final neutralRatio = neutral / total;
    final negativeRatio = negative / total;

    return Container(
      height: 8,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: const Color(0xFFE9ECEF),
      ),
      child: Row(
        children: [
          if (positiveRatio > 0)
            Expanded(
              flex: (positiveRatio * 100).round(),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF27AE60),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4),
                    bottomLeft: Radius.circular(4),
                  ),
                ),
              ),
            ),
          if (neutralRatio > 0)
            Expanded(
              flex: (neutralRatio * 100).round(),
              child: Container(color: const Color(0xFF95A5A6)),
            ),
          if (negativeRatio > 0)
            Expanded(
              flex: (negativeRatio * 100).round(),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFE74C3C),
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(4),
                    bottomRight: Radius.circular(4),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSentimentLabel(String label, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$label $count',
          style: const TextStyle(fontSize: 12, color: Color(0xFF495057)),
        ),
      ],
    );
  }

  Widget _buildNavigationCards() {
    return Row(
      children: [
        Expanded(
          child: _buildNavigationCard(
            title: '예측 결과',
            subtitle: '지지율 예측 보기',
            icon: Icons.poll,
            color: const Color(0xFF9B59B6),
            onTap:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PredictionPage(),
                  ),
                ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildNavigationCard(
            title: '뉴스 분석',
            subtitle: '상세 뉴스 보기',
            icon: Icons.article,
            color: const Color(0xFFE67E22),
            onTap:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const NewsPage()),
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color, color.withOpacity(0.8)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white, size: 32),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLastUpdateInfo() {
    final timeRange = _trendData?['time_range'] ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9ECEF)),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule, color: Color(0xFF7F8C8D), size: 16),
          const SizedBox(width: 8),
          Text(
            '마지막 업데이트: $timeRange',
            style: const TextStyle(fontSize: 12, color: Color(0xFF7F8C8D)),
          ),
        ],
      ),
    );
  }
}
