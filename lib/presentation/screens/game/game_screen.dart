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
    _loadBanner();
  }

  void _loadBanner() {
    final ad = AdService().createBanner();
    ad.load().then((_) {
      if (mounted) setState(() { _banner = ad; _bannerLoaded = true; });
    });
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

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(world['bgColor'] as int), AppColors.bg],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _GameHeader(worldColor: worldColor, worldName: world['name'] as String),
              Expanded(child: _GameBoard()),
              _GameControls(),
              // Banner ad at bottom
              if (_bannerLoaded && _banner != null)
                Container(
                  height: _banner!.size.height.toDouble(),
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

class _GameHeader extends StatelessWidget {
  final Color worldColor;
  final String worldName;
  const _GameHeader({required this.worldColor, required this.worldName});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
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
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.white, size: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  worldName,
                  style: TextStyle(fontSize: 13, fontFamily: 'Poppins', color: AppColors.white40),
                ),
                Text(
                  'Level ${game.currentLevelInWorld + 1}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins',
                    color: worldColor,
                  ),
                ),
              ],
            ),
          ),
          // Moves counter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AppColors.white10,
              border: Border.all(color: AppColors.white20),
            ),
            child: Row(
              children: [
                const Icon(Icons.swap_vert_rounded, color: AppColors.white40, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${game.moves}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins',
                    color: AppColors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GameBoard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    final tubes = game.tubes;
    final sz = MediaQuery.of(context).size;

    if (game.status == GameStatus.won) {
      return _WinOverlay();
    }

    // Layout: responsive tube sizing
    final count = tubes.length;
    final crossCount = count <= 6 ? 3 : 4;
    final tubeWidth = (sz.width - 48 - (crossCount - 1) * 12) / crossCount;
    final tubeHeight = tubeWidth * 2.8;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossCount,
          childAspectRatio: tubeWidth / (tubeHeight + 40),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: tubes.length,
        itemBuilder: (context, i) {
          return _TubeWidget(
            tube: tubes[i],
            index: i,
            isHintFrom: game.isHinting && game.hintFrom == i,
            isHintTo: game.isHinting && game.hintTo == i,
            tubeWidth: tubeWidth,
            tubeHeight: tubeHeight,
          );
        },
      ),
    );
  }
}

class _TubeWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final game = context.read<GameProvider>();
    final isSelected = tube.isSelected;

    Color borderColor = Colors.white.withOpacity(0.15);
    if (isSelected) borderColor = AppColors.neonBlue;
    if (isHintFrom) borderColor = AppColors.neonYellow;
    if (isHintTo) borderColor = AppColors.neonGreen;
    if (tube.isCompleted) borderColor = AppColors.neonGreen;

    return GestureDetector(
      onTap: () => game.selectTube(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(0, isSelected ? -10 : 0, 0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Tube body
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: tubeWidth,
              height: tubeHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(tubeWidth / 2),
                border: Border.all(
                  color: borderColor,
                  width: isSelected || isHintFrom || isHintTo ? 2.5 : 1.5,
                ),
                color: Colors.white.withOpacity(0.04),
                boxShadow: isSelected || tube.isCompleted
                    ? [BoxShadow(color: borderColor.withOpacity(0.4), blurRadius: 16)]
                    : null,
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Liquid layers (bottom to top in display = reversed list)
                  ...List.generate(tube.colors.length, (li) {
                    final ci = tube.colors[li];
                    final color = AppColors.liquidColors[ci % AppColors.liquidColors.length];
                    final h = tubeHeight / tube.capacity;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: double.infinity,
                      height: h,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [color.withOpacity(0.85), color, color.withOpacity(0.9)],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            // Hint arrow below tube
            if (isHintFrom || isHintTo)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Icon(
                  isHintFrom ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  color: isHintFrom ? AppColors.neonYellow : AppColors.neonGreen,
                  size: 16,
                ).animate().fadeIn().scale(),
              ),
          ],
        ),
      ),
    );
  }
}

