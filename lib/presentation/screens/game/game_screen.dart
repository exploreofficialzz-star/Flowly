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
      setState(() { _banner = ad; _bannerLoaded = true; });
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
              _GameHeader(worldColor: worldColor, worldName: world['name'] as String),
              Expanded(
                child: game.status == GameStatus.won
                    ? _WinOverlay()
                    : _GameBoard(),
              ),
              _GameControls(),
              if (_bannerLoaded && _banner != null)
                SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: AdWidget(ad: _banner!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── HEADER ──────────────────────────────────────────────────────────────────
class _GameHeader extends StatelessWidget {
  final Color worldColor;
  final String worldName;
  const _GameHeader({required this.worldColor, required this.worldName});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
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
                    style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Poppins',
                        color: AppColors.white40)),
                Text('Level ${game.currentLevelInWorld + 1}',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Poppins',
                        color: worldColor)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AppColors.white10,
              border: Border.all(color: AppColors.white20),
            ),
            child: Row(
              children: [
                const Icon(Icons.swap_vert_rounded,
                    color: AppColors.white40, size: 16),
                const SizedBox(width: 4),
                Text('${game.moves}',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Poppins',
                        color: AppColors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── GAME BOARD ───────────────────────────────────────────────────────────────
class _GameBoard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    final tubes = game.tubes;
    final size = MediaQuery.of(context).size;
    final count = tubes.length;

    // Responsive grid: always fits all tubes
    int crossCount;
    if (count <= 4) crossCount = 2;
    else if (count <= 6) crossCount = 3;
    else if (count <= 8) crossCount = 4;
    else crossCount = 4;

    final hPad = 20.0;
    final spacing = 10.0;
    final availW = size.width - hPad * 2 - spacing * (crossCount - 1);
    final tubeW = availW / crossCount;
    // Height: tube should be tall enough to show 4 segments clearly
    final tubeH = tubeW * 2.6;

    final rows = (count / crossCount).ceil();
    final availH = size.height * 0.58;
    final rowH = availH / rows;
    final finalTubeH = min(tubeH, rowH - 20);
    final finalTubeW = min(tubeW, finalTubeH / 2.6);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 8),
      child: Center(
        child: Wrap(
          spacing: spacing,
          runSpacing: 14,
          alignment: WrapAlignment.center,
          children: List.generate(tubes.length, (i) => _TubeWidget(
            tube: tubes[i],
            index: i,
            isHintFrom: game.isHinting && game.hintFrom == i,
            isHintTo: game.isHinting && game.hintTo == i,
            tubeWidth: finalTubeW,
            tubeHeight: finalTubeH,
          )),
        ),
      ),
    );
  }
}

// ── REALISTIC GLASS TUBE ─────────────────────────────────────────────────────
class _TubeWidget extends StatefulWidget {
  final TubeModel tube;
  final int index;
  final bool isHintFrom, isHintTo;
  final double tubeWidth, tubeHeight;

  const _TubeWidget({
    required this.tube,
    required this.index,
    required this.isHintFrom,
    required this.isHintTo,
    required this.tubeWidth,
    required this.tubeHeight,
  });

  @override
  State<_TubeWidget> createState() => _TubeWidgetState();
}

