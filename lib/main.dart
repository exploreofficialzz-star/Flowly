import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/game_provider.dart';
import 'presentation/screens/splash/splash_screen.dart';
import 'presentation/widgets/ad_blocker_overlay.dart';
import 'presentation/widgets/connectivity_overlay.dart';
import 'services/ad_block_service.dart';
import 'services/ad_service.dart';
import 'services/audio_service.dart';
import 'services/connectivity_service.dart';
import 'services/iap_service.dart';
import 'services/competition_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // ── Bootstrap global singletons — all fire-and-forget ────────────────────
  // Previously AdService, IapService, and CompetitionService were awaited
  // SEQUENTIALLY here before runApp(), adding 450–650 ms of blank native
  // screen on every cold start (AdMob SDK init alone takes 300–500 ms).
  // None of their results are needed before the first frame paints:
  //   • AdService   — first banner isn't created until GameScreen, which is
  //                   several seconds away through Splash → Home navigation.
  //   • IapService  — defaults to adsRemoved=false (safe). Notifies when
  //                   the real value loads; UI updates automatically.
  //   • Competition — defaults to empty leaderboard. Populates during splash.
  // Starting all five concurrently and calling runApp() immediately means
  // the splash frame renders without waiting for any SDK — then they all
  // catch up in the background while the user watches the animation.
  AdService().init().catchError((_) {});
  IapService().init().catchError((_) {});
  CompetitionService().init().catchError((_) {});
  ConnectivityService().init();
  AdBlockService().init();

  runApp(const FlowlyApp());
}

class FlowlyApp extends StatefulWidget {
  const FlowlyApp({super.key});
  @override
  State<FlowlyApp> createState() => _FlowlyAppState();
}

class _FlowlyAppState extends State<FlowlyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        AudioService().pauseMusic();
        // Stop background network polling while the app isn't visible —
        // no user is watching the connectivity/ad-block gates, so probing
        // every 8-20s here is pure battery + mobile-data waste.
        ConnectivityService().pause();
        AdBlockService().pause();
        break;
      case AppLifecycleState.resumed:
        // Re-probe both connectivity and ad-blocking when app comes back
        // from background — catches cases where user toggled VPN / DNS.
        AudioService().resumeMusic();
        ConnectivityService().resume();
        AdBlockService().resume();
        break;
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GameProvider()),
        // All three singletons exposed as ChangeNotifiers so every widget
        // that calls context.watch<T>() gets rebuilds automatically.
        ChangeNotifierProvider.value(value: IapService()),
        ChangeNotifierProvider.value(value: CompetitionService()),
        ChangeNotifierProvider.value(value: ConnectivityService()),
        ChangeNotifierProvider.value(value: AdBlockService()),
      ],
      child: MaterialApp(
        title: 'Flowly',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const SplashScreen(),

        // ── Global overlay stack ─────────────────────────────────────────────
        // builder wraps the ENTIRE Navigator, so these overlays sit above
        // every route — splash, home, game, worlds, dialogs — everything.
        //
        // Stack order (bottom → top):
        //   [0] child  → the Navigator with all pushed routes
        //   [1] AdBlockerGate  → blocks non-premium when ad-blocker detected
        //   [2] ConnectivityGate → blocks EVERYONE when internet/data is lost
        //
        // ConnectivityGate is on top so a network loss always wins visually,
        // even if the ad-blocker overlay is also showing.
        builder: (context, child) {
          return Stack(
            children: [
              // The full app Navigator — must come first
              child!,

              // Ad-blocker detection overlay
              // Visible only when: ad-blocker active AND user is NOT premium.
              // Premium users (adsRemoved == true) play through uninterrupted.
              const AdBlockerGate(),

              // Network / data overlay
              // Visible for EVERYONE (including premium) when the device has
              // no internet or no real data. Auto-hides when connection restores.
              const ConnectivityGate(),
            ],
          );
        },
      ),
    );
  }
}
