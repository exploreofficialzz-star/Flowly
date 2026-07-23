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
    // Scoped select: HomeScreen only rebuilds when one of the displayed values
    // actually changes (level completion, streak update, hint grant, popup).
    // Tube taps / pours / undos / hint animations during gameplay do NOT
    // increment any of these fields, so HomeScreen stays completely silent
    // while GameScreen is on top of the nav stack.
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
              worldIdx:     g.currentWorldIndex.clamp(0, AppConstants.worlds.length - 1),
              levelInWorld: g.currentLevelInWorld,
              total:        g.totalLevelsCompleted,
              streak:       g.dailyStreak,
              hints:        g.hints,
              isEndless:    g.isEndlessLevel,
              reward:       g.pendingStreakReward,
            ));

    final world   = AppConstants.worlds[gs.worldIdx];
    final screenH = MediaQuery.sizeOf(context).height;
    final scale   = (screenH / 844).clamp(0.82, 1.0);
    double gap(double v) => v * scale;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.gradientBg),
        child: Stack(children: [
          // Background orbs — CustomPainter: zero widget objects per frame,
          // pure GPU paint.  Previously used AnimatedBuilder + Stack +
          // Positioned + Container at 60 fps, creating hundreds of short-lived
          // Dart objects per second and causing GC-driven jank spikes.
          RepaintBoundary(child: const _BgOrbs()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: gap(24)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: gap(16)),

                      // ── Header row ───────────────────────────────────────
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
                              const Text('by chAs',
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
                              const Text('🔥', style: TextStyle(fontSize: 18)),
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

                      // ── Remove-Ads banner ────────────────────────────────
                      const RemoveAdsBanner()
                          .animate().fadeIn(delay: 150.ms),
                      SizedBox(height: gap(16)),

                      // ── Current world / Continue card ────────────────────
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
                                      style: const TextStyle(
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
                              onTap: () => Navigator.push(context,
                                  MaterialPageRoute(
                                      builder: (_) => const GameScreen())),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 200.ms)
                       .slideY(begin: 0.2, delay: 200.ms),
                      SizedBox(height: gap(16)),

                      // ── Stats row ─────────────────────────────────────────
                      Row(children: [
                        Expanded(child: _StatCard(
                          label: 'Completed',
                          value: '${gs.total}',
                          icon: Icons.check_circle_outline,
                          color: AppColors.neonGreen,
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _StatCard(
                          label: 'Hints Left',
                          value: '${gs.hints}',
                          icon: Icons.lightbulb_outline,
                          color: AppColors.neonYellow,
                        )),
                      ]).animate().fadeIn(delay: 350.ms),
                      SizedBox(height: gap(16)),

                      // ── All Worlds ────────────────────────────────────────
                      GlassCard(
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(
                                builder: (_) => const WorldsScreen())),
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

                      // ── Competition card ──────────────────────────────────
                      _CompetitionCard().animate().fadeIn(delay: 500.ms),
                      SizedBox(height: gap(16)),

                      // ── Daily challenge ───────────────────────────────────
                      _DailyChallengeCard().animate().fadeIn(delay: 550.ms),
                      SizedBox(height: gap(40)),

                      Center(
                        child: Text('by chAs',
                            style: const TextStyle(
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

          // ── Streak milestone reward popup (topmost) ───────────────────────
          if (gs.reward != null) _StreakRewardPopup(reward: gs.reward!),
        ]),
      ),
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => GlassCard(
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
              style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'Poppins',
                  color: AppColors.white40)),
        ]),
      );
}

// ── Competition card ──────────────────────────────────────────────────────────
// Watches CompetitionService independently — CompetitionService.notifyListeners
// now fires every 5 s from the tick timer.  This widget has its own element
// so only _CompetitionCard rebuilds (not the whole HomeScreen).
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
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins', color: AppColors.white)),
            if (hasScore) ...[
              Text(
                userPos > 0
                    ? 'You\'re #$userPos · ${svc.userScore} pts'
                    : '${svc.userScore} pts earned today',
                style: const TextStyle(
                    fontSize: 12, fontFamily: 'Poppins',
                    color: AppColors.neonBlue)),
              if (ptsTop10 > 0 && userPos > 10)
                Text('$ptsTop10 pts to Top 10  🔥',
                    style: const TextStyle(
                        fontSize: 11, fontFamily: 'Poppins',
                        color: AppColors.white40)),
            ] else ...[
              const Text('Prizes: \$50 · \$40 · \$30 · more',
                  style: TextStyle(
                      fontSize: 12, fontFamily: 'Poppins',
                      color: AppColors.white40)),
            ],
          ],
        )),
        const Icon(Icons.chevron_right_rounded, color: AppColors.white40),
      ]),
    );
  }
}

// ── Daily challenge card ──────────────────────────────────────────────────────
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
                style: const TextStyle(
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
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ][m - 1];
}

// ── Background orbs ─────────────────────────────────────────────────────────────
// CustomPainter replaces the previous AnimatedBuilder → Stack → Positioned →
// Container approach.  The old pattern allocated new Dart widget objects on
// EVERY animation frame (60 fps × 6 objects = 360 objects/second), generating
// constant GC pressure that showed up as frame-budget overruns and made the
// home screen feel sluggish.  CustomPainter calls paint() directly on the
// raster thread with zero widget-tree work per frame.
class _BgOrbs extends StatefulWidget {
  const _BgOrbs();

  @override
  State<_BgOrbs> createState() => _BgOrbsState();
}

class _BgOrbsState extends State<_BgOrbs> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.expand(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => CustomPaint(
            painter: _BgOrbsPainter(_ctrl.value),
          ),
        ),
      );
}

class _BgOrbsPainter extends CustomPainter {
  final double t;
  const _BgOrbsPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    // Orb 1 — top-right corner, neon blue
    final x1 = size.width  + sin(t * 2 * pi) * 30;
    final y1 = -60.0       + cos(t * 2 * pi) * 30;
    _orb(canvas, Offset(x1, y1), 140, const Color(0xFF00C8FF), 0.13);

    // Orb 2 — bottom-left corner, neon purple
    final x2 = -60.0             + sin((t + 0.5) * 2 * pi) * 20;
    final y2 = size.height * 0.8 + cos((t + 0.5) * 2 * pi) * 20;
    _orb(canvas, Offset(x2, y2), 120, const Color(0xFFB400FF), 0.11);
  }

  void _orb(Canvas canvas, Offset center, double r, Color color, double opacity) {
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withOpacity(opacity), Colors.transparent],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
  }

  @override
  bool shouldRepaint(_BgOrbsPainter old) => old.t != t;
}

// ── Streak reward popup ───────────────────────────────────────────────────────
class _StreakRewardPopup extends StatelessWidget {
  final StreakReward reward;
  const _StreakRewardPopup({required this.reward});

  @override
  Widget build(BuildContext context) {
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
                    .animate().scale(duration: 500.ms, curve: Curves.elasticOut),
                const SizedBox(height: 10),
                Text('${reward.streak}-Day Streak!',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Poppins',
                        color: AppColors.white)),
                const SizedBox(height: 6),
                const Text("You've played every day — here's your reward",
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
                      _Chip('💡', '+${reward.hints} Hints', AppColors.neonYellow),
                    if (reward.adFreeHours > 0) ...[
                      const SizedBox(width: 12),
                      _Chip('🚫', '${reward.adFreeHours}h Ad-Free',
                          AppColors.neonGreen),
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

class _Chip extends StatelessWidget {
  final String icon, label;
  final Color color;
  const _Chip(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
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
