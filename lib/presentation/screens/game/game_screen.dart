import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/game_model.dart';
import '../../../services/ad_service.dart';
import '../../../services/iap_service.dart';
import '../../../services/competition_service.dart';
import '../../providers/game_provider.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/remove_ads_sheet.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  BannerAd? _banner;

  @override
  void initState() {
    super.initState();
    _loadBanner();
  }

  void _loadBanner() {
    final iap = IapService();
    if (iap.adsRemoved) return;
    try {
      final ad = AdService().createBanner();
      if (mounted) setState(() => _banner = ad);
    } catch (_) {}
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    final iap = context.watch<IapService>();
    final worldIdx =
        game.currentWorldIndex.clamp(0, AppConstants.worlds.length - 1);
    final world = AppConstants.worlds[worldIdx];
    final worldColor = Color(world['primaryColor'] as int);
    final worldBg = Color(world['bgColor'] as int);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [worldBg, AppColors.bg, AppColors.bg],
          ),
        ),
        child: SafeArea(
          child: Column(children: [
            _GameHeader(worldColor: worldColor, worldName: world['name'] as String),
            Expanded(
              child: Stack(
                children: [
                  if (game.status == GameStatus.won)
                    _WinOverlay()
                  else if (game.status == GameStatus.gameOver)
                    _GameOverOverlay()
                  else
                    _GameBoard(),
                ],
              ),
            ),
            if (game.status == GameStatus.playing) _GameControls(),
            if (!iap.adsRemoved && _banner != null)
              SizedBox(
                height: 50,
                width: double.infinity,
                child: AdWidget(ad: _banner!),
              ),
          ]),
        ),
      ),
    );
  }
}

// ── HEADER ─────────────────────────────────────────────────────────────────────
class _GameHeader extends StatelessWidget {
  final Color worldColor;
  final String worldName;
  const _GameHeader({required this.worldColor, required this.worldName});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    final remaining = game.movesRemaining;
    final isLow = game.isMovesLow;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.white10,
              border: Border.all(color: AppColors.white20),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.white, size: 16),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(worldName,
                style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'Poppins',
                    color: AppColors.white40)),
            Text('Level ${game.currentLevelInWorld + 1}',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins',
                    color: worldColor)),
          ]),
        ),
        // Moves remaining counter
        _MovesCounter(remaining: remaining, isLow: isLow),
      ]),
    );
  }
}

class _MovesCounter extends StatefulWidget {
  final int remaining;
  final bool isLow;
  const _MovesCounter({required this.remaining, required this.isLow});

  @override
  State<_MovesCounter> createState() => _MovesCounterState();
}

class _MovesCounterState extends State<_MovesCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isLow ? AppColors.neonRed : AppColors.white;
    final borderColor =
        widget.isLow ? AppColors.neonRed.withOpacity(0.6) : AppColors.white20;
    final bg = widget.isLow
        ? AppColors.neonRed.withOpacity(0.08)
        : AppColors.white10;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        final scale = widget.isLow ? (0.96 + 0.04 * _pulse.value) : 1.0;
        return Transform.scale(
          scale: scale,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: bg,
              border: Border.all(color: borderColor),
              boxShadow: widget.isLow
                  ? [
                      BoxShadow(
                          color:
                              AppColors.neonRed.withOpacity(0.3 * _pulse.value),
                          blurRadius: 12)
                    ]
                  : null,
            ),
            child: Row(children: [
              Icon(Icons.flash_on_rounded, color: color, size: 15),
              const SizedBox(width: 4),
              Text('${ widget.remaining}',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins',
                      color: color)),
              const SizedBox(width: 2),
              Text('left',
                  style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'Poppins',
                      color: color.withOpacity(0.6))),
            ]),
          ),
        );
      },
    );
  }
}

