import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'candidate_detail_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fl_chart/fl_chart.dart';

class MainPage extends StatefulWidget {
  final ThemeMode? themeMode;
  final VoidCallback? onToggleTheme;

  const MainPage({super.key, this.themeMode, this.onToggleTheme});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? newsData;
  bool isLoading = true;
  String? error;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  String _selectedSentiment = '전체';
  final List<String> _sentimentFilters = ['전체', '긍정', '중립', '부정'];
  bool _isHoveringRefresh = false;
  bool isNewsExpanded = false;
  Map<String, List<Map<String, dynamic>>> candidateNews = {};

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
    fetchNewsData();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> fetchNewsData() async {
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

        // 뉴스 데이터를 후보자별로 분류
        final Map<String, List<Map<String, dynamic>>> categorizedNews = {
          '이재명': [],
          '김문수': [],
          '이준석': [],
        };

        // 전체 뉴스 데이터에서 후보자별 뉴스 분류
        if (newsData['news_list'] != null) {
          for (var article in newsData['news_list']) {
            final title = article['title'] as String;
            final summary = article['summary'] as String? ?? '';
            final content = '$title $summary'.toLowerCase();

            // 각 후보자별로 관련 뉴스 분류
            for (var candidate in categorizedNews.keys) {
              if (content.contains(candidate.toLowerCase())) {
                // 중복 체크
                final isDuplicate = categorizedNews[candidate]!.any(
                  (existing) => existing['url'] == article['url'],
                );

                if (!isDuplicate) {
                  categorizedNews[candidate]!.add({
                    ...article,
                    'sentiment_color': _getSentimentColor(
                      article['sentiment'] ?? '중립',
                    ),
                  });
                }
                break;
              }
            }
          }

          // 각 후보자별 뉴스를 발행일 기준으로 정렬
          for (var candidate in categorizedNews.keys) {
            categorizedNews[candidate]!.sort((a, b) {
              final dateA =
                  DateTime.tryParse(a['published_date'] ?? '') ??
                  DateTime(2000);
              final dateB =
                  DateTime.tryParse(b['published_date'] ?? '') ??
                  DateTime(2000);
              return dateB.compareTo(dateA); // 최신순 정렬
            });
          }
        }

        setState(() {
          this.newsData = newsData;
          this.candidateNews = categorizedNews;
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

  Future<void> _refreshNews() async {
    try {
      final uri = Uri.base.resolve('/refresh');
      final response = await http.post(uri);

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('뉴스 데이터 새로고침이 시작되었습니다. 잠시만 기다려주세요.')),
          );
        }
        // 5초 후 데이터 다시 불러오기
        await Future.delayed(const Duration(seconds: 5));
        await fetchNewsData();
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

  List<Map<String, dynamic>> _getFilteredNews(
    List<Map<String, dynamic>> newsList,
  ) {
    if (_selectedSentiment == '전체') return newsList;
    return newsList
        .where((article) => article['sentiment'] == _selectedSentiment)
        .toList();
  }

  Color _getSentimentColor(String sentiment) {
    switch (sentiment.trim()) {
      case "긍정":
        return Colors.green;
      case "부정":
        return Colors.red;
      case "중립":
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                onPressed: fetchNewsData,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    final trendSummary =
        newsData?['trend_summary'] as String? ?? '데이터를 불러오는 중입니다...';
    final candidateStats =
        newsData?['candidate_stats'] as Map<String, dynamic>? ?? {};
    final totalArticles = newsData?['total_articles'] as int? ?? 0;
    final timeRange = newsData?['time_range'] as String? ?? '데이터 수집 중';

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF141921) : const Color(0xFFFCFCFF),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A202C) : Colors.white,
        elevation: 0,
        shadowColor: isDark ? Colors.black26 : Colors.black12,
        surfaceTintColor: isDark ? null : Colors.white,
        title: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Text(
            '대선 트렌드 분석',
            style: TextStyle(
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
              letterSpacing: -0.5,
            ),
          ),
        ),
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
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
                onPressed: _refreshNews,
                tooltip: '뉴스 새로고침',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: Icon(
                isDark ? Icons.light_mode : Icons.dark_mode,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
              onPressed: widget.onToggleTheme,
              tooltip: isDark ? '라이트모드' : '다크모드',
            ),
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
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 트렌드 요약 카드
                    Card(
                      color: isDark ? const Color(0xFF1A202C) : Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color:
                              isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.grey.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(28.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: (isDark
                                            ? Colors.blue
                                            : const Color(0xFF4361EE))
                                        .withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.insights_rounded,
                                    color:
                                        isDark
                                            ? Colors.blue
                                            : const Color(0xFF4361EE),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '최근 트렌드 분석',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: -0.5,
                                          color:
                                              isDark
                                                  ? Colors.white
                                                  : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '기준: $timeRange',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color:
                                              isDark
                                                  ? Colors.white60
                                                  : Colors.black45,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 20,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isDark
                                        ? Colors.white.withOpacity(0.03)
                                        : Colors.grey.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                trendSummary,
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.7,
                                  color:
                                      isDark ? Colors.white70 : Colors.black87,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    // 후보별 통계
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 20,
                          decoration: BoxDecoration(
                            color:
                                isDark ? Colors.white : const Color(0xFF4361EE),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '후보별 뉴스 통계',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '뉴스감성분석은 매일 오전 6시에 이루어집니다.',
                          style: TextStyle(
                            fontSize: isMobile ? 11 : 13,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // 후보 카드들
                    ...['이재명', '김문수', '이준석'].map((candidate) {
                      final stats =
                          candidateStats[candidate] as Map<String, dynamic>? ??
                          {};
                      final positive = stats['긍정'] as int? ?? 0;
                      final negative = stats['부정'] as int? ?? 0;
                      final neutral = stats['중립'] as int? ?? 0;
                      final total = positive + negative + neutral;
                      final candidateColor = _getCandidateColor(candidate);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Hero(
                          tag: 'candidate_$candidate',
                          child: Card(
                            color:
                                isDark ? const Color(0xFF1A202C) : Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color:
                                    isDark
                                        ? Colors.white.withOpacity(0.05)
                                        : Colors.grey.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            child: InkWell(
                              onTap: () {
                                final candidateNews = _getFilteredNews(
                                  (newsData?['news_list'] as List<dynamic>? ??
                                          [])
                                      .where(
                                        (article) =>
                                            article['title']
                                                .toString()
                                                .contains(candidate) ||
                                            article['summary']
                                                .toString()
                                                .contains(candidate),
                                      )
                                      .map(
                                        (article) =>
                                            Map<String, dynamic>.from(article),
                                      )
                                      .toList(),
                                );

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => CandidateDetailPage(
                                          candidate: candidate,
                                          news: candidateNews,
                                          themeMode:
                                              widget.themeMode ??
                                              ThemeMode.system,
                                          onToggleTheme:
                                              widget.onToggleTheme ?? () {},
                                        ),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: candidateColor.withOpacity(
                                              0.1,
                                            ),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: candidateColor
                                                    .withOpacity(0.2),
                                                blurRadius: 10,
                                                spreadRadius: 0,
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child: Text(
                                              candidate[0],
                                              style: TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                color: candidateColor,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 20),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                candidate,
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: -0.3,
                                                  color:
                                                      isDark
                                                          ? Colors.white
                                                          : Colors.black87,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                '총 $total개 기사',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color:
                                                      isDark
                                                          ? Colors.white60
                                                          : Colors.black45,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color:
                                                isDark
                                                    ? Colors.white.withOpacity(
                                                      0.05,
                                                    )
                                                    : Colors.grey.withOpacity(
                                                      0.05,
                                                    ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.arrow_forward_rounded,
                                            color:
                                                isDark
                                                    ? Colors.white60
                                                    : Colors.black45,
                                            size: 20,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (total > 0) ...[
                                      const SizedBox(height: 24),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            child: Row(
                                              children: [
                                                _buildStatChip(
                                                  '긍정',
                                                  positive,
                                                  const Color(0xFF4CAF50),
                                                  isDark,
                                                ),
                                                const SizedBox(width: 12),
                                                _buildStatChip(
                                                  '중립',
                                                  neutral,
                                                  const Color(0xFF607D8B),
                                                  isDark,
                                                ),
                                                const SizedBox(width: 12),
                                                _buildStatChip(
                                                  '부정',
                                                  negative,
                                                  const Color(0xFFF44336),
                                                  isDark,
                                                ),
                                              ],
                                            ),
                                          ),
                                          SizedBox(
                                            height: 80,
                                            width: 80,
                                            child: PieChart(
                                              PieChartData(
                                                sectionsSpace: 2,
                                                centerSpaceRadius: 20,
                                                sections: [
                                                  PieChartSectionData(
                                                    value: positive.toDouble(),
                                                    color: const Color(
                                                      0xFF4CAF50,
                                                    ),
                                                    radius: 15,
                                                    title: '',
                                                    titleStyle: const TextStyle(
                                                      fontSize: 0,
                                                    ),
                                                  ),
                                                  PieChartSectionData(
                                                    value: neutral.toDouble(),
                                                    color: const Color(
                                                      0xFF607D8B,
                                                    ),
                                                    radius: 15,
                                                    title: '',
                                                    titleStyle: const TextStyle(
                                                      fontSize: 0,
                                                    ),
                                                  ),
                                                  PieChartSectionData(
                                                    value: negative.toDouble(),
                                                    color: const Color(
                                                      0xFFF44336,
                                                    ),
                                                    radius: 15,
                                                    title: '',
                                                    titleStyle: const TextStyle(
                                                      fontSize: 0,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 36),
                    // 감성 필터
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 20,
                          decoration: BoxDecoration(
                            color:
                                isDark ? Colors.white : const Color(0xFF4361EE),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '취합된 기사 목록',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '감성 필터:',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children:
                                _sentimentFilters.map((sentiment) {
                                  final isSelected =
                                      _selectedSentiment == sentiment;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: FilterChip(
                                      selected: isSelected,
                                      label: Text(sentiment),
                                      labelStyle: TextStyle(
                                        color:
                                            isSelected
                                                ? Colors.white
                                                : isDark
                                                ? Colors.white70
                                                : Colors.black87,
                                        fontWeight:
                                            isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                        fontSize: 13,
                                      ),
                                      backgroundColor:
                                          isDark
                                              ? const Color(0xFF232836)
                                              : Colors.grey[100],
                                      selectedColor: _getSentimentFilterColor(
                                        sentiment,
                                      ),
                                      checkmarkColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 0,
                                      ),
                                      onSelected: (selected) {
                                        if (selected) {
                                          setState(
                                            () =>
                                                _selectedSentiment = sentiment,
                                          );
                                        }
                                      },
                                    ),
                                  );
                                }).toList(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // 전체 뉴스 목록
                    ..._getFilteredNews(
                      (newsData?['news_list'] as List<dynamic>? ?? [])
                          .map((article) => Map<String, dynamic>.from(article))
                          .toList(),
                    ).map((article) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Hero(
                          tag: 'news_${article['url']}',
                          child: Card(
                            color:
                                isDark ? const Color(0xFF1A202C) : Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color:
                                    isDark
                                        ? Colors.white.withOpacity(0.05)
                                        : Colors.grey.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            child: InkWell(
                              onTap: () async {
                                final Uri uri = Uri.parse(
                                  article['url'] as String,
                                );
                                if (!await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                )) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('링크를 열 수 없습니다.'),
                                      ),
                                    );
                                  }
                                }
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      article['title'] as String,
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: -0.3,
                                        height: 1.4,
                                        color:
                                            isDark
                                                ? Colors.white
                                                : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                        horizontal: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            isDark
                                                ? Colors.white.withOpacity(0.03)
                                                : Colors.grey.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        article['summary'] as String,
                                        style: TextStyle(
                                          fontSize: 15,
                                          color:
                                              isDark
                                                  ? Colors.white70
                                                  : Colors.black87,
                                          height: 1.5,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getSentimentColor(
                                              article['sentiment'] as String,
                                            ).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: _getSentimentColor(
                                                article['sentiment'] as String,
                                              ).withOpacity(0.2),
                                            ),
                                          ),
                                          child: Text(
                                            article['sentiment'] as String,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: _getSentimentColor(
                                                article['sentiment'] as String,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Icon(
                                          Icons.newspaper_rounded,
                                          size: 14,
                                          color:
                                              isDark
                                                  ? Colors.white60
                                                  : Colors.black45,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          article['source'] as String,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color:
                                                isDark
                                                    ? Colors.white60
                                                    : Colors.black45,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Icon(
                                          Icons.access_time_rounded,
                                          size: 14,
                                          color:
                                              isDark
                                                  ? Colors.white60
                                                  : Colors.black45,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          article['published_date'] as String,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color:
                                                isDark
                                                    ? Colors.white60
                                                    : Colors.black45,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, int count, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getCandidateColor(String candidate) {
    switch (candidate) {
      case '이재명':
        return const Color(0xFF4361EE);
      case '김문수':
        return const Color(0xFFE63946);
      case '이준석':
        return const Color(0xFFFF9F1C);
      default:
        return Colors.grey;
    }
  }

  Color _getSentimentFilterColor(String sentiment) {
    switch (sentiment.trim()) {
      case "긍정":
        return const Color(0xFF4CAF50);
      case "부정":
        return const Color(0xFFF44336);
      case "중립":
        return const Color(0xFF607D8B);
      default:
        return const Color(0xFF4361EE);
    }
  }
}
