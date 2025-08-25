import 'package:flutter_sample_networking/core/error_types.dart';
import 'package:flutter_sample_networking/data/api_client.dart';
import 'package:flutter_sample_networking/data/models/post.dart';

class Result<T> {
  final T? data;
  final AppError? error;

  const Result._({this.data, this.error});

  factory Result.success(T data) => Result._(data: data);
  factory Result.failure(AppError error) => Result._(error: error);

  bool get isSuccess => data != null;
}

class Repository {
  final ApiClient _client;
  Repository(this._client);

  Future<Result<List<Post>>> getPosts() async {
    try {
      final list = await _client.fetchPosts();
      return Result.success(list);
    } on AppError catch (e) {
      return Result.failure(e);
    } catch (e) {
      return Result.failure(AppError(type: AppErrorType.unknown, message: e.toString(), raw: e));
    }
  }
}