// ── GAME BOARD ─────────────────────────────────────────────────────────────────
class _GameBoard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    final tubes = game.tubes;
    if (tubes.isEmpty) return const SizedBox.shrink();

    final count = tubes.length;
    int cols;
    if (count <= 4) cols = 2;
    else if (count <= 6) cols = 3;
    else cols = 4;
    final rows = (count / cols).ceil();

    return LayoutBuilder(builder: (ctx, constraints) {
      final availW = constraints.maxWidth;
      final availH = constraints.maxHeight;
      const hGap = 10.0;
      const vGap = 12.0;
      const arrowH = 20.0;

      final maxTubeW = (availW - 32 - hGap * (cols - 1)) / cols;
      final maxTubeH =
          (availH - 16 - vGap * (rows - 1) - arrowH * rows) / rows;

      double tubeW = maxTubeW.clamp(34.0, 88.0);
      double tubeH = tubeW * 3.2;
      if (tubeH > maxTubeH) {
        tubeH = maxTubeH.clamp(80.0, 280.0);
        tubeW = (tubeH / 3.2).clamp(26.0, 88.0);
      }

      final tubeWidgets = List.generate(count, (i) {
        return _TubeWidget(
          key: ValueKey('tube_$i'),
          tube: tubes[i],
          index: i,
          isHintFrom: game.isHinting && game.hintFrom == i,
          isHintTo: game.isHinting && game.hintTo == i,
          tubeW: tubeW,
          tubeH: tubeH,
          cols: cols,
          totalCount: count,
        );
      });

      return Stack(children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: hGap,
              runSpacing: vGap,
              alignment: WrapAlignment.center,
              runAlignment: WrapAlignment.center,
              children: tubeWidgets,
            ),
          ),
        ),
        if (game.isPouring && game.currentPour != null)
          _PhysicsPourOverlay(
            pour: game.currentPour!,
            tubeW: tubeW,
            tubeH: tubeH,
            cols: cols,
            hGap: hGap,
            vGap: vGap,
            arrowH: arrowH,
            totalCount: count,
            availW: availW,
            availH: availH,
          ),
      ]);
    });
  }
}

// ── PHYSICS POUR OVERLAY ───────────────────────────────────────────────────────
class _PhysicsPourOverlay extends StatefulWidget {
  final PourEvent pour;
  final double tubeW, tubeH, hGap, vGap, arrowH;
  final int cols, totalCount;
  final double availW, availH;

  const _PhysicsPourOverlay({
    required this.pour,
    required this.tubeW,
    required this.tubeH,
    required this.cols,
    required this.hGap,
    required this.vGap,
    required this.arrowH,
    required this.totalCount,
    required this.availW,
    required this.availH,
  });

  @override
  State<_PhysicsPourOverlay> createState() => _PhysicsPourOverlayState();
}

