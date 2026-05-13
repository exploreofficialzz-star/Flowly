import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../core/constants/app_constants.dart';
import 'ad_block_service.dart';
import 'iap_service.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  InterstitialAd? _interstitialAd;
  RewardedAd?    _rewardedAd;
  bool _isInterstitialLoading = false;
  bool _isRewardedLoading = false;
  bool _initialized = false;

  // ── Ad unit IDs ────────────────────────────────────────────────────────────
  String get _bannerUnitId =>
      Platform.isAndroid ? AppConstants.adBannerAndroid : AppConstants.adBannerIos;
  String get _interstitialUnitId =>
      Platform.isAndroid ? AppConstants.adInterstitialAndroid : AppConstants.adInterstitialIos;
  String get _rewardedUnitId =>
      Platform.isAndroid ? AppConstants.adRewardedAndroid : AppConstants.adRewardedIos;

  // ── Guard: skip ad ops when premium or when ad-blocker is active ───────────
  // Premium (adsRemoved) → skip all ads
  // Ad-blocked + not premium → skip loading (overlay blocks user anyway)
  // Rewarded ads are ALWAYS served regardless of IAP (user must opt in to watch)
  bool get _skipRegularAds =>
      IapService().adsRemoved || AdBlockService().adBlocked;

  // ── Init ───────────────────────────────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;
    try {
      await MobileAds.instance.initialize();
      _initialized = true;
      // Preload ads eagerly on start (guards will short-circuit if not needed)
      loadInterstitial();
      loadRewarded();
    } catch (_) {}
  }

  // ── Banner ─────────────────────────────────────────────────────────────────
  /// Returns null when the user is premium or when ads are blocked.
  /// The caller is responsible for not rendering the widget when null is returned.
  BannerAd? createBanner() {
    if (_skipRegularAds) return null;
    final ad = BannerAd(
      adUnitId: _bannerUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdFailedToLoad: (ad, err) {
          try { ad.dispose(); } catch (_) {}
          // Persistent failures on a live connection hint at DNS-level blocking;
          // AdBlockService handles detection independently via its own probes.
        },
      ),
    )..load();
    return ad;
  }

  // ── Interstitial ───────────────────────────────────────────────────────────
  void loadInterstitial() {
    if (_isInterstitialLoading || !_initialized || _skipRegularAds) return;
    _isInterstitialLoading = true;
    try {
      InterstitialAd.load(
        adUnitId: _interstitialUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialAd = ad;
            _isInterstitialLoading = false;
            try { ad.setImmersiveMode(true); } catch (_) {}
          },
          onAdFailedToLoad: (_) {
            _isInterstitialLoading = false;
            Future.delayed(const Duration(seconds: 30), loadInterstitial);
          },
        ),
      );
    } catch (_) {
      _isInterstitialLoading = false;
    }
  }

  Future<void> showInterstitial({VoidCallback? onDismissed}) async {
    if (_skipRegularAds || _interstitialAd == null) {
      onDismissed?.call();
      if (!_skipRegularAds) loadInterstitial();
      return;
    }
    try {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          try { ad.dispose(); } catch (_) {}
          _interstitialAd = null;
          loadInterstitial();
          onDismissed?.call();
        },
        onAdFailedToShowFullScreenContent: (ad, _) {
          try { ad.dispose(); } catch (_) {}
          _interstitialAd = null;
          loadInterstitial();
          onDismissed?.call();
        },
      );
      await _interstitialAd!.show();
    } catch (_) {
      _interstitialAd = null;
      onDismissed?.call();
    }
  }

  // ── Rewarded ───────────────────────────────────────────────────────────────
  // Rewarded ads are OPT-IN — user deliberately watches them for a reward.
  // They are served to EVERYONE (premium users won't see them unless they choose
  // to tap "Watch Ad" themselves, which shouldn't happen since the UI hides those
  // buttons for premium users, but we keep the service layer neutral).
  void loadRewarded() {
    if (_isRewardedLoading || !_initialized) return;
    _isRewardedLoading = true;
    try {
      RewardedAd.load(
        adUnitId: _rewardedUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedAd = ad;
            _isRewardedLoading = false;
          },
          onAdFailedToLoad: (_) {
            _isRewardedLoading = false;
            Future.delayed(const Duration(seconds: 30), loadRewarded);
          },
        ),
      );
    } catch (_) {
      _isRewardedLoading = false;
    }
  }

  bool get isRewardedReady => _rewardedAd != null;

  Future<void> showRewarded({
    required void Function(AdWithoutView, RewardItem) onRewarded,
    VoidCallback? onFailed,
  }) async {
    if (_rewardedAd == null) {
      onFailed?.call();
      return;
    }
    try {
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          try { ad.dispose(); } catch (_) {}
          _rewardedAd = null;
          loadRewarded();
        },
        onAdFailedToShowFullScreenContent: (ad, _) {
          try { ad.dispose(); } catch (_) {}
          _rewardedAd = null;
          loadRewarded();
          onFailed?.call();
        },
      );
      await _rewardedAd!.show(onUserEarnedReward: onRewarded);
    } catch (_) {
      _rewardedAd = null;
      onFailed?.call();
    }
  }

  void dispose() {
    try { _interstitialAd?.dispose(); } catch (_) {}
    try { _rewardedAd?.dispose(); } catch (_) {}
  }
}
