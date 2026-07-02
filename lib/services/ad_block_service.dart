import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

class AdBlockService extends ChangeNotifier {
  static final AdBlockService _instance = AdBlockService._internal();
  factory AdBlockService() => _instance;
  AdBlockService._internal();

  bool _adBlocked = false;
  bool get adBlocked => _adBlocked;

  bool _checking = false;
  Timer? _timer;

  // ── Ad-network endpoints to probe ─────────────────────────────────────────
  // Reduced from 6 to 3: still spans multiple Google ad-serving hostnames
  // (a single CDN edge hiccup won't false-positive), at half the network
  // traffic of every periodic check.
  static const _endpoints = [
    'https://googleads.g.doubleclick.net/pagead/id',
    'https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js',
    'https://www.googletagservices.com/tag/js/gpt.js',
  ];

  Future<void> init() async {
    unawaited(_check());
    _startPolling();
  }

  void _startPolling() {
    _timer?.cancel();
    // 45s: ad-blocker state changes are rare and non-urgent — this isn't a
    // security boundary, just a monetization nudge. Slower polling here
    // cuts continuous background network traffic substantially.
    _timer = Timer.periodic(const Duration(seconds: 45), (_) => _check());
  }

  /// Stops background polling — call when the app is backgrounded.
  void pause() {
    _timer?.cancel();
    _timer = null;
  }

  /// Resumes polling and immediately re-checks — call on app foreground.
  void resume() {
    _check();
    _startPolling();
  }

  /// Force an immediate re-check (called by "I've Enabled Ads" button).
  Future<void> recheck() => _check();

  Future<void> _check() async {
    if (_checking) return;
    _checking = true;
    try {
      // ── Step 1: confirm real internet is up via TCP ─────────────────────
      // We use the same TCP probe as ConnectivityService so we don't
      // accidentally flag "ad blocked" when there's simply no internet.
      final hasInternet = await _tcpProbe('8.8.8.8', 53) ||
          await _tcpProbe('1.1.1.1', 443);
      if (!hasInternet) {
        // Internet down — ConnectivityGate handles that overlay.
        // Don't change adBlocked state here.
        _checking = false;
        return;
      }

      // ── Step 2: probe all ad endpoints in parallel ───────────────────────
      final results = await Future.wait(
        _endpoints.map((url) => _httpProbe(url)),
        eagerError: false,
      );

      final reachable = results.where((r) => r).length;
      final blocked   = results.length - reachable;

      // Majority blocked → ad blocker active.
      // Using > 50% so a single flaky CDN edge node doesn't trigger false pos.
      _setBlocked(blocked > results.length ~/ 2);
    } catch (_) {
      // Unexpected error — don't change state
    } finally {
      _checking = false;
    }
  }

  /// HTTP HEAD request to [url].
  /// Returns TRUE  if the endpoint is REACHABLE (any HTTP response received).
  /// Returns FALSE if connection fails (timeout / refused / DNS / TLS blocked).
  Future<bool> _httpProbe(String url) async {
    HttpClient? client;
    try {
      client = HttpClient()
        ..connectionTimeout        = const Duration(seconds: 6)
        ..idleTimeout              = const Duration(seconds: 6)
        // Don't reject self-signed certs — we only care about TCP reachability
        ..badCertificateCallback   = (_, __, ___) => true;

      final uri     = Uri.parse(url);
      final request = await client
          .headUrl(uri)
          .timeout(const Duration(seconds: 6));
      request.headers
        ..set(HttpHeaders.connectionHeader, 'close')
        ..set(HttpHeaders.userAgentHeader,
            'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36');
      final response =
          await request.close().timeout(const Duration(seconds: 6));
      await response.drain<void>();
      // ANY status code means the server responded → endpoint reachable
      return true;
    } on SocketException {
      // Connection refused or TCP reset — likely IP-level block
      return false;
    } on HttpException {
      // Protocol-level error from an ad-blocker proxy returning garbage
      return false;
    } on TlsException {
      // TLS interception / blocking
      return false;
    } on TimeoutException {
      // Timed out — endpoint is being silently dropped (DNS-null-route / VPN)
      return false;
    } catch (_) {
      return false;
    } finally {
      try { client?.close(force: true); } catch (_) {}
    }
  }

  /// TCP socket connect — used only for the internet sanity check in Step 1.
  Future<bool> _tcpProbe(String host, int port) async {
    Socket? socket;
    try {
      socket = await Socket.connect(
          host, port, timeout: const Duration(seconds: 4));
      return true;
    } catch (_) {
      return false;
    } finally {
      try { socket?.destroy(); } catch (_) {}
    }
  }

  void _setBlocked(bool blocked) {
    if (_adBlocked == blocked) return;
    _adBlocked = blocked;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