class _PhysicsPourOverlayState extends State<_PhysicsPourOverlay>
    with TickerProviderStateMixin {
  late AnimationController _mainCtrl;
  late AnimationController _dropsCtrl;
  late Animation<double> _progress;
  late Animation<double> _tiltAngle;
  final List<_Particle> _particles = [];
  late Color _pourColor;

  @override
  void initState() {
    super.initState();
    _pourColor = AppColors
        .liquidColors[widget.pour.color % AppColors.liquidColors.length];

    _mainCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 680),
    );

    _dropsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 680),
    );

    _progress = CurvedAnimation(
      parent: _mainCtrl,
      curve: Curves.easeInOut,
    );

    // Tilt: ramp up in first 30% then hold, then ramp down at end
    _tiltAngle = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 28),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 22),
    ]).animate(CurvedAnimation(parent: _mainCtrl, curve: Curves.easeInOut));

    _mainCtrl.forward();
    _dropsCtrl.forward();

    // Spawn particles during pour
    _mainCtrl.addListener(_spawnParticles);
  }

  void _spawnParticles() {
    final p = _mainCtrl.value;
    if (p > 0.30 && p < 0.90) {
      final dest = _tubeTopCenter(widget.pour.toIndex);
      if (_particles.length < 18) {
        final rng = Random();
        _particles.add(_Particle(
          position: Offset(
            dest.dx + (rng.nextDouble() - 0.5) * widget.tubeW * 0.7,
            dest.dy + rng.nextDouble() * widget.tubeH * 0.08,
          ),
          velocity: Offset(
            (rng.nextDouble() - 0.5) * 2.5,
            -rng.nextDouble() * 1.5,
          ),
          radius: 1.5 + rng.nextDouble() * 2.5,
          life: 1.0,
          color: _pourColor,
        ));
      }
    }
    // Age particles
    for (final pt in _particles) {
      pt.life -= 0.025;
      pt.position = Offset(
        pt.position.dx + pt.velocity.dx,
        pt.position.dy + pt.velocity.dy + 0.12,
      );
    }
    _particles.removeWhere((pt) => pt.life <= 0);
  }

  @override
  void dispose() {
    _mainCtrl.removeListener(_spawnParticles);
    _mainCtrl.dispose();
    _dropsCtrl.dispose();
    super.dispose();
  }

  Offset _tubeTopCenter(int index) {
    final cols = widget.cols;
    final col = index % cols;
    final row = index ~/ cols;
    final totalRowWidth = cols * widget.tubeW + (cols - 1) * widget.hGap;
    final startX = (widget.availW - totalRowWidth) / 2 + 16;
    final x = startX + col * (widget.tubeW + widget.hGap) + widget.tubeW / 2;
    final y = 8 +
        row * (widget.tubeH + widget.vGap + widget.arrowH) +
        widget.arrowH;
    return Offset(x, y);
  }

  @override
  Widget build(BuildContext context) {
    final fromPos = _tubeTopCenter(widget.pour.fromIndex);
    final toPos = _tubeTopCenter(widget.pour.toIndex);
    final isRight = toPos.dx > fromPos.dx;
    final isSameCol = (widget.pour.fromIndex % widget.cols) ==
        (widget.pour.toIndex % widget.cols);

    double maxTilt;
    if (isSameCol) {
      maxTilt = -0.28;
    } else {
      maxTilt = isRight ? -0.48 : 0.48;
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_mainCtrl, _dropsCtrl]),
      builder: (_, __) {
        return Stack(children: [
          // Tilted tube ghost overlay (shows source tube tilting)
          if (_tiltAngle.value > 0)
            Positioned(
              left: fromPos.dx - widget.tubeW / 2,
              top: fromPos.dy,
              child: Transform.rotate(
                angle: maxTilt * _tiltAngle.value,
                alignment: Alignment.bottomCenter,
                child: Opacity(
                  opacity: 0.0, // Tube tilt handled in _TubeWidget
                  child: SizedBox(
                      width: widget.tubeW, height: widget.tubeH),
                ),
              ),
            ),

          // Physics pour stream
          CustomPaint(
            size: Size(widget.availW, widget.availH),
            painter: _PhysicsPourPainter(
              from: fromPos,
              to: toPos,
              color: _pourColor,
              progress: _progress.value,
              tilt: _tiltAngle.value,
              tubeW: widget.tubeW,
              tubeH: widget.tubeH,
              isRight: isRight,
              isSameCol: isSameCol,
              particles: List.from(_particles),
            ),
          ),
        ]);
      },
    );
  }
}

class _Particle {
  Offset position;
  Offset velocity;
  double radius;
  double life;
  Color color;
  _Particle({
    required this.position,
    required this.velocity,
    required this.radius,
    required this.life,
    required this.color,
  });
}

class _PhysicsPourPainter extends CustomPainter {
  final Offset from;
  final Offset to;
  final Color color;
  final double progress;
  final double tilt;
  final double tubeW;
  final double tubeH;
  final bool isRight;
  final bool isSameCol;
  final List<_Particle> particles;