class _TubeWidgetState extends State<_TubeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnim;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _bounceAnim = Tween<double>(begin: 0, end: -12).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(_TubeWidget old) {
    super.didUpdateWidget(old);
    if (widget.tube.isSelected && !old.tube.isSelected) {
      _bounceController.forward().then((_) => _bounceController.reverse());
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = context.read<GameProvider>();
    final w = widget.tubeWidth;
    final h = widget.tubeHeight;
    final r = w / 2;
    final isSelected = widget.tube.isSelected;

    Color glowColor = Colors.transparent;
    if (isSelected) glowColor = AppColors.neonBlue;
    if (widget.isHintFrom) glowColor = AppColors.neonYellow;
    if (widget.isHintTo) glowColor = AppColors.neonGreen;
    if (widget.tube.isCompleted) glowColor = AppColors.neonGreen;

    return GestureDetector(
      onTap: () => game.selectTube(widget.index),
      child: AnimatedBuilder(
        animation: _bounceAnim,
        builder: (_, __) => Transform.translate(
          offset: Offset(0, isSelected ? _bounceAnim.value : 0),
          child: SizedBox(
            width: w,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Hint arrow above
                SizedBox(
                  height: 18,
                  child: widget.isHintFrom
                      ? Icon(Icons.keyboard_arrow_up_rounded,
                          color: AppColors.neonYellow, size: 18)
                          .animate(onPlay: (c) => c.repeat())
                          .moveY(begin: 0, end: -4, duration: 500.ms)
                      : widget.isHintTo
                          ? Icon(Icons.keyboard_arrow_down_rounded,
                              color: AppColors.neonGreen, size: 18)
                              .animate(onPlay: (c) => c.repeat())
                              .moveY(begin: -4, end: 0, duration: 500.ms)
                          : const SizedBox.shrink(),
                ),
                // The tube itself
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: w,
                  height: h,
                  decoration: BoxDecoration(
                    boxShadow: glowColor != Colors.transparent
                        ? [BoxShadow(
                            color: glowColor.withOpacity(0.6),
                            blurRadius: 18,
                            spreadRadius: 2,
                          )]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(r),
                    child: Stack(
                      children: [
                        // Glass tube background
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            border: Border.all(
                              color: glowColor != Colors.transparent
                                  ? glowColor.withOpacity(0.8)
                                  : Colors.white.withOpacity(0.18),
                              width: glowColor != Colors.transparent ? 2 : 1.5,
                            ),
                            borderRadius: BorderRadius.circular(r),
                          ),
                        ),
                        // Liquid layers - bottom to top
                        Positioned(
                          bottom: 0, left: 0, right: 0,
                          child: _LiquidStack(
                            tube: widget.tube,
                            tubeHeight: h,
                            tubeWidth: w,
                          ),
                        ),
                        // Glass shine highlight (left edge)
                        Positioned(
                          top: h * 0.05,
                          left: w * 0.12,
                          child: Container(
                            width: w * 0.18,
                            height: h * 0.6,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(w * 0.09),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withOpacity(0.35),
                                  Colors.white.withOpacity(0.05),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Top shine dot
                        Positioned(
                          top: h * 0.04,
                          left: w * 0.25,
                          child: Container(
                            width: w * 0.22,
                            height: w * 0.22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),
                        ),
                        // Liquid fill line separators
                        ...List.generate(widget.tube.colors.length - 1, (li) {
                          final segH = h / widget.tube.capacity;
                          final fromBottom = (li + 1) * segH;
                          return Positioned(
                            bottom: fromBottom,
                            left: 2, right: 2,
                            child: Container(
                              height: 1.5,
                              color: Colors.black.withOpacity(0.25),
                            ),
                          );
                        }),
                        // Tube border overlay
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(r),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── ANIMATED LIQUID STACK ────────────────────────────────────────────────────
class _LiquidStack extends StatelessWidget {
  final TubeModel tube;
  final double tubeHeight;
  final double tubeWidth;

  const _LiquidStack({
    required this.tube,
    required this.tubeHeight,
    required this.tubeWidth,
  });

  @override
  Widget build(BuildContext context) {
    if (tube.colors.isEmpty) return const SizedBox.shrink();
    final segH = tubeHeight / tube.capacity;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(tube.colors.length, (i) {
        // Reversed: index 0 is bottom
        final colorIdx = tube.colors[i] % AppColors.liquidColors.length;
        final color = AppColors.liquidColors[colorIdx];
        final isDark = color.computeLuminance() < 0.3;

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
                color.withOpacity(0.8),
                color,
                isDark ? color.withOpacity(0.85) : color.withOpacity(0.9),
              ],
            ),
            boxShadow: i == tube.colors.length - 1
                ? [BoxShadow(
                    color: color.withOpacity(0.5),
                    blurRadius: 6,
                    offset: const Offset(0, -2),
                  )]
                : null,
          ),
          child: i == tube.colors.length - 1
              ? Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: Colors.white.withOpacity(0.4),
                    ),
                  ),
                )
              : null,
        );
      }).reversed.toList(),
    );
  }
}

// ── CONTROLS ─────────────────────────────────────────────────────────────────
class _GameControls extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      child: Row(
        children: [
          Expanded(child: _ControlBtn(
            icon: Icons.refresh_rounded,
            label: 'Restart',
            color: AppColors.neonOrange,
            onTap: () => _showRestartDialog(context),
          )),
          const SizedBox(width: 10),
          Expanded(child: _ControlBtn(
            icon: Icons.undo_rounded,
            label: 'Undo',
            color: AppColors.neonBlue,
            badge: game.undoCount > 0 ? '${game.undoCount}' : null,
            onTap: game.undoCount > 0
                ? () => game.undo()
                : () => _showRewardedForUndo(context),
          )),
          const SizedBox(width: 10),
          Expanded(child: _ControlBtn(
            icon: Icons.lightbulb_outline_rounded,
            label: 'Hint (${game.hints})',
            color: AppColors.neonYellow,
            onTap: game.hints > 0
                ? () => game.useHint()
                : () => _showRewardedForHint(context),
          )),
        ],
      ),
    );
  }

  void _showRestartDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Restart Level?',
            style: TextStyle(fontFamily: 'Poppins',
                color: AppColors.white, fontWeight: FontWeight.w700)),
        content: const Text('Your progress will be lost.',
            style: TextStyle(fontFamily: 'Poppins', color: AppColors.white40)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.white40))),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<GameProvider>().restartLevel();
            },
            child: const Text('Restart',
                style: TextStyle(
                    color: AppColors.neonOrange, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showRewardedForHint(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('No Hints Left 💡',
            style: TextStyle(fontFamily: 'Poppins',
                color: AppColors.white, fontWeight: FontWeight.w700)),
        content: const Text('Watch a short video to earn 3 hints!',
            style: TextStyle(fontFamily: 'Poppins', color: AppColors.white40)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.white40))),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              AdService().showRewarded(
                onRewarded: (_, __) =>
                    context.read<GameProvider>().addHints(3),
                onFailed: () {},
              );
            },
            child: const Text('Watch Ad',
                style: TextStyle(
                    color: AppColors.neonYellow,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showRewardedForUndo(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Nothing to Undo ↩️',
            style: TextStyle(fontFamily: 'Poppins',
                color: AppColors.white, fontWeight: FontWeight.w700)),
        content: const Text('Watch a short video to undo your last move!',
            style: TextStyle(fontFamily: 'Poppins', color: AppColors.white40)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.white40))),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              AdService().showRewarded(
                onRewarded: (_, __) =>
                    context.read<GameProvider>().addUndoFromAd(),
                onFailed: () {},
              );
            },
            child: const Text('Watch Ad',
                style: TextStyle(
                    color: AppColors.neonBlue, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final String? badge;

  const _ControlBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: color.withOpacity(0.12),
              border: Border.all(color: color.withOpacity(0.35), width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 4),
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'Poppins',
                        color: color,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (badge != null)
            Positioned(
              top: -6, right: -6,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                child: Text(badge!,
                    style: const TextStyle(
                        fontSize: 9, color: Colors.white,
                        fontWeight: FontWeight.w800)),
              ),
            ),
        ],
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
        padding: const EdgeInsets.all(28),
        child: GlassCard(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                      color: filled ? AppColors.neonYellow : AppColors.white20,
                      size: 38,
                    )
                        .animate(delay: Duration(milliseconds: 200 + i * 150))
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
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => game.nextLevel(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
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
            ],
          ),
        ),
      ),
    );
  }
}
