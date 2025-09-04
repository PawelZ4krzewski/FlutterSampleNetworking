import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sample_networking/bench/bench_runner.dart';
import 'package:flutter_sample_networking/core/app_config.dart';
import 'package:flutter_sample_networking/data/api_client.dart';

class BenchScreen extends StatefulWidget {
  const BenchScreen({super.key});

  @override
  State<BenchScreen> createState() => _BenchScreenState();
}

class _BenchScreenState extends State<BenchScreen> {
  final _baseUrlController = TextEditingController();
  final _pathController = TextEditingController(text: '/posts');
  final _runsController = TextEditingController(text: '20');
  final _connectTimeoutController = TextEditingController();
  final _sendTimeoutController = TextEditingController();
  final _receiveTimeoutController = TextEditingController();

  bool _warmup = true;
  bool _enableRetry = false;
  bool _isRunning = false;
  BenchSummary? _lastResult;

  @override
  void initState() {
    super.initState();
    _baseUrlController.text = AppConfig.baseUrl;
    _connectTimeoutController.text =
        AppConfig.connectTimeout.inMilliseconds.toString();
    _sendTimeoutController.text =
        AppConfig.sendTimeout.inMilliseconds.toString();
    _receiveTimeoutController.text =
        AppConfig.receiveTimeout.inMilliseconds.toString();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _pathController.dispose();
    _runsController.dispose();
    _connectTimeoutController.dispose();
    _sendTimeoutController.dispose();
    _receiveTimeoutController.dispose();
    super.dispose();
  }

  Future<void> _runBench() async {
    final runs = int.tryParse(_runsController.text) ?? 20;
    final connectMs = int.tryParse(_connectTimeoutController.text);
    final sendMs = int.tryParse(_sendTimeoutController.text);
    final receiveMs = int.tryParse(_receiveTimeoutController.text);
    final baseUrl = _baseUrlController.text.trim();

    if (baseUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('BASE_URL nie może być pusty')),
      );
      return;
    }

    setState(() {
      _isRunning = true;
      _lastResult = null;
    });

    try {
      // Create ApiClient with custom base URL for this bench run
      final customApiClient = ApiClient.withBaseUrl(baseUrl);
      final runner = BenchRunner();
      final result = await runner.run(
        client: customApiClient,
        path: _pathController.text,
        runs: runs,
        warmup: _warmup,
        connectTimeout:
            connectMs != null ? Duration(milliseconds: connectMs) : null,
        sendTimeout: sendMs != null ? Duration(milliseconds: sendMs) : null,
        receiveTimeout:
            receiveMs != null ? Duration(milliseconds: receiveMs) : null,
        enableRetryOverride: _enableRetry,
      );

      setState(() {
        _lastResult = result;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bench failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRunning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bench')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _baseUrlController,
                      decoration: const InputDecoration(labelText: 'BASE_URL'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _pathController,
                      decoration: const InputDecoration(labelText: 'PATH'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _runsController,
                      decoration: const InputDecoration(labelText: 'Runs (N)'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: _warmup,
                      onChanged: (v) => setState(() => _warmup = v ?? true),
                      title: const Text('Warm-up (discard 1st)'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _connectTimeoutController,
                            decoration: const InputDecoration(
                                labelText: 'Connect timeout (ms)'),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _sendTimeoutController,
                            decoration: const InputDecoration(
                                labelText: 'Send timeout (ms)'),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _receiveTimeoutController,
                            decoration: const InputDecoration(
                                labelText: 'Receive timeout (ms)'),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: _enableRetry,
                      onChanged: (v) => setState(() => _enableRetry = v),
                      title: const Text('Enable retry'),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isRunning ? null : _runBench,
                      child: _isRunning
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 8),
                                Text('Running...'),
                              ],
                            )
                          : const Text('Run'),
                    ),
                  ],
                ),
              ),
            ),

            if (_lastResult != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Results',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),

                      Text('Count: ${_lastResult!.count}'),
                      Text('Min: ${_lastResult!.minMs}ms'),
                      Text('Max: ${_lastResult!.maxMs}ms'),
                      Text('Median: ${_lastResult!.medianMs}ms'),
                      Text('P95: ${_lastResult!.p95Ms}ms'),

                      if (_lastResult!.errorCounts.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Errors:',
                            style: Theme.of(context).textTheme.titleSmall),
                        ..._lastResult!.errorCounts.entries.map(
                          (e) => Text('${e.key.name}: ${e.value}'),
                        ),
                      ],

                      if (_lastResult!.payloadPreview.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Preview:',
                            style: Theme.of(context).textTheme.titleSmall),
                        Text(_lastResult!.payloadPreview),
                      ],

                      const SizedBox(height: 16),

                      Text('Attempts:',
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 300, // Fixed height to prevent overflow
                        child: ListView.builder(
                          itemCount: _lastResult!.attempts.length,
                          itemBuilder: (context, index) {
                            final attempt = _lastResult!.attempts[index];
                            return ListTile(
                              dense: true,
                              leading: Text('${index + 1}'),
                              title: Text('${attempt.durationMs}ms'),
                              trailing: attempt.errorType != null
                                  ? Text(attempt.errorType!.name,
                                      style: const TextStyle(color: Colors.red))
                                  : Text('${attempt.status ?? ""}',
                                      style:
                                          const TextStyle(color: Colors.green)),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
