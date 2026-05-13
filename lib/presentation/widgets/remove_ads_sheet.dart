import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../services/iap_service.dart';

/// Compact banner shown inline — press opens the full sheet
class RemoveAdsBanner extends StatelessWidget {
  const RemoveAdsBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final iap = context.watch<IapService>();
    if (iap.adsRemoved) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: AppColors.neonGreen.withOpacity(0.08),
          border: Border.all(color: AppColors.neonGreen.withOpacity(0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.block_rounded, color: AppColors.neonGreen, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              iap.removeAdsExpiryLabel ?? 'Ads removed ✓',
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'Poppins',
                color: AppColors.neonGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ]),
      );
    }

    return GestureDetector(
      onTap: () => RemoveAdsSheet.show(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [
              AppColors.neonPurple.withOpacity(0.15),
              AppColors.neonBlue.withOpacity(0.12),
            ],
          ),
          border: Border.all(
              color: AppColors.neonPurple.withOpacity(0.35), width: 1.5),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.gradientPrimary,
            ),
            child:
                const Icon(Icons.block_rounded, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Remove Ads',
                    style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        color: AppColors.white)),
                Text('From \$0.99 — Play without interruptions',
                    style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'Poppins',
                        color: AppColors.white40)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.white40, size: 20),
        ]),
      ),
    );
  }
}

class RemoveAdsSheet extends StatelessWidget {
  const RemoveAdsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: IapService(),
        child: const RemoveAdsSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final iap = context.watch<IapService>();

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      decoration: const BoxDecoration(
        color: Color(0xFF12182E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.white20,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Header
          ShaderMask(
            shaderCallback: (r) => AppColors.gradientPrimary.createShader(r),
            child: const Text('✨ Remove Ads',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Poppins',
                    color: Colors.white)),
          ),
          const SizedBox(height: 6),
          const Text('Enjoy Flowly completely ad-free',
              style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'Poppins',
                  color: AppColors.white40)),
          const SizedBox(height: 28),

          // Plans
          if (iap.products.isEmpty && !iap.available) ...[
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Store unavailable on this device.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'Poppins', color: AppColors.white40)),
            ),
          ] else if (iap.products.isEmpty) ...[
            const SizedBox(
                height: 40,
                child: CircularProgressIndicator(
                    color: AppColors.neonBlue, strokeWidth: 2)),
          ] else ...[
            ...iap.products.map((product) => _PlanTile(product: product)),
          ],

          const SizedBox(height: 16),

          // Restore
          GestureDetector(
            onTap: () => iap.restorePurchases(),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Restore Purchases',
                  style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Poppins',
                      color: AppColors.white40,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.white40)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  final dynamic product;
  const _PlanTile({required this.product});

  String get _label {
    switch (product.id) {
      case AppConstants.iapRemoveAds1Day:   return '1 Day';
      case AppConstants.iapRemoveAds1Week:  return '1 Week';
      case AppConstants.iapRemoveAds1Month: return '1 Month';
      default: return product.title;
    }
  }

  String get _sublabel {
    switch (product.id) {
      case AppConstants.iapRemoveAds1Day:   return 'Try it out';
      case AppConstants.iapRemoveAds1Week:  return 'Best value short-term';
      case AppConstants.iapRemoveAds1Month: return '🔥 Most popular';
      default: return '';
    }
  }

  bool get _isPopular => product.id == AppConstants.iapRemoveAds1Month;

  @override
  Widget build(BuildContext context) {
    final iap = context.watch<IapService>();

    return GestureDetector(
      onTap: iap.purchasing ? null : () => iap.buyProduct(product),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: _isPopular
              ? LinearGradient(colors: [
                  AppColors.neonPurple.withOpacity(0.2),
                  AppColors.neonBlue.withOpacity(0.15),
                ])
              : null,
          color: _isPopular ? null : AppColors.white10,
          border: Border.all(
            color: _isPopular
                ? AppColors.neonPurple.withOpacity(0.5)
                : AppColors.white20,
            width: _isPopular ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_label,
                  style: const TextStyle(
                      fontSize: 15,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      color: AppColors.white)),
              if (_sublabel.isNotEmpty)
                Text(_sublabel,
                    style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'Poppins',
                        color: _isPopular
                            ? AppColors.neonPurple
                            : AppColors.white40)),
            ]),
          ),
          if (iap.purchasing)
            const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.neonBlue))
          else
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: _isPopular ? AppColors.gradientPrimary : null,
                color: _isPopular ? null : AppColors.white20,
              ),
              child: Text(product.price,
                  style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      color:
                          _isPopular ? Colors.white : AppColors.white)),
            ),
        ]),
      ),
    );
  }
}
