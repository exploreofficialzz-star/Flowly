import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/ad_service.dart';
import '../../../services/competition_service.dart';
import '../../providers/game_provider.dart';
import '../home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _glowCtrl;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);

    // Splash animation starts immediately — no blank screen.
    // _init() fires after the first frame so context is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    // Run GameProvider.init(), CompetitionService.init(), the minimum
    // display delay, and ad-SDK init ALL IN PARALLEL.
    //
    // Old approach: await GameProvider.init() → then await delay(2400ms)
    // was sequential: on a device where init takes 600ms, total = 3000ms.
    //
    // New approach: all four run concurrently; total = max(init, 1500ms).
    // On that same device: max(600ms, 1500ms) = 1500ms — saves ~1.5s.
    try {
      await Future.wait([
        context.read<GameProvider>().init(),
        context.read<CompetitionService>().init(),
        AdService().init().catchError((_) async {}),
        Future.delayed(const Duration(milliseconds: 1500)),
      ]);
    } catch (_) {}

    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, a, __) => const HomeScreen(),
      transitionsBuilder: (_, a, __, child) =>
          FadeTransition(opacity: a, child: child),
      transitionDuration: const Duration(milliseconds: 500),
    ));
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.gradientBg),
        child: Stack(children: [
          // ── Background orbs ─────────────────────────────────────────────
          // CustomPainter replaces the previous AnimatedBuilder → Stack →
          // Positioned → Container chain.  The old approach created
          // 6 Dart objects per frame (Stack + 2×Positioned + 2×Container +
          // BoxDecoration) at 60 fps = 360 allocations/second just for orbs.
          RepaintBoundary(
            child: SizedBox.expand(
              child: AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, __) => CustomPaint(
                  painter: _OrbPainter(_pulseCtrl.value),
                ),
              ),
            ),
          ),

          // ── Ambient particles ────────────────────────────────────────────
          // 10 particles × (Stack + Positioned + Opacity + Container) = 31
          // objects per frame = 1 860 allocations/second.  CustomPainter
          // replaces all of that with 10 drawCircle() calls per frame.
          RepaintBoundary(
            child: const _ParticleField(count: 10),
          ),

          // ── Content ──────────────────────────────────────────────────────
          Column(children: [
            SizedBox(height: h * 0.20),
            _LogoTubes()
                .animate()
                .fadeIn(duration: 600.ms)
                .slideY(begin: -0.15, duration: 700.ms, curve: Curves.easeOut),
            const SizedBox(height: 30),
            AnimatedBuilder(
              animation: _glowCtrl,
              builder: (_, __) => ShaderMask(
                shaderCallback: (r) => const LinearGradient(
                  colors: [AppColors.neonBlue, AppColors.neonPurple],
                ).createShader(r),
                child: Text(
                  'Flowly',
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Poppins',
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: AppColors.neonBlue.withOpacity(
                            0.45 + 0.35 * _glowCtrl.value),
                        blurRadius: 24 + 14 * _glowCtrl.value,
                      ),
                    ],
                  ),
                ),
              ),
            )
                .animate()
                .fadeIn(delay: 300.ms, duration: 600.ms)
                .scale(
                    begin: const Offset(0.85, 0.85),
                    delay: 300.ms,
                    duration: 600.ms),
            const SizedBox(height: 6),
            const Text(
              'Color Sort · Fluid Puzzle',
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'Poppins',
                color: AppColors.white40,
                letterSpacing: 2.5,
              ),
            ).animate().fadeIn(delay: 600.ms),
            const SizedBox(height: 56),
            _LoadingDots().animate().fadeIn(delay: 900.ms),
          ]),

          // ── Bottom tag ───────────────────────────────────────────────────
          Positioned(
            bottom: 36, left: 0, right: 0,
            child: Column(children: [
              Container(width: 36, height: 1, color: AppColors.white20),
              const SizedBox(height: 10),
              const Text(
                'by chAs',
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  color: AppColors.white40,
                  letterSpacing: 2,
                ),
              ),
            ]),
          ).animate().fadeIn(delay: 1100.ms),
        ]),
      ),
    );
  }
}

// ── Orb painter ───────────────────────────────────────────────────────────────
class _OrbPainter extends CustomPainter {
  final double t; // 0–1 from _pulseCtrl

