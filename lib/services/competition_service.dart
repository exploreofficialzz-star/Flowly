import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/competition/bot_names.dart';
import '../data/models/competition_model.dart';

class CompetitionService extends ChangeNotifier {
  // ── Singleton ────────────────────────────────────────────────────────────────
  static final CompetitionService _instance = CompetitionService._internal();
  factory CompetitionService() => _instance;
  CompetitionService._internal();

  // ── User state ───────────────────────────────────────────────────────────────
  String? _userName;
  String? _userCountry;
  String? _userFlag;
  int _userScore = 0;
  int _userPosition = 0;
  String _lastResetDate = '';

  String? get userName       => _userName;
  String? get userCountry    => _userCountry;
  String? get userFlag       => _userFlag;
  int     get userScore      => _userScore;
  int     get userPosition   => _userPosition;
  bool    get isRegistered   => _userName != null && _userName!.isNotEmpty;

  // ── Leaderboard state ────────────────────────────────────────────────────────
  List<LeaderboardEntry> _leaderboard = [];
  List<LiveEvent>        _liveEvents  = [];
  List<LeaderboardEntry> get leaderboard => List.unmodifiable(_leaderboard);
  List<LiveEvent>        get liveEvents  => List.unmodifiable(_liveEvents);

  // Per-bot current scores: botIndex → score
  final Map<int, int> _botScores = {};

  // ── Timer state ──────────────────────────────────────────────────────────────
  Timer?  _positionTimer;
  bool    _disposed    = false;
  bool    _initialized = false;

  // ── Prize amounts (Phase 1: display only) ────────────────────────────────────
  static const prizes = {1: 50, 2: 40, 3: 30, 4: 20, 5: 10};
  static const prizeGrouped = '6-10'; // each $5

