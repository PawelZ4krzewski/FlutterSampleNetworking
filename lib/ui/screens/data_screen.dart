import 'package:flutter/material.dart';

import 'package:flutter_sample_networking/core/app_config.dart';
import 'package:flutter_sample_networking/core/error_types.dart';
import 'package:flutter_sample_networking/data/api_client.dart';
import 'package:flutter_sample_networking/data/models/post.dart';
import 'package:flutter_sample_networking/domain/repository.dart';
import 'package:flutter_sample_networking/ui/widgets/error_view.dart';

class DataScreen extends StatefulWidget {
  const DataScreen({super.key});

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  final Repository _repository = Repository(ApiClient());

  bool _loading = true;
  List<Post> _items = const [];
  AppError? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _items = const [];
    });
    final result = await _repository.getPosts();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.isSuccess) {
        _items = result.data!;
        AppConfig.log('DataScreen status=success count=${_items.length}');
      } else {
        _error = result.error;
        AppConfig.log('DataScreen status=error type=${_error!.type}');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DataScreen – Flutter')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ErrorView(
        message: _humanMessage(_error!),
        onRetry: _load,
      );
    }
    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final p = _items[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(p.body, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        );
      },
    );
  }

  String _humanMessage(AppError error) {
    switch (error.type) {
      case AppErrorType.offline:
        return 'Jesteś offline. Sprawdź połączenie internetowe.';
      case AppErrorType.timeout:
        return 'Przekroczono czas oczekiwania na odpowiedź.';
      case AppErrorType.client4xx:
        return 'Błąd po stronie klienta (${error.statusCode ?? ''}).';
      case AppErrorType.server5xx:
        return 'Błąd serwera (${error.statusCode ?? ''}).';
      case AppErrorType.cancel:
        return 'Żądanie anulowane.';
      case AppErrorType.unknown:
        return 'Nieznany błąd. Spróbuj ponownie.';
    }
  }
}
