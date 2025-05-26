import 'dart:convert';
import 'dart:async'; // TimeoutException을 위해 추가
import 'dart:io'; // SocketException을 위해 추가
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'news_model.dart';
import 'candidate_pie_chart.dart'; // ✅ 새로 만든 그래프 위젯 임포트
import 'candidate_detail_page.dart'; // 후보 상세페이지 임포트
import 'prediction_page.dart'; // AI 예측 득표율 페이지 임포트
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

/// 뉴스 분석 페이지 - 상세 뉴스 목록 및 분석
class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> with TickerProviderStateMixin {
  // === 상태 변수 ===
  Map<String, dynamic>? _newsData;
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _refreshTimer;

  // 필터링 상태
  String _selectedSentiment = '전체';
  String _selectedCandidate = '전체';

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

  // 필터 옵션
  static const List<String> sentimentFilters = ['전체', '긍정', '중립', '부정'];
  static const List<String> candidateFilters = ['전체', '이재명', '김문수', '이준석'];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadNewsData();
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
  Future<void> _loadNewsData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // 캐시 업데이트 먼저 시도
      await _updateCache();

      // 뉴스 데이터 가져오기
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/trend-summary'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _newsData = data;
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
        _errorMessage = '뉴스 데이터를 불러오는 중 오류가 발생했습니다: ${e.toString()}';
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
        _loadNewsData();
      }
    });
  }

  // === 필터링 로직 ===
  List<Map<String, dynamic>> _getFilteredNews() {
    final newsList = _newsData?['news_list'] as List<dynamic>? ?? [];

    return newsList.map((article) => Map<String, dynamic>.from(article)).where((
      article,
    ) {
      // 감성 필터
      if (_selectedSentiment != '전체' &&
          article['sentiment'] != _selectedSentiment) {
        return false;
      }

      // 후보자 필터
      if (_selectedCandidate != '전체') {
        final title = article['title']?.toString().toLowerCase() ?? '';
        final summary = article['summary']?.toString().toLowerCase() ?? '';
        final candidateName = _selectedCandidate.toLowerCase();

        if (!title.contains(candidateName) &&
            !summary.contains(candidateName)) {
          return false;
        }
      }

      return true;
    }).toList();
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
        '뉴스 분석',
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
          onPressed: _isLoading ? null : _loadNewsData,
          tooltip: '새로고침',
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading && _newsData == null) {
      return _buildLoadingWidget();
    }

    if (_errorMessage != null && _newsData == null) {
      return _buildErrorWidget();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Column(
          children: [_buildFilterSection(), Expanded(child: _buildNewsList())],
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
            '뉴스 데이터를 불러오는 중...',
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
              '뉴스 데이터 로딩 실패',
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
              onPressed: _loadNewsData,
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

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE9ECEF), width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.filter_list, color: Color(0xFF3498DB), size: 20),
              const SizedBox(width: 8),
              const Text(
                '필터',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const Spacer(),
              Text(
                '총 ${_getFilteredNews().length}개 기사',
                style: const TextStyle(fontSize: 14, color: Color(0xFF7F8C8D)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildFilterDropdown(
                  label: '감성',
                  value: _selectedSentiment,
                  items: sentimentFilters,
                  onChanged: (value) {
                    setState(() {
                      _selectedSentiment = value!;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFilterDropdown(
                  label: '후보자',
                  value: _selectedCandidate,
                  items: candidateFilters,
                  onChanged: (value) {
                    setState(() {
                      _selectedCandidate = value!;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF7F8C8D),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE9ECEF)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items:
                  items.map((item) {
                    return DropdownMenuItem<String>(
                      value: item,
                      child: Text(
                        item,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                    );
                  }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNewsList() {
    final filteredNews = _getFilteredNews();

    if (filteredNews.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredNews.length,
      itemBuilder: (context, index) {
        final article = filteredNews[index];
        return _buildNewsCard(article, index);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '조건에 맞는 뉴스가 없습니다',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '다른 필터 조건을 선택해보세요',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsCard(Map<String, dynamic> article, int index) {
    final title = article['title']?.toString() ?? '제목 없음';
    final summary = article['summary']?.toString() ?? '요약 없음';
    final sentiment = article['sentiment']?.toString() ?? '중립';
    final source = article['source']?.toString() ?? '출처 불명';
    final publishedDate = article['published_date']?.toString() ?? '';
    final url = article['url']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _openArticle(url),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildSentimentChip(sentiment),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  summary,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF495057),
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.source, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    source,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _formatDate(publishedDate),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                  const Icon(
                    Icons.open_in_new,
                    size: 16,
                    color: Color(0xFF3498DB),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSentimentChip(String sentiment) {
    Color color;
    IconData icon;

    switch (sentiment) {
      case '긍정':
        color = const Color(0xFF27AE60);
        icon = Icons.thumb_up;
        break;
      case '부정':
        color = const Color(0xFFE74C3C);
        icon = Icons.thumb_down;
        break;
      default:
        color = const Color(0xFF95A5A6);
        icon = Icons.remove;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            sentiment,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // === 유틸리티 메서드 ===
  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return '${difference.inDays}일 전';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}시간 전';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}분 전';
      } else {
        return '방금 전';
      }
    } catch (e) {
      return dateString;
    }
  }

  Future<void> _openArticle(String url) async {
    if (url.isEmpty) {
      _showSnackBar('유효하지 않은 링크입니다.');
      return;
    }

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showSnackBar('링크를 열 수 없습니다.');
      }
    } catch (e) {
      _showSnackBar('링크를 여는 중 오류가 발생했습니다.');
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF2C3E50),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
