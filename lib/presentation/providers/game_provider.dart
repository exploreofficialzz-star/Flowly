import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/game_model.dart';
import '../../data/levels/level_generator.dart';
import '../../services/audio_service.dart';
import '../../core/constants/app_constants.dart';

enum GameStatus { idle, playing, won }

class GameProvider extends ChangeNotifier {
  final _audio = AudioService();

  // All 100 levels — generated once synchronously
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

  int _hints = 3;
  int get hints => _hints;

  int _currentLevelId = 0;

  bool _isHinting = false;
  int? _hintFromIndex;
  int? _hintToIndex;
  bool get isHinting => _isHinting;
  int? get hintFrom => _hintFromIndex;
  int? get hintTo => _hintToIndex;

  // Called from splash screen
  Future<void> init() async {
    // Load progress from prefs
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentWorldIndex = prefs.getInt(AppConstants.keyCurrentWorld) ?? 0;
      _currentLevelInWorld = prefs.getInt(AppConstants.keyCurrentLevel) ?? 0;
      _totalLevelsCompleted =
          prefs.getInt(AppConstants.keyTotalLevelsCompleted) ?? 0;
      _dailyStreak = prefs.getInt(AppConstants.keyDailyStreak) ?? 0;
      _hints = prefs.getInt(AppConstants.keyTotalHints) ?? 3;
      _updateStreak(prefs);
    } catch (_) {
      // Defaults already set above
    }

    // Load audio (non-blocking)
    _audio.init().catchError((_) {});

