class AppConstants {
  // ── App info ────────────────────────────────────────────────────────────────
  static const appName     = 'Flowly';
  static const brandTag    = 'by chAs';
  static const packageName = 'com.chastechgroup.flowly';
  static const version     = '1.0.0';

  // ── AdMob — Android (LIVE) ──────────────────────────────────────────────────
  static const adBannerAndroid       = 'ca-app-pub-2492078126313994/9092958789';
  static const adInterstitialAndroid = 'ca-app-pub-2492078126313994/8574084036';
  static const adRewardedAndroid     = 'ca-app-pub-2492078126313994/3840632109';

  // ── AdMob — iOS (replace with real iOS unit IDs before iOS build) ──────────
  static const adBannerIos       = 'ca-app-pub-3940256099942544/2934735716'; // test
  static const adInterstitialIos = 'ca-app-pub-3940256099942544/4411468910'; // test
  static const adRewardedIos     = 'ca-app-pub-3940256099942544/1712485313'; // test

  // ── In-App Purchase product IDs ─────────────────────────────────────────────
  static const iapRemoveAds1Day   = 'remove_ads_1_day';
  static const iapRemoveAds1Week  = 'remove_ads_1_week';
  static const iapRemoveAds1Month = 'remove_ads_1_month';

  static const Set<String> iapProductIds = {
    iapRemoveAds1Day,
    iapRemoveAds1Week,
    iapRemoveAds1Month,
  };

  // Fallback prices shown when store products haven't loaded yet
  static const iapFallbackPrices = {
    iapRemoveAds1Day:   '\$0.99',
    iapRemoveAds1Week:  '\$2.99',
    iapRemoveAds1Month: '\$8.99',
  };

  // ── Game config ─────────────────────────────────────────────────────────────
  static const totalWorlds              = 5;
  static const levelsPerWorld           = 20;
  static const interstitialEveryNLevels = 2; // ad every 2 completed levels
  static const maxUndoStack             = 30;

  // Starting hints for every new player
  static const initialHints = 2;

  // Move limit = colorCount * 4 + bonus
  static const moveBonusEasy    = 6;
  static const moveBonusMedium  = 8;
  static const moveBonusHard    = 6;
  static const moveBonusExpert  = 4;
  static const moveBonusEndless = 15; // generous buffer for infinite mode

  // Extra moves granted per rewarded-ad watch
  static const extraMovesPerAd = 5;
  static const lowMovesWarning = 5;

  // ── World definitions ─────────────────────────────────────────────────────────
  static const worlds = [
    {'name': 'Ocean Deep',  'emoji': '🌊', 'primaryColor': 0xFF00C8FF, 'bgColor': 0xFF050F20},
    {'name': 'Neon City',   'emoji': '🌆', 'primaryColor': 0xFFB400FF, 'bgColor': 0xFF120A20},
    {'name': 'Forest Glow', 'emoji': '🌿', 'primaryColor': 0xFF00FF96, 'bgColor': 0xFF051508},
    {'name': 'Fire Realm',  'emoji': '🔥', 'primaryColor': 0xFFFF8C00, 'bgColor': 0xFF1A0800},
    {'name': 'Cosmic Void', 'emoji': '🌌', 'primaryColor': 0xFF7B61FF, 'bgColor': 0xFF08051A},
    {'name': 'Endless Mode','emoji': '♾️', 'primaryColor': 0xFFFF00FF, 'bgColor': 0xFF0A020F},
  ];

  // ── Streak milestone rewards ─────────────────────────────────────────────────
  // day → hints granted at that milestone
  static const streakHintRewards = {3: 2, 7: 5, 14: 10, 30: 15};
  // day → hours of ad-free granted (0 = none)
  static const streakAdFreeHours = {3: 0, 7: 0, 14: 1, 30: 3};

  // ── Competition ─────────────────────────────────────────────────────────────
  static const supportEmail      = 'chastechnologiesllc@gmail.com';
  static const competitionName   = 'Future Hope Competition';
  /// Flip to true once prize payouts are active
  static const prizesActive      = false;

  // ── SharedPreferences keys ──────────────────────────────────────────────────
  static const keyTotalLevelsCompleted = 'total_levels_completed';
  static const keyCurrentWorld         = 'current_world';
  static const keyCurrentLevel         = 'current_level';
  static const keyHighScores           = 'high_scores';
  static const keyDailyStreak          = 'daily_streak';
  static const keyLastPlayDate         = 'last_play_date';
  static const keyTotalHints           = 'total_hints';
  static const keySoundEnabled         = 'sound_enabled';
  static const keyStreakClaimedPrefix  = 'streak_claimed_'; // + milestone day
  static const keyMusicEnabled         = 'music_enabled';
  static const keyHapticsEnabled       = 'haptics_enabled';
  static const keyTotalStars           = 'total_stars';
  static const keyRemoveAdsExpiry      = 'remove_ads_expiry';
}
