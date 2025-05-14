import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class CandidatePieChart extends StatefulWidget {
  final String candidateName;
  final Map<String, int> sentimentData;
  final Color? hoverColor;
  final VoidCallback? onTap;

  const CandidatePieChart({
    super.key,
    required this.candidateName,
    required this.sentimentData,
    this.hoverColor,
    this.onTap,
  });

  @override
  State<CandidatePieChart> createState() => _CandidatePieChartState();
}

class _CandidatePieChartState extends State<CandidatePieChart> {
  int? touchedIndex;
  bool _hovering = false;

  static const sentimentLabels = ['긍정', '중립', '부정'];
  static const sentimentColors = [
    Color(0xFF4CAF50), // 긍정: 초록
    Color(0xFFBDBDBD), // 중립: 회색
    Color(0xFFF44336), // 부정: 빨강
  ];

  Color getPartyColor(String candidate) {
    switch (candidate) {
      case '이재명':
        return const Color(0xFF1877F2); // 민주당 파랑
      case '김문수':
        return const Color(0xFFEF3340); // 국민의힘 빨강
      case '이준석':
        return const Color(0xFFFF9900); // 개혁신당 주황
      default:
        return Colors.grey;
    }
  }

  Color getSentimentColor(String candidate, String sentiment) {
    final base = getPartyColor(candidate);
    switch (sentiment) {
      case '긍정':
        return base.withAlpha(217);
      case '중립':
        return base.withAlpha(115);
      case '부정':
        return base.withAlpha(166);
      default:
        return Colors.grey;
    }
  }

  double getTotal() {
    return widget.sentimentData.values.fold(0, (sum, e) => sum + e);
  }

  @override
  Widget build(BuildContext context) {
    final total = sentimentLabels.fold(
      0,
      (sum, label) => sum + (widget.sentimentData[label] ?? 0),
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF232A36) : Colors.white;
    final borderColor = isDark ? Colors.grey[800] : Colors.grey[200];
    final shadowColor = isDark ? Colors.black26 : Colors.black12;
    final hoverColor = widget.hoverColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color:
                  _hovering && hoverColor != null
                      ? hoverColor.withAlpha(isDark ? 217 : 46)
                      : cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor ?? Colors.grey),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.candidateName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color:
                          _hovering && hoverColor != null
                              ? Colors.white
                              : (isDark ? Colors.white : Colors.black),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 120,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 1.5,
                        centerSpaceRadius: 28,
                        pieTouchData: PieTouchData(enabled: false),
                        sections: List.generate(sentimentLabels.length, (
                          index,
                        ) {
                          final label = sentimentLabels[index];
                          final value = widget.sentimentData[label] ?? 0;
                          final percent =
                              total == 0
                                  ? 0
                                  : (value / total * 100).toStringAsFixed(1);
                          final color = sentimentColors[index].withAlpha(204);
                          return PieChartSectionData(
                            color: color,
                            value: value.toDouble(),
                            radius: 38,
                            title: value == 0 ? '' : '$percent%',
                            titleStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(color: Colors.black26, blurRadius: 2),
                              ],
                            ),
                            titlePositionPercentageOffset: 0.62,
                            borderSide: BorderSide(
                              color: Colors.white.withAlpha(179),
                              width: 2,
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(sentimentLabels.length, (i) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 13,
                              height: 13,
                              decoration: BoxDecoration(
                                color: sentimentColors[i],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              sentimentLabels[i],
                              style: TextStyle(
                                fontSize: 13,
                                color:
                                    _hovering && hoverColor != null
                                        ? Colors.white
                                        : (isDark
                                            ? Colors.grey[200]
                                            : Colors.grey[800]),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
