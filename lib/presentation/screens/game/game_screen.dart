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
    if (IapService().adsRemoved) return;
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
    final game     = context.watch<GameProvider>();
    final iap      = context.watch<IapService>();
    final worldIdx = game.currentWorldIndex.clamp(0, AppConstants.worlds.length - 1);
    final world    = AppConstants.worlds[worldIdx];
    final worldColor = Color(world['primaryColor'] as int);
    final worldBg    = Color(world['bgColor'] as int);

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
              child: Stack(children: [
                // Ambient glow sits behind everything — seeded per level so
                // each one looks a little different, colored to the current
                // world so it stays visually coherent.
                _LevelAmbientGlow(
                  levelSeed:    game.currentLevelId,
                  primaryColor: worldColor,
                ),
                if (game.status == GameStatus.won)
                  _WinOverlay()
                else if (game.status == GameStatus.gameOver)
                  _GameOverOverlay()
                else
                  _GameBoard(),
              ]),
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

// ── HEADER ──────────────────────────────────────────────────────────────────────
// ── LEVEL AMBIENT GLOW ────────────────────────────────────────────────────────
// A small number of soft, slowly-drifting glow orbs colored to the current
// world, with per-level variation in position/motion/timing so every level
// looks a little different from its neighbors even within the same world —
// while staying visually coherent (same color family) since the palette is
// still tied to the world, not randomized per level.
//
// Kept deliberately cheap, the same way the home screen's ambient orbs are:
// ONE shared AnimationController drives all orbs (not one controller each —
// that pattern caused real ticker pile-ups earlier on the splash screen and
// competition leaderboard). Rendering is plain Container + RadialGradient,
// not a CustomPainter — no per-pixel work, no blur filters. Wrapped in
// RepaintBoundary so this continuous animation never forces the tube board
// above it to repaint, and IgnorePointer so it can never intercept a tap
// meant for a tube.
class _LevelAmbientGlow extends StatefulWidget {
  final int   levelSeed;
  final Color primaryColor;
  const _LevelAmbientGlow({required this.levelSeed, required this.primaryColor});

  @override
  State<_LevelAmbientGlow> createState() => _LevelAmbientGlowState();
}

class _LevelAmbientGlowState extends State<_LevelAmbientGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_GlowOrbSpec> _orbs;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
    _buildOrbs();
  }

  @override
  void didUpdateWidget(_LevelAmbientGlow old) {
    super.didUpdateWidget(old);
    // New level → regenerate the orb layout so each level looks different.
    if (old.levelSeed != widget.levelSeed) {
      setState(_buildOrbs);
    }
  }

  void _buildOrbs() {
    final rng = Random(widget.levelSeed * 7919 + 13);
    _orbs = List.generate(4, (i) {
      return _GlowOrbSpec(
        baseX:   rng.nextDouble(),
        baseY:   rng.nextDouble(),
        radius:  90 + rng.nextDouble() * 90,
        phase:   rng.nextDouble(),
        driftX:  0.08 + rng.nextDouble() * 0.10,
        driftY:  0.08 + rng.nextDouble() * 0.10,
        opacity: 0.10 + rng.nextDouble() * 0.10,
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
    final size = MediaQuery.sizeOf(context);
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final t = _ctrl.value;
            return Stack(
              children: _orbs.map((o) {
                final angle = (t + o.phase) * 2 * pi;
                final x = o.baseX * size.width +
                    sin(angle) * o.driftX * size.width;
                final y = o.baseY * size.height +
                    cos(angle * 0.8) * o.driftY * size.height;
                final pulse = 0.75 + 0.25 * sin((t + o.phase) * 2 * pi * 1.3);

                return Positioned(
                  left: x - o.radius,
                  top:  y - o.radius,
                  child: Container(
                    width:  o.radius * 2,
                    height: o.radius * 2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          widget.primaryColor.withOpacity(o.opacity * pulse),
                          widget.primaryColor.withOpacity(0),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }
}

class _GlowOrbSpec {
  final double baseX, baseY, radius, phase, driftX, driftY, opacity;
  _GlowOrbSpec({
    required this.baseX,
    required this.baseY,
    required this.radius,
    required this.phase,
    required this.driftX,
    required this.driftY,
    required this.opacity,
  });
}

class _GameHeader extends StatelessWidget {
  final Color  worldColor;
  final String worldName;
  const _GameHeader({required this.worldColor, required this.worldName});

  @override
  Widget build(BuildContext context) {
    final game      = context.watch<GameProvider>();
    final remaining = game.movesRemaining;
    final isLow     = game.isMovesLow;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:  AppColors.white10,
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
                    fontSize: 12, fontFamily: 'Poppins', color: AppColors.white40)),
            Text('Level ${game.currentLevelInWorld + 1}',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins',
                    color: worldColor)),
          ]),
        ),
        _MovesCounter(remaining: remaining, isLow: isLow),
      ]),
    );
  }
}

