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
    final worldIdx = game.currentWorldIndex
        .clamp(0, AppConstants.worlds.length - 1);
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
            // Board — always Expanded so LayoutBuilder gets real constraints
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
  const _GameHeader(
      {required this.worldColor, required this.worldName});

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

    if (tubes.isEmpty) {
      // Should never happen but just in case
      return const Center(
          child: Text('Loading...',
              style: TextStyle(
                  color: AppColors.white40, fontFamily: 'Poppins')));
    }

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
      const arrowH = 20.0; // space for hint arrow

      // Tube width
      final maxTubeW =
          (availW - 32 - hGap * (cols - 1)) / cols;
      // Tube height (each row also has arrowH above each tube)
      final maxTubeH =
          (availH - 16 - vGap * (rows - 1) - arrowH * rows) / rows;

      // Ratio 1 : 3.2  (width : height)
      double tubeW = maxTubeW.clamp(34.0, 88.0);
      double tubeH = tubeW * 3.2;
      if (tubeH > maxTubeH) {
        tubeH = maxTubeH.clamp(80.0, 280.0);
        tubeW = (tubeH / 3.2).clamp(26.0, 88.0);
      }

      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: hGap,
            runSpacing: vGap,
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            children: List.generate(
                count,
                (i) => _TubeWidget(
                      tube: tubes[i],
                      index: i,
                      isHintFrom:
                          game.isHinting && game.hintFrom == i,
                      isHintTo:
                          game.isHinting && game.hintTo == i,
                      tubeW: tubeW,
                      tubeH: tubeH,
                    )),
          ),
        ),
      );
    });
  }
}

