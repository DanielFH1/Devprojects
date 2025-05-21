import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class CandidateDetailPage extends StatefulWidget {
  final String candidate;
  final List<Map<String, dynamic>> news;
  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;

  const CandidateDetailPage({
    super.key,
    required this.candidate,
    required this.news,
    required this.themeMode,
    required this.onToggleTheme,
  });

  @override
  State<CandidateDetailPage> createState() => _CandidateDetailPageState();
}

class _CandidateDetailPageState extends State<CandidateDetailPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  String _selectedSentiment = '전체';
  final List<String> _sentimentFilters = ['전체', '긍정', '중립', '부정'];
  bool _isHoveringPledge = false;

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
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('링크를 열 수 없습니다.')));
      }
    }
  }

  String _getPledgeUrl(String candidate) {
    switch (candidate) {
      case '이재명':
        return 'https://www.begintruekorea.com/15';
      case '김문수':
        return 'https://www.peoplepowerparty.kr/news/policy_promotion_view/106687';
      case '이준석':
        return 'https://www.reformparty.kr/policy/28';
      default:
        return '';
    }
  }

  Color _getCandidateColor(String candidate) {
    switch (candidate) {
      case '이재명':
        return const Color(0xFF1877F2);
      case '김문수':
        return const Color(0xFFEF3340);
      case '이준석':
        return const Color(0xFFFF9900);
      default:
        return Colors.grey;
    }
  }

  List<Map<String, dynamic>> _getFilteredNews() {
    if (_selectedSentiment == '전체') return widget.news;
    return widget.news
        .where((article) => article['sentiment'] == _selectedSentiment)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final candidateColor = _getCandidateColor(widget.candidate);
    final pledgeUrl = _getPledgeUrl(widget.candidate);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF181C23) : const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF232A36) : Colors.white,
        elevation: isDark ? 0.5 : 2,
        shadowColor: isDark ? Colors.black26 : Colors.black12,
        surfaceTintColor: isDark ? null : Colors.white,
        title: Text(
          '${widget.candidate} 후보 상세 정보',
          style: TextStyle(
            fontSize: isMobile ? 18 : 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 후보 정보 카드
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
                                Hero(
                                  tag: 'candidate_${widget.candidate}',
                                  child: Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: candidateColor.withValues(
                                        alpha: 0.1,
                                      ),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: candidateColor,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: candidateColor.withValues(
                                            alpha: 0.2,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        widget.candidate[0],
                                        style: TextStyle(
                                          fontSize: 36,
                                          fontWeight: FontWeight.bold,
                                          color: candidateColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.candidate,
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '대선 후보',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color:
                                              isDark
                                                  ? Colors.white70
                                                  : Colors.black54,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            // 공식 공약 페이지 링크
                            MouseRegion(
                              onEnter:
                                  (_) =>
                                      setState(() => _isHoveringPledge = true),
                              onExit:
                                  (_) =>
                                      setState(() => _isHoveringPledge = false),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                transform:
                                    Matrix4.identity()..translate(
                                      0.0,
                                      _isHoveringPledge ? -2.0 : 0.0,
                                    ),
                                child: InkWell(
                                  onTap: () => _launchUrl(pledgeUrl),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: candidateColor.withValues(
                                        alpha: isDark ? 0.15 : 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: candidateColor.withValues(
                                          alpha: isDark ? 0.4 : 0.3,
                                        ),
                                        width: _isHoveringPledge ? 1.5 : 1,
                                      ),
                                      boxShadow:
                                          _isHoveringPledge
                                              ? [
                                                BoxShadow(
                                                  color: candidateColor
                                                      .withValues(alpha: 0.1),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ]
                                              : null,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.policy_outlined,
                                              color: candidateColor,
                                              size: 22,
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              '공식 공약 페이지',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    isDark
                                                        ? Colors.white
                                                        : Colors.black87,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          color: candidateColor,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // 감성 필터
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
                                  ),
                                  backgroundColor:
                                      isDark
                                          ? const Color(0xFF2A2F3A)
                                          : Colors.grey[100],
                                  selectedColor: _getSentimentColor(sentiment),
                                  checkmarkColor: Colors.white,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(
                                        () => _selectedSentiment = sentiment,
                                      );
                                    }
                                  },
                                ),
                              );
                            }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // 관련 뉴스 목록
                    Text(
                      '관련 뉴스',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._getFilteredNews().map((article) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Hero(
                          tag: 'news_${article['url']}',
                          child: Card(
                            color:
                                isDark ? const Color(0xFF232A36) : Colors.white,
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: InkWell(
                              onTap: () => _launchUrl(article['url'] as String),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      article['title'] as String,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -0.3,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      article['summary'] as String,
                                      style: TextStyle(
                                        fontSize: 15,
                                        color:
                                            isDark
                                                ? Colors.white70
                                                : Colors.black87,
                                        height: 1.5,
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
                                            ).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(
                                              10,
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
                                          Icons.newspaper_outlined,
                                          size: 14,
                                          color:
                                              isDark
                                                  ? Colors.white60
                                                  : Colors.black54,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          article['source'] as String,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color:
                                                isDark
                                                    ? Colors.white60
                                                    : Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Icon(
                                          Icons.access_time_rounded,
                                          size: 14,
                                          color:
                                              isDark
                                                  ? Colors.white60
                                                  : Colors.black54,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          article['published_date'] as String,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color:
                                                isDark
                                                    ? Colors.white60
                                                    : Colors.black54,
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
}
