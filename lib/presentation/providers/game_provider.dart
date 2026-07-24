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

  int get currentLevelId => _currentLevelId;

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

  // ── Board state version ───────────────────────────────────────────────────
  // Incremented only when board-visible state changes: tubes, activePours,
  // isHinting, hintFrom/To, selectedIndex.  Widgets that only care about
  // the board (e.g. _GameBoard) use context.select on this int so they
  // rebuild only when the board actually changes, not on every
  // hints/moves/undo-count update.  Meta-state changes (hints count,
  // maxMoves, undo stack size) intentionally do NOT increment this, so
  // _GameControls and _GameHeader can similarly scope their rebuilds via
  // context.select on their own specific fields.
  int _boardStateVersion = 0;
  int get boardStateVersion => _boardStateVersion;

  // Bumped by undo() and level loads. Each pour's deferred win/game-over
  // check captures this value when scheduled; if it no longer matches when
  // the callback fires, the outcome is stale and is safely discarded.
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
      _hints = prefs.getInt(AppConstants.keyTotalHints) ??
          AppConstants.initialHints;
      _updateStreak(prefs);
    } catch (_) {}

    _audio.init().catchError((_) {});
    _loadLevelInternal(savedLevelId.clamp(0, 999999));
  }

  void _loadLevelInternal(int globalId) {
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
    _levelStartTime = DateTime.now();
    _boardStateVersion++;   // new level = new board
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
    loadLevel(_currentLevelId + 1);
  }

  void startEndlessMode() {
    final start = max(100, _currentLevelId + 1);
    loadLevel(start);
  }

  bool get isEndlessLevel => _currentLevelId >= 100;

  // ── Tube selection & pour ───────────────────────────────────────────────────
  void selectTube(int index) {
    if (_status != GameStatus.playing) return;
    // Block new taps while a pour animation is in flight.  With the
    // deferred-tube-update model (colors only applied after 700 ms), a second
    // tap during that window would read stale pre-pour tube data and produce
    // wrong results — so we simply ignore it.
    if (isPouring) return;
    if (isOutOfMoves) return;
    if (index < 0 || index >= _tubes.length) return;

    _audio.playTap().catchError((_) {});

    if (_selectedIndex == null) {
      if (_tubes[index].isEmpty)    return;
      if (_tubes[index].isPerfect)  return;
      _selectedIndex = index;
      _tubes[index] = _tubes[index].copyWith(isSelected: true);
      _tryHaptic(HapticFeedback.selectionClick);
      _boardStateVersion++;
      notifyListeners();
      return;
    }

    if (_selectedIndex == index) {
      _tubes[index] = _tubes[index].copyWith(isSelected: false);
      _selectedIndex = null;
      _boardStateVersion++;
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
      _boardStateVersion++;
      notifyListeners();
    }
  }

  // ── Pour execution ───────────────────────────────────────────────────────────
  // DEFERRED-UPDATE MODEL:
  // Tube colors are NOT changed immediately.  The pour animation must play
  // first (700 ms) so the stream is visually consistent with the liquid
  // movement — previously colors jumped in the destination tube BEFORE the
  // stream appeared, because notifyListeners() rebuilt the board with the
  // post-pour data before _PourOverlay even mounted its AnimationController.
  //
  // Flow:
  //  1. Capture undo snapshot (pre-pour state).
  //  2. Pre-compute the post-pour tube states.
  //  3. Deselect source tube visually (no color change yet).
  //  4. Add PourEvent → first notifyListeners() → overlay appears, liquid UNCHANGED.
  //  5. After 700 ms: apply pre-computed colors + resolve win/loss.
  void _executePour(int fromIdx, int toIdx) {
    if (fromIdx == toIdx) return;
    if (fromIdx < 0 || fromIdx >= _tubes.length) return;
    if (toIdx   < 0 || toIdx   >= _tubes.length) return;
    if (isPouring)     return;
    if (isOutOfMoves)  return;

    final from = _tubes[fromIdx];
    final to   = _tubes[toIdx];
    if (!to.canReceive(from)) return;

    final topColor  = from.topColor!;
    final topCount  = from.topColorCount;
    final canFit    = to.capacity - to.colors.length;
    final moveCount = min(topCount, canFit);

    // ── Undo snapshot — pre-pour state ────────────────────────────────────
    _undoStack.add(_tubes
        .map((t) => t.copyWith(colors: List<int>.from(t.colors), isSelected: false))
        .toList());
    if (_undoStack.length > AppConstants.maxUndoStack) _undoStack.removeAt(0);

    // ── Pre-compute post-pour tube states ──────────────────────────────────
    final newFromColors = List<int>.from(from.colors)
      ..removeRange(from.colors.length - moveCount, from.colors.length);
    final newToColors   = List<int>.from(to.colors)
      ..addAll(List.filled(moveCount, topColor));

    final rawToTube  = TubeModel(colors: newToColors, capacity: to.capacity);
    final resultFrom = _tubes[fromIdx].copyWith(colors: newFromColors, isSelected: false);
    final resultTo   = rawToTube.isPerfect
        ? rawToTube.copyWith(isCompleted: true)
        : rawToTube;

    // ── Check outcome with the result state ────────────────────────────────
    // We compute win/loss NOW so the 700ms callback is a pure data-apply step
    // with no heavy logic.  justWon/justLost are captured in the closure.
    final resultTubes = List<TubeModel>.from(_tubes)
      ..[fromIdx] = resultFrom
      ..[toIdx]   = resultTo;
    final justWon = resultTubes.every((t) => t.isEmpty || t.isPerfect);

    // Increment moves immediately (drives isOutOfMoves → justLost)
    _moves++;
    final justLost = !justWon && isOutOfMoves;

    // ── Visual-only changes (NO color data change yet) ─────────────────────
    // Clear the selection highlight on the source tube so it no longer glows
    // blue, but keep its liquid at the pre-pour level.
    _tubes[fromIdx] = _tubes[fromIdx].copyWith(isSelected: false);
    _selectedIndex  = null;

    _audio.playPour().catchError((_) {});
    _tryHaptic(HapticFeedback.lightImpact);

    final id  = _pourIdCounter++;
    final gen = _undoGeneration;
    _activePours.add(PourEvent(
      id: id, fromIndex: fromIdx, toIndex: toIdx, color: topColor, count: moveCount,
    ));

    // First notify: pour overlay appears.  Tube COLORS are unchanged here so
    // the user sees the stream start flowing before any liquid moves.
    _boardStateVersion++;
    notifyListeners();

    // ── After animation: apply colors + resolve game state ─────────────────
    Future.delayed(const Duration(milliseconds: 700), () {
      _activePours.removeWhere((p) => p.id == id);

      if (gen != _undoGeneration) {
        // Undo() was called during the animation — it already restored _tubes
        // from the snapshot.  Just clear the overlay and return.
        _boardStateVersion++;
        notifyListeners();
        return;
      }

      // Apply the pre-computed result (AnimatedContainer will smoothly animate
      // the liquid level change from its current visual state to the new one)
      _tubes[fromIdx] = resultFrom;
      _tubes[toIdx]   = resultTo;

      if (resultTo.isCompleted) {
        _audio.playChime().catchError((_) {});
      }

      if (_status == GameStatus.playing) {
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

      // Second notify: overlay gone, colors updated.  AnimatedContainer in
      // _LiquidFill transitions from the pre-pour to post-pour liquid level.
      _boardStateVersion++;
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
    _undoGeneration++;
    _audio.playClick().catchError((_) {});
    _tryHaptic(HapticFeedback.selectionClick);
    _boardStateVersion++;
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
    if (isPouring)     return;

    final move = _findBestMove();
    if (move == null) return;

    _hints--;
    _hintFromIndex = move[0];
    _hintToIndex   = move[1];
    _isHinting     = true;
    _audio.playClick().catchError((_) {});
    _boardStateVersion++;
    notifyListeners();

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
      // _executePour increments _boardStateVersion and calls notifyListeners
      _executePour(move[0], move[1]);
    });
  }

  List<int>? _findBestMove() {
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

  // Zero-pad month/day so the stored string is always ISO-8601
  // (e.g. "2025-07-05"). The original bare interpolation (e.g. "2025-7-5")
  // causes DateTime.tryParse to return null on single-digit months or days —
  // true for 9 of 12 months and most days — silently breaking streak
  // counting for the large majority of calendar days.
  static String _z(int v) => v.toString().padLeft(2, '0');

  void _updateStreak(SharedPreferences prefs) {
    try {
      final today    = DateTime.now();
      final todayStr = '${today.year}-${_z(today.month)}-${_z(today.day)}';
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
        _checkStreakMilestone(_dailyStreak, prefs);
      }
      prefs.setInt(AppConstants.keyDailyStreak,    _dailyStreak);
      prefs.setString(AppConstants.keyLastPlayDate, todayStr);
    } catch (_) {}
  }

  void _checkStreakMilestone(int streak, SharedPreferences prefs) {
    final milestones = AppConstants.streakHintRewards.keys.toList()..sort();
    for (final day in milestones) {
      if (streak == day) {
        final claimedKey = '${AppConstants.keyStreakClaimedPrefix}$day';
        if (prefs.getBool(claimedKey) == true) return;

        final hints    = AppConstants.streakHintRewards[day] ?? 0;
        final adHours  = AppConstants.streakAdFreeHours[day] ?? 0;

        if (hints > 0) {
          _hints += hints;
          prefs.setInt(AppConstants.keyTotalHints, _hints);
        }

        if (adHours > 0) {
          IapService().grantStreakAdFree(adHours);
        }

        prefs.setBool(claimedKey, true);

        _pendingStreakReward = StreakReward(
          streak:      day,
          hints:       hints,
          adFreeHours: adHours,
        );
        notifyListeners();
        return;
      }
    }
  }

  void _tryHaptic(Future<void> Function() fn) => fn().catchError((_) {});
}
