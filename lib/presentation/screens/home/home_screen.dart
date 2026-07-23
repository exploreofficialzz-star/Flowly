import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../services/iap_service.dart';
import '../../providers/game_provider.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/neon_button.dart';
import '../../widgets/remove_ads_sheet.dart';
import '../worlds/worlds_screen.dart';
import '../game/game_screen.dart';
import '../competition/competition_screen.dart';
import '../../../services/competition_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ── Scoped select: only rebuild HomeScreen when one of these specific
    // values changes.  Previously context.watch<GameProvider>() caused a full
    // HomeScreen rebuild on EVERY tube tap, pour animation, undo, and hint
    // use — even while HomeScreen was invisible underneath GameScreen in the
    // nav stack.  With context.select and a Dart record, the equality check
    // is structural (all fields compared by value), so rebuilds only happen
    // when something the home screen actually displays has changed.
    final gs = context.select<GameProvider,
        ({
          int worldIdx,
          int levelInWorld,
          int total,
          int streak,
          int hints,
          bool isEndless,
          StreakReward? reward,
        })>((g) => (
              worldIdx:    g.currentWorldIndex.clamp(0, AppConstants.worlds.length - 1),
              levelInWorld: g.currentLevelInWorld,
              total:       g.totalLevelsCompleted,
              streak:      g.dailyStreak,
              hints:       g.hints,
              isEndless:   g.isEndlessLevel,
              reward:      g.pendingStreakReward,
            ));

    final world      = AppConstants.worlds[gs.worldIdx];
    final screenH    = MediaQuery.sizeOf(context).height;
    final scale      = (screenH / 844).clamp(0.82, 1.0);
    double gap(double v) => v * scale;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.gradientBg),
        child: Stack(
          children: [
            RepaintBoundary(child: _BgOrbs()),
            SafeArea(
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(
                    (MediaQuery.textScalerOf(context).scale(100) / 100) * scale,
                  ),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: gap(24)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: gap(16)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ShaderMask(
                                    shaderCallback: (r) =>
                                        AppColors.gradientPrimary.createShader(r),
                                    child: const Text('Flowly',
                                        style: TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.w800,
                                            fontFamily: 'Poppins',
                                            color: Colors.white)),
                                  ),
                                  Text('by chAs',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontFamily: 'Poppins',
                                          color: AppColors.white40,
                                          letterSpacing: 1.5)),
                                ],
                              ),
                              GlassCard(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                child: Row(children: [
                                  const Text('🔥',
                                      style: TextStyle(fontSize: 18)),
                                  const SizedBox(width: 6),
                                  Text('${gs.streak}',
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          fontFamily: 'Poppins',
                                          color: AppColors.neonOrange)),
                                ]),
                              ),
                            ],
                          ).animate().fadeIn(duration: 500.ms),
                          SizedBox(height: gap(24)),

                          const RemoveAdsBanner()
                              .animate()
                              .fadeIn(delay: 150.ms),
                          SizedBox(height: gap(16)),

                          // Current world card
                          GlassCard(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Text(world['emoji'] as String,
                                      style: const TextStyle(fontSize: 32)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(world['name'] as String,
                                            style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w700,
                                                fontFamily: 'Poppins',
                                                color: AppColors.white)),
                                        Text(
                                          gs.isEndless
                                              ? 'Level ${gs.levelInWorld + 1} · infinite'
                                              : 'Level ${gs.levelInWorld + 1}'
                                                ' of ${AppConstants.levelsPerWorld}',
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontFamily: 'Poppins',
                                              color: AppColors.white40),
                                        ),
                                      ],
                                    ),
                                  ),
                                ]),
                                SizedBox(height: gap(16)),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: gs.isEndless
                                        ? 1.0
                                        : (gs.levelInWorld + 1) /
                                            AppConstants.levelsPerWorld,
                                    backgroundColor: AppColors.white10,
                                    valueColor: AlwaysStoppedAnimation(
                                        Color(world['primaryColor'] as int)),
                                    minHeight: 6,
                                  ),
                                ),
                                SizedBox(height: gap(20)),
                                NeonButton(
                                  label: 'Continue Playing',
                                  icon: Icons.play_arrow_rounded,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const GameScreen()),
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, delay: 200.ms),
                          SizedBox(height: gap(16)),

                          // Stats row
                          Row(children: [
                            Expanded(
                              child: _StatCard(
                                label: 'Completed',
                                value: '${gs.total}',
                                icon: Icons.check_circle_outline,
                                color: AppColors.neonGreen,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                label: 'Hints Left',
                                value: '${gs.hints}',
                                icon: Icons.lightbulb_outline,
                                color: AppColors.neonYellow,
                              ),
                            ),
                          ]).animate().fadeIn(delay: 350.ms),
                          SizedBox(height: gap(16)),

                          // All Worlds
                          GlassCard(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const WorldsScreen()),
                            ),
                            padding: const EdgeInsets.all(20),
                            child: Row(children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: AppColors.gradientPrimary,
                                ),
                                child: const Icon(Icons.public_rounded,
                                    color: Colors.white, size: 22),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Text('All Worlds',
                                    style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Poppins',
                                        color: AppColors.white)),
                              ),
                              const Icon(Icons.chevron_right_rounded,
                                  color: AppColors.white40),
                            ]),
                          ).animate().fadeIn(delay: 450.ms),
                          SizedBox(height: gap(16)),

                          // Future Hope Competition Card
                          _CompetitionCard().animate().fadeIn(delay: 500.ms),
                          SizedBox(height: gap(16)),

                          _DailyChallengeCard().animate().fadeIn(delay: 550.ms),
                          SizedBox(height: gap(40)),

                          Center(
                            child: Text('by chAs',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'Poppins',
                                    color: AppColors.white40,
                                    letterSpacing: 2)),
                          ),
                          SizedBox(height: gap(24)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Streak milestone reward popup (topmost layer)
            if (gs.reward != null)
              _StreakRewardPopup(reward: gs.reward!),
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
  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 8),
        Text(value,
            style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                fontFamily: 'Poppins',
                color: color)),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontFamily: 'Poppins',
                color: AppColors.white40)),
      ]),
    );
  }
}

