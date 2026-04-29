import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../services/audio_service.dart';
import '../../services/ad_service.dart';
import '../providers/game_provider.dart';
import '../screens/home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _init();
  }

  Future<void> _init() async {
    await Future.wait([
      context.read<GameProvider>().init(),
      AdService().init(),
      Future.delayed(const Duration(milliseconds: 2800)),
    ]);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, a, b) => const HomeScreen(),
        transitionsBuilder: (_, a, b, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.gradientBg),
        child: Stack(
          children: [
            // Animated background particles
            ...List.generate(12, (i) => _Particle(index: i)),
            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo tubes illustration
                  _LogoTubes()
                      .animate()
                      .fadeIn(duration: 600.ms)
                      .slideY(begin: -0.3, duration: 700.ms, curve: Curves.easeOut),
                  const SizedBox(height: 28),
                  // App name
                  AnimatedBuilder(
                    animation: _glowController,
                    builder: (_, __) => Text(
                      'Flowly',
                      style: TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Poppins',
                        foreground: Paint()
                          ..shader = LinearGradient(
                            colors: [AppColors.neonBlue, AppColors.neonPurple],
                          ).createShader(const Rect.fromLTWH(0, 0, 220, 60)),
                        shadows: [
                          Shadow(
                            color: AppColors.neonBlue.withOpacity(0.4 + 0.3 * _glowController.value),
                            blurRadius: 20 + 10 * _glowController.value,
                          ),
                        ],
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 400.ms, duration: 600.ms)
                      .scale(begin: const Offset(0.8, 0.8), delay: 400.ms),
                  const SizedBox(height: 8),
                  Text(
                    'Color Sort · Fluid Puzzle',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Poppins',
                      color: AppColors.white40,
                      letterSpacing: 2,
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 700.ms, duration: 600.ms),
                  const SizedBox(height: 48),
                  // Loading dots
                  _LoadingDots()
                      .animate()
                      .fadeIn(delay: 1000.ms),
                ],
              ),
            ),
            // "by chAs" at the bottom
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Text(
                    'by chAs',
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      color: AppColors.white40,
                      letterSpacing: 1.5,
                    ),
                  ).animate().fadeIn(delay: 1200.ms),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoTubes extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = [
      AppColors.neonBlue,
      AppColors.neonPurple,
      AppColors.neonGreen,
      AppColors.neonOrange,
    ];
    final fills = [0.75, 0.50, 0.90, 0.35];

    return SizedBox(
      width: 160,
      height: 120,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(4, (i) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: _GlassTube(
              color: colors[i],
              fillRatio: fills[i],
              height: 90 + (i % 2 == 0 ? 10.0 : 0),
            ),
          );
        }),
      ),
    );
  }
}

class _GlassTube extends StatelessWidget {
  final Color color;
  final double fillRatio;
  final double height;

  const _GlassTube({required this.color, required this.fillRatio, required this.height});

  @override
  Widget build(BuildContext context) {
    const w = 26.0;
    return Container(
      width: w,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(w / 2),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
        color: Colors.white.withOpacity(0.04),
      ),
      clipBehavior: Clip.antiAlias,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: height * fillRatio,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color.withOpacity(0.7), color],
            ),
            boxShadow: [BoxShadow(color: color.withOpacity(0.6), blurRadius: 8)],
          ),
        ),
      ),
    );
  }
}

class _LoadingDots extends StatefulWidget {
  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
        ..repeat(reverse: true);
      Future.delayed(Duration(milliseconds: i * 150), () { if (mounted) c.forward(); });
      return c;
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _controllers[i],
          builder: (_, __) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.neonBlue.withOpacity(0.4 + 0.6 * _controllers[i].value),
            ),
          ),
        );
      }),
    );
  }
}

class _Particle extends StatefulWidget {
  final int index;
  const _Particle({required this.index});
  @override
  State<_Particle> createState() => _ParticleState();
}

class _ParticleState extends State<_Particle> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late double x, y, size;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _randomize();
    _c = AnimationController(
      vsync: this,
      duration: Duration(seconds: 3 + _rng.nextInt(4)),
    )..repeat(reverse: true);
  }

  void _randomize() {
    x = _rng.nextDouble();
    y = _rng.nextDouble();
    size = 2 + _rng.nextDouble() * 4;
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final colors = [AppColors.neonBlue, AppColors.neonPurple, AppColors.neonGreen];
    final color = colors[widget.index % colors.length];
    final sz = MediaQuery.of(context).size;
    return Positioned(
      left: x * sz.width,
      top: y * sz.height,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Opacity(
          opacity: 0.1 + 0.4 * _c.value,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6)],
            ),
          ),
        ),
      ),
    );
  }
}


