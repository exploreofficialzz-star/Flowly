import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  AudioPlayer? _musicPlayer;

  // One pre-loaded AudioPlayer per SFX file.
  // Previously _playSfx() called `AudioPlayer()` on every tap / pour / chime,
  // which allocated a new native Android MediaPlayer + loaded the asset from
  // the APK each time — costing 200–500 ms on the platform thread and causing
  // the game screen to hang on first interaction.  By pre-creating and
  // pre-loading all players here during init(), _playSfx() does zero native
  // allocation on the hot path; the file is already in native memory.
  final Map<String, AudioPlayer> _sfx = {};

  bool _soundEnabled = true;
  bool _musicEnabled = true;
  bool _initialized  = false;

  static const _sfxFiles = [
    'pour.wav',
    'win.wav',
    'tap.wav',
    'error.wav',
    'chime.wav',
    'level_start.wav',
    'click.wav',
  ];

  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _soundEnabled = prefs.getBool(AppConstants.keySoundEnabled) ?? true;
      _musicEnabled = prefs.getBool(AppConstants.keyMusicEnabled) ?? true;

      // Pre-create one player per SFX and load its source so the native layer
      // has already decoded/buffered the file before the first play() call.
      for (final file in _sfxFiles) {
        final p = AudioPlayer();
        await p.setVolume(1.0);
        await p.setSource(AssetSource('audio/$file'));
        _sfx[file] = p;
      }

      _musicPlayer = AudioPlayer();
      await _musicPlayer!.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer!.setVolume(0.45);

      _initialized = true;
      if (_musicEnabled) await playMusic();
    } catch (_) {}
  }

  Future<void> _playSfx(String file) async {
    if (!_soundEnabled) return;
    final p = _sfx[file];
    // Guard: if init() hasn't completed yet, _sfx is empty — safe no-op.
    if (p == null) return;
    try {
      // play() on a pre-loaded player restarts playback from the beginning.
      // No new AudioPlayer created, no new native MediaPlayer, no asset load.
      await p.play(AssetSource('audio/$file'));
    } catch (_) {}
  }

  Future<void> playMusic() async {
    try {
      await _musicPlayer?.stop();
      await _musicPlayer?.play(AssetSource('audio/bg_music.mp3'));
    } catch (_) {}
  }

  Future<void> stopMusic()   async { try { await _musicPlayer?.stop();   } catch (_) {} }
  Future<void> pauseMusic()  async { try { await _musicPlayer?.pause();  } catch (_) {} }
  Future<void> resumeMusic() async {
    try { if (_musicEnabled) await _musicPlayer?.resume(); } catch (_) {}
  }

  Future<void> playPour()       => _playSfx('pour.wav');
  Future<void> playWin()        => _playSfx('win.wav');
  Future<void> playTap()        => _playSfx('tap.wav');
  Future<void> playError()      => _playSfx('error.wav');
  Future<void> playChime()      => _playSfx('chime.wav');
  Future<void> playLevelStart() => _playSfx('level_start.wav');
  Future<void> playClick()      => _playSfx('click.wav');

  bool get soundEnabled => _soundEnabled;
  bool get musicEnabled => _musicEnabled;

  Future<void> toggleSound() async {
    try {
      _soundEnabled = !_soundEnabled;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.keySoundEnabled, _soundEnabled);
    } catch (_) {}
  }

  Future<void> toggleMusic() async {
    try {
      _musicEnabled = !_musicEnabled;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.keyMusicEnabled, _musicEnabled);
      if (_musicEnabled) await playMusic(); else await stopMusic();
    } catch (_) {}
  }

  void dispose() {
    try { _musicPlayer?.dispose(); } catch (_) {}
    for (final p in _sfx.values) {
      try { p.dispose(); } catch (_) {}
    }
  }
}