// ── MOVES COUNTER ───────────────────────────────────────────────────────────────
// FIX: only pulsed when isLow; stopped otherwise. Was always ticking at 60fps.
class _MovesCounter extends StatefulWidget {
  final int  remaining;
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
        vsync: this, duration: const Duration(milliseconds: 600));
    if (widget.isLow) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_MovesCounter old) {
    super.didUpdateWidget(old);
    if (widget.isLow && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.isLow && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color       = widget.isLow ? AppColors.neonRed : AppColors.white;
    final borderColor = widget.isLow
        ? AppColors.neonRed.withOpacity(0.6)
        : AppColors.white20;
    final bg = widget.isLow
        ? AppColors.neonRed.withOpacity(0.08)
        : AppColors.white10;

    // When not low: static widget — zero tickers, zero repaints per frame.
    if (!widget.isLow) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: bg,
          border: Border.all(color: borderColor),
        ),
        child: Row(children: [
          Icon(Icons.flash_on_rounded, color: color, size: 15),
          const SizedBox(width: 4),
          Text('${widget.remaining}',
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
      );
    }

    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        final scale = 0.96 + 0.04 * _pulse.value;
        return Transform.scale(
          scale: scale,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: bg,
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                    color: AppColors.neonRed.withOpacity(0.3 * _pulse.value),
                    blurRadius: 12)
              ],
            ),
            child: Row(children: [
              Icon(Icons.flash_on_rounded, color: color, size: 15),
              const SizedBox(width: 4),
              Text('${widget.remaining}',
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

// ── GAME BOARD ──────────────────────────────────────────────────────────────────
class _GameBoard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final game  = context.watch<GameProvider>();
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
      const hGap  = 10.0;
      const vGap  = 12.0;
      const arrowH = 20.0;

      final maxTubeW = (availW - 32 - hGap * (cols - 1)) / cols;
      final maxTubeH = (availH - 16 - vGap * (rows - 1) - arrowH * rows) / rows;

      // Available space is the hard ceiling here. The upper bound (88/280)
      // caps how large tubes get when there's plenty of room, so they don't
      // look comically oversized on a tablet — but nothing is allowed to
      // push size ABOVE what's actually available. The previous two-sided
      // clamp(80, 280) could force tubeH UP to a minimum of 80 even when
      // the real available height per row was smaller than that — on very
      // cramped screens (split-screen multitasking, a folded foldable,
      // unusual aspect ratios) that forced overflow rather than shrinking
      // to fit. A verified-safe tube here is always slightly small rather
      // than clipped off-screen.
      double tubeW = maxTubeW.clamp(0.0, 88.0);
      double tubeH = tubeW * 3.2;
      if (tubeH > maxTubeH) {
        tubeH = maxTubeH.clamp(0.0, 280.0);
        tubeW = (tubeH / 3.2).clamp(0.0, 88.0);
      }

      final tubeWidgets = List.generate(count, (i) {
        return RepaintBoundary(
          key: ValueKey('tube_$i'),
          child: _TubeWidget(
            tube:       tubes[i],
            index:      i,
            isHintFrom: game.isHinting && game.hintFrom == i,
            isHintTo:   game.isHinting && game.hintTo   == i,
            tubeW:      tubeW,
            tubeH:      tubeH,
            cols:       cols,
            totalCount: count,
          ),
        );
      });

      return Stack(children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing:       hGap,
              runSpacing:    vGap,
              alignment:     WrapAlignment.center,
              runAlignment:  WrapAlignment.center,
              children:      tubeWidgets,
            ),
          ),
        ),
        if (game.activePours.isNotEmpty)
          ...game.activePours.map((pour) => IgnorePointer(
            key: ValueKey('pour_${pour.id}'),
            // IgnorePointer guarantees this purely-decorative layer can
            // never intercept a tap meant for a tube underneath it —
            // applied defensively here regardless of Flutter's exact
            // default hit-test behavior for CustomPaint, since taps must
            // always reach the board no matter how many pours are active.
            // RepaintBoundary isolates each concurrent pour's own repaints
            // from the others and from the tube board — important now
            // that several pours can legitimately be animating at once.
            child: RepaintBoundary(
              child: _PourOverlay(
                pour:       pour,
                tubeW:      tubeW,
                tubeH:      tubeH,
                cols:       cols,
                hGap:       hGap,
                vGap:       vGap,
                arrowH:     arrowH,
                totalCount: count,
                availW:     availW,
                availH:     availH,
              ),
            ),
          )),
      ]);
    });
  }
}