  _PhysicsPourPainter({
    required this.from,
    required this.to,
    required this.color,
    required this.progress,
    required this.tilt,
    required this.tubeW,
    required this.tubeH,
    required this.isRight,
    required this.isSameCol,
    required this.particles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.02) return;

    final rng = Random(42);

    // ── Pour mouth: tip of the tilting tube ──
    double maxTilt = isSameCol ? -0.28 : (isRight ? -0.48 : 0.48);
    final currentTilt = maxTilt * tilt;
    final mouthOffset = Offset(
      tubeW * 0.5 * sin(-currentTilt) * (isRight ? 1.4 : -1.4),
      tubeH * 0.08 * (1 - cos(currentTilt.abs())),
    );
    final mouth = Offset(
      from.dx + mouthOffset.dx + (isRight ? tubeW * 0.35 : -tubeW * 0.35) * tilt,
      from.dy + mouthOffset.dy + tubeH * 0.06,
    );

    // ── Destination point ──
    final dest = Offset(to.dx, to.dy + 6);

    // ── Physics-based bezier control points ──
    // Gravity pulls arc downward, horizontal motion carries stream
    final dx = dest.dx - mouth.dx;
    final dy = dest.dy - mouth.dy;
    final arcHeight = max(tubeH * 0.22, dy * 0.30);

    final cp1 = Offset(
      mouth.dx + dx * 0.25,
      mouth.dy - arcHeight * 0.4,
    );
    final cp2 = Offset(
      dest.dx - dx * 0.15,
      dest.dy - arcHeight * 0.25,
    );

    // Stream phases: appear(0–0.2), flow(0.2–0.80), thin+fade(0.80–1.0)
    final streamT = (progress * 1.18).clamp(0.0, 1.0);
    final fadeAlpha = progress < 0.82 ? 1.0 : (1.0 - (progress - 0.82) / 0.18).clamp(0.0, 1.0);
    final baseWidth = (5.5 * (1 - progress * 0.38)).clamp(1.8, 6.0);

    // ── Draw stream segments ──
    const segs = 28;
    for (int i = 0; i < segs; i++) {
      final t0 = (i / segs) * streamT;
      final t1 = ((i + 1) / segs) * streamT;
      if (t1 <= 0) continue;

      final p0 = _cubic(mouth, cp1, cp2, dest, t0);
      final p1 = _cubic(mouth, cp1, cp2, dest, t1);

      // Taper: slightly narrower mid-arc, wider mouth/dest
      final mid = (t0 + t1) / 2.0;
      final taper = 1.0 - 0.35 * sin(mid * pi);
      final segW = baseWidth * taper;

      // Subtle color shimmer along stream
      final shimmer = 0.06 * sin(mid * pi * 3 + progress * 6.28);
      final segColor = Color.lerp(color, Colors.white, shimmer.abs())!;

      canvas.drawLine(
        p0,
        p1,
        Paint()
          ..color = segColor.withOpacity(0.85 * fadeAlpha)
          ..strokeWidth = segW
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
    }

    // ── Leading droplet ──
    if (streamT > 0.06 && streamT < 0.96) {
      final dropPt = _cubic(mouth, cp1, cp2, dest, streamT);
      canvas.drawCircle(
        dropPt,
        baseWidth * 1.05,
        Paint()
          ..color = color.withOpacity(0.92 * fadeAlpha)
          ..style = PaintingStyle.fill,
      );
      // Droplet highlight
      canvas.drawCircle(
        dropPt - Offset(baseWidth * 0.25, baseWidth * 0.25),
        baseWidth * 0.3,
        Paint()
          ..color = Colors.white.withOpacity(0.45 * fadeAlpha)
          ..style = PaintingStyle.fill,
      );
    }

    // ── Trailing micro-droplets along stream ──
    if (progress > 0.15) {
      for (int d = 0; d < 5; d++) {
        final dt = (d / 5.0) * streamT * 0.85;
        if (dt <= 0) continue;
        final dp = _cubic(mouth, cp1, cp2, dest, dt);
        final side = (rng.nextBool() ? 1.0 : -1.0) * (1.0 + rng.nextDouble() * 2.5);
        canvas.drawCircle(
          dp + Offset(side, rng.nextDouble() * 2),
          0.8 + rng.nextDouble() * 1.2,
          Paint()
            ..color = color.withOpacity((0.35 + rng.nextDouble() * 0.3) * fadeAlpha)
            ..style = PaintingStyle.fill,
        );
      }
    }

    // ── Splash & ripple at destination ──
    if (progress > 0.68) {
      final splashP = ((progress - 0.68) / 0.32).clamp(0.0, 1.0);
      final splashAlpha = (1.0 - splashP) * 0.75 * fadeAlpha;

      // Expanding ring
      canvas.drawCircle(
        dest,
        tubeW * 0.28 * splashP,
        Paint()
          ..color = color.withOpacity(splashAlpha * 0.55)
          ..strokeWidth = 1.8
          ..style = PaintingStyle.stroke,
      );
      // Second ring (delayed)
      if (splashP > 0.3) {
        canvas.drawCircle(
          dest,
          tubeW * 0.42 * ((splashP - 0.3) / 0.7),
          Paint()
            ..color = color.withOpacity(splashAlpha * 0.3)
            ..strokeWidth = 1.2
            ..style = PaintingStyle.stroke,
        );
      }

      // Spray droplets fanning out
      for (int s = 0; s < 6; s++) {
        final angle = (s / 6.0) * 2 * pi + splashP * 0.8;
        final dist = tubeW * 0.22 * splashP;
        final sp = dest + Offset(cos(angle) * dist, sin(angle) * dist * 0.5);
        canvas.drawCircle(
          sp,
          max(0.1, 2.0 * (1 - splashP)),
          Paint()
            ..color = color.withOpacity(splashAlpha * 0.65)
            ..style = PaintingStyle.fill,
        );
      }

      // Inner fill glow
      final glowPaint = Paint()
        ..color = color.withOpacity(0.12 * (1 - splashP) * fadeAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(dest, tubeW * 0.3, glowPaint);
    }

    // ── Ambient particles ──
    for (final pt in particles) {
      if (pt.life <= 0) continue;
      canvas.drawCircle(
        pt.position,
        pt.radius * pt.life,
        Paint()
          ..color = pt.color.withOpacity(pt.life * 0.7)
          ..style = PaintingStyle.fill,
      );
    }

    // ── Glow around mouth while pouring ──
    if (tilt > 0.2 && progress < 0.85) {
      final glowMouth = Paint()
        ..color = color.withOpacity(0.18 * tilt * fadeAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(mouth, tubeW * 0.4, glowMouth);
    }
  }

  Offset _cubic(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
    final mt = 1 - t;
    return Offset(
      mt * mt * mt * p0.dx +
          3 * mt * mt * t * p1.dx +
          3 * mt * t * t * p2.dx +
          t * t * t * p3.dx,
      mt * mt * mt * p0.dy +
          3 * mt * mt * t * p1.dy +
          3 * mt * t * t * p2.dy +
          t * t * t * p3.dy,
    );
  }

  @override
  bool shouldRepaint(_PhysicsPourPainter old) =>
      old.progress != progress ||
      old.tilt != tilt ||
      old.particles.length != particles.length;
}

// ── TUBE WIDGET ────────────────────────────────────────────────────────────────
class _TubeWidget extends StatefulWidget {
  final TubeModel tube;
  final int index;
  final bool isHintFrom, isHintTo;
  final double tubeW, tubeH;
  final int cols, totalCount;

  const _TubeWidget({
    super.key,
    required this.tube,
    required this.index,
    required this.isHintFrom,
    required this.isHintTo,
    required this.tubeW,
    required this.tubeH,
    required this.cols,
    required this.totalCount,
  });

  @override
  State<_TubeWidget> createState() => _TubeWidgetState();
}

class _TubeWidgetState extends State<_TubeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _lift;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 260));
    _lift = Tween<double>(begin: 0, end: -16).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(_TubeWidget old) {
    super.didUpdateWidget(old);
    final game = context.read<GameProvider>();
    final pour = game.currentPour;

    if (widget.tube.isSelected && !old.tube.isSelected) {
      _ctrl.forward();
    } else if (!widget.tube.isSelected && old.tube.isSelected) {
      _ctrl.reverse();
    }

    if (pour != null && pour.fromIndex == widget.index) {
      _ctrl.forward();
    } else if (old.tube.isSelected && !widget.tube.isSelected) {
      _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = context.read<GameProvider>();
    final pour = game.currentPour;
    final isPourSource = pour != null && pour.fromIndex == widget.index;

    final w = widget.tubeW;
    final h = widget.tubeH;
    final r = w / 2;

    Color borderColor = Colors.white.withOpacity(0.15);
    double borderW = 1.5;
    List<BoxShadow> glow = [];

    if (widget.tube.isSelected || isPourSource) {
      borderColor = AppColors.neonBlue;
      borderW = 2.5;
      glow = [BoxShadow(
          color: AppColors.neonBlue.withOpacity(0.55), blurRadius: 18, spreadRadius: 2)];
    } else if (widget.isHintFrom) {
      borderColor = AppColors.neonYellow;
      borderW = 2.5;
      glow = [BoxShadow(
          color: AppColors.neonYellow.withOpacity(0.5), blurRadius: 14, spreadRadius: 1)];
    } else if (widget.isHintTo) {
      borderColor = AppColors.neonGreen;
      borderW = 2.5;
      glow = [BoxShadow(
          color: AppColors.neonGreen.withOpacity(0.5), blurRadius: 14, spreadRadius: 1)];
    } else if (widget.tube.isCompleted) {
      borderColor = AppColors.neonGreen;
      glow = [BoxShadow(
          color: AppColors.neonGreen.withOpacity(0.35), blurRadius: 12)];
    }

    // Tilt direction toward destination tube during pour
    double tiltTarget = 0;
    if (isPourSource) {
      final toIdx = pour!.toIndex;
      final fromCol = widget.index % widget.cols;
      final toCol = toIdx % widget.cols;
      if (toCol > fromCol) tiltTarget = -0.46;
      else if (toCol < fromCol) tiltTarget = 0.46;
      else tiltTarget = -0.28;
    }

    return GestureDetector(
      onTap: () => game.selectTube(widget.index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final liftVal = (widget.tube.isSelected || isPourSource)
              ? _lift.value
              : 0.0;
          final tiltVal = isPourSource ? tiltTarget * _ctrl.value : 0.0;

          return Transform.translate(
            offset: Offset(0, liftVal),
            child: Transform.rotate(
              angle: tiltVal,
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: w,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(
                    height: 20,
                    child: widget.isHintFrom
                        ? const Icon(Icons.keyboard_arrow_up_rounded,
                            color: AppColors.neonYellow, size: 18)
                        : widget.isHintTo
                            ? const Icon(Icons.keyboard_arrow_down_rounded,
                                color: AppColors.neonGreen, size: 18)
                            : const SizedBox.shrink(),
                  ),
                  Container(
                    width: w,
                    height: h,
                    decoration: BoxDecoration(boxShadow: glow),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(r),
                      child: Stack(children: [
                        // Glass body
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(r),
                            color: Colors.white.withOpacity(0.05),
                            border: Border.all(color: borderColor, width: borderW),
                          ),
                        ),
                        // Liquid fill
                        if (widget.tube.colors.isNotEmpty)
                          Positioned(
                            bottom: 0, left: 0, right: 0,
                            child: _LiquidFill(
                              tube: widget.tube,
                              tubeH: h,
                              isPourSource: isPourSource,
                              pourColor: pour != null
                                  ? AppColors.liquidColors[
                                      pour.color % AppColors.liquidColors.length]
                                  : null,
                            ),
                          ),
                        // Left glass shine
                        Positioned(
                          top: h * 0.05, left: w * 0.12,
                          child: Container(
                            width: w * 0.15, height: h * 0.52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(w * 0.08),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withOpacity(0.28),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Top shine dot
                        Positioned(
                          top: h * 0.04, left: w * 0.28,
                          child: Container(
                            width: w * 0.2, height: w * 0.2,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.18),
                            ),
                          ),
                        ),
                        // Right depth shine
                        Positioned(
                          top: h * 0.08, right: w * 0.1,
                          child: Container(
                            width: w * 0.08, height: h * 0.35,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withOpacity(0.12),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── LIQUID FILL ────────────────────────────────────────────────────────────────
class _LiquidFill extends StatelessWidget {
  final TubeModel tube;
  final double tubeH;
  final bool isPourSource;
  final Color? pourColor;

  const _LiquidFill({
    required this.tube,
    required this.tubeH,
    this.isPourSource = false,
    this.pourColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = tube.colors;
    if (colors.isEmpty) return const SizedBox.shrink();
    final segH = tubeH / tube.capacity;
    final reversed = colors.reversed.toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(reversed.length, (i) {
        final ci = reversed[i] % AppColors.liquidColors.length;
        final color = AppColors.liquidColors[ci];
        final isTopLayer = i == 0;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          width: double.infinity,
          height: segH,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                color.withOpacity(0.78),
                color,
                color.withOpacity(0.82),
              ],
            ),
          ),
          child: isTopLayer
              ? Stack(children: [
                  // Surface shine
                  Positioned(
                    top: 2, left: 6, right: 6,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 3,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: LinearGradient(colors: [
                          Colors.white.withOpacity(0.1),
                          Colors.white.withOpacity(0.5),
                          Colors.white.withOpacity(0.1),
                        ]),
                      ),
                    ),
                  ),
                  // Wave on surface
                  Positioned(
                    top: 6, left: 0, right: 0,
                    child: _WaveSurface(color: color, height: 4),
                  ),
                ])
              : Container(
                  alignment: Alignment.topCenter,
                  child: Container(height: 1, color: Colors.black.withOpacity(0.2)),
                ),
        );
      }),
    );
  }
}

// ── WAVE SURFACE ───────────────────────────────────────────────────────────────
class _WaveSurface extends StatefulWidget {
  final Color color;
  final double height;
  const _WaveSurface({required this.color, required this.height});
  @override
  State<_WaveSurface> createState() => _WaveSurfaceState();
}

class _WaveSurfaceState extends State<_WaveSurface>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat();
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
      builder: (_, __) => CustomPaint(
        painter: _WavePainter(
            color: widget.color, phase: _ctrl.value * 2 * pi),
        size: Size(double.infinity, widget.height),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final Color color;
  final double phase;
  _WavePainter({required this.color, required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height);
    for (double x = 0; x <= size.width; x++) {
      final y = size.height * 0.5 +
          sin(x * 0.08 + phase) * size.height * 0.4;
      path.lineTo(x, y);
    }
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.phase != phase;
}

// ── CONTROLS ───────────────────────────────────────────────────────────────────
class _GameControls extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Row(children: [
        Expanded(child: _CtrlBtn(
          icon: Icons.refresh_rounded, label: 'Restart',
          color: AppColors.neonOrange,
          onTap: () => _confirmRestart(context),
        )),
        const SizedBox(width: 10),
        Expanded(child: _CtrlBtn(
          icon: Icons.undo_rounded,
          label: game.undoCount > 0 ? 'Undo (${game.undoCount})' : 'Undo',
          color: AppColors.neonBlue,
          onTap: game.undoCount > 0
              ? () => game.undo()
              : () => _rewardedDialog(context,
                    title: 'Nothing to Undo ↩️',
                    body: 'Watch a short video to get a free undo!',
                    color: AppColors.neonBlue,
                    onReward: () => context.read<GameProvider>().addUndoFromAd(),
                  ),
        )),
        const SizedBox(width: 10),
        Expanded(child: _CtrlBtn(
          icon: Icons.lightbulb_outline_rounded,
          label: 'Hint (${game.hints})',
          color: AppColors.neonYellow,
          onTap: game.hints > 0
              ? () => game.useHint()
              : () => _rewardedDialog(context,
                    title: 'No Hints Left 💡',
                    body: 'Watch a short video to earn 3 hints!',
                    color: AppColors.neonYellow,
                    onReward: () => context.read<GameProvider>().addHints(3),
                  ),
        )),
      ]),
    );
  }

  void _confirmRestart(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => _Dialog(
        ctx: ctx,
        title: 'Restart Level?',
        body: 'Your progress will be lost.',
        actionLabel: 'Restart',
        actionColor: AppColors.neonOrange,
        onAction: () {
          Navigator.pop(ctx);
          ctx.read<GameProvider>().restartLevel();
        },
      ),
    );
  }

  void _rewardedDialog(BuildContext ctx, {
    required String title,
    required String body,
    required Color color,
    required VoidCallback onReward,
  }) {
    showDialog(
      context: ctx,
      builder: (_) => _Dialog(
        ctx: ctx,
        title: title,
        body: body,
        actionLabel: 'Watch Ad',
        actionColor: color,
        onAction: () {
          Navigator.pop(ctx);
          AdService().showRewarded(
            onRewarded: (_, __) => onReward(),
            onFailed: () {},
          );
        },
      ),
    );
  }
}

class _Dialog extends StatelessWidget {
  final BuildContext ctx;
  final String title, body, actionLabel;
  final Color actionColor;
  final VoidCallback onAction;
  const _Dialog({
    required this.ctx,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.actionColor,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title,
          style: const TextStyle(
              fontFamily: 'Poppins',
              color: AppColors.white,
              fontWeight: FontWeight.w700)),
      content: Text(body,
          style: const TextStyle(
              fontFamily: 'Poppins', color: AppColors.white40)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.white40))),
        TextButton(
            onPressed: onAction,
            child: Text(actionLabel,
                style: TextStyle(
                    color: actionColor, fontWeight: FontWeight.w700))),
      ],
    );
  }
}

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _CtrlBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: color.withOpacity(0.10),
            border: Border.all(color: color.withOpacity(0.4), width: 1.5),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'Poppins',
                    color: color,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

