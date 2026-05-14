import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

enum NetworkState {
  connected,   // good signal + data confirmed
  weak,        // data flows but slow / packet-lossy
  noData,      // radio up but zero real data flowing
  noInternet,  // no radio at all (airplane / WiFi off / no SIM)
}

class _ProbeResult {
  final bool   success;
  final int    latencyMs;
  const _ProbeResult({required this.success, required this.latencyMs});
}

class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  NetworkState _state = NetworkState.connected;
  NetworkState get state => _state;

  bool get isConnected   => _state == NetworkState.connected;
  bool get isWeak        => _state == NetworkState.weak;
  bool get hasNoData     => _state == NetworkState.noData;
  bool get hasNoInternet => _state == NetworkState.noInternet;
  bool get isBlocking    => _state != NetworkState.connected;

  StreamSubscription<List<ConnectivityResult>>? _radioSub;
  Timer? _pollTimer;
  bool  _inCheck = false;

  // ── Seven endpoints across FOUR independent providers ─────────────────────
  // • Google  (Android's own connectivity check — returns 204 on success)
  // • Apple   (returns 200 + short HTML body)
  // • Microsoft (returns literal text "Microsoft Connect Test")
  // • Cloudflare (one.one.one.one landing page)
  //
  // Using HTTP (not HTTPS) where possible so TLS handshake latency doesn't
  // inflate RTT and give false "weak" readings.
  static const _probeTargets = [
    'http://connectivitycheck.gstatic.com/generate_204',   // Google Android ①
    'http://www.google.com/generate_204',                   // Google ②
    'https://clients3.google.com/generate_204',             // Google ③
    'http://connectivitycheck.android.com/generate_204',    // AOSP ④
    'http://captive.apple.com/hotspot-detect.html',         // Apple ⑤
    'http://www.msftconnecttest.com/connecttest.txt',        // Microsoft ⑥
    'https://one.one.one.one/',                              // Cloudflare ⑦
  ];

  // Thresholds
  static const _weakLatencyMs   = 3000; // median RTT above this → weak
  static const _weakSuccessRate = 0.40; // fewer than 40 % probes succeed → weak
  static const _probeTimeoutMs  = 5000;

  Future<void> init() async {
    await _check();
    _radioSub = Connectivity()
        .onConnectivityChanged
        .listen((_) => _check());
    // Poll every 8 s; short enough to feel instant, easy on battery
    _pollTimer =
        Timer.periodic(const Duration(seconds: 8), (_) => _check());
  }

  Future<void> recheck() => _check();

  Future<void> _check() async {
    if (_inCheck) return;
    _inCheck = true;
    try {
      // ── Step 1: radio check (no I/O, instant) ────────────────────────────
      final radios = await Connectivity().checkConnectivity();
      final hasRadio = radios.any((r) =>
          r == ConnectivityResult.wifi    ||
          r == ConnectivityResult.mobile  ||
          r == ConnectivityResult.ethernet||
          r == ConnectivityResult.vpn);

      if (!hasRadio) {
        _set(NetworkState.noInternet);
        return;
      }

      // ── Step 2: parallel HTTP probes with latency measurement ────────────
      final results = await Future.wait(
        _probeTargets.map(_probe),
        eagerError: false,
      );

      final successes = results.where((r) => r.success).toList();

      // Zero successes across all seven endpoints = no data
      if (successes.isEmpty) {
        _set(NetworkState.noData);
        return;
      }

      // Success rate check — too many drops = weak / unstable
      final successRate = successes.length / results.length;

      // Median latency of successful probes
      final latencies = successes.map((r) => r.latencyMs).toList()..sort();
      final medianMs  = latencies[latencies.length ~/ 2];

      if (successRate < _weakSuccessRate || medianMs > _weakLatencyMs) {
        _set(NetworkState.weak);
      } else {
        _set(NetworkState.connected);
      }
    } catch (_) {
      _set(NetworkState.noInternet);
    } finally {
      _inCheck = false;
    }
  }

  Future<_ProbeResult> _probe(String url) async {
    final sw     = Stopwatch()..start();
    HttpClient?  client;
    try {
      client = HttpClient()
        ..connectionTimeout      = Duration(milliseconds: _probeTimeoutMs)
        ..idleTimeout            = Duration(milliseconds: _probeTimeoutMs)
        ..badCertificateCallback = (_, __, ___) => true;

      final request = await client
          .getUrl(Uri.parse(url))
          .timeout(Duration(milliseconds: _probeTimeoutMs));
      request.headers
        ..set(HttpHeaders.connectionHeader, 'close')
        ..set(HttpHeaders.userAgentHeader,
            'Mozilla/5.0 (Linux; Android 12) Mobile');

      final response = await request
          .close()
          .timeout(Duration(milliseconds: _probeTimeoutMs));
      await response.drain<void>();
      sw.stop();

      // 204 / 200 / 301 / 302 all count as "reached the server"
      // 5xx might mean server error but traffic IS flowing
      final ok = response.statusCode < 600;
      return _ProbeResult(success: ok, latencyMs: sw.elapsedMilliseconds);
    } on SocketException {
      sw.stop();
      return _ProbeResult(success: false, latencyMs: sw.elapsedMilliseconds);
    } on HttpException {
      sw.stop();
      return _ProbeResult(success: false, latencyMs: sw.elapsedMilliseconds);
    } on TlsException {
      sw.stop();
      return _ProbeResult(success: false, latencyMs: sw.elapsedMilliseconds);
    } on TimeoutException {
      sw.stop();
      return _ProbeResult(success: false, latencyMs: _probeTimeoutMs);
    } catch (_) {
      sw.stop();
      return _ProbeResult(success: false, latencyMs: sw.elapsedMilliseconds);
    } finally {
      try { client?.close(force: true); } catch (_) {}
    }
  }

  void _set(NetworkState next) {
    if (_state == next) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _radioSub?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }
}
