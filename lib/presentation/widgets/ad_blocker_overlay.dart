import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../services/ad_block_service.dart';
import '../../services/iap_service.dart';
import 'remove_ads_sheet.dart';

/// Drop this into the MaterialApp builder stack.
/// Renders a full-screen blocking overlay when an ad blocker is detected
/// AND the user has not purchased a Remove Ads plan.
/// Premium users (adsRemoved == true) bypass this entirely.
class AdBlockerGate extends StatefulWidget {
  const AdBlockerGate({super.key});

  @override
  State<AdBlockerGate> createState() => _AdBlockerGateState();
}

class _AdBlockerGateState extends State<AdBlockerGate>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _retry() async {
    if (_checking) return;
    setState(() => _checking = true);
    await AdBlockService().recheck();
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    final adBlock = context.watch<AdBlockService>();
    final iap = context.watch<IapService>();

    // Premium users are completely exempt from this overlay
    if (!adBlock.adBlocked || iap.adsRemoved) return const SizedBox.shrink();

    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: AbsorbPointer(
          absorbing: true,
          child: GestureDetector(
            // Swallow all gestures so nothing beneath is tappable
            onTap: () {},
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0A0E23).withOpacity(0.98),
                    const Color(0xFF120A20).withOpacity(0.99),
                  ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated shield icon
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, __) => Transform.scale(
                        scale: 0.93 + 0.07 * _pulse.value,
                        child: Container(
                          width: 104,
                          height: 104,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.neonOrange.withOpacity(0.10),
                            border: Border.all(
                              color: AppColors.neonOrange
                                  .withOpacity(0.35 + 0.45 * _pulse.value),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.neonOrange
                                    .withOpacity(0.22 * _pulse.value),
                                blurRadius: 32,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.shield_outlined,
                            color: AppColors.neonOrange,
                            size: 50,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Title
                    const Text(
                      'Ad Blocker Detected',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Poppins',
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Body
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 36),
                      child: Text(
                        'Flowly is free because of ads.\n'
                        'Please disable your ad blocker for this app,\n'
                        'or go ad-free with a premium plan.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'Poppins',
                          color: AppColors.white40,
                          height: 1.65,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // ── Enable Ads ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: AbsorbPointer(
                        absorbing: false,
                        child: GestureDetector(
                          onTap: _checking ? null : _retry,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFF8C00),
                                  Color(0xFFFFE600),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.neonOrange.withOpacity(0.40),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                            child: _checking
                                ? const Center(
                                    child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.black87,
                                        strokeWidth: 2.5,
                                      ),
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check_circle_outline_rounded,
                                          color: Colors.black87, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        "I've Enabled Ads",
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          fontFamily: 'Poppins',
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Go Ad-Free (IAP) ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: AbsorbPointer(
                        absorbing: false,
                        child: GestureDetector(
                          onTap: () => RemoveAdsSheet.show(context),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: AppColors.white10,
                              border: Border.all(
                                  color: AppColors.neonPurple.withOpacity(0.45),
                                  width: 1.5),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.workspace_premium_rounded,
                                    color: AppColors.neonPurple, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Go Ad-Free — from \$0.99',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Poppins',
                                    color: AppColors.neonPurple,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Fine-print
                    const Text(
                      'Flowly cannot run with ads blocked.',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'Poppins',
                        color: AppColors.white20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
