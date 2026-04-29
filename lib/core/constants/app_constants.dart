class AppConstants {
  // App info
  static const appName = 'Flowly';
  static const brandTag = 'by chAs';
  static const packageName = 'com.chastechgroup.flowly';
  static const version = '1.0.0';

  // AdMob IDs — replace with real IDs before release
  // Test IDs below (safe for development)
  static const adBannerAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const adBannerIos = 'ca-app-pub-3940256099942544/2934735716';
  static const adInterstitialAndroid = 'ca-app-pub-3940256099942544/1033173712';
  static const adInterstitialIos = 'ca-app-pub-3940256099942544/4411468910';
  static const adRewardedAndroid = 'ca-app-pub-3940256099942544/5224354917';
  static const adRewardedIos = 'ca-app-pub-3940256099942544/1712485313';

  // Game config
  static const totalWorlds = 5;
  static const levelsPerWorld = 20;
  static const interstitialEveryNLevels = 1; // after every level completion
  static const maxUndoStack = 30;

  // World names & themes
  static const worlds = [
    {'name': 'Ocean Deep', 'emoji': '🌊', 'primaryColor': 0xFF00C8FF, 'bgColor': 0xFF050F20},
    {'name': 'Neon City', 'emoji': '🌆', 'primaryColor': 0xFFB400FF, 'bgColor': 0xFF120A20},
    {'name': 'Forest Glow', 'emoji': '🌿', 'primaryColor': 0xFF00FF96, 'bgColor': 0xFF051508},
    {'name': 'Fire Realm', 'emoji': '🔥', 'primaryColor': 0xFFFF8C00, 'bgColor': 0xFF1A0800},
    {'name': 'Cosmic Void', 'emoji': '🌌', 'primaryColor': 0xFF7B61FF, 'bgColor': 0xFF08051A},
  ];

  // Storage keys
  static const keyTotalLevelsCompleted = 'total_levels_completed';
  static const keyCurrentWorld = 'current_world';
  static const keyCurrentLevel = 'current_level';
  static const keyHighScores = 'high_scores';
  static const keyDailyStreak = 'daily_streak';
  static const keyLastPlayDate = 'last_play_date';
  static const keyTotalHints = 'total_hints';
  static const keySoundEnabled = 'sound_enabled';
  static const keyMusicEnabled = 'music_enabled';
  static const keyHapticsEnabled = 'haptics_enabled';
  static const keyTotalStars = 'total_stars';
}
