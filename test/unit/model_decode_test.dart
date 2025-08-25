import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sample_networking/data/models/post.dart';

void main() {
  test('decode JSON -> Post', () {
    const raw = '{"id": 1, "title": "Hello", "body": "World"}';
    final map = json.decode(raw) as Map<String, dynamic>;
    final post = Post.fromJson(map);
    expect(post.id, 1);
    expect(post.title, 'Hello');
    expect(post.body, 'World');
  });
}
