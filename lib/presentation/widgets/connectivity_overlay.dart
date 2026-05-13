import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../services/connectivity_service.dart';

/// Stand-alone gate — place in MaterialApp.builder Stack ABOVE all other layers.
/// Blocks ALL users (including premium) whenever the device has no internet or
/// no real data. Disappears automatically the moment connectivity restores.
/// No child, no wrapper — reads ConnectivityService from the ancestor provider.
class ConnectivityGate extends StatefulWidget {
  const ConnectivityGate({super.key});

  @override
  State<ConnectivityGate> createState() => _ConnectivityGateState();
}

class _ConnectivityGateState extends State<ConnectivityGate>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

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

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<ConnectivityService>();

    // Fully transparent when connected — zero cost, zero interference
    if (svc.isConnected) return const SizedBox.shrink();

    final isNoInternet = svc.hasNoInternet;
    final accent = isNoInternet ? AppColors.neonRed : AppColors.neonOrange;

    return Positioned.fill(
      child: Material(
        // Raise above everything — dialogs, bottom sheets, game overlays
        type: MaterialType.transparency,
        child: AbsorbPointer(
          absorbing: true,
          child: GestureDetector(
            onTap: () {},
            onPanUpdate: (_) {},
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF060A1A).withOpacity(0.97),
                    const Color(0xFF0B1020).withOpacity(0.99),
                  ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ── Pulsing icon ──────────────────────────────────────
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, __) => Transform.scale(
                        scale: 0.92 + 0.08 * _pulse.value,
                        child: Container(
                          width: 104,
                          height: 104,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accent.withOpacity(0.10),
                            border: Border.all(
                              color: accent.withOpacity(
                                  0.35 + 0.45 * _pulse.value),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withOpacity(
                                    0.22 * _pulse.value),
                                blurRadius: 36,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Icon(
                            isNoInternet
                                ? Icons.wifi_off_rounded
                                : Icons.signal_wifi_bad_rounded,
                            color: accent,
                            size: 50,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Title ─────────────────────────────────────────────
                    Text(
                      isNoInternet
                          ? 'Internet Connection Lost'
                          : 'No Data Connection',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Poppins',
                        color: AppColors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── Message ───────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 38),
                      child: Text(
                        isNoInternet
                            ? 'You\'re offline.\nConnect to the internet to keep playing Flowly.'
                            : 'You\'re connected but there\'s no data.\n'
                                'Check your WiFi signal or mobile data plan.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontFamily: 'Poppins',
                          color: AppColors.white40,
                          height: 1.65,
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),

                    // ── Live status pill ──────────────────────────────────
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, __) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 11),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          color: AppColors.white10,
                          border: Border.all(color: AppColors.white20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: accent.withOpacity(
                                    0.5 + 0.5 * _pulse.value),
                              ),
                            ),
                            const SizedBox(width: 9),
                            const Text(
                              'Waiting for connection…',
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'Poppins',
                                color: AppColors.white40,
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
        ),
      ),
    );
  }
}
