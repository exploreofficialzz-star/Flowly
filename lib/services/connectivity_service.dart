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

  // ── Probe endpoints across THREE independent providers ────────────────────
  // Reduced from 7 to 3: still multi-provider redundant (a single CDN or
  // provider hiccup won't cause a false reading), but cuts per-check network
  // traffic by more than half. Every additional endpoint is one more real
  // HTTP round-trip repeated forever on a timer — for a puzzle game, 3
  // well-chosen, independently-operated targets are enough signal.
  static const _probeTargets = [
    'http://connectivitycheck.gstatic.com/generate_204',   // Google Android
    'http://www.msftconnecttest.com/connecttest.txt',       // Microsoft
    'https://one.one.one.one/',                              // Cloudflare
  ];

  // Thresholds
  static const _weakLatencyMs   = 3000; // median RTT above this → weak
  static const _weakSuccessRate = 0.40; // fewer than 40 % probes succeed → weak
  static const _probeTimeoutMs  = 5000;

  Future<void> init() async {
    // Fire the first check but don't let callers block on it — see main.dart.
    unawaited(_check());
    _radioSub = Connectivity()
        .onConnectivityChanged
        .listen((_) => _check());
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    // 25s: still catches a dropped connection well within one short puzzle
    // level, at roughly a third of the previous network traffic volume.
    _pollTimer =
        Timer.periodic(const Duration(seconds: 25), (_) => _check());
  }

  /// Stops background polling — call when the app is backgrounded.
  /// No user is watching the connectivity gate while the app isn't visible.
  void pause() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Resumes polling and immediately re-checks — call on app foreground.
  void resume() {
    _check();
    _startPolling();
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
