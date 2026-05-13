import 'dart:math';
import '../models/game_model.dart';
import '../../core/constants/app_constants.dart';

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
    int colorCount, emptyTubes, moveBonus;
    String difficulty;

    if (progress < 0.10) {
      colorCount = 3; emptyTubes = 2; difficulty = 'easy';
      moveBonus = AppConstants.moveBonusEasy;
    } else if (progress < 0.25) {
      colorCount = 4; emptyTubes = 2; difficulty = 'easy';
      moveBonus = AppConstants.moveBonusEasy;
    } else if (progress < 0.45) {
      colorCount = 5; emptyTubes = 2; difficulty = 'medium';
      moveBonus = AppConstants.moveBonusMedium;
    } else if (progress < 0.60) {
      colorCount = 6; emptyTubes = 2; difficulty = 'medium';
      moveBonus = AppConstants.moveBonusMedium;
    } else if (progress < 0.78) {
      colorCount = 7; emptyTubes = 2; difficulty = 'hard';
      moveBonus = AppConstants.moveBonusHard;
    } else {
      colorCount = 8; emptyTubes = 2; difficulty = 'expert';
      moveBonus = AppConstants.moveBonusExpert;
    }

    // maxMoves = optimal (colorCount * 4) + bonus buffer
    final maxMoves = colorCount * 4 + moveBonus;
    final initialState = _buildShuffled(colorCount, emptyTubes, id);

    return LevelConfig(
      id: id,
      worldId: worldId,
      levelInWorld: levelInWorld,
      tubeCount: colorCount + emptyTubes,
      emptyTubes: emptyTubes,
      colorCount: colorCount,
      initialState: initialState,
      difficulty: difficulty,
      maxMoves: maxMoves,
    );
  }

  static List<List<int>> _buildShuffled(
      int colorCount, int emptyTubes, int seed) {
    final rng = Random(seed * 6271 + 4919);
    const capacity = 4;

    final allUnits = <int>[];
    for (int c = 0; c < colorCount; c++) {
      for (int j = 0; j < capacity; j++) {
        allUnits.add(c);
      }
    }

    // Fisher-Yates shuffle
    for (int i = allUnits.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final tmp = allUnits[i];
      allUnits[i] = allUnits[j];
      allUnits[j] = tmp;
    }

    final state = <List<int>>[];
    for (int t = 0; t < colorCount; t++) {
      final tube = <int>[];
      for (int j = 0; j < capacity; j++) {
        tube.add(allUnits[t * capacity + j]);
      }
      state.add(tube);
    }
    for (int e = 0; e < emptyTubes; e++) {
      state.add(<int>[]);
    }
    return state;
  }

  static LevelConfig dailyChallenge(DateTime date) {
    final seed = date.year * 10000 + date.month * 100 + date.day;
    return _generate(seed % 100, 2, seed % 20);
  }
}