// ── WIN OVERLAY ────────────────────────────────────────────────────────────────
class _WinOverlay extends StatefulWidget {
  @override
  State<_WinOverlay> createState() => _WinOverlayState();
}

class _WinOverlayState extends State<_WinOverlay> {
  bool _adShown        = false;
  int  _competitionPts = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final iap  = IapService();
      final game = context.read<GameProvider>();

      // Interstitial fires every N levels (AppConstants.interstitialEveryNLevels)
      // — not on every win. Right after it's dismissed, nudge with Remove Ads.
      if (!_adShown && !iap.adsRemoved && game.shouldShowInterstitial) {
        _adShown = true;
        AdService().showInterstitial(onDismissed: () {
          if (mounted) {
            Future.delayed(const Duration(milliseconds: 250), () {
              if (mounted && !IapService().adsRemoved) {
                RemoveAdsSheet.show(context);
              }
            });
          }
        });
      }

      // Submit competition score
      final pts = await CompetitionService().submitLevelScore(
        colorCount:  game.currentColorCount,
        movesUsed:   game.moves,
        maxMoves:    game.maxMoves,
        secondsUsed: game.elapsedSeconds,
        streakDays:  game.dailyStreak,
      );
      if (mounted && pts > 0) setState(() => _competitionPts = pts);
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: GlassCard(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🎉', style: TextStyle(fontSize: 52))
                .animate()
                .scale(duration: 600.ms, curve: Curves.elasticOut),
            const SizedBox(height: 10),
            const Text('Level Complete!',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Poppins',
                    color: AppColors.white)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final filled = i < game.stars;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                      filled
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: filled
                          ? AppColors.neonYellow
                          : AppColors.white20,
                      size: 38)
                      .animate(
                          delay: Duration(milliseconds: 200 + i * 150))
                      .scale(duration: 400.ms, curve: Curves.elasticOut),
                );
              }),
            ),
            const SizedBox(height: 6),
            Text('${game.moves} moves',
                style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'Poppins',
                    color: AppColors.white40)),
            // Competition pts earned badge
            if (_competitionPts > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00C8FF), Color(0xFFB400FF)],
                  ),
                ),
                child: Text(
                  '🏆 +$_competitionPts competition pts',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins',
                      color: Colors.white),
                ),
              ).animate().fadeIn(delay: 300.ms).slideY(begin: -0.3),
            ],
            const SizedBox(height: 20),
            // Remove Ads upsell
            const RemoveAdsBanner(),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => game.nextLevel(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: AppColors.gradientPrimary,
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.neonBlue.withOpacity(0.4),
                        blurRadius: 18)
                  ],
                ),
                child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Next Level',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Poppins',
                              color: Colors.white)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, color: Colors.white),
                    ]),
              ),
            ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.3),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => game.restartLevel(),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Text('Replay Level',
                    style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'Poppins',
                        color: AppColors.white40)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── GAME OVER OVERLAY ──────────────────────────────────────────────────────────
