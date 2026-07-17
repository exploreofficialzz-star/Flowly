import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/game_model.dart';
import '../../data/levels/level_generator.dart';
import '../../services/audio_service.dart';
import '../../services/iap_service.dart';
import '../../core/constants/app_constants.dart';

enum GameStatus { idle, playing, won, gameOver }

/// Carries the pending streak milestone reward (shown once as a popup).
class StreakReward {
  final int streak;
  final int hints;
  final int adFreeHours;
  const StreakReward({
    required this.streak,
    required this.hints,
    required this.adFreeHours,
  });
}

class PourEvent {
  final int id;
  final int fromIndex;
  final int toIndex;
  final int color;
  final int count;
  PourEvent({
    required this.id,
    required this.fromIndex,
    required this.toIndex,
    required this.color,
    required this.count,
  });
}

class GameProvider extends ChangeNotifier {
  final _audio = AudioService();
  final List<LevelConfig> _allLevels = LevelGenerator.generateAll();

  List<TubeModel> _tubes = [];
  List<TubeModel> get tubes => List.unmodifiable(_tubes);

  int? _selectedIndex;
  int? get selectedIndex => _selectedIndex;

  final List<List<TubeModel>> _undoStack = [];
  int get undoCount => _undoStack.length;

  GameStatus _status = GameStatus.idle;
  GameStatus get status => _status;

  int _moves = 0;
  int get moves => _moves;

  int _maxMoves = 20;
  int get maxMoves => _maxMoves;
  int get movesRemaining => (_maxMoves - _moves).clamp(0, _maxMoves);
  bool get isMovesLow =>
      movesRemaining <= AppConstants.lowMovesWarning &&
      _status == GameStatus.playing;
  bool get isOutOfMoves => movesRemaining <= 0;

  int _stars = 0;
  int get stars => _stars;

  int _currentWorldIndex = 0;
  int get currentWorldIndex => _currentWorldIndex;

  int _currentLevelInWorld = 0;
  int get currentLevelInWorld => _currentLevelInWorld;

  int _totalLevelsCompleted = 0;
  int get totalLevelsCompleted => _totalLevelsCompleted;

  int _dailyStreak = 0;
  int get dailyStreak => _dailyStreak;

  // Starts at initialHints (2) for every fresh install
  int _hints = AppConstants.initialHints;
  int get hints => _hints;

  int _currentLevelId = 0;

  bool _isHinting = false;
  int? _hintFromIndex;
  int? _hintToIndex;
  bool get isHinting  => _isHinting;
  int? get hintFrom   => _hintFromIndex;
  int? get hintTo     => _hintToIndex;

  // Multiple pours can be visually in flight at once — each move commits to
  // the data model instantly (see _executePour), so one tube's pour never
  // blocks another tube from being tapped in the meantime. This list is
  // purely cosmetic: it only drives which stream/splash overlays render.
  final List<PourEvent> _activePours = [];
  List<PourEvent> get activePours => List.unmodifiable(_activePours);
  bool get isPouring => _activePours.isNotEmpty;
  int _pourIdCounter = 0;

  // Bumped by undo() and level loads. Each pour's deferred win/game-over
  // check captures this value when scheduled; if it no longer matches when
  // the callback fires, the outcome is stale (e.g. the move was undone
  // before its animation finished) and is safely discarded instead of
  // wrongly flipping the game to won/gameOver after the fact.
  int _undoGeneration = 0;

  // ── Competition timing & color count ──────────────────────────────────────
  DateTime? _levelStartTime;
  int get elapsedSeconds => _levelStartTime != null
      ? DateTime.now().difference(_levelStartTime!).inSeconds
      : 120;
  int get currentColorCount => _currentLevelConfig?.colorCount ?? 4;

  // Active level config (supports infinite levels beyond index 99)
  LevelConfig? _currentLevelConfig;

  // Pending streak milestone reward — UI shows popup then clears this
  StreakReward? _pendingStreakReward;
  StreakReward? get pendingStreakReward => _pendingStreakReward;
  void clearStreakReward() { _pendingStreakReward = null; notifyListeners(); }

  // ── Init ────────────────────────────────────────────────────────────────────
  Future<void> init() async {
    int savedLevelId = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentWorldIndex = prefs.getInt(AppConstants.keyCurrentWorld) ?? 0;
      _currentLevelInWorld = prefs.getInt(AppConstants.keyCurrentLevel) ?? 0;
      savedLevelId = prefs.getInt(AppConstants.keyCurrentLevel) ?? 0;
      _totalLevelsCompleted =
          prefs.getInt(AppConstants.keyTotalLevelsCompleted) ?? 0;
      _dailyStreak = prefs.getInt(AppConstants.keyDailyStreak) ?? 0;
      // Use persisted hints; fall back to initialHints (2) for new installs
      _hints = prefs.getInt(AppConstants.keyTotalHints) ??
          AppConstants.initialHints;
      _updateStreak(prefs);
    } catch (_) {}

