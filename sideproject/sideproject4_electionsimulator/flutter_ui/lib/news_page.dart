import 'dart:convert';
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
  final VoidCallback? onToggleTheme;
  final ThemeMode? themeMode;
  final VoidCallback? onNavigatePrediction;
  const NewsPage({
    super.key,
    this.onToggleTheme,
    this.themeMode,
    this.onNavigatePrediction,
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
  String selectedSentiment = '전체';
  Map<String, bool> _hoveringStates = {}; // 각 후보별 hover 상태를 저장

  @override
  void initState() {
    super.initState();
    fetchNewsData();
  }

  Future<void> fetchNewsData() async {
    try {
      final response = await http.get(Uri.parse('/news'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print(data); // API 응답 로그 출력

        final List<dynamic> newsJson = data['news'];
        final summary = data['trend_summary'];
        final stats = data['candidate_stats'];

        if (stats == null) {
          print('candidate_stats is null'); // null 체크 로그
        } else {
          print('candidate_stats: $stats'); // stats 로그 출력
        }

        setState(() {
          newsList = newsJson.map((item) => NewsItem.fromJson(item)).toList();
          trendSummary = summary;
          candidateStats = stats ?? {};
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

  List<NewsItem> _getFilteredNews() {
    if (selectedSentiment == '전체') return newsList;
    return newsList
        .where((item) => item.sentiment == selectedSentiment)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredNews = _getFilteredNews();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appBarColor = isDark ? const Color(0xFF232A36) : Colors.white;
    final candidateList = candidateStats.entries.toList();

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF181C23) : const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF232A36) : Colors.white,
        elevation: isDark ? 0.5 : 2, // 라이트모드에서 그림자 강화
        shadowColor: isDark ? Colors.black26 : Colors.black12, // 그림자 색상 추가
        surfaceTintColor: isDark ? null : Colors.white, // 라이트모드에서 표면 색상 설정
        title: Text(
          '대선 뉴스 시뮬레이터',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: -1,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.bar_chart, size: 20),
              label: const Text(
                'AI 예측',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber[700],
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
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
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
              color: isDark ? Colors.white : Colors.black87,
            ),
            onPressed: widget.onToggleTheme,
            tooltip: isDark ? '라이트모드' : '다크모드',
          ),
        ],
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : error != null
              ? Center(
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              )
              : ListView(
                padding: const EdgeInsets.symmetric(
                  vertical: 32,
                  horizontal: 0,
                ),
                children: [
                  // 후보별 감성 통계 (GridView로 3개 한 줄)
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: Card(
                        color: isDark ? const Color(0xFF232A36) : Colors.white,
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 24,
                            horizontal: 24,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text(
                                "📊 후보별 감성 통계",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: List.generate(candidateList.length, (
                                  i,
                                ) {
                                  final entry = candidateList[i];
                                  final name = entry.key;
                                  final data = Map<String, int>.from(
                                    entry.value,
                                  );
                                  // 후보별 대표색, 공약 URL, 더미 공약 요약, 관련 뉴스 리스트 정의
                                  Color color;
                                  String pledgeUrl;
                                  List<String> pledgeSummary;
                                  switch (name) {
                                    case '이재명':
                                      color = const Color(0xFF1877F2);
                                      pledgeUrl =
                                          'https://theminjoo.kr/main/sub/news/list.php?sno=0&par=&&par=&brd=254';
                                      pledgeSummary = [
                                        '기본소득 도입',
                                        '부동산 개혁',
                                        '공정사회 실현',
                                      ];
                                      break;
                                    case '김문수':
                                      color = const Color(0xFFEF3340);
                                      pledgeUrl =
                                          'https://2025victory.kr/sub/?h_page=promise';
                                      pledgeSummary = [
                                        '경제 성장',
                                        '안보 강화',
                                        '복지 확대',
                                      ];
                                      break;
                                    case '이준석':
                                      color = const Color(0xFFFF9900);
                                      pledgeUrl =
                                          'https://www.reformparty.kr/policy';
                                      pledgeSummary = [
                                        '청년 정책',
                                        '정치 개혁',
                                        '미래산업 육성',
                                      ];
                                      break;
                                    default:
                                      color = Colors.grey;
                                      pledgeUrl = '';
                                      pledgeSummary = [];
                                  }
                                  final candidateNews =
                                      newsList
                                          .where(
                                            (n) =>
                                                n.title.contains(name) ||
                                                n.summary.contains(name),
                                          )
                                          .map(
                                            (n) => {
                                              'title': n.title,
                                              'summary': n.summary,
                                              'sentiment': n.sentiment,
                                            },
                                          )
                                          .toList();
                                  return Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (context) =>
                                                    CandidateDetailPage(
                                                      candidateName: name,
                                                      color: color,
                                                      pledgeUrl: pledgeUrl,
                                                      pledgeSummary:
                                                          pledgeSummary,
                                                      newsList: candidateNews,
                                                    ),
                                          ),
                                        );
                                      },
                                      child: MouseRegion(
                                        onEnter:
                                            (_) => setState(
                                              () =>
                                                  _hoveringStates[name] = true,
                                            ),
                                        onExit:
                                            (_) => setState(
                                              () =>
                                                  _hoveringStates[name] = false,
                                            ),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 120,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                _hoveringStates[name] == true &&
                                                        color != null
                                                    ? color.withAlpha(
                                                      isDark ? 217 : 46,
                                                    )
                                                    : _getCardColor(name),
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            border: Border.all(
                                              color: Colors.grey,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black26,
                                                blurRadius: 4,
                                                offset: const Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                          child: CandidatePieChart(
                                            candidateName: name,
                                            sentimentData: data,
                                            hoverColor: color,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                              const SizedBox(height: 24),
                              // 여론 흐름 요약 (마크다운 bold → TextSpan 강조)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color:
                                      isDark
                                          ? const Color(0xFF1A1E26)
                                          : const Color(0xFFF3F6FA),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: _MarkdownSummary(
                                  trendSummary: trendSummary,
                                  isDark: isDark,
                                ),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '📰 최신 뉴스',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...filteredNews.map(
                            (news) => _HoverCard(
                              child: Card(
                                color: _getCardColor(news.sentiment),
                                elevation: 1,
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: ListTile(
                                  title: Text(
                                    news.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                  subtitle: Text(
                                    news.summary,
                                    style: TextStyle(
                                      color:
                                          isDark
                                              ? Colors.white70
                                              : Colors.black87,
                                    ),
                                  ),
                                  trailing: Text(
                                    news.sentiment,
                                    style: TextStyle(
                                      color:
                                          news.sentiment == '긍정'
                                              ? Colors.green
                                              : news.sentiment == '부정'
                                              ? Colors.red
                                              : Colors.grey,
                                    ),
                                  ),
                                  onTap: () {
                                    _launchUrl(news.url);
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
    );
  }
}

class _HoverCard extends StatefulWidget {
  final Widget child;
  final Color? hoverColor;
  const _HoverCard({required this.child, this.hoverColor});
  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool _hovering = false;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        transform:
            _hovering
                ? (Matrix4.identity()..scale(1.015, 1.015))
                : Matrix4.identity(),
        decoration:
            widget.hoverColor != null && _hovering
                ? BoxDecoration(
                  color: widget.hoverColor!.withOpacity(isDark ? 0.7 : 0.13),
                  borderRadius: BorderRadius.circular(16),
                )
                : null,
        child: widget.child,
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
