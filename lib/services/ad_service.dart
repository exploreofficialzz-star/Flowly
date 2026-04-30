import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../core/constants/app_constants.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  BannerAd? _bannerAd;
  bool _isInterstitialLoading = false;
  bool _isRewardedLoading = false;
  bool _initialized = false;

  String get _bannerAdUnitId => Platform.isAndroid
      ? AppConstants.adBannerAndroid : AppConstants.adBannerIos;
  String get _interstitialAdUnitId => Platform.isAndroid
      ? AppConstants.adInterstitialAndroid : AppConstants.adInterstitialIos;
  String get _rewardedAdUnitId => Platform.isAndroid
      ? AppConstants.adRewardedAndroid : AppConstants.adRewardedIos;

  Future<void> init() async {
    if (_initialized) return;
    try {
      await MobileAds.instance.initialize();
      _initialized = true;
      loadInterstitial();
      loadRewarded();
    } catch (_) {}
  }

  BannerAd createBanner() {
    _bannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdFailedToLoad: (ad, error) {
          try { ad.dispose(); } catch (_) {}
        },
      ),
    )..load();
    return _bannerAd!;
  }

  void loadInterstitial() {
    if (_isInterstitialLoading || !_initialized) return;
    _isInterstitialLoading = true;
    try {
      InterstitialAd.load(
        adUnitId: _interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialAd = ad;
            _isInterstitialLoading = false;
            try { ad.setImmersiveMode(true); } catch (_) {}
          },
          onAdFailedToLoad: (error) {
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
    if (_interstitialAd == null) {
      onDismissed?.call();
      loadInterstitial();
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
        onAdFailedToShowFullScreenContent: (ad, error) {
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

  void loadRewarded() {
    if (_isRewardedLoading || !_initialized) return;
    _isRewardedLoading = true;
    try {
      RewardedAd.load(
        adUnitId: _rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedAd = ad;
            _isRewardedLoading = false;
          },
          onAdFailedToLoad: (error) {
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
    required void Function(AdWithoutView ad, RewardItem reward) onRewarded,
    VoidCallback? onFailed,
  }) async {
    if (_rewardedAd == null) { onFailed?.call(); return; }
    try {
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          try { ad.dispose(); } catch (_) {}
          _rewardedAd = null;
          loadRewarded();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
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
    try { _bannerAd?.dispose(); } catch (_) {}
  }
}