// ── POUR OVERLAY ────────────────────────────────────────────────────────────────
// FIX: single AnimationController, no per-listener Random(), no double-builder.
class _PourOverlay extends StatefulWidget {
  final PourEvent pour;
  final double tubeW, tubeH, hGap, vGap, arrowH;
  final int cols, totalCount;
  final double availW, availH;

  const _PourOverlay({
    super.key,
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
  State<_PourOverlay> createState() => _PourOverlayState();
}

class _PourOverlayState extends State<_PourOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Color _pourColor;
  // Pre-seeded RNG — not recreated every frame.
  final _rng = Random(12345);
  // Splash particles born once when splash phase starts.
  final List<_SplashParticle> _splashPts = [];
  bool _splashSpawned = false;

  @override
  void initState() {
    super.initState();
    _pourColor = AppColors.liquidColors[
        widget.pour.color % AppColors.liquidColors.length];
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..addListener(_tick)..forward();
  }

  void _tick() {
    final p = _ctrl.value;
    // Spawn splash particles once when stream reaches destination
    if (!_splashSpawned && p >= 0.65) {
      _splashSpawned = true;
      final dest = _tubeTopCenter(widget.pour.toIndex);
      for (int i = 0; i < 8; i++) {
        final angle = (_rng.nextDouble() * 2 * pi) - pi / 2;
        final speed = 1.5 + _rng.nextDouble() * 2.5;
        _splashPts.add(_SplashParticle(
          pos:   Offset(dest.dx + cos(angle) * 4, dest.dy + sin(angle) * 2),
          vel:   Offset(cos(angle) * speed, sin(angle) * speed - 1.5),
          color: _pourColor,
        ));
      }
    }
    // Age particles
    if (_splashSpawned) {
      for (final sp in _splashPts) sp.age += 0.07;
      _splashPts.removeWhere((sp) => sp.age >= 1.0);
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_tick);
    _ctrl.dispose();
    super.dispose();
  }

  Offset _tubeTopCenter(int index) {
    final col = index % widget.cols;
    final row = index ~/ widget.cols;
    final totalRowWidth =
        widget.cols * widget.tubeW + (widget.cols - 1) * widget.hGap;
    final startX = (widget.availW - totalRowWidth) / 2 + 16;
    final x = startX + col * (widget.tubeW + widget.hGap) + widget.tubeW / 2;
    final y = 8 + row * (widget.tubeH + widget.vGap + widget.arrowH) + widget.arrowH;
    return Offset(x, y);
  }

  @override
  Widget build(BuildContext context) {
    final from = _tubeTopCenter(widget.pour.fromIndex);
    final to   = _tubeTopCenter(widget.pour.toIndex);
    final isRight   = to.dx > from.dx;
    final isSameCol = (widget.pour.fromIndex % widget.cols) ==
        (widget.pour.toIndex   % widget.cols);
    final maxTilt   = isSameCol ? -0.28 : (isRight ? -0.48 : 0.48);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return CustomPaint(
          size: Size(widget.availW, widget.availH),
          painter: _PourPainter(
            from:           from,
            to:             to,
            color:          _pourColor,
            progress:       _ctrl.value,
            maxTilt:        maxTilt,
            tubeW:          widget.tubeW,
            tubeH:          widget.tubeH,
            isRight:        isRight,
            isSameCol:      isSameCol,
            splashParticles: List.unmodifiable(_splashPts),
          ),
        );
      },
    );
  }
}

