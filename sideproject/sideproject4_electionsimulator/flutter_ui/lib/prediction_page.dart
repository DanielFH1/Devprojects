import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

/// 예측 결과 페이지 - 지지율 예측 및 분석
class PredictionPage extends StatefulWidget {
  const PredictionPage({super.key});

  @override
  State<PredictionPage> createState() => _PredictionPageState();
}

class _PredictionPageState extends State<PredictionPage>
    with TickerProviderStateMixin {
  // === 상태 변수 ===
  Map<String, dynamic>? _predictionData;
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

  // 후보자 정보
  static const Map<String, Map<String, dynamic>> candidateInfo = {
    '이재명': {
      'color': Color(0xFF3498DB),
      'party': '더불어민주당',
      'description': '현 더불어민주당 대표',
    },
    '김문수': {
      'color': Color(0xFFE74C3C),
      'party': '국민의힘',
      'description': '전 경기도지사',
    },
    '이준석': {
      'color': Color(0xFFE67E22),
      'party': '개혁신당',
      'description': '개혁신당 대표',
    },
  };

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadPredictionData();
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
  Future<void> _loadPredictionData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // 캐시 업데이트 먼저 시도
      await _updateCache();

      // 예측 데이터 가져오기
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/prediction'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _predictionData = data;
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
        _errorMessage = '예측 데이터를 불러오는 중 오류가 발생했습니다: ${e.toString()}';
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
      // 캐시 업데이트 실패는 무시
      debugPrint('캐시 업데이트 실패: $e');
    }
  }

  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(refreshInterval, (timer) {
      if (mounted) {
        _loadPredictionData();
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
        '지지율 예측',
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
          onPressed: _isLoading ? null : _loadPredictionData,
          tooltip: '새로고침',
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading && _predictionData == null) {
      return _buildLoadingWidget();
    }

    if (_errorMessage != null && _predictionData == null) {
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
              _buildHeaderSection(),
              const SizedBox(height: 24),
              _buildPredictionChart(),
              const SizedBox(height: 24),
              _buildCandidateDetails(),
              const SizedBox(height: 24),
              _buildAnalysisSection(),
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
            '예측 데이터를 분석하는 중...',
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
              '예측 데이터 로딩 실패',
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
              onPressed: _loadPredictionData,
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

  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9B59B6), Color(0xFF8E44AD)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9B59B6).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '2025 대선 지지율 예측',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '뉴스 감성 분석 기반 실시간 예측',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.analytics, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                '총 ${_predictionData?['total_articles'] ?? 0}개 기사 분석',
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

  Widget _buildPredictionChart() {
    final predictions =
        _predictionData?['predictions'] as Map<String, dynamic>? ?? {};

    if (predictions.isEmpty) {
      return _buildEmptyChart();
    }

    // 예측 데이터를 정렬 (지지율 높은 순)
    final sortedPredictions =
        predictions.entries.toList()
          ..sort((a, b) => (b.value as num).compareTo(a.value as num));

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
                    color: const Color(0xFF9B59B6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.poll,
                    color: Color(0xFF9B59B6),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  '예측 지지율',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ...sortedPredictions
                .map(
                  (entry) =>
                      _buildCandidateBar(entry.key, entry.value.toDouble()),
                )
                .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChart() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.poll_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '예측 데이터가 없습니다',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '뉴스 데이터가 수집되면 예측 결과가 표시됩니다',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCandidateBar(String candidate, double percentage) {
    final info = candidateInfo[candidate];
    final color = info?['color'] as Color? ?? Colors.grey;
    final party = info?['party'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      candidate,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    if (party.isNotEmpty)
                      Text(
                        party,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF7F8C8D),
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 12,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: Colors.grey[200],
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage / 100,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.8)],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCandidateDetails() {
    final predictions =
        _predictionData?['predictions'] as Map<String, dynamic>? ?? {};

    if (predictions.isEmpty) {
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
                  '후보자 상세 정보',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...candidateInfo.entries
                .map(
                  (entry) => _buildCandidateDetailCard(
                    entry.key,
                    entry.value,
                    predictions[entry.key]?.toDouble() ?? 0.0,
                  ),
                )
                .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCandidateDetailCard(
    String candidate,
    Map<String, dynamic> info,
    double percentage,
  ) {
    final color = info['color'] as Color;
    final party = info['party'] as String;
    final description = info['description'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9ECEF)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                candidate[0],
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  candidate,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                Text(
                  party,
                  style: TextStyle(
                    fontSize: 14,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7F8C8D),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisSection() {
    final analysis = _predictionData?['analysis'] ?? '분석 데이터가 없습니다.';

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
                    color: const Color(0xFFE67E22).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.insights,
                    color: Color(0xFFE67E22),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  '예측 분석',
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '분석 방법론',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• 뉴스 기사의 감성 분석 (긍정/부정/중립)\n'
                    '• 후보자별 언급 빈도 및 맥락 분석\n'
                    '• 시간별 트렌드 변화 추적\n'
                    '• AI 기반 종합 예측 모델링',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Color(0xFF495057),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '현재 분석 결과',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    analysis,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: Color(0xFF495057),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLastUpdateInfo() {
    final timeRange = _predictionData?['time_range'] ?? '';

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
          Expanded(
            child: Text(
              '마지막 업데이트: $timeRange',
              style: const TextStyle(fontSize: 12, color: Color(0xFF7F8C8D)),
            ),
          ),
          const Icon(Icons.info_outline, color: Color(0xFF7F8C8D), size: 16),
          const SizedBox(width: 4),
          const Text(
            '예측 결과는 참고용입니다',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF7F8C8D),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
