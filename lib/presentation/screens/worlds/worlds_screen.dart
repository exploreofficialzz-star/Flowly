import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../providers/game_provider.dart';
import '../../widgets/glass_card.dart';
import '../game/game_screen.dart';

class WorldsScreen extends StatelessWidget {
  const WorldsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.gradientBg),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.white10,
                          border: Border.all(color: AppColors.white20),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.white, size: 18),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Choose World',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Poppins',
                        color: AppColors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: AppConstants.worlds.length,
                  itemBuilder: (context, worldIdx) {
                    final world = AppConstants.worlds[worldIdx];
                    final isUnlocked = worldIdx == 0 ||
                        (game.totalLevelsCompleted >= worldIdx * AppConstants.levelsPerWorld);
                    final completed = (worldIdx == game.currentWorldIndex)
                        ? game.currentLevelInWorld
                        : (worldIdx < game.currentWorldIndex ? AppConstants.levelsPerWorld : 0);
                    final color = Color(world['primaryColor'] as int);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: GlassCard(
                        padding: const EdgeInsets.all(20),
                        onTap: isUnlocked
                            ? () {
                                game.loadLevel(worldIdx * AppConstants.levelsPerWorld);
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const GameScreen()));
                              }
                            : null,
                        child: Row(
                          children: [
                            // Emoji + colored ring
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: isUnlocked ? color : AppColors.white20, width: 2),
                                color: isUnlocked ? color.withOpacity(0.15) : AppColors.white10,
                              ),
                              child: Center(
                                child: Text(
                                  isUnlocked ? world['emoji'] as String : '🔒',
                                  style: const TextStyle(fontSize: 28),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    world['name'] as String,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'Poppins',
                                      color: isUnlocked ? AppColors.white : AppColors.white40,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isUnlocked
                                        ? '$completed / ${AppConstants.levelsPerWorld} levels'
                                        : 'Complete prev world to unlock',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontFamily: 'Poppins',
                                      color: AppColors.white40,
                                    ),
                                  ),
                                  if (isUnlocked) ...[
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: completed / AppConstants.levelsPerWorld,
                                        backgroundColor: AppColors.white10,
                                        valueColor: AlwaysStoppedAnimation(color),
                                        minHeight: 4,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (isUnlocked)
                              Icon(Icons.chevron_right_rounded, color: color, size: 28),
                          ],
                        ),
                      ).animate().fadeIn(delay: Duration(milliseconds: worldIdx * 100)).slideX(begin: 0.1),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
