import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/ad_service.dart';
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

    // Init runs after first frame so context is available
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    // GameProvider.init() loads progress + audio — non-blocking level gen
    try {
      await context.read<GameProvider>().init();
    } catch (_) {}

    // Init ads in background
    AdService().init().catchError((_) {});

    // Minimum splash display time
    await Future.delayed(const Duration(milliseconds: 2400));

    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, a, __) => const HomeScreen(),
      transitionsBuilder: (_, a, __, child) =>
          FadeTransition(opacity: a, child: child),
      transitionDuration: const Duration(milliseconds: 600),
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
          // Pulsing orbs
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => Stack(children: [
              Positioned(
                top: -60 + 20 * _pulseCtrl.value,
                right: -60,
                child: _Orb(
                    color: AppColors.neonBlue, size: 260, opacity: 0.12),
              ),
              Positioned(
                bottom: 80 - 15 * _pulseCtrl.value,
                left: -80,
                child: _Orb(
                    color: AppColors.neonPurple, size: 220, opacity: 0.10),
              ),
            ]),
          ),
          // Particles — ONE shared ticker driving all 10, was 10 separate
          // AnimationControllers (10 independent tickers) for one field.
          const _ParticleField(count: 10),
          // Content
          Column(children: [
            SizedBox(height: h * 0.20),
            // Logo tubes
            _LogoTubes()
                .animate()
                .fadeIn(duration: 600.ms)
                .slideY(begin: -0.15, duration: 700.ms, curve: Curves.easeOut),
            const SizedBox(height: 30),
            // App name
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
          // by chAs — bottom
          Positioned(
            bottom: 36,
            left: 0,
            right: 0,
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

class _LogoTubes extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final data = [
      {'color': AppColors.neonBlue, 'fill': 0.72},
      {'color': AppColors.neonPurple, 'fill': 0.48},
      {'color': AppColors.neonGreen, 'fill': 0.88},
      {'color': AppColors.neonOrange, 'fill': 0.35},
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (i) {
        final color = data[i]['color'] as Color;
        final fill = data[i]['fill'] as double;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: _GlassTube(
            color: color,
            fillRatio: fill,
            height: 96.0 + (i % 2 == 0 ? 16.0 : 0),
          ),
        );
      }),
    );
  }
}

class _GlassTube extends StatelessWidget {
  final Color color;
  final double fillRatio;
  final double height;
  const _GlassTube(
      {required this.color, required this.fillRatio, required this.height});

  @override
  Widget build(BuildContext context) {
    const w = 28.0;
    const r = w / 2;
    return Container(
      width: w,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 12,
              spreadRadius: 1),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        // Liquid
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            height: height * fillRatio,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [color.withOpacity(0.75), color],
              ),
            ),
          ),
        ),
        // Liquid surface
        Positioned(
          bottom: height * fillRatio - 3,
          left: 4, right: 4,
          child: Container(
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: Colors.white.withOpacity(0.4),
            ),
          ),
        ),
        // Glass shine
        Positioned(
          top: 5, left: 4,
          child: Container(
            width: w * 0.2,
            height: height * 0.5,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _LoadingDots extends StatefulWidget {
  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  // ONE controller driving all 3 dots via staggered Interval curves —
  // was 3 separate AnimationControllers (3 independent tickers) for
  // what is visually a single loading indicator.
  late AnimationController _ctrl;
  late List<Animation<double>> _phases;

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
              color: AppColors.neonBlue.withOpacity(0.3 + 0.7 * (v - 0.3) / 0.7),
              boxShadow: [
                BoxShadow(
                  color: AppColors.neonBlue.withOpacity(0.4 * (v - 0.3) / 0.7),
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

class _Orb extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;
  const _Orb(
      {required this.color, required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
          colors: [color.withOpacity(opacity), Colors.transparent]),
    ),
  );
}

// ONE shared controller drives ALL particles' opacity via per-particle
// phase offsets — was 10 separate _Particle widgets, each with its own
// independent AnimationController (10 concurrent tickers for what is
// visually a single ambient dust-particle effect).
class _ParticleField extends StatefulWidget {
  final int count;
  const _ParticleField({required this.count});
  @override
  State<_ParticleField> createState() => _ParticleFieldState();
}

class _ParticleFieldState extends State<_ParticleField>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_ParticleSpec> _specs;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3000))
      ..repeat();
    _specs = List.generate(widget.count, (i) {
      return _ParticleSpec(
        x:     _rng.nextDouble(),
        y:     _rng.nextDouble(),
        size:  1.5 + _rng.nextDouble() * 3,
        phase: _rng.nextDouble(), // 0..1 offset into the shared cycle
        colorIndex: i % 3,
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const colors = [AppColors.neonBlue, AppColors.neonPurple, AppColors.neonGreen];
    final sz = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Stack(
        children: _specs.map((p) {
          // Each particle rides the same clock but at its own phase offset,
          // so they don't all pulse in lockstep — same visual variety as
          // before, one ticker instead of ten.
          final t = (_ctrl.value + p.phase) % 1.0;
          final wave = (sin(t * 2 * pi) + 1) / 2; // 0..1 smooth pulse
          return Positioned(
            left: p.x * sz.width,
            top:  p.y * sz.height,
            child: Opacity(
              opacity: 0.05 + 0.25 * wave,
              child: Container(
                width: p.size, height: p.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors[p.colorIndex],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ParticleSpec {
  final double x, y, size, phase;
  final int colorIndex;
  _ParticleSpec({
    required this.x, required this.y, required this.size,
    required this.phase, required this.colorIndex,
  });
}
