import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../services/iap_service.dart';
import '../../services/paystack_service.dart';

// ── Inline banner ──────────────────────────────────────────────────────────────
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

    return GestureDetector(
      onTap: () => RemoveAdsSheet.show(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(colors: [
            AppColors.neonPurple.withOpacity(0.15),
            AppColors.neonBlue.withOpacity(0.12),
          ]),
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
class RemoveAdsSheet extends StatefulWidget {
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
  State<RemoveAdsSheet> createState() => _RemoveAdsSheetState();
}

class _RemoveAdsSheetState extends State<RemoveAdsSheet> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pop sheet automatically when purchase succeeds
    final iap = context.read<IapService>();
    if (iap.adsRemoved && Navigator.canPop(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final iap = context.watch<IapService>();

    // Show error snackbar when a purchase fails
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (iap.purchaseState == IapPurchaseState.error &&
          iap.purchaseError != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(iap.purchaseError!,
              style: const TextStyle(fontFamily: 'Poppins')),
          backgroundColor: AppColors.neonRed,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {
              iap.clearError();
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ));
      }
    });

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
          const SizedBox(height: 20),

          // Pending banner
          if (iap.purchaseState == IapPurchaseState.pending)
            _PendingBanner(),

          const SizedBox(height: 8),

          // Plans — routed by install source
          if (!iap.available && iap.isPlayStore)
            _UnavailableNote()
          else if (!iap.isPlayStore) ...[
            // ── Paystack (sideloaded install) ─────────────────────────────────
            // Show USD prices (same as Play Store). Paystack's own payment
            // screen will display the equivalent NGN amount automatically.
            _PaystackPlanTile(productId: AppConstants.iapRemoveAds1Day,
                label: '1 Day',   usdPrice: '\$0.99', sublabel: 'Try it out', iap: iap),
            _PaystackPlanTile(productId: AppConstants.iapRemoveAds1Week,
                label: '1 Week',  usdPrice: '\$2.99', sublabel: 'Best value short-term', iap: iap),
            _PaystackPlanTile(productId: AppConstants.iapRemoveAds1Month,
                label: '1 Month', usdPrice: '\$8.99', sublabel: '🔥 Most popular',
                iap: iap, isPopular: true),
            _PaystackPlanTile(productId: 'remove_ads_perm',
                label: 'Forever', usdPrice: '\$4.99', sublabel: 'One-time · Never expires', iap: iap),
            const SizedBox(height: 6),
            const Text('Paid securely via Paystack · Price shown in NGN on payment screen',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, fontFamily: 'Poppins',
                    color: AppColors.white20)),
          ] else ...[
            // ── Google Play IAP ───────────────────────────────────────────────
            _PlanTile(productId: AppConstants.iapRemoveAds1Day,
                storeProduct: iap.productById(AppConstants.iapRemoveAds1Day), iap: iap),
            _PlanTile(productId: AppConstants.iapRemoveAds1Week,
                storeProduct: iap.productById(AppConstants.iapRemoveAds1Week), iap: iap),
            _PlanTile(productId: AppConstants.iapRemoveAds1Month,
                storeProduct: iap.productById(AppConstants.iapRemoveAds1Month),
                iap: iap, isPopular: true),
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

          const SizedBox(height: 6),
          const Text(
            'Purchases are time-limited and renew manually.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 10, fontFamily: 'Poppins', color: AppColors.white20),
          ),
        ],
      ),
    );
  }
}

// ── Pending banner ─────────────────────────────────────────────────────────────
class _PendingBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.neonBlue.withOpacity(0.08),
        border:
            Border.all(color: AppColors.neonBlue.withOpacity(0.35)),
      ),
      child: const Row(children: [
        SizedBox(
          width: 16, height: 16,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.neonBlue),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Payment is being processed…\nThis may take a moment.',
            style: TextStyle(
                fontSize: 12,
                fontFamily: 'Poppins',
                color: AppColors.neonBlue,
                height: 1.5),
          ),
        ),
      ]),
    );
  }
}