  // ── Init ─────────────────────────────────────────────────────────────────────
  // Guarded: this starts a Timer.periodic AND a self-perpetuating recursive
  // Future.delayed chain for live events (_scheduleLiveEvents). If init()
  // ever ran twice — a hot-restart edge case, a future call site added
  // elsewhere — each call would stack another independent timer and another
  // independent recursive chain on top of the last, silently doubling (then
  // tripling, etc.) CPU work and notifyListeners() traffic forever with no
  // visible error. This service is a singleton meant to init exactly once
  // per app lifetime, so we make that explicit instead of assuming it.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _loadUserData();
    await _checkAndReset();
    _startTimers();
  }

  // ── Daily reset logic ────────────────────────────────────────────────────────
  String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${_z(n.month)}-${_z(n.day)}';
  }

  String _z(int v) => v.toString().padLeft(2, '0');

  Future<void> _checkAndReset() async {
    final today = _todayKey();
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('comp_last_date') ?? '';

    if (saved != today) {
      _userScore = 0;
      await prefs.setInt('comp_user_score', 0);
      await prefs.setString('comp_last_date', today);
    } else {
      _userScore = prefs.getInt('comp_user_score') ?? 0;
    }
    _lastResetDate = today;
    _generateBotScores();
    _rebuildLeaderboard();
  }

  // ── Score generation ─────────────────────────────────────────────────────────
  void _generateBotScores() {
    final today  = DateTime.now();
    final dSeed  = today.year * 10000 + today.month * 100 + today.day;
    final prog   = _getDayProgress();
    final bots   = BotNames.allBots;

    // Assign each bot a shuffled index so "elite" slots rotate daily
    // We pick top-scoring bots by sorted score — not by fixed index
    for (int i = 0; i < bots.length; i++) {
      final rng = Random(dSeed + i * 97 + 4919);
      int target;
      if (i < 20) {
        target = 2200 + rng.nextInt(900); // top-zone bots: 2200–3100
      } else if (i < 70) {
        target = 900 + rng.nextInt(1100); // mid-zone: 900–2000
      } else {
        target = 120 + rng.nextInt(800);  // lower zone: 120–920
      }
      _botScores[i] = (target * prog).round();
    }
  }

  // S-curve: 0 at 5am → peaks at 10pm Nigeria time (UTC+1)
  double _getDayProgress() {
    // Use local device time; Nigeria users' local clock ≈ correct zone
    final now     = DateTime.now();
    final mins    = now.hour * 60 + now.minute;
    if (mins < 300)  return 0.0;   // before 5am
    if (mins >= 1320) return 1.0;  // after 10pm
    final ratio   = (mins - 300) / 1020.0; // 5am→10pm = 1020 min
    // smoothstep
    return ratio * ratio * (3 - 2 * ratio);
  }

  // ── Timer ────────────────────────────────────────────────────────────────────
  void _startTimers() {
    // Position shuffle every 3 minutes
    _positionTimer = Timer.periodic(const Duration(minutes: 3), (_) {
      _onTick();
    });
    // First live event at 30s, then stochastic
    Future.delayed(const Duration(seconds: 30), _scheduleLiveEvents);
  }

  void _onTick() {
    if (_disposed) return;
    _checkDailyResetSync();
    _shufflePositions();
    _generateLiveEvent();
    notifyListeners();
  }

  void _checkDailyResetSync() {
    final today = _todayKey();
    if (today != _lastResetDate) {
      _userScore = 0;
      _lastResetDate = today;
      _generateBotScores();
      SharedPreferences.getInstance().then((p) {
        p.setInt('comp_user_score', 0);
        p.setString('comp_last_date', today);
      });
    }
  }

  // ── Position shuffling ───────────────────────────────────────────────────────
  void _shufflePositions() {
    final today    = DateTime.now();
    final dSeed    = today.year * 10000 + today.month * 100 + today.day;
    final timeSlot = today.minute ~/ 3; // changes every 3 mins
    final bots     = BotNames.allBots;

    // Shuffle ALL bots with varying amplitudes
    for (int i = 0; i < bots.length; i++) {
      final seed        = dSeed + i * 97 + timeSlot * 37 + 8191;
      final rng         = Random(seed);
      final amplitude   = i < 20 ? 20 : (i < 70 ? 50 : 70);
      final perturbation = rng.nextInt(amplitude * 2 + 1) - amplitude;
      final current     = _botScores[i] ?? 0;
      _botScores[i]     = max(0, current + perturbation);
    }

    // Enforce: top-10 always above real user
    _enforceEliteGap();
    _rebuildLeaderboard();
  }

  // Gap table: position 10 → 50pts above user, position 1 → 1100pts above
  static const _eliteGaps = [1100, 950, 800, 660, 530, 410, 300, 200, 120, 50];

  void _enforceEliteGap() {
    if (_userScore <= 0) return;

    // Sort bot scores descending, grab top 10 indices
    final sorted = _botScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (int rank = 0; rank < 10 && rank < sorted.length; rank++) {
      final idx      = sorted[rank].key;
      final minScore = _userScore + _eliteGaps[rank];
      if ((_botScores[idx] ?? 0) < minScore) {
        _botScores[idx] = minScore + Random().nextInt(40);
      }
    }
  }

  // ── Leaderboard rebuild ───────────────────────────────────────────────────────
  void _rebuildLeaderboard() {
    final bots = BotNames.allBots;
    final entries = <LeaderboardEntry>[];

    for (int i = 0; i < bots.length; i++) {
      entries.add(LeaderboardEntry(
        id:       'bot_$i',
        name:     bots[i].name,
        country:  bots[i].country,
        flag:     bots[i].flag,
        score:    _botScores[i] ?? 0,
        isBot:    true,
        isElite:  false, // assigned after sort
        position: 0,
      ));
    }

    // Add real user if registered + has played today
    if (isRegistered && _userScore > 0) {
      entries.add(LeaderboardEntry(
        id:       'user',
        name:     _userName!,
        country:  _userCountry ?? 'Nigeria',
        flag:     _userFlag ?? '🇳🇬',
        score:    _userScore,
        isBot:    false,
        isElite:  false,
        position: 0,
      ));
    }

    // Sort descending
    entries.sort((a, b) => b.score.compareTo(a.score));

    // Assign positions and mark top-10 as elite
    _leaderboard = [];
    for (int i = 0; i < entries.length; i++) {
      _leaderboard.add(entries[i].copyWith(
        position: i + 1,
        isElite:  i < 10,
      ));
    }

    // Find user position
    if (isRegistered) {
      final idx    = _leaderboard.indexWhere((e) => !e.isBot);
      _userPosition = idx >= 0 ? idx + 1 : 0;
    }
  }

  // ── Live events ───────────────────────────────────────────────────────────────
  void _scheduleLiveEvents() {
    if (_disposed) return;
    _generateLiveEvent();
    if (!_disposed) notifyListeners();
    final delay = 55 + Random().nextInt(70); // 55–125s
    Future.delayed(Duration(seconds: delay), _scheduleLiveEvents);
  }

  void _generateLiveEvent() {
    if (_leaderboard.isEmpty) return;
    final rng     = Random();
    // Pick from top-30 entries for credibility
    final pool    = _leaderboard.where((e) => e.isBot).take(30).toList();
    if (pool.isEmpty) return;
    final bot     = pool[rng.nextInt(pool.length)];
    final level   = 8 + rng.nextInt(17);
    final moves   = 5 + rng.nextInt(10);
    final streak  = 2 + rng.nextInt(22);
    final seconds = 25 + rng.nextInt(110);

    final templates = [
      '⚡ ${bot.name} solved Level $level in $moves moves',
      '🔥 ${bot.name} is on a $streak-day streak',
      '🎯 ${bot.name} just completed the Daily Challenge',
      '🏆 ${bot.name} earned 3★ on Level $level',
      '📈 ${bot.name} climbed to #${bot.position}',
      '⚡ ${bot.name} solved in ${seconds}s — blazing fast!',
      '💡 ${bot.name} collected their daily score',
      '🔥 ${bot.name} is unstoppable today!',
    ];

    _liveEvents.insert(0, LiveEvent(
      text:      templates[rng.nextInt(templates.length)],
      flag:      bot.flag,
      timestamp: DateTime.now(),
    ));
    if (_liveEvents.length > 25) _liveEvents.removeLast();
  }

  // ── Score submission ──────────────────────────────────────────────────────────
  int calculateLevelScore({
    required int colorCount,
    required int movesUsed,
    required int maxMoves,
    required int secondsUsed,
    required int streakDays,
  }) {
    // Efficiency: how many moves saved out of max (0–1000)
    final efficiency = maxMoves > 0
        ? (maxMoves - movesUsed) / maxMoves
        : 0.0;
    final moveScore = (efficiency.clamp(0.0, 1.0) * 1000).round();

    // Speed bonus: max 400pts, best under 30s, zero after 300s
    final clamped   = secondsUsed.clamp(0, 300);
    final timeScore = ((1 - clamped / 300) * 400).round();

    // Difficulty multiplier: 3 colors=1.0x → 8 colors=1.75x
    final multiplier = 1.0 + (colorCount - 3) * 0.15;

    // Streak loyalty bonus (cap 200)
    final streakBonus = min(streakDays * 10, 200);

    return ((moveScore + timeScore) * multiplier + streakBonus).round();
  }

  Future<int> submitLevelScore({
    required int colorCount,
    required int movesUsed,
    required int maxMoves,
    required int secondsUsed,
    required int streakDays,
  }) async {
    if (!isRegistered) return 0;
    final pts = calculateLevelScore(
      colorCount:  colorCount,
      movesUsed:   movesUsed,
      maxMoves:    maxMoves,
      secondsUsed: secondsUsed,
      streakDays:  streakDays,
    );
    _userScore += pts;
    _enforceEliteGap();
    _rebuildLeaderboard();
    _generateLiveEvent(); // trigger a bot event to look reactive
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('comp_user_score', _userScore);
    if (!_disposed) notifyListeners();
    return pts;
  }

  // ── Registration ──────────────────────────────────────────────────────────────
  Future<void> register({
    required String name,
    required String country,
    required String flag,
  }) async {
    _userName    = name.trim();
    _userCountry = country;
    _userFlag    = flag;
    final prefs  = await SharedPreferences.getInstance();
    await prefs.setString('comp_name',    _userName!);
    await prefs.setString('comp_country', country);
    await prefs.setString('comp_flag',    flag);
    _rebuildLeaderboard();
    if (!_disposed) notifyListeners();
  }

  Future<void> _loadUserData() async {
    final prefs  = await SharedPreferences.getInstance();
    _userName    = prefs.getString('comp_name');
    _userCountry = prefs.getString('comp_country');
    _userFlag    = prefs.getString('comp_flag');
  }

  // ── Helpers for UI ────────────────────────────────────────────────────────────
  /// Points the user needs to enter the elite top-10 zone
  int get ptsToTop10 {
    if (_leaderboard.length < 10) return 0;
    final pos10score = _leaderboard[9].score;
    return max(0, pos10score - _userScore + 1);
  }

  /// Entry immediately above the user in the leaderboard
  LeaderboardEntry? get entryAboveUser {
    if (_userPosition <= 1 || _userPosition == 0) return null;
    final idx = _userPosition - 2;
    if (idx < 0 || idx >= _leaderboard.length) return null;
    return _leaderboard[idx];
  }

  int get ptsToNextPosition {
    final above = entryAboveUser;
    if (above == null) return 0;
    return max(0, above.score - _userScore + 1);
  }

  /// Countdown string to midnight (daily reset)
  String get resetCountdown {
    final now       = DateTime.now();
    final midnight  = DateTime(now.year, now.month, now.day + 1);
    final remaining = midnight.difference(now);
    final h = remaining.inHours;
    final m = remaining.inMinutes % 60;
    final s = remaining.inSeconds % 60;
    return '${_z(h)}:${_z(m)}:${_z(s)}';
  }

  @override
  void dispose() {
    _disposed = true;
    _positionTimer?.cancel();
    super.dispose();
  }
}
