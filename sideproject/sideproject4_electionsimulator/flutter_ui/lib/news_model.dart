class NewsItem {
  final String title;
  final String description;
  final String summary;
  final String sentiment;
  final String url;
  final String publishedDate;
  final String source;
  final String query;

  NewsItem({
    required this.title,
    required this.description,
    required this.summary,
    required this.sentiment,
    required this.url,
    required this.publishedDate,
    required this.source,
    required this.query,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    return NewsItem(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      summary: json['summary'] ?? '',
      sentiment: json['sentiment'] ?? '중립',
      url: json['url'] ?? '',
      publishedDate: json['published_date'] ?? '',
      source: json['source'] ?? '',
      query: json['query'] ?? '',
    );
  }
}
