import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class TubeModel {
  final List<int> colors;
  final int capacity;
  final bool isSelected;
  final bool isCompleted;

  const TubeModel({
    required this.colors,
    this.capacity = 4,
    this.isSelected = false,
    this.isCompleted = false,
  });

  TubeModel copyWith({
    List<int>? colors,
    int? capacity,
    bool? isSelected,
    bool? isCompleted,
  }) {
    return TubeModel(
      colors: colors ?? List<int>.from(this.colors),
      capacity: capacity ?? this.capacity,
      isSelected: isSelected ?? this.isSelected,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  bool get isEmpty => colors.isEmpty;
  bool get isFull => colors.length >= capacity;
  int? get topColor => colors.isEmpty ? null : colors.last;

  int get topColorCount {
    if (colors.isEmpty) return 0;
    final top = colors.last;
    int count = 0;
    for (int i = colors.length - 1; i >= 0; i--) {
      if (colors[i] == top) count++;
      else break;
    }
    return count;
  }

  bool get isUniform =>
      colors.isNotEmpty && colors.every((c) => c == colors.first);
  bool get isPerfect => isUniform && colors.length == capacity;

  bool canReceive(TubeModel from) {
    if (isFull) return false;
    if (from.isEmpty) return false;
    if (isEmpty) return true;
    return topColor == from.topColor;
  }

  Color get liquidColor => colors.isEmpty
      ? Colors.transparent
      : AppColors.liquidColors[colors.last % AppColors.liquidColors.length];
}

class LevelConfig {
  final int id;
  final int worldId;
  final int levelInWorld;
  final int tubeCount;
  final int emptyTubes;
  final int colorCount;
  final List<List<int>> initialState;
  final String difficulty;
  final int maxMoves;

  const LevelConfig({
    required this.id,
    required this.worldId,
    required this.levelInWorld,
    required this.tubeCount,
    required this.emptyTubes,
    required this.colorCount,
    required this.initialState,
    required this.difficulty,
    required this.maxMoves,
  });
}