class _GameOverOverlay extends StatefulWidget {
  @override
  State<_GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<_GameOverOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _shake;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..forward();
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: AnimatedBuilder(
          animation: _shake,
          builder: (_, child) {
            final shakeX = _shake.value < 0.5
                ? sin(_shake.value * pi * 8) * 6 * (1 - _shake.value * 2)
                : 0.0;
            return Transform.translate(
              offset: Offset(shakeX, 0),
              child: child,
            );
          },
          child: GlassCard(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('😤', style: TextStyle(fontSize: 52))
                  .animate()
                  .scale(duration: 500.ms, curve: Curves.elasticOut),
              const SizedBox(height: 10),
              const Text('Out of Moves!',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Poppins',
                      color: AppColors.neonRed)),
              const SizedBox(height: 8),
              Text(
                'Used all ${game.maxMoves} moves.\nWatch an ad to keep going!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'Poppins',
                    color: AppColors.white40,
                    height: 1.5),
              ),
              const SizedBox(height: 24),

              // Watch ad for +5 moves
              GestureDetector(
                onTap: () {
                  AdService().showRewarded(
                    onRewarded: (_, __) {
                      context.read<GameProvider>().addExtraMoves(
                          AppConstants.extraMovesPerAd);
                    },
                    onFailed: () {},
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFE600), Color(0xFFFF8C00)],
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.neonOrange.withOpacity(0.45),
                          blurRadius: 18)
                    ],
                  ),
                  child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_circle_outline_rounded,
                            color: Colors.black87, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Watch Ad → +${AppConstants.extraMovesPerAd} Moves',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Poppins',
                              color: Colors.black87),
                        ),
                      ]),
                ),
              ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.3),

              const SizedBox(height: 16),

              // Remove Ads upsell
              const RemoveAdsBanner(),

              const SizedBox(height: 16),

              // Restart
              GestureDetector(
                onTap: () => game.restartLevel(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: AppColors.white10,
                    border: Border.all(color: AppColors.white20),
                  ),
                  child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.refresh_rounded,
                            color: AppColors.white40, size: 18),
                        SizedBox(width: 8),
                        Text('Restart Level',
                            style: TextStyle(
                                fontSize: 14,
                                fontFamily: 'Poppins',
                                color: AppColors.white40,
                                fontWeight: FontWeight.w600)),
                      ]),
                ),
              ),

              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Back to Home',
                      style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Poppins',
                          color: AppColors.white40)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
