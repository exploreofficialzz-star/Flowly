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
  bool _bannerLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBanner());
  }

  void _loadBanner() {
    try {
      final ad = AdService().createBanner();
      if (mounted) setState(() { _banner = ad; _bannerLoaded = true; });
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
    final world = AppConstants.worlds[game.currentWorldIndex];
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
          child: Column(
            children: [
              _GameHeader(
                  worldColor: worldColor,
                  worldName: world['name'] as String),
              Expanded(
                child: game.status == GameStatus.won
                    ? _WinOverlay()
                    : _GameBoard(),
              ),
              _GameControls(),
              if (_bannerLoaded && _banner != null)
                SafeArea(
                  top: false,
                  child: SizedBox(
                    height: 50,
                    width: double.infinity,
                    child: AdWidget(ad: _banner!),
                  ),
                ),
            ],
          ),
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
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
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
                    fontSize: 12, fontFamily: 'Poppins', color: AppColors.white40)),
            Text('Level ${game.currentLevelInWorld + 1}',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins',
                    color: worldColor)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: AppColors.white10,
            border: Border.all(color: AppColors.white20),
          ),
          child: Row(children: [
            const Icon(Icons.swap_vert_rounded, color: AppColors.white40, size: 16),
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
    final count = tubes.length;
    final size = MediaQuery.of(context).size;

    // Fixed tube dimensions — compact so all tubes always fit
    // Available height for board
    const headerH = 70.0;
    const controlsH = 80.0;
    const bannerH = 50.0;
    const padding = 24.0;
    final boardH = size.height -
        MediaQuery.of(context).padding.top -
        headerH - controlsH - bannerH - padding;
    final boardW = size.width - 32;

    // Determine columns
    int cols;
    if (count <= 4) cols = 2;
    else if (count <= 6) cols = 3;
    else cols = 4;

    final rows = (count / cols).ceil();

    // Calculate tube size to fit everything
    const hGap = 10.0;
    const vGap = 12.0;
    final maxTubeW = (boardW - hGap * (cols - 1)) / cols;
    final maxTubeH = (boardH - vGap * (rows - 1)) / rows;

    // Tube must be narrow (ratio 1:3.5) and fit board
    double tubeW = maxTubeW.clamp(40.0, 80.0);
    double tubeH = (tubeW * 3.5).clamp(100.0, maxTubeH);
    // Reduce width if height doesn't fit
    if (tubeH > maxTubeH) {
      tubeH = maxTubeH;
      tubeW = (tubeH / 3.5).clamp(30.0, maxTubeW);
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Wrap(
          spacing: hGap,
          runSpacing: vGap,
          alignment: WrapAlignment.center,
          runAlignment: WrapAlignment.center,
          children: List.generate(count, (i) => _TubeWidget(
            tube: tubes[i],
            index: i,
            isHintFrom: game.isHinting && game.hintFrom == i,
            isHintTo: game.isHinting && game.hintTo == i,
            tubeW: tubeW,
            tubeH: tubeH,
          )),
        ),
      ),
    );
  }
}

// ── TUBE ─────────────────────────────────────────────────────────────────────
class _TubeWidget extends StatefulWidget {
  final TubeModel tube;
  final int index;
  final bool isHintFrom, isHintTo;
  final double tubeW, tubeH;
  const _TubeWidget({
    required this.tube, required this.index,
    required this.isHintFrom, required this.isHintTo,
    required this.tubeW, required this.tubeH,
  });
  @override
  State<_TubeWidget> createState() => _TubeWidgetState();
}

