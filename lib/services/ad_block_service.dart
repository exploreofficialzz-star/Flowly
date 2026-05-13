import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

class AdBlockService extends ChangeNotifier {
  static final AdBlockService _instance = AdBlockService._internal();
  factory AdBlockService() => _instance;
  AdBlockService._internal();

  bool _adBlocked = false;
  bool get adBlocked => _adBlocked;

  // Consecutive failures before we flag as blocked
  // (guards against transient DNS hiccups)
  int _failStreak = 0;
  static const _failThreshold = 2;

  Timer? _timer;

  /// The known Google ad-serving domains we probe.
  /// If ALL of them fail while google.com succeeds → ad blocker active.
  static const _adDomains = [
    'googleads.g.doubleclick.net',
    'pagead2.googlesyndication.com',
  ];

  Future<void> init() async {
    await _check();
    // Re-check every 30 s so the overlay auto-clears when user disables blocker
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _check());
  }

  /// Force an immediate re-check (e.g. after user taps "I've Enabled Ads")
  Future<void> recheck() => _check();

  Future<void> _check() async {
    try {
      // Step 1 – confirm general internet is up; if not, don't flag as ad-block
      final hasInternet = await _canLookup('google.com');
      if (!hasInternet) {
        // Internet is down – ConnectivityService handles that overlay.
        // Don't change adBlocked state here.
        return;
      }

      // Step 2 – probe every ad domain; if ALL fail → likely blocked
      bool anyAdDomainReachable = false;
      for (final host in _adDomains) {
        if (await _canLookup(host)) {
          anyAdDomainReachable = true;
          break;
        }
      }

      if (!anyAdDomainReachable) {
        _failStreak++;
      } else {
        _failStreak = 0;
      }

      final nowBlocked = _failStreak >= _failThreshold;
      if (_adBlocked != nowBlocked) {
        _adBlocked = nowBlocked;
        notifyListeners();
      }
    } catch (_) {
      // Swallow – don't change state on unexpected errors
    }
  }

  Future<bool> _canLookup(String host) async {
    try {
      final result = await InternetAddress.lookup(host)
          .timeout(const Duration(seconds: 4));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
