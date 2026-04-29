import 'dart:math';
import '../models/game_model.dart';

class LevelGenerator {
  static final _rng = Random(42); // seeded for consistency

  /// Generate all 100 levels (5 worlds x 20 levels each)
  static List<LevelConfig> generateAll() {
    final levels = <LevelConfig>[];
    for (int world = 0; world < 5; world++) {
      for (int lvl = 0; lvl < 20; lvl++) {
        final globalId = world * 20 + lvl;
        levels.add(_generate(globalId, world, lvl));
      }
    }
    return levels;
  }

  static LevelConfig _generate(int id, int worldId, int levelInWorld) {
    // Progressive difficulty
    final progress = (worldId * 20 + levelInWorld) / 100.0;
    int colorCount, emptyTubes;
    String difficulty;

    if (progress < 0.15) {
      colorCount = 3; emptyTubes = 2; difficulty = 'easy';
    } else if (progress < 0.35) {
      colorCount = 4; emptyTubes = 2; difficulty = 'easy';
    } else if (progress < 0.55) {
      colorCount = 5; emptyTubes = 2; difficulty = 'medium';
    } else if (progress < 0.70) {
      colorCount = 6; emptyTubes = 2; difficulty = 'medium';
    } else if (progress < 0.85) {
      colorCount = 7; emptyTubes = 2; difficulty = 'hard';
    } else {
      colorCount = 8; emptyTubes = 2; difficulty = 'expert';
    }

    final tubeCount = colorCount + emptyTubes;
    final initialState = _generateSolvable(colorCount, emptyTubes, id);

    return LevelConfig(
      id: id,
      worldId: worldId,
      levelInWorld: levelInWorld,
      tubeCount: tubeCount,
      emptyTubes: emptyTubes,
      colorCount: colorCount,
      initialState: initialState,
      difficulty: difficulty,
    );
  }

  static List<List<int>> _generateSolvable(int colorCount, int emptyTubes, int seed) {
    final rng = Random(seed * 1337 + 42);
    const capacity = 4;

    // Start from solved state, then shuffle
    final solved = <List<int>>[];
    for (int c = 0; c < colorCount; c++) {
      solved.add(List.filled(capacity, c));
    }
    for (int e = 0; e < emptyTubes; e++) {
      solved.add([]);
    }

    // Simulate random valid moves to shuffle
    var state = solved.map((t) => List<int>.from(t)).toList();
    int shuffleMoves = 20 + colorCount * 8;

    for (int m = 0; m < shuffleMoves; m++) {
      final nonEmpty = <int>[];
      for (int i = 0; i < state.length; i++) {
        if (state[i].isNotEmpty) nonEmpty.add(i);
      }
      if (nonEmpty.isEmpty) break;

      final from = nonEmpty[rng.nextInt(nonEmpty.length)];
      final fromTop = state[from].last;

      final validTo = <int>[];
      for (int i = 0; i < state.length; i++) {
        if (i == from) continue;
        if (state[i].length >= capacity) continue;
        if (state[i].isEmpty || state[i].last == fromTop) {
          // avoid moving uniform full to empty (pointless)
          if (state[i].isEmpty && state[from].every((c) => c == state[from].first)) continue;
          validTo.add(i);
        }
      }

      if (validTo.isEmpty) continue;
      final to = validTo[rng.nextInt(validTo.length)];

      // Move top color segment
      int count = 0;
      for (int i = state[from].length - 1; i >= 0; i--) {
        if (state[from][i] == fromTop) count++;
        else break;
      }
      final canMove = min(count, capacity - state[to].length);
      for (int i = 0; i < canMove; i++) {
        state[to].add(state[from].removeLast());
      }
    }

    return state;
  }

  /// Daily challenge - deterministic by date
  static LevelConfig dailyChallenge(DateTime date) {
    final seed = date.year * 10000 + date.month * 100 + date.day;
    return _generate(seed % 100, 2, seed % 20);
  }
}