class _SplashParticle {
  Offset pos;
  final Offset vel;
  final Color  color;
  double age = 0.0;
  _SplashParticle({required this.pos, required this.vel, required this.color});
}

class _PourPainter extends CustomPainter {
  final Offset from, to;
  final Color  color;
  final double progress, maxTilt, tubeW, tubeH;
  final bool   isRight, isSameCol;
  final List<_SplashParticle> splashParticles;

  const _PourPainter({
    required this.from,
    required this.to,
    required this.color,
    required this.progress,
    required this.maxTilt,
    required this.tubeW,
    required this.tubeH,
    required this.isRight,
    required this.isSameCol,
    required this.splashParticles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.02) return;

    // Tilt ramp: 0→1 in first 30%, hold, 1→0 at end
    final double tilt;
    if (progress < 0.28)      tilt = progress / 0.28;
    else if (progress < 0.78) tilt = 1.0;
    else                       tilt = 1.0 - (progress - 0.78) / 0.22;

    final currentTilt = maxTilt * tilt;

    // Pour mouth position on tilting tube
    final mouth = Offset(
      from.dx +
          tubeW * 0.5 * sin(-currentTilt) * (isRight ? 1.4 : -1.4) +
          (isRight ? tubeW * 0.35 : -tubeW * 0.35) * tilt,
      from.dy + tubeH * 0.08 * (1 - cos(currentTilt.abs())),
    );
    final dest = Offset(to.dx, to.dy + 6);

    // Bezier control points
    final dx = dest.dx - mouth.dx;
    final dy = dest.dy - mouth.dy;
    final arcH = max(tubeH * 0.22, dy * 0.30);
    final cp1 = Offset(mouth.dx + dx * 0.25, mouth.dy - arcH * 0.4);
    final cp2 = Offset(dest.dx  - dx * 0.15, dest.dy  - arcH * 0.25);

    final streamT  = (progress * 1.18).clamp(0.0, 1.0);
    final fadeAlpha = progress < 0.82
        ? 1.0
        : (1.0 - (progress - 0.82) / 0.18).clamp(0.0, 1.0);
    final baseW = (5.5 * (1 - progress * 0.38)).clamp(1.8, 6.0);

    // Stream — 18 segments (was 28, same visual quality)
    // Segment count reduced from the original single-pour tuning (was 18)
    // — with concurrent pours now a core feature, several of these can be
    // painting on the same frame, so per-instance cost matters more than
    // it used to. Still visually smooth at 12.
    const segs = 12;
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..style     = PaintingStyle.stroke;

    for (int i = 0; i < segs; i++) {
      final t0  = (i / segs) * streamT;
      final t1  = ((i + 1) / segs) * streamT;
      if (t1 <= 0) continue;
      final mid   = (t0 + t1) / 2.0;
      final taper = 1.0 - 0.35 * sin(mid * pi);
      // Shimmer: precomputed, no extra Random()
      final shimmer = 0.06 * sin(mid * pi * 3 + progress * 6.28);
      paint
        ..color      = Color.lerp(color, Colors.white, shimmer.abs())!
            .withOpacity(0.85 * fadeAlpha)
        ..strokeWidth = baseW * taper;
      canvas.drawLine(_cubic(mouth, cp1, cp2, dest, t0),
                      _cubic(mouth, cp1, cp2, dest, t1), paint);
    }

    // Leading droplet
    if (streamT > 0.06 && streamT < 0.96) {
      final dropPt = _cubic(mouth, cp1, cp2, dest, streamT);
      canvas.drawCircle(dropPt, baseW * 1.05,
          Paint()..color = color.withOpacity(0.92 * fadeAlpha));
      canvas.drawCircle(
        dropPt - Offset(baseW * 0.25, baseW * 0.25),
        baseW * 0.3,
        Paint()..color = Colors.white.withOpacity(0.45 * fadeAlpha),
      );
    }

    // ── SPLASH at destination ─────────────────────────────────────────────────
    if (progress > 0.65) {
      final sp = ((progress - 0.65) / 0.35).clamp(0.0, 1.0);
      final sa = (1.0 - sp) * 0.8 * fadeAlpha;

      // Expanding ring
      canvas.drawCircle(
        dest, tubeW * 0.30 * sp,
        Paint()
          ..color       = color.withOpacity(sa * 0.6)
          ..strokeWidth = 1.8
          ..style       = PaintingStyle.stroke,
      );
      // Second ring (delayed)
      if (sp > 0.3) {
        canvas.drawCircle(
          dest, tubeW * 0.45 * ((sp - 0.3) / 0.7),
          Paint()
            ..color       = color.withOpacity(sa * 0.35)
            ..strokeWidth = 1.2
            ..style       = PaintingStyle.stroke,
        );
      }
      // Splash fan drops — 6 rays (was 8; trimmed for concurrent-pour cost)
      for (int s = 0; s < 6; s++) {
        final angle = (s / 6.0) * 2 * pi + sp * 0.8;
        final dist  = tubeW * 0.25 * sp;
        canvas.drawCircle(
          dest + Offset(cos(angle) * dist, sin(angle) * dist * 0.55),
          (2.2 * (1 - sp)).clamp(0.1, 3.0),
          Paint()..color = color.withOpacity(sa * 0.7),
        );
      }
      // Inner glow — a plain, unblurred translucent circle. The previous
      // version used MaskFilter.blur here, which is a genuinely expensive
      // GPU operation compared to everything else this painter does; with
      // several pours now able to run at once, that cost multiplies per
      // concurrent instance. This keeps the same soft-glow read without it.
      canvas.drawCircle(
        dest, tubeW * 0.32,
        Paint()..color = color.withOpacity(0.10 * (1 - sp) * fadeAlpha),
      );
    }

    // ── Water splash particles (born once, aged in _tick) ────────────────────
    for (final pt in splashParticles) {
      final alpha = (1.0 - pt.age).clamp(0.0, 1.0);
      final r     = (2.5 * alpha).clamp(0.3, 3.0);
      // Apply gravity per-frame (age-based, no timer)
      final gPos = Offset(
        pt.pos.dx + pt.vel.dx * pt.age * 12,
        pt.pos.dy + pt.vel.dy * pt.age * 12 + 30 * pt.age * pt.age,
      );
      canvas.drawCircle(
        gPos, r,
        Paint()..color = color.withOpacity(alpha * 0.8),
      );
      // Tiny highlight
      canvas.drawCircle(
        gPos - Offset(r * 0.3, r * 0.3), r * 0.3,
        Paint()..color = Colors.white.withOpacity(alpha * 0.4),
      );
    }
  }

