import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double borderRadius;
  final Gradient? gradient;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 20,
    this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary caches this card's blurred shadow as its own
    // compositing layer. Without it, every card's BoxShadow blur gets
    // re-rasterized on every single frame while an ancestor scrolls —
    // with several GlassCards visible at once (as on the home screen),
    // that repeated blur work on every scroll frame is exactly what
    // causes scrolling to stutter/hang. The card is now painted once
    // and reused; scrolling just repositions the cached bitmap.
    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: gradient,
            color: gradient == null ? AppColors.bgCard : null,
            border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
