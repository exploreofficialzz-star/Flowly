import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

enum NetworkState {
  connected,   // radio up + real data flowing
  noInternet,  // no radio at all (WiFi off, airplane mode, no SIM)
  noData,      // radio shows connected but data can't reach the internet
               // (captive portal, data-plan exhausted, carrier issue)
}

class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  NetworkState _state = NetworkState.connected;
  NetworkState get state => _state;

  bool get isConnected  => _state == NetworkState.connected;
  bool get hasNoInternet => _state == NetworkState.noInternet;
  bool get hasNoData     => _state == NetworkState.noData;

  StreamSubscription<List<ConnectivityResult>>? _radioSub;
  Timer? _deepCheckTimer;
  bool _inCheck = false;

  /// Call once from main() before runApp.
  Future<void> init() async {
    // Immediate baseline check
    await _check();

    // React to every radio change
    _radioSub = Connectivity()
        .onConnectivityChanged
        .listen((_) => _check());

    // Deep data-reachability poll every 12 s
    _deepCheckTimer =
        Timer.periodic(const Duration(seconds: 12), (_) => _check());
  }

  Future<void> recheck() => _check();

  Future<void> _check() async {
    if (_inCheck) return;
    _inCheck = true;
    try {
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

      // Radio is up — verify actual data with a two-target probe.
      // We try two independent hosts; if EITHER responds we consider data up.
      // This avoids false-positives caused by a single host being temporarily down.
      final results2 = await Future.wait([
        _probe('google.com'),
        _probe('1.1.1.1'), // Cloudflare — DNS-over-IP, bypasses DNS spoofing
      ]);

      final hasData = results2.any((ok) => ok);
      _set(hasData ? NetworkState.connected : NetworkState.noData);
    } catch (_) {
      _set(NetworkState.noInternet);
    } finally {
      _inCheck = false;
    }
  }

  Future<bool> _probe(String host) async {
    try {
      final addrs = await InternetAddress.lookup(host)
          .timeout(const Duration(seconds: 4));
      return addrs.isNotEmpty && addrs.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
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
    _deepCheckTimer?.cancel();
    super.dispose();
  }
}