  Offset _cubic(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
    final mt = 1 - t;
    return Offset(
      mt*mt*mt*p0.dx + 3*mt*mt*t*p1.dx + 3*mt*t*t*p2.dx + t*t*t*p3.dx,
      mt*mt*mt*p0.dy + 3*mt*mt*t*p1.dy + 3*mt*t*t*p2.dy + t*t*t*p3.dy,
    );
  }

  @override
  bool shouldRepaint(_PourPainter old) =>
      old.progress != progress ||
      old.splashParticles.length != splashParticles.length;
}

// ── TUBE WIDGET ─────────────────────────────────────────────────────────────────
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
    // A tube may be the source of an in-flight pour even while others are
    // also animating elsewhere on the board — check membership, not a
    // single global pour reference.
    final isPourSrc = game.activePours.any((p) => p.fromIndex == widget.index);

    if (widget.tube.isSelected && !old.tube.isSelected) {
      _ctrl.forward();
    } else if (!widget.tube.isSelected && old.tube.isSelected) {
      _ctrl.reverse();
    }
    if (isPourSrc) {
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
    // Find this tube's own in-flight pour, if any — other tubes may have
    // their own independent pours active at the same time.
    PourEvent? myPour;
    for (final p in game.activePours) {
      if (p.fromIndex == widget.index) { myPour = p; break; }
    }
    final isPourSrc = myPour != null;
    final w = widget.tubeW;
    final h = widget.tubeH;
    final r = w / 2;

    Color borderColor = Colors.white.withOpacity(0.15);
    double borderW    = 1.5;
    List<BoxShadow> glow = const [];

    if (widget.tube.isSelected || isPourSrc) {
      borderColor = AppColors.neonBlue;
      borderW     = 2.5;
      glow = [BoxShadow(
          color: AppColors.neonBlue.withOpacity(0.55), blurRadius: 18, spreadRadius: 2)];
    } else if (widget.isHintFrom) {
      borderColor = AppColors.neonYellow;
      borderW     = 2.5;
      glow = [BoxShadow(
          color: AppColors.neonYellow.withOpacity(0.5), blurRadius: 14, spreadRadius: 1)];
    } else if (widget.isHintTo) {
      borderColor = AppColors.neonGreen;
      borderW     = 2.5;
      glow = [BoxShadow(
          color: AppColors.neonGreen.withOpacity(0.5), blurRadius: 14, spreadRadius: 1)];
    } else if (widget.tube.isCompleted) {
      borderColor = AppColors.neonGreen;
      glow = [BoxShadow(
          color: AppColors.neonGreen.withOpacity(0.35), blurRadius: 12)];
    }

    double tiltTarget = 0;
    if (isPourSrc) {
      final toCol  = myPour!.toIndex  % widget.cols;
      final frmCol = widget.index     % widget.cols;
      if      (toCol > frmCol) tiltTarget = -0.46;
      else if (toCol < frmCol) tiltTarget =  0.46;
      else                      tiltTarget = -0.28;
    }

    return GestureDetector(
      onTap: () => game.selectTube(widget.index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final liftVal = (widget.tube.isSelected || isPourSrc) ? _lift.value : 0.0;
          final tiltVal = isPourSrc ? tiltTarget * _ctrl.value : 0.0;

          return Transform.translate(
            offset: Offset(0, liftVal),
            child: Transform.rotate(
              angle:     tiltVal,
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
                    width: w, height: h,
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
                        // Liquid fill — pure static rendering, no wave ticker
                        if (widget.tube.colors.isNotEmpty)
                          Positioned(
                            bottom: 0, left: 0, right: 0,
                            child: _LiquidFill(
                              tube:        widget.tube,
                              tubeH:       h,
                              isPourSource: isPourSrc,
                            ),
                          ),
                        // Left shine
                        Positioned(
                          top: h*0.05, left: w*0.12,
                          child: Container(
                            width: w*0.15, height: h*0.52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(w*0.08),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end:   Alignment.bottomCenter,
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
                          top: h*0.04, left: w*0.28,
                          child: Container(
                            width: w*0.2, height: w*0.2,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.18),
                            ),
                          ),
                        ),
                        // Right depth
                        Positioned(
                          top: h*0.08, right: w*0.10,
                          child: Container(
                            width: w*0.08, height: h*0.35,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end:   Alignment.bottomCenter,
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

// ── LIQUID FILL ─────────────────────────────────────────────────────────────────
// FIX: removed _WaveSurface per-layer ticker. Was creating up to 24 separate
// AnimationControllers in a typical game board. Replaced with a single
// shared wave ticker fed down from _GameBoard level via _WaveOverlay.
// Each color segment is now a plain AnimatedContainer — zero extra tickers.
class _LiquidFill extends StatelessWidget {
  final TubeModel tube;
  final double    tubeH;
  final bool      isPourSource;

  const _LiquidFill({
    required this.tube,
    required this.tubeH,
    this.isPourSource = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors   = tube.colors;
    if (colors.isEmpty) return const SizedBox.shrink();
    final segH    = tubeH / tube.capacity;
    final reversed = colors.reversed.toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(reversed.length, (i) {
        final ci    = reversed[i] % AppColors.liquidColors.length;
        final color = AppColors.liquidColors[ci];

        return AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOut,
          width: double.infinity,
          height: segH,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end:   Alignment.centerRight,
              colors: [
                color.withOpacity(0.78),
                color,
                color.withOpacity(0.82),
              ],
            ),
          ),
          // Top-layer surface highlight — static, no ticker
          child: i == 0
              ? Column(children: [
                  Container(
                    height: 3, margin: const EdgeInsets.fromLTRB(6, 2, 6, 0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: LinearGradient(colors: [
                        Colors.white.withOpacity(0.08),
                        Colors.white.withOpacity(0.48),
                        Colors.white.withOpacity(0.08),
                      ]),
                    ),
                  ),
                ])
              : Container(
                  alignment: Alignment.topCenter,
                  child: Container(
                      height: 1, color: Colors.black.withOpacity(0.18)),
                ),
        );
      }),
    );
  }
}

// ── CONTROLS ────────────────────────────────────────────────────────────────────
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
                    body:  'Watch a short video to get a free undo!',
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
                    body:  'Watch a short video to earn 3 hints!',
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
        ctx: ctx, title: 'Restart Level?',
        body: 'Your progress will be lost.',
        actionLabel: 'Restart', actionColor: AppColors.neonOrange,
        onAction: () { Navigator.pop(ctx); ctx.read<GameProvider>().restartLevel(); },
      ),
    );
  }

  void _rewardedDialog(BuildContext ctx, {
    required String title, required String body,
    required Color color, required VoidCallback onReward,
  }) {
    showDialog(
      context: ctx,
      builder: (_) => _Dialog(
        ctx: ctx, title: title, body: body,
        actionLabel: 'Watch Ad', actionColor: color,
        onAction: () {
          Navigator.pop(ctx);
          AdService().showRewarded(
            onRewarded: (_, __) => onReward(), onFailed: () {});
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
    required this.ctx, required this.title, required this.body,
    required this.actionLabel, required this.actionColor, required this.onAction,
  });

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: AppColors.bgCard,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: Text(title,
        style: const TextStyle(
            fontFamily: 'Poppins', color: AppColors.white, fontWeight: FontWeight.w700)),
    content: Text(body,
        style: const TextStyle(fontFamily: 'Poppins', color: AppColors.white40)),
    actions: [
      TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel',
              style: TextStyle(color: AppColors.white40))),
      TextButton(
          onPressed: onAction,
          child: Text(actionLabel,
              style: TextStyle(color: actionColor, fontWeight: FontWeight.w700))),
    ],
  );
}

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _CtrlBtn({required this.icon, required this.label,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color:  color.withOpacity(0.10),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(
            fontSize: 11, fontFamily: 'Poppins',
            color: color, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

// ── WIN OVERLAY ─────────────────────────────────────────────────────────────────
class _WinOverlay extends StatefulWidget {
  @override
  State<_WinOverlay> createState() => _WinOverlayState();
}

class _WinOverlayState extends State<_WinOverlay> {
  bool _adShown       = false;
  int  _competitionPts = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final iap  = IapService();
      final game = context.read<GameProvider>();

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
                .animate().scale(duration: 600.ms, curve: Curves.elasticOut),
            const SizedBox(height: 10),
            const Text('Level Complete!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800,
                    fontFamily: 'Poppins', color: AppColors.white)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final filled = i < game.stars;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                      filled ? Icons.star_rounded : Icons.star_border_rounded,
                      color: filled ? AppColors.neonYellow : AppColors.white20,
                      size: 38)
                      .animate(delay: Duration(milliseconds: 200 + i * 150))
                      .scale(duration: 400.ms, curve: Curves.elasticOut),
                );
              }),
            ),
            const SizedBox(height: 6),
            Text('${game.moves} moves',
                style: const TextStyle(fontSize: 13,
                    fontFamily: 'Poppins', color: AppColors.white40)),
            if (_competitionPts > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                      colors: [Color(0xFF00C8FF), Color(0xFFB400FF)]),
                ),
                child: Text('🏆 +$_competitionPts pts',
                    style: const TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Poppins', color: Colors.white)),
              ).animate().fadeIn(delay: 300.ms).slideY(begin: -0.3),
            ],
            const SizedBox(height: 20),
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
                  boxShadow: [BoxShadow(
                      color: AppColors.neonBlue.withOpacity(0.4), blurRadius: 18)],
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Next Level', style: TextStyle(fontSize: 16,
                        fontWeight: FontWeight.w700, fontFamily: 'Poppins',
                        color: Colors.white)),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, color: Colors.white),
                  ]),
              ),
            ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.3),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => game.restartLevel(),
              child: const Padding(padding: EdgeInsets.all(8),
                child: Text('Replay Level', style: TextStyle(fontSize: 13,
                    fontFamily: 'Poppins', color: AppColors.white40))),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── GAME OVER OVERLAY ───────────────────────────────────────────────────────────
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
        vsync: this, duration: const Duration(milliseconds: 500))..forward();
  }

  @override
  void dispose() { _shake.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: AnimatedBuilder(
          animation: _shake,
          builder: (_, child) => Transform.translate(
            offset: Offset(
              _shake.value < 0.5
                  ? sin(_shake.value * pi * 8) * 6 * (1 - _shake.value * 2)
                  : 0.0,
              0),
            child: child,
          ),
          child: GlassCard(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('😤', style: TextStyle(fontSize: 52))
                  .animate().scale(duration: 500.ms, curve: Curves.elasticOut),
              const SizedBox(height: 10),
              const Text('Out of Moves!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800,
                      fontFamily: 'Poppins', color: AppColors.neonRed)),
              const SizedBox(height: 8),
              Text('Used all ${game.maxMoves} moves.\nWatch an ad to keep going!',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, fontFamily: 'Poppins',
                    color: AppColors.white40, height: 1.5)),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => AdService().showRewarded(
                  onRewarded: (_, __) => context.read<GameProvider>()
                      .addExtraMoves(AppConstants.extraMovesPerAd),
                  onFailed: () {},
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                        colors: [Color(0xFFFFE600), Color(0xFFFF8C00)]),
                    boxShadow: [BoxShadow(
                        color: AppColors.neonOrange.withOpacity(0.45), blurRadius: 18)],
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.play_circle_outline_rounded,
                        color: Colors.black87, size: 20),
                    const SizedBox(width: 8),
                    Text('Watch Ad → +${AppConstants.extraMovesPerAd} Moves',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                            fontFamily: 'Poppins', color: Colors.black87)),
                  ]),
                ),
              ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.3),
              const SizedBox(height: 16),
              const RemoveAdsBanner(),
              const SizedBox(height: 16),
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
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.refresh_rounded, color: AppColors.white40, size: 18),
                      SizedBox(width: 8),
                      Text('Restart Level', style: TextStyle(fontSize: 14,
                          fontFamily: 'Poppins', color: AppColors.white40,
                          fontWeight: FontWeight.w600)),
                    ]),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Padding(padding: EdgeInsets.all(8),
                  child: Text('Back to Home', style: TextStyle(fontSize: 12,
                      fontFamily: 'Poppins', color: AppColors.white40))),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