    _audio.init().catchError((_) {});

    _loadLevelInternal(savedLevelId.clamp(0, 999999));
  }

  void _loadLevelInternal(int globalId) {
    // Use LevelGenerator.levelAt() which handles both campaign (0-99) and endless (100+)
    final lvl = LevelGenerator.levelAt(globalId);
    _currentLevelConfig = lvl;
    _currentLevelId        = globalId;
    _currentWorldIndex     = lvl.worldId;
    _currentLevelInWorld   = lvl.levelInWorld;
    _maxMoves              = lvl.maxMoves;
    _tubes = lvl.initialState
        .map((c) => TubeModel(colors: List<int>.from(c)))
        .toList();
    _selectedIndex  = null;
    _moves          = 0;
    _stars          = 0;
    _status         = GameStatus.playing;
    _isHinting      = false;
    _hintFromIndex  = null;
    _hintToIndex    = null;
    _activePours.clear();
    _undoGeneration++;
    _undoStack.clear();
    _levelStartTime = DateTime.now(); // competition timer starts here
    notifyListeners();
    _audio.playLevelStart().catchError((_) {});
  }

  void loadLevel(int globalId) {
    _loadLevelInternal(globalId);
    _saveProgress();
  }

  void restartLevel() {
    _loadLevelInternal(_currentLevelId);
    _audio.playClick().catchError((_) {});
  }

  void nextLevel() {
    // No upper bound — LevelGenerator.levelAt() generates campaign levels for
    // ids 0-99 and infinite Endless levels for id 100+.
    loadLevel(_currentLevelId + 1);
  }

  /// Jumps straight into Endless Mode from anywhere (e.g. a menu button).
  /// Always lands on a fresh endless level the player hasn't necessarily seen,
  /// keeping at least 100 as the floor.
  void startEndlessMode() {
    final start = max(100, _currentLevelId + 1);
    loadLevel(start);
  }

  bool get isEndlessLevel => _currentLevelId >= 100;

  // ── Tube selection & pour ───────────────────────────────────────────────────
  void selectTube(int index) {
    if (_status != GameStatus.playing) return;
    // Once moves are exhausted, stop accepting new pours right away — even
    // though the game-over overlay itself is deferred until the triggering
    // pour's animation finishes (see _executePour), input stops immediately
    // so the player can't sneak in bonus moves during that visual buffer.
    if (isOutOfMoves) return;
    if (index < 0 || index >= _tubes.length) return;

    _audio.playTap().catchError((_) {});

    if (_selectedIndex == null) {
      if (_tubes[index].isEmpty)    return;
      if (_tubes[index].isPerfect)  return;
      _selectedIndex = index;
      _tubes[index] = _tubes[index].copyWith(isSelected: true);
      _tryHaptic(HapticFeedback.selectionClick);
      notifyListeners();
      return;
    }

    if (_selectedIndex == index) {
      _tubes[index] = _tubes[index].copyWith(isSelected: false);
      _selectedIndex = null;
      notifyListeners();
      return;
    }

    final from = _tubes[_selectedIndex!];
    final to   = _tubes[index];

    if (to.canReceive(from)) {
      _executePour(_selectedIndex!, index);
    } else {
      _audio.playError().catchError((_) {});
      _tryHaptic(HapticFeedback.heavyImpact);
      _tubes[_selectedIndex!] =
          _tubes[_selectedIndex!].copyWith(isSelected: false);
      if (!_tubes[index].isEmpty && !_tubes[index].isPerfect) {
        _selectedIndex = index;
        _tubes[index] = _tubes[index].copyWith(isSelected: true);
      } else {
        _selectedIndex = null;
      }
      notifyListeners();
    }
  }

  // ── Pour execution ───────────────────────────────────────────────────────────
  // Data mutates INSTANTLY here — the move, undo snapshot, and win/game-over
  // outcome are all decided synchronously the moment a move is validated.
  // The 700ms that follows is a purely cosmetic stream+splash animation
  // with zero effect on game state, tracked in _activePours. This is what
  // lets one tube's pour animate without freezing input on the rest of the
  // board — previously a single _isPouring flag blocked every tube until
  // each pour's animation had fully finished playing.
  void _executePour(int fromIdx, int toIdx) {
    if (fromIdx == toIdx) return;
    if (fromIdx < 0 || fromIdx >= _tubes.length) return;
    if (toIdx   < 0 || toIdx   >= _tubes.length) return;
    if (isOutOfMoves) return;

    final from = _tubes[fromIdx];
    final to   = _tubes[toIdx];
    if (!to.canReceive(from)) return; // stale/invalid move — safe no-op

    final topColor  = from.topColor!;
    final topCount  = from.topColorCount;
    final canFit    = to.capacity - to.colors.length;
    final moveCount = min(topCount, canFit);

    // Undo snapshot — captured BEFORE mutating, same as before.
    _undoStack.add(_tubes
        .map((t) => t.copyWith(
            colors: List<int>.from(t.colors), isSelected: false))
        .toList());
    if (_undoStack.length > AppConstants.maxUndoStack) _undoStack.removeAt(0);

    final newFrom = List<int>.from(_tubes[fromIdx].colors);
    final newTo   = List<int>.from(_tubes[toIdx].colors);
    for (int i = 0; i < moveCount; i++) {
      newFrom.removeLast();
      newTo.add(topColor);
    }

    final newToTube = TubeModel(colors: newTo, capacity: _tubes[toIdx].capacity);
    _tubes[fromIdx] = _tubes[fromIdx].copyWith(colors: newFrom, isSelected: false);
    _tubes[toIdx]   = newToTube.isPerfect
        ? newToTube.copyWith(isCompleted: true)
        : newToTube;

    _selectedIndex = null;
    _moves++;

    _audio.playPour().catchError((_) {});
    _tryHaptic(HapticFeedback.lightImpact);
    if (_tubes[toIdx].isCompleted) {
      _audio.playChime().catchError((_) {});
    }

    // Register a purely-visual pour — the UI animates it independently and
    // it self-removes below. No game logic depends on it any further.
    final id  = _pourIdCounter++;
    final gen = _undoGeneration;
    _activePours.add(PourEvent(
      id: id, fromIndex: fromIdx, toIndex: toIdx, color: topColor, count: moveCount,
    ));

    // Outcome is already final — data won't change between now and when the
    // animation finishes, so it's safe to decide it here and just delay
    // *showing* it until the visual catches up with what already happened.
    final justWon  = _isBoardSolved();
    final justLost = !justWon && isOutOfMoves;

    notifyListeners();

    Future.delayed(const Duration(milliseconds: 700), () {
      _activePours.removeWhere((p) => p.id == id);

      // gen guards against a stale outcome: if undo() (or a new level load)
      // ran in the meantime, this pour's result no longer applies.
      // The `playing` guard means whichever pour's timer fires first
      // (always the earliest-started one, since every pour runs the same
      // fixed duration) performs the transition once; later ones no-op.
      if (_status == GameStatus.playing && gen == _undoGeneration) {
        if (justWon) {
          _status = GameStatus.won;
          _totalLevelsCompleted++;
          _stars = _calculateStars();
          _audio.playWin().catchError((_) {});
          _tryHaptic(HapticFeedback.heavyImpact);
          _saveProgress();
        } else if (justLost) {
          _status = GameStatus.gameOver;
          _audio.playError().catchError((_) {});
          _tryHaptic(HapticFeedback.heavyImpact);
        }
      }
      notifyListeners();
    });
  }

  bool _isBoardSolved() => _tubes.every((t) => t.isEmpty || t.isPerfect);

  int _calculateStars() {
    final optimal = currentColorCount * 4;
    if (_moves <= optimal)                    return 3;
    if (_moves <= (optimal * 1.6).round())    return 2;
    return 1;
  }

  /// True when the just-completed level should trigger an interstitial,
  /// based on AppConstants.interstitialEveryNLevels (currently every 2 wins).
  bool get shouldShowInterstitial =>
      _totalLevelsCompleted > 0 &&
      _totalLevelsCompleted % AppConstants.interstitialEveryNLevels == 0;

  // ── Undo ────────────────────────────────────────────────────────────────────
  void undo() {
    if (_undoStack.isEmpty) return;
    _tubes         = _undoStack.removeLast();
    _selectedIndex = null;
    _moves         = max(0, _moves - 1);
    _status        = GameStatus.playing;
    _activePours.clear();
    _undoGeneration++; // invalidate any pending pour outcome from before this undo
    _audio.playClick().catchError((_) {});
    _tryHaptic(HapticFeedback.selectionClick);
    notifyListeners();
  }

  void addUndoFromAd() {
    if (_undoStack.isNotEmpty) undo();
  }

  // ── Hint — auto-executes best move ──────────────────────────────────────────
  void useHint() {
    if (_status != GameStatus.playing) return;
    if (_hints <= 0)   return;
    if (isOutOfMoves)  return;

    final move = _findBestMove();
    if (move == null) return;

    _hints--;
    _hintFromIndex = move[0];
    _hintToIndex   = move[1];
    _isHinting     = true;
    _audio.playClick().catchError((_) {});
    notifyListeners();

    // Brief highlight then auto-execute. _executePour re-validates the move
    // itself (via canReceive) before touching anything, so if the board
    // changed in the meantime — the player made a manual move during this
    // highlight window — a now-stale hint safely no-ops instead of
    // corrupting state.
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!_isHinting) return;
      _isHinting     = false;
      _hintFromIndex = null;
      _hintToIndex   = null;
      for (int i = 0; i < _tubes.length; i++) {
        if (_tubes[i].isSelected) {
          _tubes[i] = _tubes[i].copyWith(isSelected: false);
        }
      }
      _selectedIndex = null;
      _executePour(move[0], move[1]);
    });
  }

  List<int>? _findBestMove() {
    // Prefer moves that complete a tube
    for (int f = 0; f < _tubes.length; f++) {
      if (_tubes[f].isEmpty) continue;
      for (int t = 0; t < _tubes.length; t++) {
        if (f == t) continue;
        if (_tubes[t].canReceive(_tubes[f])) {
          final after =
              _tubes[t].colors.length + _tubes[f].topColorCount;
          if (after == _tubes[t].capacity) return [f, t];
        }
      }
    }
    // Any valid move
    for (int f = 0; f < _tubes.length; f++) {
      if (_tubes[f].isEmpty) continue;
      for (int t = 0; t < _tubes.length; t++) {
        if (f == t) continue;
        if (_tubes[t].canReceive(_tubes[f])) return [f, t];
      }
    }
    return null;
  }

  void addHints(int count) {
    _hints += count;
    _saveProgress();
    notifyListeners();
  }

  // ── Extra moves from rewarded ad ────────────────────────────────────────────
  void addExtraMoves(int count) {
    _maxMoves += count;
    if (_status == GameStatus.gameOver) _status = GameStatus.playing;
    _audio.playClick().catchError((_) {});
    notifyListeners();
  }

  // ── Persistence ─────────────────────────────────────────────────────────────
  Future<void> _saveProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(AppConstants.keyCurrentLevel,         _currentLevelId);
      await prefs.setInt(AppConstants.keyCurrentWorld,         _currentWorldIndex);
      await prefs.setInt(AppConstants.keyTotalLevelsCompleted, _totalLevelsCompleted);
      await prefs.setInt(AppConstants.keyTotalHints,           _hints);
    } catch (_) {}
  }

  void _updateStreak(SharedPreferences prefs) {
    try {
      final today    = DateTime.now();
      final todayStr = '${today.year}-${today.month}-${today.day}';
      final lastStr  = prefs.getString(AppConstants.keyLastPlayDate);
      if (lastStr == null) {
        prefs.setString(AppConstants.keyLastPlayDate, todayStr);
        return;
      }
      if (lastStr == todayStr) return;
      final last = DateTime.tryParse(lastStr);
      if (last != null) {
        final diff   = today.difference(last).inDays;
        _dailyStreak = diff == 1 ? _dailyStreak + 1 : 1;
        // Check streak milestones after updating
        _checkStreakMilestone(_dailyStreak, prefs);
      }
      prefs.setInt(AppConstants.keyDailyStreak,    _dailyStreak);
      prefs.setString(AppConstants.keyLastPlayDate, todayStr);
    } catch (_) {}
  }

  /// Checks if the new streak day hits a reward milestone. Grants reward once.
  void _checkStreakMilestone(int streak, SharedPreferences prefs) {
    final milestones = AppConstants.streakHintRewards.keys.toList()..sort();
    for (final day in milestones) {
      if (streak == day) {
        final claimedKey = '${AppConstants.keyStreakClaimedPrefix}$day';
        if (prefs.getBool(claimedKey) == true) return; // already claimed

        final hints    = AppConstants.streakHintRewards[day] ?? 0;
        final adHours  = AppConstants.streakAdFreeHours[day] ?? 0;

        // Grant hints immediately
        if (hints > 0) {
          _hints += hints;
          prefs.setInt(AppConstants.keyTotalHints, _hints);
        }

        // Grant ad-free time via IapService
        if (adHours > 0) {
          IapService().grantStreakAdFree(adHours);
        }

        // Mark claimed
        prefs.setBool(claimedKey, true);

        // Queue the reward popup for the UI
        _pendingStreakReward = StreakReward(
          streak:      day,
          hints:       hints,
          adFreeHours: adHours,
        );
        notifyListeners();
        return; // only one milestone per update
      }
    }
  }

  void _tryHaptic(Future<void> Function() fn) => fn().catchError((_) {});
}
