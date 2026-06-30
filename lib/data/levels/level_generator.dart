import 'dart:math';
import '../models/game_model.dart';
import '../../core/constants/app_constants.dart';

/// Generates all campaign levels AND infinite endless levels.
/// Campaign:  globalId 0–99   (5 worlds × 20 levels)
/// Endless:   globalId 100+   (infinite, procedurally generated & guaranteed solvable)
class LevelGenerator {
  // ── Campaign: pre-generate all 100 levels at startup ─────────────────────────
  static List<LevelConfig> generateAll() {
    final levels = <LevelConfig>[];
    for (int world = 0; world < 5; world++) {
      for (int lvl = 0; lvl < 20; lvl++) {
        levels.add(_campaign(world * 20 + lvl, world, lvl));
      }
    }
    return levels;
  }

  // ── Universal accessor — works for ANY globalId ───────────────────────────────
  static LevelConfig levelAt(int globalId) {
    if (globalId < 0) globalId = 0;
    if (globalId < 100) {
      return _campaign(
        globalId,
        globalId ~/ AppConstants.levelsPerWorld,
        globalId % AppConstants.levelsPerWorld,
      );
    }
    return _endless(globalId);
  }

  // ── Daily Challenge ───────────────────────────────────────────────────────────
  static LevelConfig dailyChallenge(DateTime date) {
    final seed = date.year * 10000 + date.month * 100 + date.day;
    // Use a unique ID space (200+) so it never collides with campaign or endless
    return _campaign((seed % 100) + 200, 2, (seed % 20));
  }

  // ── Campaign level ────────────────────────────────────────────────────────────
  static LevelConfig _campaign(int id, int worldId, int levelInWorld) {
    final progress = (worldId * 20 + levelInWorld) / 100.0;
    int colorCount, emptyTubes, moveBonus;
    String difficulty;

    if (progress < 0.10) {
      colorCount = 3; emptyTubes = 2; difficulty = 'easy';   moveBonus = AppConstants.moveBonusEasy;
    } else if (progress < 0.25) {
      colorCount = 4; emptyTubes = 2; difficulty = 'easy';   moveBonus = AppConstants.moveBonusEasy;
    } else if (progress < 0.45) {
      colorCount = 5; emptyTubes = 2; difficulty = 'medium'; moveBonus = AppConstants.moveBonusMedium;
    } else if (progress < 0.60) {
      colorCount = 6; emptyTubes = 2; difficulty = 'medium'; moveBonus = AppConstants.moveBonusMedium;
    } else if (progress < 0.78) {
      colorCount = 7; emptyTubes = 2; difficulty = 'hard';   moveBonus = AppConstants.moveBonusHard;
    } else {
      colorCount = 8; emptyTubes = 2; difficulty = 'expert'; moveBonus = AppConstants.moveBonusExpert;
    }

    return LevelConfig(
      id:           id,
      worldId:      worldId.clamp(0, 4),
      levelInWorld: levelInWorld,
      tubeCount:    colorCount + emptyTubes,
      emptyTubes:   emptyTubes,
      colorCount:   colorCount,
      initialState: _buildShuffled(colorCount, emptyTubes, id),
      difficulty:   difficulty,
      maxMoves:     colorCount * 4 + moveBonus,
    );
  }

  // ── Endless level (globalId 100+) ─────────────────────────────────────────────
  static LevelConfig _endless(int globalId) {
    final endlessIdx = globalId - 100; // 0-based within endless

    // Progressive difficulty — increases slightly every 5 levels
    final tier       = endlessIdx ~/ 5;
    final colorCount = (8 + (tier ~/ 3)).clamp(8, 12);
    final emptyTubes = colorCount >= 11 ? 1 : 2;
    final maxMoves   = colorCount * 4 + AppConstants.moveBonusEndless;

    // Use reversal-based generation: GUARANTEED solvable
    final state = _buildByReversal(colorCount, emptyTubes, globalId * 7919 + 3571);

    return LevelConfig(
      id:           globalId,
      worldId:      5, // Endless Mode world
      levelInWorld: globalId, // display as Level 101, 102, ...
      tubeCount:    colorCount + emptyTubes,
      emptyTubes:   emptyTubes,
      colorCount:   colorCount,
      initialState: state,
      difficulty:   'endless',
      maxMoves:     maxMoves,
    );
  }

  // ── Reversal-based generator (guaranteed solvable) ────────────────────────────
  /// Start from solved state → apply N random valid scramble moves → result is
  /// ALWAYS solvable (just reverse the scramble moves to solve).
  static List<List<int>> _buildByReversal(int colorCount, int emptyTubes, int seed) {
    final rng      = Random(seed);
    const capacity = 4;

    // Solved state: each tube filled with one color
    final state = <List<int>>[];
    for (int c = 0; c < colorCount; c++) {
      state.add(List.filled(capacity, c));
    }
    for (int e = 0; e < emptyTubes; e++) {
      state.add([]);
    }

    // Apply scramble moves (valid pours from solved state)
    final scrambleCount = colorCount * 4 + rng.nextInt(colorCount * 4 + 1);
    int consecutive = 0;
    int lastFrom = -1;

    for (int m = 0; m < scrambleCount; m++) {
      final validMoves = <(int, int)>[];

      for (int from = 0; from < state.length; from++) {
        if (state[from].isEmpty) continue;
        // Avoid pouring a uniform tube into a tube of the same color
        // (would just merge solved tubes back, undoing progress)
        final topColor = state[from].last;
        for (int to = 0; to < state.length; to++) {
          if (to == from) continue;
          if (state[to].length >= capacity) continue;
          // Accept: empty target OR matching top color
          if (state[to].isEmpty || state[to].last == topColor) {
            // Avoid the trivial reverse of the last move
            if (!(from == lastFrom && consecutive > 2)) {
              validMoves.add((from, to));
            }
          }
        }
      }

      if (validMoves.isEmpty) break;
      final (from, to) = validMoves[rng.nextInt(validMoves.length)];

      state[to].add(state[from].removeLast());

      consecutive = (from == lastFrom) ? consecutive + 1 : 0;
      lastFrom    = from;
    }

    return state;
  }

  // ── Classic Fisher-Yates shuffle (used for campaign levels) ──────────────────
  static List<List<int>> _buildShuffled(int colorCount, int emptyTubes, int seed) {
    final rng      = Random(seed * 6271 + 4919);
    const capacity = 4;

    final allUnits = <int>[];
    for (int c = 0; c < colorCount; c++) {
      for (int j = 0; j < capacity; j++) allUnits.add(c);
    }

    for (int i = allUnits.length - 1; i > 0; i--) {
      final j   = rng.nextInt(i + 1);
      final tmp = allUnits[i];
      allUnits[i] = allUnits[j];
      allUnits[j] = tmp;
    }

    final state = <List<int>>[];
    for (int t = 0; t < colorCount; t++) {
      final tube = <int>[];
      for (int j = 0; j < capacity; j++) tube.add(allUnits[t * capacity + j]);
      state.add(tube);
    }
    for (int e = 0; e < emptyTubes; e++) state.add([]);
    return state;
  }
}