    // Load the current level immediately
    final idx = (_currentWorldIndex * 20 + _currentLevelInWorld)
        .clamp(0, _allLevels.length - 1);
    _loadLevelInternal(idx);
  }

  void _loadLevelInternal(int globalId) {
    final idx = globalId.clamp(0, _allLevels.length - 1);
    final lvl = _allLevels[idx];
    _currentLevelId = idx;
    _currentWorldIndex = lvl.worldId;
    _currentLevelInWorld = lvl.levelInWorld;

    // Build tube models
    _tubes = lvl.initialState
        .map((colors) => TubeModel(colors: List<int>.from(colors)))
        .toList();

    _selectedIndex = null;
    _undoStack.clear();
    _moves = 0;
    _stars = 0;
    _status = GameStatus.playing;
    _isHinting = false;
    _hintFromIndex = null;
    _hintToIndex = null;

    notifyListeners();
    _audio.playLevelStart().catchError((_) {});
  }

  // Public API
  void loadLevel(int globalId) {
    _loadLevelInternal(globalId);
    _saveProgress();
  }

  void restartLevel() {
    _loadLevelInternal(_currentLevelId);
    _audio.playClick().catchError((_) {});
  }

  void nextLevel() {
    final nextId = _currentLevelId + 1;
    if (nextId < _allLevels.length) {
      loadLevel(nextId);
    }
  }

  void selectTube(int index) {
    if (_status != GameStatus.playing) return;
    if (index < 0 || index >= _tubes.length) return;

    _audio.playTap().catchError((_) {});

    // Nothing selected yet
    if (_selectedIndex == null) {
      if (_tubes[index].isEmpty) return;
      if (_tubes[index].isPerfect) return;
      _selectedIndex = index;
      _tubes[index] = _tubes[index].copyWith(isSelected: true);
      _tryHaptic(HapticFeedback.selectionClick);
      notifyListeners();
      return;
    }

    // Tapped same tube — deselect
    if (_selectedIndex == index) {
      _tubes[index] = _tubes[index].copyWith(isSelected: false);
      _selectedIndex = null;
      notifyListeners();
      return;
    }

    final from = _tubes[_selectedIndex!];
    final to = _tubes[index];

    if (to.canReceive(from)) {
      _pour(_selectedIndex!, index);
    } else {
      // Invalid — switch selection if target has liquid
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

  void _pour(int fromIdx, int toIdx) {
    // Snapshot for undo
    _undoStack.add(_tubes
        .map((t) => t.copyWith(
            colors: List<int>.from(t.colors), isSelected: false))
        .toList());
    if (_undoStack.length > 30) _undoStack.removeAt(0);

    final from = _tubes[fromIdx];
    final to = _tubes[toIdx];
    final topColor = from.topColor!;
    final topCount = from.topColorCount;
    final canFit = to.capacity - to.colors.length;
    final moveCount = min(topCount, canFit);

    final newFrom = List<int>.from(from.colors);
    final newTo = List<int>.from(to.colors);
    for (int i = 0; i < moveCount; i++) {
      newFrom.removeLast();
      newTo.add(topColor);
    }

    final newToTube = TubeModel(colors: newTo, capacity: to.capacity);
    _tubes[fromIdx] = from.copyWith(colors: newFrom, isSelected: false);
    _tubes[toIdx] = newToTube.isPerfect
        ? newToTube.copyWith(isCompleted: true)
        : newToTube;

    _selectedIndex = null;
    _moves++;

    _audio.playPour().catchError((_) {});
    _tryHaptic(HapticFeedback.lightImpact);

    if (_tubes[toIdx].isCompleted) {
      _audio.playChime().catchError((_) {});
    }

    _checkWin();
    notifyListeners();
  }

  void _checkWin() {
    final allDone = _tubes.every((t) => t.isEmpty || t.isPerfect);
    if (!allDone) return;
    _status = GameStatus.won;
    _totalLevelsCompleted++;
    _stars = _calculateStars();
    _audio.playWin().catchError((_) {});
    _tryHaptic(HapticFeedback.heavyImpact);
    _saveProgress();
  }

  int _calculateStars() {
    final lvl = _allLevels[_currentLevelId];
    final optimal = lvl.colorCount * 4;
    if (_moves <= optimal) return 3;
    if (_moves <= (optimal * 1.6).round()) return 2;
    return 1;
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _tubes = _undoStack.removeLast();
    _selectedIndex = null;
    _moves = max(0, _moves - 1);
    _status = GameStatus.playing;
    _audio.playClick().catchError((_) {});
    _tryHaptic(HapticFeedback.selectionClick);
    notifyListeners();
  }

  void useHint() {
    if (_hints <= 0) return;
    final move = _findBestMove();
    if (move == null) return;
    _hints--;
    _hintFromIndex = move[0];
    _hintToIndex = move[1];
    _isHinting = true;
    _audio.playClick().catchError((_) {});
    notifyListeners();
    Future.delayed(const Duration(seconds: 2), () {
      if (_isHinting) {
        _isHinting = false;
        _hintFromIndex = null;
        _hintToIndex = null;
        notifyListeners();
      }
    });
  }

  List<int>? _findBestMove() {
    // Priority 1: move that completes a tube
    for (int f = 0; f < _tubes.length; f++) {
      if (_tubes[f].isEmpty) continue;
      for (int t = 0; t < _tubes.length; t++) {
        if (f == t) continue;
        if (_tubes[t].canReceive(_tubes[f])) {
          final newCount =
              _tubes[t].colors.length + _tubes[f].topColorCount;
          if (newCount == _tubes[t].capacity) return [f, t];
        }
      }
    }
    // Priority 2: any valid move
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

  void addUndoFromAd() {
    if (_undoStack.isNotEmpty) undo();
  }

  Future<void> _saveProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(AppConstants.keyCurrentWorld, _currentWorldIndex);
      await prefs.setInt(AppConstants.keyCurrentLevel, _currentLevelInWorld);
      await prefs.setInt(
          AppConstants.keyTotalLevelsCompleted, _totalLevelsCompleted);
      await prefs.setInt(AppConstants.keyTotalHints, _hints);
    } catch (_) {}
  }

  void _updateStreak(SharedPreferences prefs) {
    try {
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month}-${today.day}';
      final lastStr = prefs.getString(AppConstants.keyLastPlayDate);
      if (lastStr == null) {
        prefs.setString(AppConstants.keyLastPlayDate, todayStr);
        return;
      }
      if (lastStr == todayStr) return;
      final last = DateTime.tryParse(lastStr);
      if (last != null) {
        final diff = today.difference(last).inDays;
        _dailyStreak = diff == 1 ? _dailyStreak + 1 : 1;
      }
      prefs.setInt(AppConstants.keyDailyStreak, _dailyStreak);
      prefs.setString(AppConstants.keyLastPlayDate, todayStr);
    } catch (_) {}
  }

  void _tryHaptic(Future<void> Function() fn) {
    fn().catchError((_) {});
  }
}
