import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/game_model.dart';
import '../../../services/ad_service.dart';
import '../../providers/game_provider.dart';
import '../../widgets/glass_card.dart';

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
            _GameHeader(
                worldColor: worldColor,
                worldName: world['name'] as String),
            Expanded(
              child: game.status == GameStatus.won
                  ? _WinOverlay()
                  : _GameBoard(),
            ),
            _GameControls(),
            if (_banner != null)
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

// ── HEADER ────────────────────────────────────────────────────────────────────
class _GameHeader extends StatelessWidget {
  final Color worldColor;
  final String worldName;
  const _GameHeader({required this.worldColor, required this.worldName});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
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
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: AppColors.white10,
            border: Border.all(color: AppColors.white20),
          ),
          child: Row(children: [
            const Icon(Icons.swap_vert_rounded,
                color: AppColors.white40, size: 16),
            const SizedBox(width: 4),
            Text('${game.moves}',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins',
                    color: AppColors.white)),
          ]),
        ),
      ]),
    );
  }
}

// ── GAME BOARD ────────────────────────────────────────────────────────────────
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

      // Build tube widgets with keys to get their positions
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
        // Tubes
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
        // Pour stream overlay
        if (game.isPouring && game.currentPour != null)
          _PourStreamOverlay(
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

// ── POUR STREAM OVERLAY ───────────────────────────────────────────────────────
// Calculates tube positions and draws animated liquid arc between them
class _PourStreamOverlay extends StatefulWidget {
  final PourEvent pour;
  final double tubeW, tubeH, hGap, vGap, arrowH;
  final int cols, totalCount;
  final double availW, availH;

  const _PourStreamOverlay({
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
  State<_PourStreamOverlay> createState() => _PourStreamOverlayState();
}

class _PourStreamOverlayState extends State<_PourStreamOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
    _progress = CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // Calculate tube top-center position from index
  Offset _tubeTopCenter(int index) {
    final cols = widget.cols;
    final col = index % cols;
    final row = index ~/ cols;

    final totalRowWidth = cols * widget.tubeW + (cols - 1) * widget.hGap;
    final startX = (widget.availW - totalRowWidth) / 2 + 16;

    final x = startX + col * (widget.tubeW + widget.hGap) + widget.tubeW / 2;
    // arrowH sits above each tube
    final y = 8 +
        row * (widget.tubeH + widget.vGap + widget.arrowH) +
        widget.arrowH;
    return Offset(x, y);
  }

  @override
  Widget build(BuildContext context) {
    final fromPos = _tubeTopCenter(widget.pour.fromIndex);
    final toPos = _tubeTopCenter(widget.pour.toIndex);
    final color =
        AppColors.liquidColors[widget.pour.color % AppColors.liquidColors.length];

    return AnimatedBuilder(
      animation: _progress,
      builder: (_, __) => CustomPaint(
        size: Size(widget.availW, widget.availH),
        painter: _PourStreamPainter(
          from: fromPos,
          to: toPos,
          color: color,
          progress: _progress.value,
          tubeW: widget.tubeW,
          tubeH: widget.tubeH,
        ),
      ),
    );
  }
}

class _PourStreamPainter extends CustomPainter {
  final Offset from;
  final Offset to;
  final Color color;
  final double progress;
  final double tubeW;
  final double tubeH;

  _PourStreamPainter({
    required this.from,
    required this.to,
    required this.color,
    required this.progress,
    required this.tubeW,
    required this.tubeH,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final isRight = to.dx > from.dx;
    final tiltAngle = isRight ? -0.55 : 0.55; // radians

    // Pour mouth — tip of tilted tube
    final mouthX = from.dx + (tubeW / 2 + 4) * (isRight ? 1 : -1);
    final mouthY = from.y + tubeH * 0.15;
    final mouth = Offset(mouthX, mouthY);

    // Destination top center
    final dest = Offset(to.dx, to.dy + 4);

    // Stream phases:
    // 0.0 - 0.25: stream appears at mouth
    // 0.25 - 0.80: stream flows to destination
    // 0.80 - 1.0: stream thins and disappears

    final streamProgress = (progress * 1.2).clamp(0.0, 1.0);

    // Stream end point along the arc
    final endT = streamProgress;
    final cp1 = Offset(mouth.dx, mouth.dy + tubeH * 0.3);
    final cp2 = Offset(dest.dx, dest.dy - tubeH * 0.15);

    final streamEnd = _cubicPoint(mouth, cp1, cp2, dest, endT);

    // Draw stream as a tapered path
    final streamWidth = (4.0 * (1 - progress * 0.4)).clamp(1.5, 5.0);
    final alphaMul = progress < 0.85 ? 1.0 : (1 - (progress - 0.85) / 0.15);

    final paint = Paint()
      ..color = color.withOpacity(0.88 * alphaMul)
      ..strokeWidth = streamWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Draw stream as bezier segments
    final path = Path();
    path.moveTo(mouth.dx, mouth.dy);

    const steps = 20;
    for (int i = 1; i <= steps; i++) {
      final t = (i / steps) * endT;
      final pt = _cubicPoint(mouth, cp1, cp2, dest, t);
      // Taper: wider at mouth, thinner in middle, slightly wider at dest
      final taper = i == steps ? streamWidth * 1.2 : streamWidth;
      paint.strokeWidth = taper * (1 - 0.4 * sin(t * pi));
      path.lineTo(pt.dx, pt.dy);
    }

    canvas.drawPath(path, paint);

    // Droplet at the leading edge
    if (endT > 0.05 && endT < 0.98) {
      final dropPaint = Paint()
        ..color = color.withOpacity(0.9 * alphaMul)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(streamEnd, streamWidth * 0.9, dropPaint);
    }

    // Splash ripple when liquid hits destination
    if (progress > 0.72) {
      final splashProgress = ((progress - 0.72) / 0.28).clamp(0.0, 1.0);
      final splashRadius = tubeW * 0.25 * splashProgress;
      final splashAlpha = (1 - splashProgress) * 0.6 * alphaMul;
      final splashPaint = Paint()
        ..color = color.withOpacity(splashAlpha)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(dest, splashRadius, splashPaint);

      // Mini droplets spraying out
      for (int d = 0; d < 4; d++) {
        final angle = (d / 4) * 2 * pi + splashProgress * 0.5;
        final dr = tubeW * 0.15 * splashProgress;
        final dp = Offset(
          dest.dx + cos(angle) * dr,
          dest.dy + sin(angle) * dr * 0.5,
        );
        canvas.drawCircle(
          dp,
          1.5 * (1 - splashProgress),
          Paint()..color = color.withOpacity(splashAlpha * 0.7),
        );
      }
    }
  }

  Offset _cubicPoint(
      Offset p0, Offset p1, Offset p2, Offset p3, double t) {
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
  bool shouldRepaint(_PourStreamPainter old) =>
      old.progress != progress || old.from != from || old.to != to;
}

// ── TUBE WIDGET ───────────────────────────────────────────────────────────────
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
  late Animation<double> _tilt;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _lift = Tween<double>(begin: 0, end: -14).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _tilt = Tween<double>(begin: 0, end: 0.0).animate(_ctrl);
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

    // Tilt when this tube is the pour source
    if (pour != null && pour.fromIndex == widget.index) {
      _ctrl.forward();
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

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
      glow = [BoxShadow(color: AppColors.neonBlue.withOpacity(0.55),
          blurRadius: 18, spreadRadius: 2)];
    } else if (widget.isHintFrom) {
      borderColor = AppColors.neonYellow; borderW = 2.5;
      glow = [BoxShadow(color: AppColors.neonYellow.withOpacity(0.5),
          blurRadius: 14, spreadRadius: 1)];
    } else if (widget.isHintTo) {
      borderColor = AppColors.neonGreen; borderW = 2.5;
      glow = [BoxShadow(color: AppColors.neonGreen.withOpacity(0.5),
          blurRadius: 14, spreadRadius: 1)];
    } else if (widget.tube.isCompleted) {
      borderColor = AppColors.neonGreen;
      glow = [BoxShadow(color: AppColors.neonGreen.withOpacity(0.35),
          blurRadius: 12)];
    }

    // Tilt direction: toward destination tube
    double tiltAngle = 0;
    if (isPourSource) {
      final toIdx = pour!.toIndex;
      final fromCol = widget.index % widget.cols;
      final toCol = toIdx % widget.cols;
      if (toCol > fromCol) tiltAngle = -0.45; // tilt right
      else if (toCol < fromCol) tiltAngle = 0.45; // tilt left
      else tiltAngle = -0.3; // same column, slight tilt
    }

    return GestureDetector(
      onTap: () => game.selectTube(widget.index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final liftVal = widget.tube.isSelected || isPourSource
              ? _lift.value : 0.0;
          final tiltVal = isPourSource ? tiltAngle * _ctrl.value : 0.0;

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
                            ? const Icon(
                                Icons.keyboard_arrow_down_rounded,
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
                            border: Border.all(
                                color: borderColor, width: borderW),
                          ),
                        ),
                        // Liquid
                        if (widget.tube.colors.isNotEmpty)
                          Positioned(
                            bottom: 0, left: 0, right: 0,
                            child: _LiquidFill(
                              tube: widget.tube,
                              tubeH: h,
                              isPourSource: isPourSource,
                              pourColor: pour != null
                                  ? AppColors.liquidColors[pour.color %
                                      AppColors.liquidColors.length]
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
                        // Right shine (3D depth)
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

// ── LIQUID FILL ───────────────────────────────────────────────────────────────
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

        // If pouring from this tube, animate the top layer draining
        final heightMul = (isPourSource && isTopLayer) ? 1.0 : 1.0;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          width: double.infinity,
          height: segH * heightMul,
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
                  // Liquid surface shine
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
                  // Wave effect on top surface
                  Positioned(
                    top: 6, left: 0, right: 0,
                    child: _WaveSurface(color: color, height: 4),
                  ),
                ])
              : Container(
                  alignment: Alignment.topCenter,
                  child: Container(
                    height: 1,
                    color: Colors.black.withOpacity(0.2),
                  ),
                ),
        );
      }),
    );
  }
}

