import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../providers/game_provider.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/neon_button.dart';
import '../worlds/worlds_screen.dart';
import '../game/game_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    final world = AppConstants.worlds[game.currentWorldIndex];
    final sz = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.gradientBg),
        child: Stack(
          children: [
            // Background animated orbs
            _BgOrbs(),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    // Top row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShaderMask(
                              shaderCallback: (r) => AppColors.gradientPrimary.createShader(r),
                              child: const Text(
                                'Flowly',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'Poppins',
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Text(
                              'by chAs',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'Poppins',
                                color: AppColors.white40,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                        // Streak badge
                        GlassCard(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            children: [
                              const Text('🔥', style: TextStyle(fontSize: 18)),
                              const SizedBox(width: 6),
                              Text(
                                '${game.dailyStreak}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Poppins',
                                  color: AppColors.neonOrange,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ).animate().fadeIn(duration: 500.ms),
                    const SizedBox(height: 32),

                    // Current world card
                    GlassCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(world['emoji'] as String, style: const TextStyle(fontSize: 32)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      world['name'] as String,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'Poppins',
                                        color: AppColors.white,
                                      ),
                                    ),
                                    Text(
                                      'Level ${game.currentLevelInWorld + 1} of ${AppConstants.levelsPerWorld}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontFamily: 'Poppins',
                                        color: AppColors.white40,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Progress bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: game.currentLevelInWorld / AppConstants.levelsPerWorld,
                              backgroundColor: AppColors.white10,
                              valueColor: AlwaysStoppedAnimation(
                                Color(world['primaryColor'] as int),
                              ),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 20),
                          NeonButton(
                            label: 'Continue Playing',
                            icon: Icons.play_arrow_rounded,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const GameScreen()),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, delay: 200.ms),
                    const SizedBox(height: 16),

                    // Stats row
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Completed',
                            value: '${game.totalLevelsCompleted}',
                            icon: Icons.check_circle_outline,
                            color: AppColors.neonGreen,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: 'Hints Left',
                            value: '${game.hints}',
                            icon: Icons.lightbulb_outline,
                            color: AppColors.neonYellow,
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 350.ms),
                    const SizedBox(height: 16),

                    // All Worlds button
                    GlassCard(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const WorldsScreen()),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.gradientPrimary,
                            ),
                            child: const Icon(Icons.public_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Text(
                              'All Worlds',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Poppins',
                                color: AppColors.white,
                              ),
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: AppColors.white40),
                        ],
                      ),
                    ).animate().fadeIn(delay: 450.ms),
                    const SizedBox(height: 16),

                    // Daily Challenge
                    _DailyChallengeCard()
                        .animate()
                        .fadeIn(delay: 550.ms),
                    const SizedBox(height: 40),

                    // by chAs at bottom
                    Center(
                      child: Text(
                        'by chAs',
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Poppins',
                          color: AppColors.white40,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, fontFamily: 'Poppins', color: color)),
          Text(label, style: TextStyle(fontSize: 12, fontFamily: 'Poppins', color: AppColors.white40)),
        ],
      ),
    );
  }
}

class _DailyChallengeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return GlassCard(
      padding: const EdgeInsets.all(20),
      gradient: const LinearGradient(
        colors: [Color(0x1500FF96), Color(0x0500C8FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Row(
        children: [
          const Text('📅', style: TextStyle(fontSize: 32)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Daily Challenge',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Poppins', color: AppColors.white),
                ),
                Text(
                  '${_weekday(today.weekday)}, ${_month(today.month)} ${today.day}',
                  style: TextStyle(fontSize: 12, fontFamily: 'Poppins', color: AppColors.white40),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: AppColors.gradientPrimary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Play', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, fontFamily: 'Poppins', color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _weekday(int d) => ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][d - 1];
  String _month(int m) => ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m - 1];
}

class _BgOrbs extends StatefulWidget {
  @override
  State<_BgOrbs> createState() => _BgOrbsState();
}

class _BgOrbsState extends State<_BgOrbs> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() { super.initState(); _c = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat(reverse: true); }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Stack(children: [
        Positioned(top: -100 + 30 * _c.value, right: -80, child: _Orb(color: AppColors.neonBlue, size: 280)),
        Positioned(bottom: 100 - 20 * _c.value, left: -100, child: _Orb(color: AppColors.neonPurple, size: 240)),
      ]),
    );
  }
}

class _Orb extends StatelessWidget {
  final Color color; final double size;
  const _Orb({required this.color, required this.size});
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color.withOpacity(0.12), Colors.transparent]),
    ),
  );
}
