import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sample_networking/bench/bench_runner.dart';
import 'package:flutter_sample_networking/bench/bench_presets.dart';
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
  final _runsController = TextEditingController(text: '30');
  final _connectTimeoutController = TextEditingController();
  final _sendTimeoutController = TextEditingController();
  final _receiveTimeoutController = TextEditingController();

  bool _warmup = true;
  bool _enableRetry = false;
  bool _isRunning = false;
  BenchSummary? _lastResult;
  bool _showAttempts = false;
  BenchPreset? _activePreset;
  List<(BenchPreset, BenchSummary)> _batchResults = [];

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
  final runs = int.tryParse(_runsController.text) ?? 30;
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
  AppConfig.log('BENCH_SUMMARY: scenario=${_activePreset?.id} baseUrl=$baseUrl path=${_pathController.text} N=$runs median=${result.medianMs} p95=${result.p95Ms} min=${result.minMs} max=${result.maxMs} errors=${result.errorCounts}');
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

  Future<void> _runAllPresets() async {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
      _batchResults = [];
      _lastResult = null;
    });
    for (final preset in kBenchPresets) {
      try {
        setState(() {
          _activePreset = preset;
          _baseUrlController.text = preset.baseUrl;
          _pathController.text = preset.path;
          _connectTimeoutController.text = preset.connectTimeoutMs.toString();
          _sendTimeoutController.text = preset.sendTimeoutMs.toString();
          _receiveTimeoutController.text = preset.receiveTimeoutMs.toString();
          _enableRetry = preset.enableRetry;
          _warmup = true;
        });
        final customClient = ApiClient.withBaseUrl(preset.baseUrl);
        final runner = BenchRunner();
        final summary = await runner.run(
          client: customClient,
          path: preset.path,
          runs: int.tryParse(_runsController.text) ?? 30,
          warmup: _warmup,
          connectTimeout: Duration(milliseconds: preset.connectTimeoutMs),
          sendTimeout: Duration(milliseconds: preset.sendTimeoutMs),
          receiveTimeout: Duration(milliseconds: preset.receiveTimeoutMs),
          enableRetryOverride: preset.enableRetry,
        );
        AppConfig.log('BENCH_SUMMARY: scenario=${preset.id} baseUrl=${preset.baseUrl} path=${preset.path} N=${summary.count} median=${summary.medianMs} p95=${summary.p95Ms} min=${summary.minMs} max=${summary.maxMs} errors=${summary.errorCounts}');
        setState(() {
          _batchResults.add((preset, summary));
          _lastResult = summary; // allow export buttons to activate with latest summary
        });
      } catch (e) {
        AppConfig.log('BENCH_SUMMARY: scenario=${preset.id} failed error=$e');
      }
    }
    setState(() {
      _isRunning = false;
    });
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kBenchPresets.map((p) {
                final selected = _activePreset?.id == p.id;
                return ChoiceChip(
                  label: Text(p.title),
                  selected: selected,
                  onSelected: (v) {
                    if (v) {
                      setState(() {
                        _activePreset = p;
                        _baseUrlController.text = p.baseUrl;
                        _pathController.text = p.path;
                        _connectTimeoutController.text = p.connectTimeoutMs.toString();
                        _sendTimeoutController.text = p.sendTimeoutMs.toString();
                        _receiveTimeoutController.text = p.receiveTimeoutMs.toString();
                        _enableRetry = p.enableRetry;
                        _warmup = true;
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
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
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _isRunning ? null : _runAllPresets,
                      child: const Text('Run All (S1–S6)'),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 4.0,
                      children: [
                        TextButton(
                          onPressed: (_lastResult == null) ? null : () {
                            final meta = _buildMeta();
                            final csv = buildCsv(_lastResult!, meta);
                            _showExportDialog('CSV', csv);
                          },
                          child: const Text('Copy CSV'),
                        ),
                        TextButton(
                          onPressed: (_lastResult == null) ? null : () {
                            final meta = _buildMeta();
                            final md = buildMarkdown(_lastResult!, meta);
                            _showExportDialog('Markdown', md);
                          },
                          child: const Text('Copy MD'),
                        ),
                        FilterChip(
                          label: Text(_showAttempts ? 'Hide attempts' : 'Show attempts'),
                          selected: _showAttempts,
                          onSelected: (v) => setState(() => _showAttempts = v),
                        ),
                      ],
                    ),
                    if (_batchResults.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          children: [
                            TextButton(
                              onPressed: _logBatchCsv,
                              child: const Text('Log Batch CSV'),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: _clearBatchResults,
                              child: const Text('Clear Batch Results'),
                            ),
                          ],
                        ),
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
                      if (_showAttempts) SizedBox(
                        height: 300,
                        child: ListView.separated(
                          itemCount: _lastResult!.attempts.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final attempt = _lastResult!.attempts[index];
                            return ListTile(
                              dense: true,
                              leading: Text('${index + 1}'),
                              title: Text('${attempt.durationMs}ms'),
                              subtitle: attempt.errorType != null ? Text(attempt.errorType!.name) : null,
                              trailing: Text(
                                attempt.status?.toString() ?? '',
                                style: TextStyle(color: attempt.errorType == null ? Colors.green : Colors.red),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (_batchResults.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Batch Results (S1–S6)', style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Scenario')),
                            DataColumn(label: Text('N')),
                            DataColumn(label: Text('Median')),
                            DataColumn(label: Text('P95')),
                            DataColumn(label: Text('Min')),
                            DataColumn(label: Text('Max')),
                            DataColumn(label: Text('Errors')),
                          ],
                          rows: _batchResults.map((record) {
                            final preset = record.$1;
                            final s = record.$2;
                            return DataRow(cells: [
                              DataCell(Text(preset.title)),
                              DataCell(Text('${s.count}')),
                              DataCell(Text('${s.medianMs}ms')),
                              DataCell(Text('${s.p95Ms}ms')),
                              DataCell(Text('${s.minMs}')),
                              DataCell(Text('${s.maxMs}')),
                              DataCell(Text(s.errorCounts.isEmpty ? '0' : s.errorCounts.toString())),
                            ]);
                          }).toList(),
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

  Map<String, String> _buildMeta() {
    return {
      'tool': 'flutter',
      'platform': Theme.of(context).platform.name,
      'baseUrl': _baseUrlController.text,
      'path': _pathController.text,
      'N': (_lastResult?.count ?? 0).toString(),
      'warmup': _warmup.toString(),
      'retry': _enableRetry.toString(),
      'ua': 'NetBench/1.0',
      'ts': DateTime.now().millisecondsSinceEpoch.toString(),
    };
  }

  void _showExportDialog(String label, String content) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(label),
        content: SizedBox(
          width: 400,
          child: SelectableText(content, style: const TextStyle(fontSize: 12)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
        ],
      ),
    );
  }

  void _logBatchCsv() {
    if (_batchResults.isEmpty) return;
    final b = StringBuffer();
    b.writeln('scenario,N,median,p95,min,max,errors');
    for (final record in _batchResults) {
      final preset = record.
          $1; // BenchPreset
      final s = record.$2; // BenchSummary
      b.writeln('${preset.title},${s.count},${s.medianMs},${s.p95Ms},${s.minMs},${s.maxMs},${s.errorCounts.isEmpty ? 0 : s.errorCounts}');
    }
    AppConfig.log('BATCH_RESULTS_CSV:\n${b.toString().trim()}');
  }

  void _clearBatchResults() {
    setState(() {
      _batchResults = [];
    });
    AppConfig.log('BATCH_RESULTS_CSV_CLEARED');
  }
}