class _GameControls extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ControlBtn(
            icon: Icons.refresh_rounded,
            label: 'Restart',
            color: AppColors.neonOrange,
            onTap: () => _showRestartDialog(context),
          ),
          _ControlBtn(
            icon: Icons.undo_rounded,
            label: 'Undo',
            color: AppColors.neonBlue,
            badge: game.undoCount > 0 ? '${game.undoCount}' : null,
            onTap: game.undoCount > 0
                ? () => game.undo()
                : () => _showRewardedForUndo(context),
          ),
          _ControlBtn(
            icon: Icons.lightbulb_outline_rounded,
            label: 'Hint (${game.hints})',
            color: AppColors.neonYellow,
            onTap: game.hints > 0
                ? () => game.useHint()
                : () => _showRewardedForHint(context),
          ),
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
        title: const Text('Restart Level?', style: TextStyle(fontFamily: 'Poppins', color: AppColors.white, fontWeight: FontWeight.w700)),
        content: const Text('Your progress on this level will be lost.', style: TextStyle(fontFamily: 'Poppins', color: AppColors.white40)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: AppColors.white40))),
          TextButton(
            onPressed: () { Navigator.pop(context); context.read<GameProvider>().restartLevel(); },
            child: const Text('Restart', style: TextStyle(color: AppColors.neonOrange, fontWeight: FontWeight.w700)),
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
        title: const Text('No Hints Left 💡', style: TextStyle(fontFamily: 'Poppins', color: AppColors.white, fontWeight: FontWeight.w700)),
        content: const Text('Watch a short video to earn 3 hints!', style: TextStyle(fontFamily: 'Poppins', color: AppColors.white40)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: AppColors.white40))),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              AdService().showRewarded(
                onRewarded: (_, __) => context.read<GameProvider>().addHints(3),
                onFailed: () {},
              );
            },
            child: const Text('Watch Ad', style: TextStyle(color: AppColors.neonYellow, fontWeight: FontWeight.w700)),
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
        title: const Text('Nothing to Undo ↩️', style: TextStyle(fontFamily: 'Poppins', color: AppColors.white, fontWeight: FontWeight.w700)),
        content: const Text('Watch a short video to get a free undo move!', style: TextStyle(fontFamily: 'Poppins', color: AppColors.white40)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: AppColors.white40))),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              AdService().showRewarded(
                onRewarded: (_, __) => context.read<GameProvider>().addUndoFromAd(),
                onFailed: () {},
              );
            },
            child: const Text('Watch Ad', style: TextStyle(color: AppColors.neonBlue, fontWeight: FontWeight.w700)),
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

  const _ControlBtn({required this.icon, required this.label, required this.color, required this.onTap, this.badge});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: color.withOpacity(0.12),
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 4),
                Text(label, style: TextStyle(fontSize: 11, fontFamily: 'Poppins', color: color, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (badge != null)
            Positioned(
              top: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                child: Text(badge!, style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
    );
  }
}

class _WinOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Show interstitial after win
      AdService().showInterstitial(onDismissed: () {});
    });

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: GlassCard(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 56))
                  .animate().scale(duration: 600.ms, curve: Curves.elasticOut),
              const SizedBox(height: 12),
              const Text(
                'Level Complete!',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Poppins',
                  color: AppColors.white,
                ),
              ),
              const SizedBox(height: 8),
              // Stars
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  final filled = i < game.stars;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      filled ? Icons.star_rounded : Icons.star_border_rounded,
                      color: filled ? AppColors.neonYellow : AppColors.white20,
                      size: 40,
                    ).animate(delay: Duration(milliseconds: 200 + i * 150))
                        .scale(duration: 400.ms, curve: Curves.elasticOut),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Text(
                '${game.moves} moves',
                style: const TextStyle(
                  fontSize: 14, fontFamily: 'Poppins', color: AppColors.white40,
                ),
              ),
              const SizedBox(height: 28),
              // Next level button
              GestureDetector(
                onTap: () => game.nextLevel(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: AppColors.gradientPrimary,
                    boxShadow: [BoxShadow(color: AppColors.neonBlue.withOpacity(0.4), blurRadius: 20)],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Next Level', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, fontFamily: 'Poppins', color: Colors.white)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, color: Colors.white),
                    ],
                  ),
                ),
              ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.3),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => game.restartLevel(),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'Replay Level',
                    style: TextStyle(fontSize: 14, fontFamily: 'Poppins', color: AppColors.white40),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