// ── WAVE SURFACE ──────────────────────────────────────────────────────────────
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
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _WavePainter(
          color: widget.color,
          phase: _ctrl.value * 2 * pi,
        ),
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

// ── CONTROLS ──────────────────────────────────────────────────────────────────
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
    showDialog(context: ctx, builder: (_) => _Dialog(
      ctx: ctx, title: 'Restart Level?',
      body: 'Your progress will be lost.',
      actionLabel: 'Restart', actionColor: AppColors.neonOrange,
      onAction: () { Navigator.pop(ctx); ctx.read<GameProvider>().restartLevel(); },
    ));
  }

  void _rewardedDialog(BuildContext ctx, {
    required String title, required String body,
    required Color color, required VoidCallback onReward,
  }) {
    showDialog(context: ctx, builder: (_) => _Dialog(
      ctx: ctx, title: title, body: body,
      actionLabel: 'Watch Ad', actionColor: color,
      onAction: () {
        Navigator.pop(ctx);
        AdService().showRewarded(onRewarded: (_, __) => onReward(), onFailed: () {});
      },
    ));
  }
}

class _Dialog extends StatelessWidget {
  final BuildContext ctx;
  final String title, body, actionLabel;
  final Color actionColor;
  final VoidCallback onAction;
  const _Dialog({required this.ctx, required this.title, required this.body,
      required this.actionLabel, required this.actionColor, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: const TextStyle(
          fontFamily: 'Poppins', color: AppColors.white, fontWeight: FontWeight.w700)),
      content: Text(body, style: const TextStyle(
          fontFamily: 'Poppins', color: AppColors.white40)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.white40))),
        TextButton(onPressed: onAction,
            child: Text(actionLabel, style: TextStyle(
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
  const _CtrlBtn({required this.icon, required this.label,
      required this.color, required this.onTap});

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
        Text(label, style: TextStyle(fontSize: 11, fontFamily: 'Poppins',
            color: color, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

// ── WIN OVERLAY ───────────────────────────────────────────────────────────────
class _WinOverlay extends StatefulWidget {
  @override
  State<_WinOverlay> createState() => _WinOverlayState();
}

class _WinOverlayState extends State<_WinOverlay> {
  bool _adShown = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_adShown) { _adShown = true; AdService().showInterstitial(onDismissed: () {}); }
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GlassCard(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🎉', style: TextStyle(fontSize: 52))
                .animate().scale(duration: 600.ms, curve: Curves.elasticOut),
            const SizedBox(height: 10),
            const Text('Level Complete!', style: TextStyle(fontSize: 24,
                fontWeight: FontWeight.w800, fontFamily: 'Poppins', color: AppColors.white)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final filled = i < game.stars;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(filled ? Icons.star_rounded : Icons.star_border_rounded,
                    color: filled ? AppColors.neonYellow : AppColors.white20, size: 38)
                  .animate(delay: Duration(milliseconds: 200 + i * 150))
                  .scale(duration: 400.ms, curve: Curves.elasticOut),
                );
              }),
            ),
            const SizedBox(height: 6),
            Text('${game.moves} moves', style: const TextStyle(
                fontSize: 13, fontFamily: 'Poppins', color: AppColors.white40)),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => game.nextLevel(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: AppColors.gradientPrimary,
                  boxShadow: [BoxShadow(color: AppColors.neonBlue.withOpacity(0.4), blurRadius: 18)],
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('Next Level', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins', color: Colors.white)),
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
                child: Text('Replay Level', style: TextStyle(
                    fontSize: 13, fontFamily: 'Poppins', color: AppColors.white40)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