class _TubeWidgetState extends State<_TubeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _selectCtrl;

  @override
  void initState() {
    super.initState();
    _selectCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
  }

  @override
  void didUpdateWidget(_TubeWidget old) {
    super.didUpdateWidget(old);
    if (widget.tube.isSelected && !old.tube.isSelected) {
      _selectCtrl.forward(from: 0);
    } else if (!widget.tube.isSelected && old.tube.isSelected) {
      _selectCtrl.reverse();
    }
  }

  @override
  void dispose() { _selectCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final game = context.read<GameProvider>();
    final w = widget.tubeW;
    final h = widget.tubeH;
    final r = w / 2;
    final isSelected = widget.tube.isSelected;
    final isCompleted = widget.tube.isCompleted;

    Color borderColor = Colors.white.withOpacity(0.18);
    double borderW = 1.5;
    List<BoxShadow> shadows = [];

    if (isSelected) {
      borderColor = AppColors.neonBlue;
      borderW = 2.5;
      shadows = [BoxShadow(color: AppColors.neonBlue.withOpacity(0.55),
          blurRadius: 16, spreadRadius: 2)];
    } else if (widget.isHintFrom) {
      borderColor = AppColors.neonYellow;
      borderW = 2.5;
      shadows = [BoxShadow(color: AppColors.neonYellow.withOpacity(0.5),
          blurRadius: 14, spreadRadius: 1)];
    } else if (widget.isHintTo) {
      borderColor = AppColors.neonGreen;
      borderW = 2.5;
      shadows = [BoxShadow(color: AppColors.neonGreen.withOpacity(0.5),
          blurRadius: 14, spreadRadius: 1)];
    } else if (isCompleted) {
      borderColor = AppColors.neonGreen;
      borderW = 2;
      shadows = [BoxShadow(color: AppColors.neonGreen.withOpacity(0.4),
          blurRadius: 12)];
    }

    return GestureDetector(
      onTap: () => game.selectTube(widget.index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _selectCtrl,
        builder: (_, __) => Transform.translate(
          offset: Offset(0, -10 * _selectCtrl.value),
          child: SizedBox(
            width: w,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Hint arrow
              SizedBox(
                height: 16,
                child: widget.isHintFrom
                    ? Icon(Icons.keyboard_arrow_up_rounded,
                        color: AppColors.neonYellow, size: 16)
                    : widget.isHintTo
                        ? Icon(Icons.keyboard_arrow_down_rounded,
                            color: AppColors.neonGreen, size: 16)
                        : const SizedBox.shrink(),
              ),
              // Tube
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: w, height: h,
                decoration: BoxDecoration(
                  boxShadow: shadows,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(r),
                  child: Stack(children: [
                    // Glass background
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(r),
                        color: Colors.white.withOpacity(0.05),
                        border: Border.all(color: borderColor, width: borderW),
                      ),
                    ),
                    // Liquid layers
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: _buildLiquid(w, h),
                    ),
                    // Left shine
                    Positioned(
                      top: h * 0.06, left: w * 0.13,
                      child: Container(
                        width: w * 0.16, height: h * 0.55,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(w * 0.08),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withOpacity(0.3),
                              Colors.white.withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Top cap shine
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
                    // Outer border
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(r),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.08), width: 1),
                      ),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildLiquid(double w, double h) {
    final colors = widget.tube.colors;
    if (colors.isEmpty) return const SizedBox.shrink();
    const capacity = 4;
    final segH = h / capacity;

    // Build from bottom: index 0 = bottom segment
    return Column(
      mainAxisSize: MainAxisSize.min,
      verticalDirection: VerticalDirection.up, // bottom first
      children: List.generate(colors.length, (i) {
        final ci = colors[i] % AppColors.liquidColors.length;
        final color = AppColors.liquidColors[ci];
        final isTop = i == colors.length - 1;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          width: double.infinity,
          height: segH,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                color.withOpacity(0.82),
                color,
                color.withOpacity(0.88),
              ],
            ),
          ),
          child: isTop
              ? Stack(children: [
                  // Liquid surface shine
                  Positioned(
                    top: 2, left: 6, right: 6,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ),
                  // Segment divider at bottom of top layer
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      height: 1,
                      color: Colors.black.withOpacity(0.2),
                    ),
                  ),
                ])
              : Container(
                  // Divider between segments
                  alignment: Alignment.topCenter,
                  child: Container(
                    height: 1,
                    color: Colors.black.withOpacity(0.18),
                  ),
                ),
        );
      }),
    );
  }
}

