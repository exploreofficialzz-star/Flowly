import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/competition/bot_names.dart';
import '../data/models/competition_model.dart';

// ── Per-bot simulation state ───────────────────────────────────────────────────
// Each bot is a tiny state machine:  idle → session → idle → …
// During a session the bot "completes levels" one at a time (each completion
// is one tick apart at minimum, with a cooldown between them).  After the
// session it rests for a while, then the cycle repeats.  Skill and activity
// are seeded once per day so the same players feel dominant every day but
// individual rankings still shift as sessions start/stop at different times.
class _BotState {
  final double skill;    // 0.15 – 1.0  →  pts/level and session length
  final double activity; // 0.3  – 2.0  →  session frequency

  bool  inSession  = false;
  int   levelsLeft = 0;   // levels remaining in current session
  int   cooldown   = 0;   // ticks before next action
  bool  bursting   = false; // hot-streak: faster play, ×1.4 pts
  int   streakLvls = 0;   // consecutive levels this burst

  _BotState({required this.skill, required this.activity});
}

class CompetitionService extends ChangeNotifier {
  // ── Singleton ────────────────────────────────────────────────────────────────
  static final CompetitionService _instance = CompetitionService._internal();
  factory CompetitionService() => _instance;
  CompetitionService._internal();

  // ── User state ────────────────────────────────────────────────────────────────
  String? _userName;
  String? _userCountry;
  String? _userFlag;
  int     _userScore    = 0;
  int     _userPosition = 0;
  String  _lastResetDate = '';

  String? get userName     => _userName;
  String? get userCountry  => _userCountry;
  String? get userFlag     => _userFlag;
  int     get userScore    => _userScore;
  int     get userPosition => _userPosition;
  bool    get isRegistered => _userName != null && _userName!.isNotEmpty;

  // ── Leaderboard ───────────────────────────────────────────────────────────────
  List<LeaderboardEntry> _leaderboard = [];
  List<LiveEvent>        _liveEvents  = [];
  List<LeaderboardEntry> get leaderboard => List.unmodifiable(_leaderboard);
  List<LiveEvent>        get liveEvents  => List.unmodifiable(_liveEvents);

  // ── Bot simulation ────────────────────────────────────────────────────────────
  final List<_BotState> _botStates = [];
  final List<int>       _botScores = []; // parallel array to BotNames.allBots

  // ── Internals ─────────────────────────────────────────────────────────────────
  Timer?      _timer;
  bool        _disposed    = false;
  bool        _initialized = false;
  final       _rng         = Random();

  // Prizes shown in UI (Phase 1: display only)
  static const prizes = {1: 50, 2: 40, 3: 30, 4: 20, 5: 10};

