class Post {
  final int id;
  final String title;
  final String body;

  const Post({required this.id, required this.title, required this.body});

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: (json['id'] is String)
          ? int.tryParse(json['id'] as String) ?? 0
          : (json['id'] ?? 0) as int,
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
      };
}
