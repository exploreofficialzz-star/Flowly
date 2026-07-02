import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../services/ad_block_service.dart';
import '../../services/iap_service.dart';
import 'remove_ads_sheet.dart';

/// Full-screen blocking overlay shown when an ad blocker is detected.
/// Premium users (adsRemoved == true) are completely exempt.
/// Sits in MaterialApp.builder stack above all routes.
class AdBlockerGate extends StatefulWidget {
  const AdBlockerGate({super.key});
  @override
  State<AdBlockerGate> createState() => _AdBlockerGateState();
}

class _AdBlockerGateState extends State<AdBlockerGate>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  bool _checking = false;
  bool _justChecked = false; // shows brief "Checking…" → "Still blocked" feedback

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    // Not started here — build() starts/stops it based on whether the
    // gate is actually visible, so it never ticks while hidden (the
    // overwhelming majority of the time, for the overwhelming majority
    // of users who don't have an ad blocker active).
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _retry() async {
    if (_checking) return;
    setState(() {
      _checking    = true;
      _justChecked = false;
    });
    await AdBlockService().recheck();
    if (mounted) {
      setState(() {
        _checking    = false;
        _justChecked = true;
      });
      // Clear "still blocked" message after 2.5 s
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted) setState(() => _justChecked = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final adBlock = context.watch<AdBlockService>();
    final iap     = context.watch<IapService>();

    final willShow = adBlock.adBlocked && !iap.adsRemoved;

    // Only tick the pulse animation while this gate is actually rendering
    // something. Left unconditional, it burns a per-frame Ticker for the
    // entire app lifetime on every screen for the near-totality of users
    // who never trigger this overlay at all.
    if (willShow && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!willShow && _pulse.isAnimating) {
      _pulse.stop();
    }

    // Premium — completely bypass
    if (!willShow) return const SizedBox.shrink();

    return Positioned.fill(
      child: Material(
        type: MaterialType.transparency,
        child: GestureDetector(
          onTap: () {},
          onPanUpdate: (_) {},
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end:   Alignment.bottomCenter,
                colors: [
                  const Color(0xFF060A1A).withOpacity(0.97),
                  const Color(0xFF120A20).withOpacity(0.99),
                ],
              ),
            ),
            child: AbsorbPointer(
              // Absorb everything EXCEPT the two action buttons below
              absorbing: false,
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ── Animated shield ──────────────────────────────────
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, __) => Transform.scale(
                        scale: 0.93 + 0.07 * _pulse.value,
                        child: Container(
                          width: 108, height: 108,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.neonOrange.withOpacity(0.10),
                            border: Border.all(
                              color: AppColors.neonOrange.withOpacity(
                                  0.35 + 0.45 * _pulse.value),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.neonOrange
                                    .withOpacity(0.22 * _pulse.value),
                                blurRadius: 36,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.shield_outlined,
                            color: AppColors.neonOrange,
                            size: 52,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Title ────────────────────────────────────────────
                    const Text(
                      'Ad Blocker Detected',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Poppins',
                        color: AppColors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Body ─────────────────────────────────────────────
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
                    const SizedBox(height: 12),

                    // ── Feedback line (still blocked / checking) ─────────
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _checking
                          ? _statusPill('Checking…', AppColors.neonBlue,
                              Icons.sync_rounded, spinning: true)
                          : _justChecked
                              ? _statusPill('Still blocked', AppColors.neonRed,
                                  Icons.close_rounded)
                              : const SizedBox(height: 20),
                    ),

                    const SizedBox(height: 28),

                    // ── "I've Enabled Ads" button ─────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: GestureDetector(
                        onTap: _checking ? null : _retry,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: _checking ? 0.6 : 1.0,
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
                                      width: 22, height: 22,
                                      child: CircularProgressIndicator(
                                          color: Colors.black87,
                                          strokeWidth: 2.5),
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
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

                    // ── "Go Ad-Free" IAP button ───────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
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
                    const SizedBox(height: 28),

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

  Widget _statusPill(String text, Color color, IconData icon,
      {bool spinning = false}) {
    return Container(
      key: ValueKey(text),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: color.withOpacity(0.10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        spinning
            ? SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(
                    color: color, strokeWidth: 2))
            : Icon(icon, color: color, size: 14),
        const SizedBox(width: 8),
        Text(text,
            style: TextStyle(
                fontSize: 12,
                fontFamily: 'Poppins',
                color: color,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