// ── Plan tile ──────────────────────────────────────────────────────────────────
class _PlanTile extends StatelessWidget {
  final String productId;
  final dynamic storeProduct;
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
      default:                              return productId;
    }
  }

  String get _sublabel {
    switch (productId) {
      case AppConstants.iapRemoveAds1Day:   return 'Try it out';
      case AppConstants.iapRemoveAds1Week:  return 'Best value short-term';
      case AppConstants.iapRemoveAds1Month: return '🔥 Most popular';
      default:                              return '';
    }
  }

  String get _displayPrice =>
      storeProduct?.price ??
      AppConstants.iapFallbackPrices[productId] ??
      '—';

  bool get _canBuy =>
      storeProduct != null &&
      iap.purchaseState == IapPurchaseState.idle;

  @override
  Widget build(BuildContext context) {
    final isActivelyBuying = iap.purchasing && storeProduct != null;

    return GestureDetector(
      onTap: _canBuy ? () => iap.buyProduct(storeProduct) : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: (!_canBuy && !isActivelyBuying) ? 0.6 : 1.0,
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
            isActivelyBuying
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.neonBlue))
                : Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient:
                          isPopular ? AppColors.gradientPrimary : null,
                      color: isPopular ? null : AppColors.white20,
                    ),
                    child: Text(
                      _displayPrice,
                      style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                          color:
                              isPopular ? Colors.white : AppColors.white),
                    ),
                  ),
          ]),
        ),
      ),
    );
  }
}

// ── Paystack plan tile (sideloaded installs) ──────────────────────────────────
class _PaystackPlanTile extends StatefulWidget {
  final String     productId, label, sublabel, usdPrice;
  final IapService iap;
  final bool       isPopular;

  const _PaystackPlanTile({
    required this.productId,
    required this.label,
    required this.sublabel,
    required this.usdPrice,
    required this.iap,
    this.isPopular = false,
  });

  @override
  State<_PaystackPlanTile> createState() => _PaystackPlanTileState();
}

class _PaystackPlanTileState extends State<_PaystackPlanTile> {
  bool _loading = false;

  Future<void> _pay() async {
    setState(() => _loading = true);
    try {
      final ok = await PaystackService().checkout(
        context:   context,
        productId: widget.productId,
      );
      if (ok && mounted) {
        await widget.iap.grantPaystackPurchase(widget.productId);
        if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show the same USD price as Play Store; Paystack shows NGN on its own screen
    final price = widget.usdPrice;

    return GestureDetector(
      onTap: _loading ? null : _pay,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: widget.isPopular
              ? LinearGradient(colors: [
                  AppColors.neonPurple.withOpacity(0.20),
                  AppColors.neonBlue.withOpacity(0.15),
                ])
              : null,
          color:  widget.isPopular ? null : AppColors.white10,
          border: Border.all(
            color: widget.isPopular
                ? AppColors.neonPurple.withOpacity(0.50)
                : AppColors.white20,
            width: widget.isPopular ? 1.5 : 1.0,
          ),
        ),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.label,
                    style: const TextStyle(
                        fontSize: 15, fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700, color: AppColors.white)),
                if (widget.sublabel.isNotEmpty)
                  Text(widget.sublabel,
                      style: TextStyle(
                          fontSize: 11, fontFamily: 'Poppins',
                          color: widget.isPopular
                              ? AppColors.neonPurple
                              : AppColors.white40)),
              ],
            ),
          ),
          _loading
              ? const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.neonBlue))
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: widget.isPopular ? AppColors.gradientPrimary : null,
                    color:    widget.isPopular ? null : AppColors.white20,
                  ),
                  child: Text(price,
                      style: TextStyle(
                          fontSize: 13, fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                          color: widget.isPopular ? Colors.white : AppColors.white)),
                ),
        ]),
      ),
    );
  }
}

class _UnavailableNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'In-app purchases are not\navailable on this device.',
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontFamily: 'Poppins',
              color: AppColors.white40,
              fontSize: 13),
        ),
      );
}
