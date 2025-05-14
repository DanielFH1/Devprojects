import 'package:flutter/material.dart';

class CandidateDetailPage extends StatelessWidget {
  final String candidateName;
  final Color color;
  final String pledgeUrl;
  final List<String> pledgeSummary;
  final List<Map<String, String>> newsList;

  const CandidateDetailPage({
    super.key,
    required this.candidateName,
    required this.color,
    required this.pledgeUrl,
    required this.pledgeSummary,
    required this.newsList,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Colors.grey[900] : Colors.white;
    final borderColor = isDark ? Colors.grey[700] : Colors.grey[300];
    final shadowColor = isDark ? Colors.black26 : Colors.black12;

    return Scaffold(
      appBar: AppBar(title: Text('$candidateName 상세'), backgroundColor: color),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '$candidateName 공식 공약',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => {}, // TODO: 링크 열기
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.indigo[900] : Colors.indigo[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.link, color: color, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      '공식 공약 페이지 바로가기',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...pledgeSummary.map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text('• $e', style: const TextStyle(fontSize: 15)),
            ),
          ),
          const Divider(height: 32),
          Text(
            '관련 뉴스',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          ...newsList.map(
            (news) => _HoverCard(
              child: ListTile(
                title: Text(
                  news['title'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(news['summary'] ?? ''),
                trailing: Text(news['sentiment'] ?? ''),
                onTap: () {}, // TODO: 뉴스 원문 링크 열기
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
  const _HoverCard({required this.child});
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
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color:
              _hovering
                  ? (isDark ? Colors.indigo[800] : Colors.indigo[50])
                  : (isDark ? Colors.grey[900] : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          ),
          boxShadow:
              _hovering
                  ? [
                    BoxShadow(
                      color: Colors.indigo.withAlpha(31),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : [
                    BoxShadow(
                      color: Colors.black.withAlpha(31),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 120),
          style: TextStyle(
            fontSize: _hovering ? 16 : 15,
            fontWeight: FontWeight.w500,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
