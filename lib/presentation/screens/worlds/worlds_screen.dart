import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../providers/game_provider.dart';
import '../../widgets/glass_card.dart';
import '../game/game_screen.dart';

class WorldsScreen extends StatefulWidget {
  const WorldsScreen({super.key});
  @override
  State<WorldsScreen> createState() => _WorldsScreenState();
}

class _WorldsScreenState extends State<WorldsScreen> {
  // Entrance animations only on first build. If GameProvider notifies while
  // WorldsScreen is in the nav stack under GameScreen, items must NOT
  // re-animate — that caused a visible flash on every tube tap.
  bool _hasAnimatedIn = false;

  @override
  Widget build(BuildContext context) {
    // Scope to only the three values this screen actually displays.
    // totalLevelsCompleted / currentWorldIndex / currentLevelInWorld change
    // only when a level is completed — NOT on tube selection, pour, hint, etc.
    // This prevents WorldsScreen from rebuilding on every game action while
    // it sits invisibly beneath GameScreen in the navigator stack.
    final (total, worldIdx, levelInWorld) =
        context.select<GameProvider, (int, int, int)>((g) => (
              g.totalLevelsCompleted,
              g.currentWorldIndex,
              g.currentLevelInWorld,
            ));

    final playEntrance = !_hasAnimatedIn;
    if (!_hasAnimatedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _hasAnimatedIn = true);
      });
    }

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
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: AppColors.white, size: 18),
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
                  itemBuilder: (context, wi) {
                    final world     = AppConstants.worlds[wi];
                    final isEndless = wi == 5;
                    final isUnlocked = wi == 0 ||
                        (total >= wi * AppConstants.levelsPerWorld);
                    final completed = (wi == worldIdx && !isEndless)
                        ? levelInWorld
                        : (wi < worldIdx ? AppConstants.levelsPerWorld : 0);
                    final color = Color(world['primaryColor'] as int);

                    final card = Padding(
                      key: ValueKey('world_$wi'),
                      padding: const EdgeInsets.only(bottom: 16),
                      child: GlassCard(
                        padding: const EdgeInsets.all(20),
                        onTap: isUnlocked
                            ? () {
                                context.read<GameProvider>().loadLevel(
                                    wi * AppConstants.levelsPerWorld);
                                Navigator.push(context,
                                    MaterialPageRoute(
                                        builder: (_) => const GameScreen()));
                              }
                            : null,
                        child: Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: isUnlocked ? color : AppColors.white20,
                                    width: 2),
                                color: isUnlocked
                                    ? color.withOpacity(0.15)
                                    : AppColors.white10,
                              ),
                              child: Center(
                                child: Text(
                                  isUnlocked
                                      ? world['emoji'] as String
                                      : '🔒',
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
                                      color: isUnlocked
                                          ? AppColors.white
                                          : AppColors.white40,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    !isUnlocked
                                        ? 'Complete prev world to unlock'
                                        : isEndless
                                            ? 'Infinite levels · no limit ♾️'
                                            : '$completed / ${AppConstants.levelsPerWorld} levels',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontFamily: 'Poppins',
                                      color: AppColors.white40,
                                    ),
                                  ),
                                  if (isUnlocked && !isEndless) ...[
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: completed /
                                            AppConstants.levelsPerWorld,
                                        backgroundColor: AppColors.white10,
                                        valueColor:
                                            AlwaysStoppedAnimation(color),
                                        minHeight: 4,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (isUnlocked)
                              Icon(Icons.chevron_right_rounded,
                                  color: color, size: 28),
                          ],
                        ),
                      ),
                    );

                    // Entrance animations fire only on first mount, not on
                    // every subsequent rebuild. On re-renders triggered by a
                    // completed level, the list updates instantly with no flash.
                    if (!playEntrance) return card;
                    return card
                        .animate(
                            delay: Duration(milliseconds: wi * 100))
                        .fadeIn()
                        .slideX(begin: 0.1);
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
