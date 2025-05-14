class NewsItem {
  final String title;
  final String description;
  final String summary;
  final String sentiment;
  final String url;

  NewsItem({
    required this.title,
    required this.description,
    required this.summary,
    required this.sentiment,
    required this.url,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    return NewsItem(
      title: json['title'],
      description: json['description'],
      summary: json['summary'],
      sentiment: json['sentiment'],
      url: json['url'],
    );
  }
}