// ── CONTROLS ──────────────────────────────────────────────────────────────────
class _GameControls extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Row(children: [
        Expanded(child: _CtrlBtn(
          icon: Icons.refresh_rounded, label: 'Restart',
          color: AppColors.neonOrange,
          onTap: () => _confirmRestart(context),
        )),
        const SizedBox(width: 10),
        Expanded(child: _CtrlBtn(
          icon: Icons.undo_rounded,
          label: 'Undo${game.undoCount > 0 ? " (${game.undoCount})" : ""}',
          color: AppColors.neonBlue,
          onTap: game.undoCount > 0
              ? () => game.undo()
              : () => _rewardedUndo(context),
        )),
        const SizedBox(width: 10),
        Expanded(child: _CtrlBtn(
          icon: Icons.lightbulb_outline_rounded,
          label: 'Hint (${game.hints})',
          color: AppColors.neonYellow,
          onTap: game.hints > 0
              ? () => game.useHint()
              : () => _rewardedHint(context),
        )),
      ]),
    );
  }

  void _confirmRestart(BuildContext ctx) {
    showDialog(context: ctx, builder: (_) => AlertDialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Restart Level?',
          style: TextStyle(fontFamily: 'Poppins',
              color: AppColors.white, fontWeight: FontWeight.w700)),
      content: const Text('Your progress will be lost.',
          style: TextStyle(fontFamily: 'Poppins', color: AppColors.white40)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.white40))),
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            ctx.read<GameProvider>().restartLevel();
          },
          child: const Text('Restart',
              style: TextStyle(color: AppColors.neonOrange,
                  fontWeight: FontWeight.w700)),
        ),
      ],
    ));
  }

  void _rewardedHint(BuildContext ctx) {
    showDialog(context: ctx, builder: (_) => AlertDialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('No Hints Left 💡',
          style: TextStyle(fontFamily: 'Poppins',
              color: AppColors.white, fontWeight: FontWeight.w700)),
      content: const Text('Watch a short video to earn 3 hints!',
          style: TextStyle(fontFamily: 'Poppins', color: AppColors.white40)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.white40))),
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            AdService().showRewarded(
              onRewarded: (_, __) => ctx.read<GameProvider>().addHints(3),
              onFailed: () {},
            );
          },
          child: const Text('Watch Ad',
              style: TextStyle(color: AppColors.neonYellow,
                  fontWeight: FontWeight.w700)),
        ),
      ],
    ));
  }

  void _rewardedUndo(BuildContext ctx) {
    showDialog(context: ctx, builder: (_) => AlertDialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Nothing to Undo ↩️',
          style: TextStyle(fontFamily: 'Poppins',
              color: AppColors.white, fontWeight: FontWeight.w700)),
      content: const Text('Watch a short video to get a free undo!',
          style: TextStyle(fontFamily: 'Poppins', color: AppColors.white40)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.white40))),
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            AdService().showRewarded(
              onRewarded: (_, __) => ctx.read<GameProvider>().addUndoFromAd(),
              onFailed: () {},
            );
          },
          child: const Text('Watch Ad',
              style: TextStyle(color: AppColors.neonBlue,
                  fontWeight: FontWeight.w700)),
        ),
      ],
    ));
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: color.withOpacity(0.1),
          border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontFamily: 'Poppins',
                  color: color, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
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
      if (!_adShown) {
        _adShown = true;
        AdService().showInterstitial(onDismissed: () {});
      }
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
                    size: 38,
                  ).animate(delay: Duration(milliseconds: 200 + i * 150))
                      .scale(duration: 400.ms, curve: Curves.elasticOut),
                );
              }),
            ),
            const SizedBox(height: 6),
            Text('${game.moves} moves',
                style: const TextStyle(fontSize: 13,
                    fontFamily: 'Poppins', color: AppColors.white40)),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => game.nextLevel(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: AppColors.gradientPrimary,
                  boxShadow: [BoxShadow(
                      color: AppColors.neonBlue.withOpacity(0.4),
                      blurRadius: 18)],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Next Level',
                        style: TextStyle(fontSize: 16,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Poppins', color: Colors.white)),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, color: Colors.white),
                  ],
                ),
              ),
            ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.3),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => game.restartLevel(),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Text('Replay Level',
                    style: TextStyle(fontSize: 13,
                        fontFamily: 'Poppins', color: AppColors.white40)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
