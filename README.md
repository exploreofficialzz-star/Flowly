# 🌊 Flowly — Color Sort Fluid Puzzle

> **by chAs** | `com.chastechgroup.flowly`

A modern, dark-glass neon-styled water sort puzzle game built in Flutter.
Ships to **Android** and **iOS** from a single codebase via GitHub Actions.

---

## 📱 Features

- ✅ 100 hand-crafted levels across 5 themed worlds
- ✅ Daily Challenge — unique puzzle every day
- ✅ Streak system — play daily to build your streak
- ✅ Hint system with rewarded ads
- ✅ Undo system with rewarded ads
- ✅ Interstitial ads after every level completion
- ✅ Banner ad in gameplay (bottom)
- ✅ Real fluid animations with haptic feedback
- ✅ 8 SFX + looping background music (all generated)
- ✅ Dark glass neon design system
- ✅ Fully offline — no backend required
- ✅ GitHub Actions CI/CD → APK + IPA + GitHub Release

---

## 🚀 Quick Start

### Prerequisites
- Flutter 3.19+ (`flutter --version`)
- Android Studio / Xcode
- A Google AdMob account (for real ad IDs)

### Run locally
```bash
git clone https://github.com/YOUR_USERNAME/flowly.git
cd flowly
flutter pub get
flutter pub run flutter_native_splash:create
flutter pub run flutter_launcher_icons
flutter run
```

---

## 🔑 GitHub Secrets Required

Go to **GitHub → Your Repo → Settings → Secrets → Actions** and add:

### Android
| Secret | Description |
|--------|-------------|
| `KEYSTORE_BASE64` | `base64 -i your-keystore.jks` |
| `KEY_ALIAS` | Your key alias |
| `KEY_PASSWORD` | Your key password |
| `STORE_PASSWORD` | Your keystore password |

**Generate a keystore:**
```bash
keytool -genkey -v -keystore flowly-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias flowly -dname "CN=chAs Tech Group, O=chAs, C=US"

base64 -i flowly-key.jks | pbcopy   # copies to clipboard (macOS)
```

### iOS
| Secret | Description |
|--------|-------------|
| `IOS_CERTIFICATE_BASE64` | Distribution certificate as base64 |
| `IOS_CERTIFICATE_PASSWORD` | Certificate password |
| `IOS_PROVISIONING_PROFILE_BASE64` | Provisioning profile as base64 |
| `KEYCHAIN_PASSWORD` | Any random password for temp keychain |

---

## 💰 AdMob Setup

1. Create app on [AdMob Console](https://admob.google.com)
2. Replace test IDs in `lib/core/constants/app_constants.dart`:
```dart
static const adBannerAndroid = 'ca-app-pub-XXXXXXXX/XXXXXXXXXX';
static const adInterstitialAndroid = 'ca-app-pub-XXXXXXXX/XXXXXXXXXX';
static const adRewardedAndroid = 'ca-app-pub-XXXXXXXX/XXXXXXXXXX';
// same for iOS
```
3. Replace App ID in `android/app/src/main/AndroidManifest.xml`:
```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-XXXXXXXX~XXXXXXXXXX"/>
```
4. Replace App ID in `ios/Runner/Info.plist`:
```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-XXXXXXXX~XXXXXXXXXX</string>
```

---

## 📦 Deploy

### Trigger a release build
```bash
git tag v1.0.0
git push origin v1.0.0
```

GitHub Actions will automatically:
1. Build Android APK (split by ABI) + AAB
2. Build iOS IPA
3. Create a GitHub Release with all files attached

---

## 🏗️ Project Structure

```
flowly/
├── lib/
│   ├── core/
│   │   ├── theme/          # Dark glass neon design system
│   │   └── constants/      # App config, ad IDs, world data
│   ├── data/
│   │   ├── models/         # TubeModel, LevelConfig, GameMove
│   │   └── levels/         # Procedural level generator (100 levels)
│   ├── services/
│   │   ├── audio_service.dart  # SFX + background music
│   │   └── ad_service.dart     # Banner, interstitial, rewarded
│   └── presentation/
│       ├── providers/      # GameProvider (full game state)
│       └── screens/
│           ├── splash/     # Animated splash + "by chAs"
│           ├── home/       # Home dashboard
│           ├── worlds/     # World selector
│           └── game/       # Main game board
├── assets/
│   ├── audio/              # 8 generated WAV files
│   └── images/             # App icons + splash
├── android/                # Android config (com.chastechgroup.flowly)
├── ios/                    # iOS config
└── .github/workflows/      # CI/CD build pipeline
```

---

## 📋 Ad Strategy

| Placement | Type | Frequency |
|-----------|------|-----------|
| Gameplay bottom | Banner | Always |
| Level complete | Interstitial | Every level |
| Out of hints | Rewarded | On demand |
| Out of undos | Rewarded | On demand |

**No ads during gameplay. No app open ads. Player-friendly but profitable.**

---

**by chAs Tech Group** • `com.chastechgroup.flowly`
