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

class NewsPage extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final ThemeMode themeMode;
  final VoidCallback onNavigatePrediction;

  const NewsPage({
    super.key,
    required this.onToggleTheme,
    required this.themeMode,
    required this.onNavigatePrediction,
  });

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  List<NewsItem> newsList = [];
  String trendSummary = "";
  bool isLoading = true;
  String? error;
  Map<String, dynamic> candidateStats = {};
  String timeRange = "";
  int totalArticles = 0;
  String selectedSentiment = '전체';
  Map<String, bool> _hoveringStates = {};

  @override
  void initState() {
    super.initState();
    fetchNewsData();
  }

  Future<void> fetchNewsData() async {
    try {
      final uri = Uri.base.resolve('/news'); // 상대 경로로 변경
      final response = await http
          .get(uri)
          .timeout(
            const Duration(seconds: 10), // 타임아웃 설정
            onTimeout: () {
              throw TimeoutException('서버 응답 시간이 초과되었습니다.');
            },
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newsData = data['data'];

        if (newsData == null) {
          throw Exception('뉴스 데이터가 없습니다.');
        }

        setState(() {
          trendSummary = newsData['trend_summary'] ?? '데이터를 수집 중입니다...';
          candidateStats = Map<String, dynamic>.from(
            newsData['candidate_stats'] ?? {},
          );
          timeRange = newsData['time_range'] ?? '';
          totalArticles = newsData['total_articles'] ?? 0;

          // 뉴스 리스트 업데이트
          if (newsData['news_list'] != null) {
            newsList =
                (newsData['news_list'] as List)
                    .map((item) => NewsItem.fromJson(item))
                    .toList();
          } else {
            newsList = [];
          }

          isLoading = false;
          error = null;
        });
      } else {
        setState(() {
          error = '서버 오류: ${response.statusCode}';
          isLoading = false;
        });
      }
    } on TimeoutException {
      setState(() {
        error = '서버 응답 시간이 초과되었습니다. 잠시 후 다시 시도해주세요.';
        isLoading = false;
      });
    } on SocketException {
      setState(() {
        error = '서버에 연결할 수 없습니다. 서버가 실행 중인지 확인해주세요.';
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching news: $e'); // 디버깅용
      setState(() {
        error = '데이터 불러오기 실패: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("링크를 열 수 없습니다.")));
    }
  }

  Color _getCardColor(String sentiment) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (sentiment.trim()) {
      case "긍정":
        return isDark ? const Color(0xFF2E4732) : Colors.green[50]!;
      case "부정":
        return isDark ? const Color(0xFF4B2323) : Colors.red[50]!;
      case "중립":
      default:
        return isDark ? const Color(0xFF35363A) : Colors.grey[100]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final screenHeight = size.height;
    final isMobile = screenWidth < 600;
    final isSmallMobile = screenWidth < 360;
    // 화면 방향 감지
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    // 동적 크기 계산
    final titleFontSize = isMobile ? (isSmallMobile ? 18.0 : 20.0) : 22.0;
    final subtitleFontSize = isMobile ? (isSmallMobile ? 11.0 : 13.0) : 14.0;
    final contentPadding = EdgeInsets.symmetric(
      horizontal: isMobile ? screenWidth * 0.04 : 16.0,
      vertical: isMobile ? screenHeight * 0.02 : 32.0,
    );
    final cardBorderRadius = isMobile ? 12.0 : 18.0;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF181C23) : const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF232A36) : Colors.white,
        elevation: isDark ? 0.5 : 2,
        shadowColor: isDark ? Colors.black26 : Colors.black12,
        surfaceTintColor: isDark ? null : Colors.white,
        title: Text(
          isMobile ? '대선 시뮬레이터' : '2025__21대 대선 시뮬레이터',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: titleFontSize,
            letterSpacing: -1,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        actions: [
          if (!isSmallMobile) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 8),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.bar_chart, size: 20),
                label: Text(
                  'AI 예측',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 13 : 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber[700],
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shadowColor: Colors.black26,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 12 : 18,
                    vertical: isMobile ? 8 : 10,
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => PredictionPage(
                            themeMode: widget.themeMode,
                            onToggleTheme: widget.onToggleTheme,
                          ),
                    ),
                  );
                },
              ),
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.bar_chart),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => PredictionPage(
                          themeMode: widget.themeMode,
                          onToggleTheme: widget.onToggleTheme,
                        ),
                  ),
                );
              },
              tooltip: 'AI 예측',
            ),
          ],
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
              color: isDark ? Colors.white : Colors.black87,
            ),
            onPressed: widget.onToggleTheme,
            tooltip: isDark ? '라이트모드' : '다크모드',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showAboutDialog,
            tooltip: '웹사이트 정보',
          ),
        ],
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(isMobile ? 48 : 56),
          child: Container(
            padding: EdgeInsets.only(bottom: isMobile ? 8 : 12),
            child: Column(
              children: [
                Text(
                  '이 데이터는 $timeRange까지의 $totalArticles개의 기사를 취합한 결과입니다.',
                  style: TextStyle(
                    fontSize: subtitleFontSize,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  '데이터는 매일 오전 6시에 갱신됩니다.',
                  style: TextStyle(
                    fontSize: isSmallMobile ? 10 : 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.amber[200] : Colors.indigo,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : error != null
              ? Center(
                child: Text(
                  error!,
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: isMobile ? 14 : 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
              : ListView(
                padding: contentPadding,
                children: [
                  // 후보별 감성 통계
                  Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isMobile ? double.infinity : 1100,
                      ),
                      child: Card(
                        color: isDark ? const Color(0xFF232A36) : Colors.white,
                        elevation: 2,
                        margin: EdgeInsets.symmetric(
                          vertical: isMobile ? 4 : 8,
                          horizontal: isMobile ? 8 : 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(cardBorderRadius),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(isMobile ? 12 : 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '후보별 뉴스 감성 분석',
                                style: TextStyle(
                                  fontSize: isMobile ? 16 : 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 16),
                              GridView.count(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisCount:
                                    isPortrait ? (isMobile ? 1 : 2) : 3,
                                mainAxisSpacing: isMobile ? 12 : 16,
                                crossAxisSpacing: isMobile ? 0 : 16,
                                childAspectRatio: isMobile ? 2.5 : 2.0,
                                children:
                                    candidateStats.entries.map((entry) {
                                      final candidate = entry.key;
                                      final stats = entry.value;
                                      final total =
                                          (stats['긍정'] as int) +
                                          (stats['중립'] as int) +
                                          (stats['부정'] as int);
                                      return _buildCandidateCard(
                                        candidate,
                                        stats,
                                        total,
                                        isDark,
                                        isMobile,
                                      );
                                    }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // 뉴스 리스트
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Card(
                        color: isDark ? const Color(0xFF232A36) : Colors.white,
                        elevation: 1,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ExpansionTile(
                          title: Text(
                            '📊 취합된 뉴스 기사 목록 일부',
                            style: TextStyle(
                              fontSize: isMobile ? 18 : 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          children: [
                            ...newsList.map(
                              (news) => _NewsCard(
                                news: news,
                                isDark: isDark,
                                onTap: () => _launchUrl(news.url),
                                isMobile: isMobile,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildCandidateCard(
    String candidate,
    Map<String, dynamic> stats,
    int total,
    bool isDark,
    bool isMobile,
  ) {
    final positive = stats['긍정'] as int;
    final neutral = stats['중립'] as int;
    final negative = stats['부정'] as int;

    return Card(
      color: isDark ? const Color(0xFF2A2F3A) : Colors.grey[50],
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
        side: BorderSide(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => CandidateDetailPage(
                    candidate: candidate,
                    news:
                        newsList
                            .where(
                              (article) =>
                                  article.title.contains(candidate) ||
                                  article.summary.contains(candidate),
                            )
                            .map(
                              (article) => {
                                'title': article.title,
                                'summary': article.summary,
                                'url': article.url,
                                'published_date': article.publishedDate,
                                'source': article.source,
                                'sentiment': article.sentiment,
                              },
                            )
                            .toList(),
                    themeMode: widget.themeMode,
                    onToggleTheme: widget.onToggleTheme,
                  ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          candidate,
                          style: TextStyle(
                            fontSize: isMobile ? 16 : 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '총 $total개 기사',
                          style: TextStyle(
                            fontSize: isMobile ? 12 : 14,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: isDark ? Colors.white60 : Colors.black54,
                    size: isMobile ? 20 : 24,
                  ),
                ],
              ),
              if (total > 0) ...[
                SizedBox(height: isMobile ? 8 : 16),
                Wrap(
                  spacing: isMobile ? 4 : 8,
                  runSpacing: isMobile ? 4 : 8,
                  children: [
                    _buildStatChip(
                      '긍정',
                      positive,
                      Colors.green,
                      isDark,
                      isMobile,
                    ),
                    _buildStatChip(
                      '중립',
                      neutral,
                      Colors.grey,
                      isDark,
                      isMobile,
                    ),
                    _buildStatChip(
                      '부정',
                      negative,
                      Colors.red,
                      isDark,
                      isMobile,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(
    String label,
    int count,
    Color color,
    bool isDark,
    bool isMobile,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 12,
        vertical: isMobile ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: isDark ? color.withOpacity(0.2) : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: isMobile ? 8 : 10,
            height: isMobile ? 8 : 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: isMobile ? 4 : 6),
          Text(
            '$label $count',
            style: TextStyle(
              fontSize: isMobile ? 12 : 14,
              color: isDark ? color.withOpacity(0.9) : color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info_outline, size: 24),
              SizedBox(width: 8),
              Text('대선 예측 시뮬레이터 소개'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '대선 예측 시뮬레이터는 21대 대선 정보에 대한 접근성을 높이고, 시민들이 정치 정보를 더 쉽게 이해하고 분석할 수 있도록 돕기 위해 제작되었습니다.',
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 16),
              const Text(
                '주요 기능:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              _buildFeatureItem(Icons.analytics_outlined, 'AI 기반 뉴스 분석'),
              _buildFeatureItem(Icons.pie_chart_outline, '실시간 지지율 예측'),
              _buildFeatureItem(Icons.trending_up, '여론 트렌드 분석'),
              const SizedBox(height: 16),
              const Text(
                '피드백 & 제안사항',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () {
                  final Uri emailLaunchUri = Uri(
                    scheme: 'mailto',
                    path: 'daniel333@dgu.ac.kr',
                    queryParameters: {'subject': '대선 예측 시뮬레이터 피드백'},
                  );
                  launchUrl(emailLaunchUri);
                },
                child: Row(
                  children: [
                    const Icon(Icons.email_outlined, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'daniel333@dgu.ac.kr',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('닫기'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [Icon(icon, size: 20), const SizedBox(width: 8), Text(text)],
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  final NewsItem news;
  final bool isDark;
  final VoidCallback onTap;
  final bool isMobile;

  const _NewsCard({
    required this.news,
    required this.isDark,
    required this.onTap,
    required this.isMobile,
  });

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

  Color _getCandidateColor(String title, String summary) {
    if (title.contains('이재명') || summary.contains('이재명')) {
      return Colors.green;
    } else if (title.contains('김문수') || summary.contains('김문수')) {
      return Colors.grey;
    } else if (title.contains('이준석') || summary.contains('이준석')) {
      return Colors.red;
    }
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final candidateColor = _getCandidateColor(news.title, news.summary);
    final screenWidth = MediaQuery.of(context).size.width;
    final fontSize =
        screenWidth < 360 ? 13.0 : (screenWidth < 600 ? 14.0 : 15.0);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: isDark ? const Color(0xFF1A1E26) : Colors.grey[50],
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.04,
          vertical: screenWidth * 0.02,
        ),
        leading: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: candidateColor,
            shape: BoxShape.circle,
          ),
        ),
        title: Text(
          news.title,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              news.summary,
              style: TextStyle(
                fontSize: fontSize * 0.9,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _getSentimentColor(
                        news.sentiment,
                      ).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      news.sentiment,
                      style: TextStyle(
                        fontSize: fontSize * 0.8,
                        color: _getSentimentColor(news.sentiment),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    news.source,
                    style: TextStyle(
                      fontSize: fontSize * 0.8,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    news.publishedDate,
                    style: TextStyle(
                      fontSize: fontSize * 0.8,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

// 여론 흐름 요약 마크다운 bold → TextSpan 강조
class _MarkdownSummary extends StatelessWidget {
  final String trendSummary;
  final bool isDark;
  const _MarkdownSummary({required this.trendSummary, required this.isDark});
  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'(\*\*[^*]+\*\*)');
    final parts = trendSummary.split(regex);
    final matches = regex.allMatches(trendSummary).toList();
    int matchIdx = 0;
    for (final part in parts) {
      if (part.startsWith('**') && part.endsWith('**')) {
        spans.add(
          TextSpan(
            text: part.replaceAll('**', ''),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.amber[200] : Colors.indigo[900],
            ),
          ),
        );
        matchIdx++;
      } else {
        spans.add(
          TextSpan(
            text: part,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
        );
      }
    }
    return RichText(
      text: TextSpan(children: spans, style: const TextStyle(fontSize: 15)),
    );
  }
}
