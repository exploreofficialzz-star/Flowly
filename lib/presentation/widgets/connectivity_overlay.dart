import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../services/connectivity_service.dart';

/// Stand-alone gate — sits in MaterialApp.builder Stack above all routes.
///
/// States:
///   noInternet → RED   fully blocking, no dismiss
///   noData     → ORANGE fully blocking, no dismiss
///   weak       → AMBER  blocking with "Play Anyway" dismiss option
///   connected  → invisible (SizedBox.shrink)
class ConnectivityGate extends StatefulWidget {
  const ConnectivityGate({super.key});
  @override
  State<ConnectivityGate> createState() => _ConnectivityGateState();
}

class _ConnectivityGateState extends State<ConnectivityGate>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  // Tracks whether the user dismissed the WEAK overlay this session.
  // Auto-resets when state improves to connected then drops again.
  bool _weakDismissed = false;
  NetworkState? _lastState;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    // Not started here — build() starts/stops it based on whether the
    // gate is actually visible, so it never ticks while hidden.
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<ConnectivityService>();

    // When connection fully recovers, reset the weak-dismiss flag so the
    // warning reappears if the signal drops again later.
    if (svc.isConnected && _weakDismissed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _weakDismissed = false);
      });
    }

    final willShow = !svc.isConnected && !(svc.isWeak && _weakDismissed);

    // The pulse animation only needs to tick while something is actually
    // on screen. Left running unconditionally, this ticks every frame for
    // the entire app lifetime — on every screen, whether connected or not,
    // which is the overwhelming majority of the time. Stopping it here
    // removes that per-frame cost during normal (connected) play.
    if (willShow && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!willShow && _pulse.isAnimating) {
      _pulse.stop();
    }

    // Nothing to show
    if (!willShow) return const SizedBox.shrink();

    return Positioned.fill(
      child: Material(
        type: MaterialType.transparency,
        child: GestureDetector(
          onTap: () {},
          onPanUpdate: (_) {},
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: _OverlayContent(
              key: ValueKey(svc.state),
              state: svc.state,
              pulse: _pulse,
              onDismissWeak: () => setState(() => _weakDismissed = true),
            ),
          ),
        ),
      ),
    );
  }
}

class _OverlayContent extends StatelessWidget {
  final NetworkState state;
  final AnimationController pulse;
  final VoidCallback onDismissWeak;

  const _OverlayContent({
    super.key,
    required this.state,
    required this.pulse,
    required this.onDismissWeak,
  });

  // ── Per-state theming ──────────────────────────────────────────────────────
  Color get _accent {
    switch (state) {
      case NetworkState.noInternet: return AppColors.neonRed;
      case NetworkState.noData:     return AppColors.neonOrange;
      case NetworkState.weak:       return const Color(0xFFFFD600); // amber
      default:                      return AppColors.neonGreen;
    }
  }

  IconData get _icon {
    switch (state) {
      case NetworkState.noInternet: return Icons.wifi_off_rounded;
      case NetworkState.noData:     return Icons.signal_wifi_bad_rounded;
      case NetworkState.weak:       return Icons.network_check_rounded;
      default:                      return Icons.wifi_rounded;
    }
  }

  String get _title {
    switch (state) {
      case NetworkState.noInternet: return 'Internet Connection Lost';
      case NetworkState.noData:     return 'No Data Connection';
      case NetworkState.weak:       return 'Weak Connection';
      default:                      return '';
    }
  }

  String get _message {
    switch (state) {
      case NetworkState.noInternet:
        return 'You\'re offline.\nConnect to the internet to keep playing Flowly.';
      case NetworkState.noData:
        return 'Your device is connected but no data is flowing.\n'
            'Check your WiFi signal, mobile data plan,\nor captive portal login.';
      case NetworkState.weak:
        return 'Your connection is slow or unstable.\n'
            'Ads may not load and gameplay could be affected.';
      default:
        return '';
    }
  }

  bool get _isFullyBlocking => state != NetworkState.weak;

  @override
  Widget build(BuildContext context) {
    final Color bgTop = state == NetworkState.weak
        ? const Color(0xFF110D00).withOpacity(0.96)
        : const Color(0xFF060A1A).withOpacity(0.97);
    final Color bgBot = state == NetworkState.weak
        ? const Color(0xFF1A1000).withOpacity(0.98)
        : const Color(0xFF0B1020).withOpacity(0.99);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end:   Alignment.bottomCenter,
          colors: [bgTop, bgBot],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Pulsing icon ───────────────────────────────────────────────
            AnimatedBuilder(
              animation: pulse,
              builder: (_, __) => Transform.scale(
                scale: 0.92 + 0.08 * pulse.value,
                child: Container(
                  width: 108, height: 108,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _accent.withOpacity(0.10),
                    border: Border.all(
                      color: _accent.withOpacity(
                          0.35 + 0.45 * pulse.value),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _accent.withOpacity(0.22 * pulse.value),
                        blurRadius: 40,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(_icon, color: _accent, size: 52),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // ── Signal bars (weak only) ───────────────────────────────────
            if (state == NetworkState.weak) ...[
              _SignalBars(color: _accent),
              const SizedBox(height: 16),
            ],

            // ── Title ──────────────────────────────────────────────────────
            Text(
              _title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                fontFamily: 'Poppins',
                color: state == NetworkState.weak
                    ? const Color(0xFFFFD600)
                    : AppColors.white,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 14),

            // ── Message ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Text(
                _message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontFamily: 'Poppins',
                  color: AppColors.white40,
                  height: 1.65,
                ),
              ),
            ),
            const SizedBox(height: 44),

            // ── Status pill ────────────────────────────────────────────────
            AnimatedBuilder(
              animation: pulse,
              builder: (_, __) => Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 11),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  color: AppColors.white10,
                  border: Border.all(color: AppColors.white20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _accent.withOpacity(
                          0.5 + 0.5 * pulse.value),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Text(
                    _isFullyBlocking
                        ? 'Waiting for connection…'
                        : 'Monitoring signal…',
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'Poppins',
                      color: AppColors.white40,
                    ),
                  ),
                ]),
              ),
            ),

            // ── "Play Anyway" — weak only ──────────────────────────────────
            if (state == NetworkState.weak) ...[
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: GestureDetector(
                  onTap: onDismissWeak,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: AppColors.white10,
                      border: Border.all(
                          color: const Color(0xFFFFD600).withOpacity(0.4),
                          width: 1.5),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_arrow_rounded,
                            color: Color(0xFFFFD600), size: 20),
                        SizedBox(width: 8),
                        Text('Play Anyway',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Poppins',
                              color: Color(0xFFFFD600),
                            )),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Ads may not show during weak signal.',
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'Poppins',
                  color: AppColors.white20,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Animated signal strength bars (weak state only) ───────────────────────────
class _SignalBars extends StatefulWidget {
  final Color color;
  const _SignalBars({required this.color});
  @override
  State<_SignalBars> createState() => _SignalBarsState();
}

class _SignalBarsState extends State<_SignalBars>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        // Animate between 1 and 2 bars lit to simulate fluctuating signal
        final lit = _ctrl.value > 0.5 ? 2 : 1;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(4, (i) {
            final height = 8.0 + i * 5.0;
            final active = i < lit;
            return Container(
              width: 7,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: active
                    ? widget.color.withOpacity(0.85)
                    : AppColors.white20,
              ),
            );
          }),
        );
      },
    );
  }
}
