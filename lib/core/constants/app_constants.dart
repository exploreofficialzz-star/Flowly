class AppConstants {
  // ── App info ────────────────────────────────────────────────────────────────
  static const appName     = 'Flowly';
  static const brandTag    = 'by chAs';
  static const packageName = 'com.chastechgroup.flowly';
  static const version     = '1.0.0';

  // ── AdMob — Android (LIVE) ──────────────────────────────────────────────────
  // App ID  : ca-app-pub-2492078126313994~8748208382
  // → goes in AndroidManifest.xml (already wired there)
  static const adBannerAndroid       = 'ca-app-pub-2492078126313994/9092958789';
  static const adInterstitialAndroid = 'ca-app-pub-2492078126313994/8574084036';
  static const adRewardedAndroid     = 'ca-app-pub-2492078126313994/3840632109';

  // ── AdMob — iOS (TODO: replace with real iOS unit IDs from AdMob console) ──
  // Create matching banner / interstitial / rewarded units under the same
  // publisher account and paste the IDs here before the iOS build.
  static const adBannerIos       = 'ca-app-pub-3940256099942544/2934735716'; // test
  static const adInterstitialIos = 'ca-app-pub-3940256099942544/4411468910'; // test
  static const adRewardedIos     = 'ca-app-pub-3940256099942544/1712485313'; // test

  // ── In-App Purchase product IDs ─────────────────────────────────────────────
  // Register exactly these IDs in:
  //   • Google Play Console → Monetise → In-app products (one-time / subscriptions)
  //   • App Store Connect   → In-App Purchases
  static const iapRemoveAds1Day   = 'remove_ads_1_day';
  static const iapRemoveAds1Week  = 'remove_ads_1_week';
  static const iapRemoveAds1Month = 'remove_ads_1_month';

  static const Set<String> iapProductIds = {
    iapRemoveAds1Day,
    iapRemoveAds1Week,
    iapRemoveAds1Month,
  };

  // ── Game config ─────────────────────────────────────────────────────────────
  static const totalWorlds              = 5;
  static const levelsPerWorld           = 20;
  static const interstitialEveryNLevels = 1;
  static const maxUndoStack             = 30;

  // Move limits per difficulty (optimal moves + bonus buffer)
  static const moveBonusEasy   = 16;
  static const moveBonusMedium = 13;
  static const moveBonusHard   = 10;
  static const moveBonusExpert = 8;

  // Extra moves granted per rewarded-ad watch
  static const extraMovesPerAd = 5;
  // Remaining moves threshold at which counter turns red
  static const lowMovesWarning = 5;

  // ── World definitions ───────────────────────────────────────────────────────
  static const worlds = [
    {'name': 'Ocean Deep',  'emoji': '🌊', 'primaryColor': 0xFF00C8FF, 'bgColor': 0xFF050F20},
    {'name': 'Neon City',   'emoji': '🌆', 'primaryColor': 0xFFB400FF, 'bgColor': 0xFF120A20},
    {'name': 'Forest Glow', 'emoji': '🌿', 'primaryColor': 0xFF00FF96, 'bgColor': 0xFF051508},
    {'name': 'Fire Realm',  'emoji': '🔥', 'primaryColor': 0xFFFF8C00, 'bgColor': 0xFF1A0800},
    {'name': 'Cosmic Void', 'emoji': '🌌', 'primaryColor': 0xFF7B61FF, 'bgColor': 0xFF08051A},
  ];

  // ── SharedPreferences keys ──────────────────────────────────────────────────
  static const keyTotalLevelsCompleted = 'total_levels_completed';
  static const keyCurrentWorld         = 'current_world';
  static const keyCurrentLevel         = 'current_level';
  static const keyHighScores           = 'high_scores';
  static const keyDailyStreak          = 'daily_streak';
  static const keyLastPlayDate         = 'last_play_date';
  static const keyTotalHints           = 'total_hints';
  static const keySoundEnabled         = 'sound_enabled';
  static const keyMusicEnabled         = 'music_enabled';
  static const keyHapticsEnabled       = 'haptics_enabled';
  static const keyTotalStars           = 'total_stars';
  static const keyRemoveAdsExpiry      = 'remove_ads_expiry';
}
