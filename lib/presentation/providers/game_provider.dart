import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/game_model.dart';
import '../../data/levels/level_generator.dart';
import '../../services/audio_service.dart';
import '../../core/constants/app_constants.dart';

enum GameStatus { idle, playing, won, failed }

class GameProvider extends ChangeNotifier {
  final _audio = AudioService();
  late List<LevelConfig> _allLevels;
  late LevelConfig _currentLevel;

  List<TubeModel> _tubes = [];
  List<TubeModel> get tubes => _tubes;

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

  int _hints = 3; // start with 3 free hints
  int get hints => _hints;

  bool _showingHint = false;
  int? _hintFromIndex;
  int? _hintToIndex;

  LevelConfig get currentLevel => _currentLevel;

  Future<void> init() async {
    _allLevels = LevelGenerator.generateAll();
    await _loadProgress();
    await _audio.init();
    loadLevel(_currentWorldIndex * 20 + _currentLevelInWorld);
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    _currentWorldIndex = prefs.getInt(AppConstants.keyCurrentWorld) ?? 0;
    _currentLevelInWorld = prefs.getInt(AppConstants.keyCurrentLevel) ?? 0;
    _totalLevelsCompleted = prefs.getInt(AppConstants.keyTotalLevelsCompleted) ?? 0;
    _dailyStreak = prefs.getInt(AppConstants.keyDailyStreak) ?? 0;
    _hints = prefs.getInt(AppConstants.keyTotalHints) ?? 3;
    _checkDailyStreak(prefs);
  }