  const _OrbPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    // Orb 1 — top-right, neon blue
    _orb(canvas,
        Offset(size.width + 60, -60 + 20 * t), 130,
        const Color(0xFF00C8FF), 0.12);
    // Orb 2 — bottom-left, neon purple
    _orb(canvas,
        Offset(-80, size.height - 80 + 15 * (1 - t)), 110,
        const Color(0xFFB400FF), 0.10);
  }

  void _orb(Canvas canvas, Offset c, double r, Color color, double opacity) {
    canvas.drawCircle(
      c, r,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withOpacity(opacity), Colors.transparent],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  @override
  bool shouldRepaint(_OrbPainter old) => old.t != t;
}

// ── Particle field ────────────────────────────────────────────────────────────
// One shared controller drives all 10 particles via per-particle phase offsets.
class _ParticleField extends StatefulWidget {
  final int count;
  const _ParticleField({required this.count});
  @override
  State<_ParticleField> createState() => _ParticleFieldState();
}

class _ParticleFieldState extends State<_ParticleField>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_ParticleSpec>  _specs;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3000))
      ..repeat();
    final rng = Random();
    _specs = List.generate(widget.count, (i) => _ParticleSpec(
      x:          rng.nextDouble(),
      y:          rng.nextDouble(),
      size:       1.5 + rng.nextDouble() * 3,
      phase:      rng.nextDouble(),
      colorIndex: i % 3,
    ));
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
            painter: _ParticlePainter(_ctrl.value, _specs),
          ),
        ),
      );
}

class _ParticlePainter extends CustomPainter {
  final double             t;
  final List<_ParticleSpec> specs;

  const _ParticlePainter(this.t, this.specs);

  static const _colors = [
    Color(0xFF00C8FF), // neonBlue
    Color(0xFFB400FF), // neonPurple
    Color(0xFF00FF96), // neonGreen
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in specs) {
      final phase = (t + p.phase) % 1.0;
      final wave  = (sin(phase * 2 * pi) + 1) / 2; // 0–1
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.size / 2,
        Paint()
          ..color = _colors[p.colorIndex].withOpacity(0.05 + 0.25 * wave),
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.t != t;
}

class _ParticleSpec {
  final double x, y, size, phase;
  final int    colorIndex;
  const _ParticleSpec({
    required this.x,
    required this.y,
    required this.size,
    required this.phase,
    required this.colorIndex,
  });
}

// ── Logo tubes ────────────────────────────────────────────────────────────────
class _LogoTubes extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final data = [
      {'color': AppColors.neonBlue,   'fill': 0.72},
      {'color': AppColors.neonPurple, 'fill': 0.48},
      {'color': AppColors.neonGreen,  'fill': 0.88},
      {'color': AppColors.neonOrange, 'fill': 0.35},
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (i) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: _GlassTube(
          color:     data[i]['color'] as Color,
          fillRatio: data[i]['fill'] as double,
          height:    96.0 + (i % 2 == 0 ? 16.0 : 0),
        ),
      )),
    );
  }
}

class _GlassTube extends StatelessWidget {
  final Color  color;
  final double fillRatio;
  final double height;
  const _GlassTube(
      {required this.color, required this.fillRatio, required this.height});

  @override
  Widget build(BuildContext context) {
    const w = 28.0;
    const r = w / 2;
    return Container(
      width: w, height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.4), blurRadius: 12, spreadRadius: 1),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            height: height * fillRatio,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end:   Alignment.bottomCenter,
                colors: [color.withOpacity(0.75), color],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: height * fillRatio - 3, left: 4, right: 4,
          child: Container(
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: Colors.white.withOpacity(0.4),
            ),
          ),
        ),
        Positioned(
          top: 5, left: 4,
          child: Container(
            width: w * 0.2, height: height * 0.5,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end:   Alignment.bottomCenter,
                colors: [Colors.white.withOpacity(0.3), Colors.transparent],
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Loading dots ──────────────────────────────────────────────────────────────
class _LoadingDots extends StatefulWidget {
  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController      _ctrl;
  late List<Animation<double>>  _phases;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
    _phases = List.generate(3, (i) {
      final start = i * 0.16;
      return TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 0.3, end: 1.0), weight: 1),
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.3), weight: 1),
      ]).animate(CurvedAnimation(
        parent: _ctrl,
        curve: Interval(start, (start + 0.42).clamp(0.0, 1.0),
            curve: Curves.easeInOut),
      ));
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (i) {
          final v = _phases[i].value;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 5),
            width: 8, height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.neonBlue
                  .withOpacity(0.3 + 0.7 * (v - 0.3) / 0.7),
              boxShadow: [
                BoxShadow(
                  color: AppColors.neonBlue
                      .withOpacity(0.4 * (v - 0.3) / 0.7),
                  blurRadius: 6,
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