  // ── Init ──────────────────────────────────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _loadUserData();
    await _checkAndReset();
    _initBotStates();
    _startTimer();
  }

  // ── Bot state init (once per day) ─────────────────────────────────────────────
  void _initBotStates() {
    final bots  = BotNames.allBots;
    final dSeed = _dateSeed();
    _botStates.clear();

    for (int i = 0; i < bots.length; i++) {
      final rng = Random(dSeed + i * 1009 + 7);
      late double skill, activity;

      if (i < 5) {
        // Elite   — consistently high scores
        skill    = 0.82 + rng.nextDouble() * 0.18; // 0.82–1.0
        activity = 1.40 + rng.nextDouble() * 0.60; // 1.40–2.0
      } else if (i < 20) {
        // Strong  — regular grinders
        skill    = 0.62 + rng.nextDouble() * 0.20; // 0.62–0.82
        activity = 1.00 + rng.nextDouble() * 0.50; // 1.00–1.50
      } else if (i < 55) {
        // Mid     — casual-competitive
        skill    = 0.38 + rng.nextDouble() * 0.24; // 0.38–0.62
        activity = 0.60 + rng.nextDouble() * 0.50; // 0.60–1.10
      } else {
        // Casual  — infrequent play
        skill    = 0.15 + rng.nextDouble() * 0.23; // 0.15–0.38
        activity = 0.30 + rng.nextDouble() * 0.40; // 0.30–0.70
      }
      _botStates.add(_BotState(skill: skill, activity: activity));
    }
  }

  // ── Daily reset ───────────────────────────────────────────────────────────────
  String _z(int v) => v.toString().padLeft(2, '0');

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${_z(n.month)}-${_z(n.day)}';
  }

  int _dateSeed() {
    final n = DateTime.now();
    return n.year * 10000 + n.month * 100 + n.day;
  }

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
    _seedBotScores();
    _rebuildLeaderboard();
  }

  // ── Seed scores from midnight to now ──────────────────────────────────────────
  // Represents points each bot has already earned today before the player
  // opened the app.  Live tick increments are added on top every 5 seconds.
  void _seedBotScores() {
    final prog  = _getDayProgress(); // 0.0 (5am) → 1.0 (10pm)
    final dSeed = _dateSeed();
    _botScores.clear();

    for (int i = 0; i < BotNames.allBots.length; i++) {
      final rng   = Random(dSeed + i * 1013 + 31);
      final skill = i < _botStates.length ? _botStates[i].skill : 0.3;

      // Target score at prog = 1.0 (end of day) by tier
      final maxScore = skill > 0.80
          ? 7000 + rng.nextInt(5000)  // elite:  7 000 – 12 000
          : skill > 0.60
              ? 3500 + rng.nextInt(3000) // strong: 3 500 –  6 500
              : skill > 0.38
                  ? 1200 + rng.nextInt(2300) // mid:    1 200 –  3 500
                  : 150  + rng.nextInt(1050);  // casual:   150 –  1 200

      // ±20 % variance so bots of the same tier don't all cluster tightly
      final variance = 0.80 + rng.nextDouble() * 0.40;
      _botScores.add((maxScore * prog * variance).round());
    }
  }

  // Smoothstep: 0 before 5 am local, 1.0 after 10 pm local
  double _getDayProgress() {
    final now  = DateTime.now();
    final mins = now.hour * 60 + now.minute;
    if (mins < 300)  return 0.0;
    if (mins >= 1320) return 1.0;
    final t = (mins - 300) / 1020.0;
    return t * t * (3 - 2 * t);
  }

  // ── 5-second simulation timer ──────────────────────────────────────────────────
  void _startTimer() {
    // Tick every 5 seconds so the leaderboard updates several times per minute
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _tick());
    // First tick soon after init so the board feels alive immediately
    Future.delayed(const Duration(milliseconds: 1800), _tick);
  }

  void _tick() {
    if (_disposed) return;

    // ── Daily rollover ─────────────────────────────────────────────────────
    final today = _todayKey();
    if (today != _lastResetDate) {
      _lastResetDate = today;
      _userScore     = 0;
      _seedBotScores();
      for (final s in _botStates) {
        s.inSession  = false;
        s.levelsLeft = 0;
        s.cooldown   = 0;
        s.bursting   = false;
      }
      SharedPreferences.getInstance().then((p) {
        p.setInt('comp_user_score', 0);
        p.setString('comp_last_date', today);
      });
    }

    // ── Snapshot positions BEFORE this tick for overtake detection ─────────
    final prePos = <String, int>{for (final e in _leaderboard) e.id: e.position};

    // ── Peak-hour activity multiplier ──────────────────────────────────────
    // More players active in the evening → faster score growth → more drama
    final peakFactor = _peakMultiplier(DateTime.now().hour);

    // ── Run bot state machines ─────────────────────────────────────────────
    final newEvents = <LiveEvent>[];
    final bots      = BotNames.allBots;

    for (int i = 0; i < _botStates.length && i < _botScores.length; i++) {
      final pts = _stepBot(_botStates[i], peakFactor);
      if (pts <= 0) continue;
      _botScores[i] += pts;

      // Generate a live event ~30 % of the time a level completes
      if (_rng.nextDouble() < 0.30) {
        newEvents.add(_makeEvent(bots[i].name, bots[i].flag, pts, _botStates[i]));
      }
    }

    // ── Rebuild sorted leaderboard ─────────────────────────────────────────
    _rebuildLeaderboard();

    // ── Overtake detection — announce top-20 rank changes ─────────────────
    final overtakeEvents = <LiveEvent>[];
    for (final entry in _leaderboard) {
      final prev = prePos[entry.id];
      if (prev == null || entry.position >= prev) continue; // only climbers
      if (entry.position > 20) continue;                    // only top-20

      // Find whoever is now AT the old position (the displaced player)
      final displaced = _leaderboard.firstWhere(
        (e) => e.position == prev,
        orElse: () => entry,
      );
      if (displaced.id == entry.id) continue;

      overtakeEvents.add(LiveEvent(
        text: '🚀 ${entry.name} overtook ${displaced.name} — now #${entry.position}!',
        flag: entry.flag,
        timestamp: DateTime.now(),
      ));
    }

    // Overtakes go first (most dramatic), then generic events
    _liveEvents.insertAll(0, [...overtakeEvents, ...newEvents]);
    if (_liveEvents.length > 30) _liveEvents.removeRange(30, _liveEvents.length);

    if (!_disposed) notifyListeners();
  }

  // ── Bot state machine: returns pts earned this tick (0 = idle/cooldown) ───────
  int _stepBot(_BotState s, double peakFactor) {
    // Count down cooldown between levels or between sessions
    if (s.cooldown > 0) {
      s.cooldown--;
      return 0;
    }

    if (!s.inSession) {
      // Probability of starting a new session this tick
      // Higher activity + peak hours → more frequent sessions
      final prob = s.activity * 0.055 * peakFactor;
      if (_rng.nextDouble() > prob) return 0;

      // Start session
      s.inSession  = true;
      s.levelsLeft = _sessionLength(s.skill);
      // 12 % × skill chance of going on a hot-streak burst
      s.bursting   = _rng.nextDouble() < 0.12 * s.skill;
      s.streakLvls = 0;
      // Tiny cooldown before first level completes (feels more natural than instant)
      s.cooldown   = 1 + _rng.nextInt(2);
      return 0;
    }

    // === In session: complete one level ===
    s.levelsLeft--;
    s.streakLvls++;
    final pts = _ptsForLevel(s.skill, s.bursting);

    // Cooldown until next level (bursting = near-instant replays)
    s.cooldown = s.bursting ? _rng.nextInt(2) : 1 + _rng.nextInt(3);

    if (s.levelsLeft <= 0) {
      // Session done — enter rest phase
      s.inSession = false;
      s.bursting  = false;
      s.cooldown  = _restCooldown(s.activity);
    }

    return pts;
  }

  // 3 – 12 levels per session, longer for skilled players
  int _sessionLength(double skill) {
    final cap = (skill * 9 + 3).round(); // skill 0.15 → 4,  skill 1.0 → 12
    return 3 + _rng.nextInt(max(1, cap - 2));
  }

  // Points per completed level.  Skill 0.15 → 80–150 pts.  Skill 1.0 → 340–510 pts.
  int _ptsForLevel(double skill, bool bursting) {
    final base   = (skill * 340 + 70).round();
    final spread = (base * 0.35).round();
    final raw    = base - spread ~/ 2 + _rng.nextInt(spread + 1);
    return bursting ? (raw * 1.40).round() : raw;
  }

  // Ticks (×5 s) to rest after a session ends.  Less active players rest longer.
  int _restCooldown(double activity) {
    final base = ((1.0 / activity) * 18).round().clamp(4, 60);
    return base + _rng.nextInt(base);
  }

  // Activity multiplier by local hour: quiet 2am – 6am, busy 7pm – 10pm
  double _peakMultiplier(int hour) {
    if (hour < 6)  return 0.40;
    if (hour < 10) return 0.75;
    if (hour < 19) return 1.00;
    if (hour < 22) return 1.50;
    return 0.60;
  }

  // Varied, human-feeling event messages
  LiveEvent _makeEvent(String name, String flag, int pts, _BotState s) {
    final msgs = <String>[
      if (s.bursting && s.streakLvls >= 3)
        '🔥 $name is on a ${s.streakLvls}-level hot streak!',
      if (pts >= 450)
        '⚡ $name blazed through a level! +$pts pts',
      if (pts >= 320)
        '🎯 $name nailed a perfect 3★ clear! +$pts pts',
      if (pts >= 200)
        '💪 $name crushed it — +$pts pts',
      '💡 $name completed a level (+$pts pts)',
      '🌊 $name is flowing through today\'s puzzles',
      '📈 $name keeps the pressure on',
    ];
    // Pick the most specific applicable message
    final text = msgs.first;
    return LiveEvent(text: text, flag: flag, timestamp: DateTime.now());
  }

  // ── Leaderboard rebuild ────────────────────────────────────────────────────────
  void _rebuildLeaderboard() {
    final bots    = BotNames.allBots;
    final entries = <LeaderboardEntry>[];

    for (int i = 0; i < bots.length; i++) {
      entries.add(LeaderboardEntry(
        id:       'bot_$i',
        name:     bots[i].name,
        country:  bots[i].country,
        flag:     bots[i].flag,
        score:    i < _botScores.length ? _botScores[i] : 0,
        isBot:    true,
        isElite:  false,
        position: 0,
      ));
    }

    // Insert real user if registered and has scored today
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

    entries.sort((a, b) => b.score.compareTo(a.score));

    _leaderboard = [];
    for (int i = 0; i < entries.length; i++) {
      _leaderboard.add(entries[i].copyWith(position: i + 1, isElite: i < 10));
    }

    if (isRegistered) {
      final idx     = _leaderboard.indexWhere((e) => !e.isBot);
      _userPosition = idx >= 0 ? idx + 1 : 0;
    }
  }

  // ── Score submission (real user wins a level) ──────────────────────────────────
  int calculateLevelScore({
    required int colorCount,
    required int movesUsed,
    required int maxMoves,
    required int secondsUsed,
    required int streakDays,
  }) {
    final efficiency  = maxMoves > 0 ? (maxMoves - movesUsed) / maxMoves : 0.0;
    final moveScore   = (efficiency.clamp(0.0, 1.0) * 1000).round();
    final timeScore   = ((1 - secondsUsed.clamp(0, 300) / 300) * 400).round();
    final multiplier  = 1.0 + (colorCount - 3) * 0.15;
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
    _rebuildLeaderboard();

    // Announce the real player's score in the live feed
    if (pts > 0) {
      _liveEvents.insert(0, LiveEvent(
        text:      '🌟 $_userName just scored $pts pts — moving up!',
        flag:      _userFlag ?? '🌍',
        timestamp: DateTime.now(),
      ));
      if (_liveEvents.length > 30) _liveEvents.removeLast();
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('comp_user_score', _userScore);
    if (!_disposed) notifyListeners();
    return pts;
  }

  // ── Registration ───────────────────────────────────────────────────────────────
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

  // ── UI helpers ─────────────────────────────────────────────────────────────────
  int get ptsToTop10 {
    if (_leaderboard.length < 10) return 0;
    return max(0, _leaderboard[9].score - _userScore + 1);
  }

  LeaderboardEntry? get entryAboveUser {
    if (_userPosition <= 1 || _userPosition == 0) return null;
    final idx = _userPosition - 2;
    return (idx >= 0 && idx < _leaderboard.length) ? _leaderboard[idx] : null;
  }

  int get ptsToNextPosition {
    final above = entryAboveUser;
    return above == null ? 0 : max(0, above.score - _userScore + 1);
  }

  String get resetCountdown {
    final now      = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final rem      = midnight.difference(now);
    final h = rem.inHours;
    final m = rem.inMinutes % 60;
    final s = rem.inSeconds % 60;
    return '${_z(h)}:${_z(m)}:${_z(s)}';
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
