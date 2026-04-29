import 'dart:io';
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

  String get _bannerAdUnitId => Platform.isAndroid
      ? AppConstants.adBannerAndroid
      : AppConstants.adBannerIos;

  String get _interstitialAdUnitId => Platform.isAndroid
      ? AppConstants.adInterstitialAndroid
      : AppConstants.adInterstitialIos;

  String get _rewardedAdUnitId => Platform.isAndroid
      ? AppConstants.adRewardedAndroid
      : AppConstants.adRewardedIos;

  Future<void> init() async {
    await MobileAds.instance.initialize();
    loadInterstitial();
    loadRewarded();
  }

  // ── BANNER ──────────────────────────────────────────────
  BannerAd createBanner() {
    _bannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdFailedToLoad: (ad, error) => ad.dispose(),
      ),
    )..load();
    return _bannerAd!;
  }

  // ── INTERSTITIAL ─────────────────────────────────────────
  void loadInterstitial() {
    if (_isInterstitialLoading) return;
    _isInterstitialLoading = true;
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialLoading = false;
          ad.setImmersiveMode(true);
        },
        onAdFailedToLoad: (error) {
          _isInterstitialLoading = false;
          Future.delayed(const Duration(seconds: 30), loadInterstitial);
        },
      ),
    );
  }

  Future<void> showInterstitial({VoidCallback? onDismissed}) async {
    if (_interstitialAd == null) {
      onDismissed?.call();
      loadInterstitial();
      return;
    }
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        loadInterstitial();
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        loadInterstitial();
        onDismissed?.call();
      },
    );
    await _interstitialAd!.show();
  }

  // ── REWARDED ─────────────────────────────────────────────
  void loadRewarded() {
    if (_isRewardedLoading) return;
    _isRewardedLoading = true;
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
  }

  bool get isRewardedReady => _rewardedAd != null;

  Future<void> showRewarded({
    required void Function(AdWithoutView ad, RewardItem reward) onRewarded,
    VoidCallback? onFailed,
  }) async {
    if (_rewardedAd == null) { onFailed?.call(); return; }
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        loadRewarded();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        loadRewarded();
        onFailed?.call();
      },
    );
    await _rewardedAd!.show(onUserEarnedReward: onRewarded);
  }

  void dispose() {
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    _bannerAd?.dispose();
  }
}
