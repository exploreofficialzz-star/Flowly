import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

enum NetworkState {
  connected,   // radio up + real TCP/HTTP data confirmed
  noInternet,  // no radio (WiFi off, airplane mode, no SIM)
  noData,      // radio shows connected but data cannot actually flow
               // (captive portal, data plan exhausted, carrier block)
}

class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  NetworkState _state = NetworkState.connected;
  NetworkState get state => _state;

  bool get isConnected   => _state == NetworkState.connected;
  bool get hasNoInternet => _state == NetworkState.noInternet;
  bool get hasNoData     => _state == NetworkState.noData;

  StreamSubscription<List<ConnectivityResult>>? _radioSub;
  Timer? _pollTimer;
  bool _inCheck = false;

  Future<void> init() async {
    await _check();
    _radioSub = Connectivity()
        .onConnectivityChanged
        .listen((_) => _check());
    // Re-probe every 8 s — short enough to feel instant, light on battery
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) => _check());
  }

  Future<void> recheck() => _check();

  Future<void> _check() async {
    if (_inCheck) return;
    _inCheck = true;
    try {
      // ── Step 1: radio-level check (fast, no data needed) ──────────────────
      final results = await Connectivity().checkConnectivity();
      final hasRadio = results.any((r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet ||
          r == ConnectivityResult.vpn);

      if (!hasRadio) {
        _set(NetworkState.noInternet);
        return;
      }

      // ── Step 2: real data probe — TCP connect to known IPs ────────────────
      // Using raw TCP to well-known addresses confirms data actually flows
      // without relying on DNS (which can be spoofed or ad-blocked).
      //   8.8.8.8:53  → Google Public DNS (TCP)
      //   1.1.1.1:443 → Cloudflare HTTPS port
      //   142.250.80.46:80 → Google HTTP (hardcoded IP, no DNS needed)
      final probeResults = await Future.wait([
        _tcpProbe('8.8.8.8', 53),
        _tcpProbe('1.1.1.1', 443),
        _httpProbe(), // Android-native connectivity check endpoint
      ]);

      final hasData = probeResults.any((ok) => ok);
      _set(hasData ? NetworkState.connected : NetworkState.noData);
    } catch (_) {
      _set(NetworkState.noInternet);
    } finally {
      _inCheck = false;
    }
  }

  /// TCP socket connect — verifies actual Layer-4 connectivity.
  /// Returns true if a socket can be established within the timeout.
  Future<bool> _tcpProbe(String host, int port) async {
    Socket? socket;
    try {
      socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 4),
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      try { socket?.destroy(); } catch (_) {}
    }
  }

  /// HTTP probe against Android's built-in connectivity check URL.
  /// Returns 204 No Content on a live connection; redirect/error on captive
  /// portal or no data. This is exactly what Android uses internally.
  Future<bool> _httpProbe() async {
    HttpClient? client;
    try {
      client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 4)
        ..idleTimeout       = const Duration(seconds: 4);
      final req = await client
          .getUrl(Uri.parse(
              'http://connectivitycheck.gstatic.com/generate_204'))
          .timeout(const Duration(seconds: 4));
      req.headers.set(HttpHeaders.connectionHeader, 'close');
      final res = await req.close().timeout(const Duration(seconds: 4));
      await res.drain<void>();
      // 204 = fully connected, 200 = captive portal page = treat as no data
      return res.statusCode == 204;
    } catch (_) {
      return false;
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
