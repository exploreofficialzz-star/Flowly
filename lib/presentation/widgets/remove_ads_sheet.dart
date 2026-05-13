import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../services/iap_service.dart';

// ── Inline banner ──────────────────────────────────────────────────────────────
class RemoveAdsBanner extends StatelessWidget {
  const RemoveAdsBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final iap = context.watch<IapService>();

    // Already purchased — show expiry confirmation
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
          const Icon(Icons.check_circle_rounded,
              color: AppColors.neonGreen, size: 16),
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

    // Not purchased — show upsell banner
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
            child: const Icon(Icons.block_rounded,
                color: Colors.white, size: 14),
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

// ── Bottom sheet ───────────────────────────────────────────────────────────────
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
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.white20,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Header
          ShaderMask(
            shaderCallback: (r) =>
                AppColors.gradientPrimary.createShader(r),
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

          // Plans — always render using store prices when loaded,
          // fallback to static prices when store hasn't responded yet.
          // This prevents the spinner-only state seen in the screenshots.
          if (!iap.available) ...[
            _UnavailableNote(),
          ] else ...[
            _PlanTile(
              productId: AppConstants.iapRemoveAds1Day,
              storeProduct: iap.productById(AppConstants.iapRemoveAds1Day),
              iap: iap,
            ),
            _PlanTile(
              productId: AppConstants.iapRemoveAds1Week,
              storeProduct: iap.productById(AppConstants.iapRemoveAds1Week),
              iap: iap,
            ),
            _PlanTile(
              productId: AppConstants.iapRemoveAds1Month,
              storeProduct: iap.productById(AppConstants.iapRemoveAds1Month),
              iap: iap,
              isPopular: true,
            ),
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

// ── Plan tile — shows store price when available, static price as fallback ─────
class _PlanTile extends StatelessWidget {
  final String productId;
  final dynamic storeProduct; // ProductDetails? from IAP
  final IapService iap;
  final bool isPopular;

  const _PlanTile({
    required this.productId,
    required this.storeProduct,
    required this.iap,
    this.isPopular = false,
  });

  String get _label {
    switch (productId) {
      case AppConstants.iapRemoveAds1Day:   return '1 Day';
      case AppConstants.iapRemoveAds1Week:  return '1 Week';
      case AppConstants.iapRemoveAds1Month: return '1 Month';
      default: return productId;
    }
  }

  String get _sublabel {
    switch (productId) {
      case AppConstants.iapRemoveAds1Day:   return 'Try it out';
      case AppConstants.iapRemoveAds1Week:  return 'Best value short-term';
      case AppConstants.iapRemoveAds1Month: return '🔥 Most popular';
      default: return '';
    }
  }

  /// Display price: real store price if loaded, else static fallback.
  String get _displayPrice =>
      storeProduct?.price ??
      AppConstants.iapFallbackPrices[productId] ??
      '—';

  /// Whether we can actually process a purchase right now.
  bool get _canBuy => storeProduct != null && !iap.purchasing;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _canBuy ? () => iap.buyProduct(storeProduct) : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: storeProduct == null ? 0.65 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: isPopular
                ? LinearGradient(colors: [
                    AppColors.neonPurple.withOpacity(0.20),
                    AppColors.neonBlue.withOpacity(0.15),
                  ])
                : null,
            color: isPopular ? null : AppColors.white10,
            border: Border.all(
              color: isPopular
                  ? AppColors.neonPurple.withOpacity(0.50)
                  : AppColors.white20,
              width: isPopular ? 1.5 : 1.0,
            ),
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                            color: isPopular
                                ? AppColors.neonPurple
                                : AppColors.white40)),
                ],
              ),
            ),
            // Show spinner only while a purchase is actively processing
            if (iap.purchasing && storeProduct != null)
              const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.neonBlue),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: isPopular ? AppColors.gradientPrimary : null,
                  color: isPopular ? null : AppColors.white20,
                ),
                child: Text(
                  _displayPrice,
                  style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      color: isPopular ? Colors.white : AppColors.white),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class _UnavailableNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        'In-app purchases are not available\non this device.',
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontFamily: 'Poppins',
            color: AppColors.white40,
            fontSize: 13),
      ),
    );
  }
}