  void _checkDailyStreak(SharedPreferences prefs) {
    final lastStr = prefs.getString(AppConstants.keyLastPlayDate);
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';
    if (lastStr == null) {
      prefs.setString(AppConstants.keyLastPlayDate, todayStr);
    } else if (lastStr != todayStr) {
      final last = DateTime.parse(lastStr);
      final diff = today.difference(last).inDays;
      if (diff == 1) {
        _dailyStreak++;
      } else if (diff > 1) {
        _dailyStreak = 1;
      }
      prefs.setInt(AppConstants.keyDailyStreak, _dailyStreak);
      prefs.setString(AppConstants.keyLastPlayDate, todayStr);
    }
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.keyCurrentWorld, _currentWorldIndex);
    await prefs.setInt(AppConstants.keyCurrentLevel, _currentLevelInWorld);
    await prefs.setInt(AppConstants.keyTotalLevelsCompleted, _totalLevelsCompleted);
    await prefs.setInt(AppConstants.keyTotalHints, _hints);
  }

  void loadLevel(int globalId) {
    final idx = globalId.clamp(0, _allLevels.length - 1);
    _currentLevel = _allLevels[idx];
    _currentWorldIndex = _currentLevel.worldId;
    _currentLevelInWorld = _currentLevel.levelInWorld;
    _tubes = _currentLevel.initialState
        .map((colors) => TubeModel(colors: List.from(colors)))
        .toList();
    _selectedIndex = null;
    _undoStack.clear();
    _moves = 0;
    _stars = 0;
    _status = GameStatus.playing;
    _showingHint = false;
    _hintFromIndex = null;
    _hintToIndex = null;
    _audio.playLevelStart();
    notifyListeners();
  }

  void restartLevel() {
    loadLevel(_currentLevel.id);
    _audio.playClick();
  }

  void nextLevel() {
    final nextId = _currentLevel.id + 1;
    if (nextId < _allLevels.length) {
      if (_currentLevelInWorld + 1 >= AppConstants.levelsPerWorld) {
        _currentWorldIndex = min(_currentWorldIndex + 1, AppConstants.totalWorlds - 1);
      }
      loadLevel(nextId);
    }
  }

  void selectTube(int index) {
    if (_status != GameStatus.playing) return;
    _audio.playTap();

    if (_selectedIndex == null) {
      if (_tubes[index].isEmpty) return;
      if (_tubes[index].isPerfect) return;
      _selectedIndex = index;
      _tubes[index] = _tubes[index].copyWith(isSelected: true);
      HapticFeedback.selectionClick();
      notifyListeners();
      return;
    }

    if (_selectedIndex == index) {
      // Deselect
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
      // Switch selection
      _audio.playError();
      HapticFeedback.heavyImpact();
      _tubes[_selectedIndex!] = _tubes[_selectedIndex!].copyWith(isSelected: false);
      if (!_tubes[index].isEmpty) {
        _selectedIndex = index;
        _tubes[index] = _tubes[index].copyWith(isSelected: true);
      } else {
        _selectedIndex = null;
      }
      notifyListeners();
    }
  }

  void _pour(int fromIdx, int toIdx) {
    // Save undo snapshot
    _undoStack.add(_tubes.map((t) => t.copyWith(colors: List.from(t.colors), isSelected: false)).toList());
    if (_undoStack.length > AppConstants.maxUndoStack) _undoStack.removeAt(0);

    final fromTube = _tubes[fromIdx];
    final toTube = _tubes[toIdx];
    final topColor = fromTube.topColor!;
    final topCount = fromTube.topColorCount;
    final canFit = toTube.capacity - toTube.colors.length;
    final moveCount = min(topCount, canFit);

    final newFromColors = List<int>.from(fromTube.colors);
    final newToColors = List<int>.from(toTube.colors);
    for (int i = 0; i < moveCount; i++) {
      newFromColors.removeLast();
      newToColors.add(topColor);
    }

    _tubes[fromIdx] = fromTube.copyWith(colors: newFromColors, isSelected: false);
    _tubes[toIdx] = toTube.copyWith(colors: newToColors);
    _selectedIndex = null;
    _moves++;

    _audio.playPour();
    HapticFeedback.lightImpact();

    // Check tube completion
    if (_tubes[toIdx].isPerfect) {
      _tubes[toIdx] = _tubes[toIdx].copyWith(isCompleted: true);
      _audio.playChime();
    }

    _checkWin();
    notifyListeners();
  }

  void _checkWin() {
    final allDone = _tubes.every((t) => t.isEmpty || t.isPerfect);
    if (allDone) {
      _status = GameStatus.won;
      _totalLevelsCompleted++;
      _stars = _calculateStars();
      _audio.playWin();
      HapticFeedback.heavyImpact();
      _saveProgress();
    }
  }

  int _calculateStars() {
    final optimal = _currentLevel.colorCount * 4;
    if (_moves <= optimal) return 3;
    if (_moves <= optimal * 1.5) return 2;
    return 1;
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _tubes = _undoStack.removeLast();
    _selectedIndex = null;
    _moves = max(0, _moves - 1);
    _status = GameStatus.playing;
    _audio.playClick();
    HapticFeedback.selectionClick();
    notifyListeners();
  }

  /// Use hint — highlights best move
  void useHint() {
    if (_hints <= 0) return;
    final move = _findBestMove();
    if (move == null) return;
    _hints--;
    _hintFromIndex = move[0];
    _hintToIndex = move[1];
    _showingHint = true;
    _audio.playClick();
    notifyListeners();
    Future.delayed(const Duration(seconds: 2), () {
      _showingHint = false;
      _hintFromIndex = null;
      _hintToIndex = null;
      notifyListeners();
    });
  }

  List<int>? _findBestMove() {
    // Priority: complete a tube first, then best fill
    for (int f = 0; f < _tubes.length; f++) {
      if (_tubes[f].isEmpty) continue;
      for (int t = 0; t < _tubes.length; t++) {
        if (f == t) continue;
        if (_tubes[t].canReceive(_tubes[f])) {
          // Check if it would complete the to-tube
          final newCount = _tubes[t].colors.length + _tubes[f].topColorCount;
          if (newCount == _tubes[t].capacity) return [f, t];
        }
      }
    }
    // Fallback: any valid move
    for (int f = 0; f < _tubes.length; f++) {
      if (_tubes[f].isEmpty) continue;
      for (int t = 0; t < _tubes.length; t++) {
        if (f == t) continue;
        if (_tubes[t].canReceive(_tubes[f])) return [f, t];
      }
    }
    return null;
  }

  bool get isHinting => _showingHint;
  int? get hintFrom => _hintFromIndex;
  int? get hintTo => _hintToIndex;

  /// Called after watching rewarded ad
  void addHints(int count) {
    _hints += count;
    _saveProgress();
    notifyListeners();
  }

  void addUndoFromAd() {
    // After ad, give one free undo
    if (_undoStack.isNotEmpty) undo();
    notifyListeners();
  }
}
