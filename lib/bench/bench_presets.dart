// Bench scenario presets (S1-S6)
enum BenchScenario { s1Small, s2List, s3Error, s4Timeout, s5Offline, s6Headers }

class BenchPreset {
  final BenchScenario id;
  final String title;
  final String baseUrl;
  final String path;
  final int connectTimeoutMs;
  final int sendTimeoutMs;
  final int receiveTimeoutMs;
  final bool enableRetry;
  final String note;
  const BenchPreset({
    required this.id,
    required this.title,
    required this.baseUrl,
    required this.path,
    required this.connectTimeoutMs,
    required this.sendTimeoutMs,
    required this.receiveTimeoutMs,
    required this.enableRetry,
    required this.note,
  });
}

const _t8 = 8000;
const _t1 = 1000; // timeout scenario

const List<BenchPreset> kBenchPresets = [
  BenchPreset(
    id: BenchScenario.s1Small,
    title: 'S1 Small',
    baseUrl: 'https://dummyjson.com',
    path: '/posts/1',
    connectTimeoutMs: _t8,
    sendTimeoutMs: _t8,
    receiveTimeoutMs: _t8,
    enableRetry: false,
    note: 'Latency single small payload',
  ),
  BenchPreset(
    id: BenchScenario.s2List,
    title: 'S2 List',
    baseUrl: 'https://dummyjson.com',
    path: '/posts?limit=100',
    connectTimeoutMs: _t8,
    sendTimeoutMs: _t8,
    receiveTimeoutMs: _t8,
    enableRetry: false,
    note: 'List parsing',
  ),
  BenchPreset(
    id: BenchScenario.s3Error,
    title: 'S3 Error',
    baseUrl: 'https://httpbingo.org', // alternatywa https://httpbin.org
    path: '/status/500',
    connectTimeoutMs: _t8,
    sendTimeoutMs: _t8,
    receiveTimeoutMs: _t8,
    enableRetry: false,
    note: 'Deterministic 500',
  ),
  BenchPreset(
    id: BenchScenario.s4Timeout,
    title: 'S4 Timeout',
    baseUrl: 'https://httpbingo.org', // deterministic 10s delay
    path: '/delay/10',
    connectTimeoutMs: _t1,
    sendTimeoutMs: _t1,
    receiveTimeoutMs: _t1,
    enableRetry: false,
    note: '200 delayed -> timeout',
  ),
  BenchPreset(
    id: BenchScenario.s5Offline,
    title: 'S5 Offline',
    baseUrl: 'https://dummyjson.com',
    path: '/posts/1',
    connectTimeoutMs: _t8,
    sendTimeoutMs: _t8,
    receiveTimeoutMs: _t8,
    enableRetry: false,
    note: 'Enable airplane mode',
  ),
  BenchPreset(
    id: BenchScenario.s6Headers,
    title: 'S6 Headers',
    baseUrl: 'https://httpbingo.org',
    path: '/headers',
    connectTimeoutMs: _t8,
    sendTimeoutMs: _t8,
    receiveTimeoutMs: _t8,
    enableRetry: false,
    note: 'Echo headers (httpbin)',
  ),
];