// ── TUBE ──────────────────────────────────────────────────────────────────────
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
  late AnimationController _ctrl;
  late Animation<double> _lift;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _lift = Tween<double>(begin: 0, end: -12).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(_TubeWidget old) {
    super.didUpdateWidget(old);
    if (widget.tube.isSelected && !old.tube.isSelected) {
      _ctrl.forward();
    } else if (!widget.tube.isSelected && old.tube.isSelected) {
      _ctrl.reverse();
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final game = context.read<GameProvider>();
    final w = widget.tubeW;
    final h = widget.tubeH;
    final r = w / 2;

    Color borderColor = Colors.white.withOpacity(0.15);
    double borderW = 1.5;
    List<BoxShadow> glow = [];

    if (widget.tube.isSelected) {
      borderColor = AppColors.neonBlue;
      borderW = 2.5;
      glow = [BoxShadow(color: AppColors.neonBlue.withOpacity(0.55),
          blurRadius: 18, spreadRadius: 2)];
    } else if (widget.isHintFrom) {
      borderColor = AppColors.neonYellow;
      borderW = 2.5;
      glow = [BoxShadow(color: AppColors.neonYellow.withOpacity(0.5),
          blurRadius: 14, spreadRadius: 1)];
    } else if (widget.isHintTo) {
      borderColor = AppColors.neonGreen;
      borderW = 2.5;
      glow = [BoxShadow(color: AppColors.neonGreen.withOpacity(0.5),
          blurRadius: 14, spreadRadius: 1)];
    } else if (widget.tube.isCompleted) {
      borderColor = AppColors.neonGreen;
      glow = [BoxShadow(color: AppColors.neonGreen.withOpacity(0.35),
          blurRadius: 12)];
    }

    return GestureDetector(
      onTap: () => game.selectTube(widget.index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _lift,
        builder: (_, __) => Transform.translate(
          offset: Offset(0, _lift.value),
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
                            color: AppColors.neonGreen,
                            size: 18)
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
                        border: Border.all(
                            color: borderColor, width: borderW),
                      ),
                    ),
                    // Liquid from bottom
                    if (widget.tube.colors.isNotEmpty)
                      Positioned(
                        bottom: 0, left: 0, right: 0,
                        child: _LiquidFill(
                            tube: widget.tube,
                            tubeH: h,
                            tubeW: w),
                      ),
                    // Left shine
                    Positioned(
                      top: h * 0.05, left: w * 0.12,
                      child: Container(
                        width: w * 0.16, height: h * 0.52,
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(w * 0.08),
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
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── LIQUID ────────────────────────────────────────────────────────────────────
class _LiquidFill extends StatelessWidget {
  final TubeModel tube;
  final double tubeH, tubeW;
  const _LiquidFill(
      {required this.tube, required this.tubeH, required this.tubeW});

  @override
  Widget build(BuildContext context) {
    final colors = tube.colors;
    if (colors.isEmpty) return const SizedBox.shrink();
    final segH = tubeH / tube.capacity;

    // Draw reversed so index 0 is at the bottom visually
    final reversed = colors.reversed.toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(reversed.length, (i) {
        final ci = reversed[i] % AppColors.liquidColors.length;
        final color = AppColors.liquidColors[ci];
        final isTopLayer = i == 0; // first in reversed = top segment

        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          width: double.infinity,
          height: segH,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                color.withOpacity(0.80),
                color,
                color.withOpacity(0.85),
              ],
            ),
          ),
          child: isTopLayer
              ? Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    margin:
                        const EdgeInsets.fromLTRB(6, 2, 6, 0),
                    height: 3,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: Colors.white.withOpacity(0.45),
                    ),
                  ),
                )
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
          label: game.undoCount > 0
              ? 'Undo (${game.undoCount})' : 'Undo',
          color: AppColors.neonBlue,
          onTap: game.undoCount > 0
              ? () => game.undo()
              : () => _rewardedDialog(
                    context,
                    title: 'Nothing to Undo ↩️',
                    body: 'Watch a short video to get a free undo!',
                    color: AppColors.neonBlue,
                    onReward: () =>
                        context.read<GameProvider>().addUndoFromAd(),
                  ),
        )),
        const SizedBox(width: 10),
        Expanded(child: _CtrlBtn(
          icon: Icons.lightbulb_outline_rounded,
          label: 'Hint (${game.hints})',
          color: AppColors.neonYellow,
          onTap: game.hints > 0
              ? () => game.useHint()
              : () => _rewardedDialog(
                    context,
                    title: 'No Hints Left 💡',
                    body: 'Watch a short video to earn 3 hints!',
                    color: AppColors.neonYellow,
                    onReward: () =>
                        context.read<GameProvider>().addHints(3),
                  ),
        )),
      ]),
    );
  }

  void _confirmRestart(BuildContext ctx) {
    showDialog(
        context: ctx,
        builder: (_) => _dialog(
              ctx: ctx,
              title: 'Restart Level?',
              body: 'Your progress will be lost.',
              actionLabel: 'Restart',
              actionColor: AppColors.neonOrange,
              onAction: () {
                Navigator.pop(ctx);
                ctx.read<GameProvider>().restartLevel();
              },
            ));
  }

  void _rewardedDialog(
    BuildContext ctx, {
    required String title,
    required String body,
    required Color color,
    required VoidCallback onReward,
  }) {
    showDialog(
        context: ctx,
        builder: (_) => _dialog(
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
            ));
  }

  Widget _dialog({
    required BuildContext ctx,
    required String title,
    required String body,
    required String actionLabel,
    required Color actionColor,
    required VoidCallback onAction,
  }) {
    return AlertDialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
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
              style: TextStyle(color: AppColors.white40)),
        ),
        TextButton(
          onPressed: onAction,
          child: Text(actionLabel,
              style: TextStyle(
                  color: actionColor, fontWeight: FontWeight.w700)),
        ),
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
                    filled ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: filled ? AppColors.neonYellow
                        : AppColors.white20,
                    size: 38,
                  ).animate(
                      delay: Duration(milliseconds: 200 + i * 150))
                      .scale(duration: 400.ms,
                          curve: Curves.elasticOut),
                );
              }),
            ),
            const SizedBox(height: 6),
            Text('${game.moves} moves',
                style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'Poppins',
                    color: AppColors.white40)),
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
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Poppins',
                            color: Colors.white)),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded,
                        color: Colors.white),
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
