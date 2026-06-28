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

  // ── Bootstrap global singletons ───────────────────────────────────────────
  // AdMob must be ready before anything tries to create a BannerAd.
  await AdService().init();
  // IAP: restore any active Remove-Ads subscription from SharedPreferences.
  await IapService().init();
  await CompetitionService().init();
  // Connectivity: begins radio + DNS probing immediately (fire-and-forget).
  await ConnectivityService().init();
  // Ad-block detection: DNS-probe ad-serving domains (fire-and-forget).
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
        break;
      case AppLifecycleState.resumed:
        // Re-probe both connectivity and ad-blocking when app comes back
        // from background — catches cases where user toggled VPN / DNS.
        AudioService().resumeMusic();
        ConnectivityService().recheck();
        AdBlockService().recheck();
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