class _CompetitionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final svc      = context.watch<CompetitionService>();
    final hasScore = svc.isRegistered && svc.userScore > 0;
    final userPos  = svc.userPosition;
    final ptsTop10 = svc.ptsToTop10;

    return GlassCard(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const CompetitionScreen())),
      padding: const EdgeInsets.all(18),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
            boxShadow: [BoxShadow(
                color: const Color(0xFFFFD700).withOpacity(0.25), blurRadius: 8)],
          ),
          child: const Center(
              child: Text('🌍', style: TextStyle(fontSize: 20))),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Daily Rankings',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins', color: AppColors.white)),
            if (hasScore) ...[
              Text(
                userPos > 0
                    ? 'You\'re #$userPos today · ${svc.userScore} pts'
                    : '${svc.userScore} pts earned today',
                style: const TextStyle(fontSize: 12, fontFamily: 'Poppins',
                    color: AppColors.neonBlue)),
              if (ptsTop10 > 0 && userPos > 10)
                Text('$ptsTop10 pts to Top 10  🔥',
                    style: const TextStyle(fontSize: 11, fontFamily: 'Poppins',
                        color: AppColors.white40)),
            ] else ...[
              const Text('Prizes: \$50 · \$40 · \$30 · more',
                  style: TextStyle(fontSize: 12, fontFamily: 'Poppins',
                      color: AppColors.white40)),
            ],
          ],
        )),
        const Icon(Icons.chevron_right_rounded, color: AppColors.white40),
      ]),
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
      child: Row(children: [
        const Text('📅', style: TextStyle(fontSize: 32)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Daily Challenge',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins',
                      color: AppColors.white)),
              Text(
                '${_weekday(today.weekday)}, ${_month(today.month)} ${today.day}',
                style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Poppins',
                    color: AppColors.white40),
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
          child: const Text('Play',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins',
                  color: Colors.white)),
        ),
      ]),
    );
  }

  String _weekday(int d) =>
      ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d - 1];
  String _month(int m) => [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m - 1];
}

class _BgOrbs extends StatefulWidget {
  @override
  State<_BgOrbs> createState() => _BgOrbsState();
}

class _BgOrbsState extends State<_BgOrbs>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(seconds: 6))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Stack(children: [
        Positioned(
            top: -100 + 30 * _c.value,
            right: -80,
            child: _Orb(color: AppColors.neonBlue, size: 280)),
        Positioned(
            bottom: 100 - 20 * _c.value,
            left: -100,
            child: _Orb(color: AppColors.neonPurple, size: 240)),
      ]),
    );
  }
}

class _Orb extends StatelessWidget {
  final Color color;
  final double size;
  const _Orb({required this.color, required this.size});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient:
              RadialGradient(colors: [color.withOpacity(0.12), Colors.transparent]),
        ),
      );
}

// ── Streak milestone reward popup ─────────────────────────────────────────────
class _StreakRewardPopup extends StatelessWidget {
  final StreakReward reward;
  const _StreakRewardPopup({required this.reward});

  @override
  Widget build(BuildContext context) {
    final hasAdFree = reward.adFreeHours > 0;

    return Positioned.fill(
      child: GestureDetector(
        onTap: () {},
        child: Container(
          color: Colors.black.withOpacity(0.65),
          child: Center(
            child: GlassCard(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('🔥', style: TextStyle(fontSize: 52))
                    .animate()
                    .scale(duration: 500.ms, curve: Curves.elasticOut),
                const SizedBox(height: 10),
                Text('${reward.streak}-Day Streak!',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Poppins',
                        color: AppColors.white)),
                const SizedBox(height: 6),
                const Text('You\'ve played every day — here\'s your reward',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'Poppins',
                        color: AppColors.white40)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (reward.hints > 0)
                      _RewardChip(
                        icon: '💡',
                        label: '+${reward.hints} Hints',
                        color: AppColors.neonYellow,
                      ),
                    if (hasAdFree) ...[
                      const SizedBox(width: 12),
                      _RewardChip(
                        icon: '🚫',
                        label: '${reward.adFreeHours}h Ad-Free',
                        color: AppColors.neonGreen,
                      ),
                    ],
                  ],
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () => context.read<GameProvider>().clearStreakReward(),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: AppColors.gradientPrimary,
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.neonBlue.withOpacity(0.4),
                            blurRadius: 16)
                      ],
                    ),
                    child: const Text('Claim Reward',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Poppins',
                            color: Colors.white)),
                  ),
                ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.3),
              ]),
            ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
          ),
        ),
      ),
    );
  }
}

class _RewardChip extends StatelessWidget {
  final String icon, label;
  final Color color;
  const _RewardChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withOpacity(0.12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFamily: 'Poppins',
                color: color)),
      ]),
    );
  }
}
