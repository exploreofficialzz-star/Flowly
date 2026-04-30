import 'dart:math';
import '../models/game_model.dart';

class LevelGenerator {
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
    final progress = (worldId * 20 + levelInWorld) / 100.0;
    int colorCount, emptyTubes;
    String difficulty;

    if (progress < 0.10) {
      colorCount = 3; emptyTubes = 2; difficulty = 'easy';
    } else if (progress < 0.25) {
      colorCount = 4; emptyTubes = 2; difficulty = 'easy';
    } else if (progress < 0.45) {
      colorCount = 5; emptyTubes = 2; difficulty = 'medium';
    } else if (progress < 0.60) {
      colorCount = 6; emptyTubes = 2; difficulty = 'medium';
    } else if (progress < 0.78) {
      colorCount = 7; emptyTubes = 2; difficulty = 'hard';
    } else {
      colorCount = 8; emptyTubes = 2; difficulty = 'expert';
    }

    final initialState = _generateSolvableShuffled(colorCount, emptyTubes, id);
    return LevelConfig(
      id: id,
      worldId: worldId,
      levelInWorld: levelInWorld,
      tubeCount: colorCount + emptyTubes,
      emptyTubes: emptyTubes,
      colorCount: colorCount,
      initialState: initialState,
      difficulty: difficulty,
    );
  }

  static List<List<int>> _generateSolvableShuffled(
      int colorCount, int emptyTubes, int seed) {
    final rng = Random(seed * 7919 + 1337);
    const capacity = 4;

    // Build solved state
    var state = <List<int>>[];
    for (int c = 0; c < colorCount; c++) {
      state.add(List.filled(capacity, c));
    }
    for (int e = 0; e < emptyTubes; e++) {
      state.add(<int>[]);
    }

    // Shuffle aggressively — minimum moves based on difficulty
    final minMoves = 30 + colorCount * 15;
    int attempts = 0;
    int validMoves = 0;

    while (validMoves < minMoves && attempts < 2000) {
      attempts++;

      // Pick random non-empty source tube
      final nonEmpty = <int>[];
      for (int i = 0; i < state.length; i++) {
        if (state[i].isNotEmpty && !_isUniform(state[i])) nonEmpty.add(i);
      }
      // Also allow uniform tubes to be sources
      final allNonEmpty = <int>[];
      for (int i = 0; i < state.length; i++) {
        if (state[i].isNotEmpty) allNonEmpty.add(i);
      }

      final sources = nonEmpty.isNotEmpty ? nonEmpty : allNonEmpty;
      if (sources.isEmpty) break;

      final fromIdx = sources[rng.nextInt(sources.length)];
      final fromTube = state[fromIdx];
      final topColor = fromTube.last;
      final topCount = _topColorCount(fromTube);

      // Find valid destinations
      final validTo = <int>[];
      for (int i = 0; i < state.length; i++) {
        if (i == fromIdx) continue;
        if (state[i].length >= capacity) continue;
        // Don't move to empty if source is uniform (pointless)
        if (state[i].isEmpty && _isUniform(fromTube)) continue;
        if (state[i].isEmpty || state[i].last == topColor) {
          // Don't complete a tube during shuffle (keep it mixed)
          final willFill = state[i].length + topCount >= capacity;
          final wouldComplete = willFill && state[i].isNotEmpty &&
              state[i].every((c) => c == topColor);
          if (!wouldComplete) validTo.add(i);
        }
      }

      if (validTo.isEmpty) continue;

      final toIdx = validTo[rng.nextInt(validTo.length)];
      final canFit = capacity - state[toIdx].length;
      final moveCount = min(topCount, canFit);

      for (int i = 0; i < moveCount; i++) {
        state[toIdx].add(state[fromIdx].removeLast());
      }
      validMoves++;
    }

    // Verify it's not solved (shuffle was effective)
    if (_isSolved(state)) {
      // Force one more mix
      for (int f = 0; f < state.length; f++) {
        if (state[f].length < 2) continue;
        for (int t = 0; t < state.length; t++) {
          if (f == t) continue;
          if (state[t].length < capacity) {
            state[t].add(state[f].removeLast());
            break;
          }
        }
        break;
      }
    }

    return state;
  }

  static bool _isUniform(List<int> tube) =>
      tube.isNotEmpty && tube.every((c) => c == tube.first);

  static int _topColorCount(List<int> tube) {
    if (tube.isEmpty) return 0;
    final top = tube.last;
    int count = 0;
    for (int i = tube.length - 1; i >= 0; i--) {
      if (tube[i] == top) count++;
      else break;
    }
    return count;
  }

  static bool _isSolved(List<List<int>> state) {
    return state.every((t) =>
        t.isEmpty || (t.length == 4 && t.every((c) => c == t.first)));
  }

  static LevelConfig dailyChallenge(DateTime date) {
    final seed = date.year * 10000 + date.month * 100 + date.day;
    return _generate(seed % 100, 2, seed % 20);
  }
}
