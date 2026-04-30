import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  AudioPlayer? _musicPlayer;
  AudioPlayer? _sfxPlayer;
  bool _soundEnabled = true;
  bool _musicEnabled = true;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _soundEnabled = prefs.getBool(AppConstants.keySoundEnabled) ?? true;
      _musicEnabled = prefs.getBool(AppConstants.keyMusicEnabled) ?? true;
      _musicPlayer = AudioPlayer();
      _sfxPlayer = AudioPlayer();
      await _musicPlayer!.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer!.setVolume(0.45);
      await _sfxPlayer!.setVolume(1.0);
      _initialized = true;
      if (_musicEnabled) await playMusic();
    } catch (_) {}
  }

  Future<void> playMusic() async {
    try {
      await _musicPlayer?.stop();
      await _musicPlayer?.play(AssetSource('audio/bg_music.mp3'));
    } catch (_) {}
  }

  Future<void> stopMusic() async {
    try { await _musicPlayer?.stop(); } catch (_) {}
  }

  Future<void> pauseMusic() async {
    try { await _musicPlayer?.pause(); } catch (_) {}
  }

  Future<void> resumeMusic() async {
    try { if (_musicEnabled) await _musicPlayer?.resume(); } catch (_) {}
  }

  Future<void> _playSfx(String file) async {
    if (!_soundEnabled) return;
    try {
      final player = AudioPlayer();
      await player.setVolume(1.0);
      await player.play(AssetSource('audio/$file'));
      player.onPlayerComplete.listen((_) => player.dispose());
    } catch (_) {}
  }

  Future<void> playPour() => _playSfx('pour.wav');
  Future<void> playWin() => _playSfx('win.wav');
  Future<void> playTap() => _playSfx('tap.wav');
  Future<void> playError() => _playSfx('error.wav');
  Future<void> playChime() => _playSfx('chime.wav');
  Future<void> playLevelStart() => _playSfx('level_start.wav');
  Future<void> playClick() => _playSfx('click.wav');

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
    try { _sfxPlayer?.dispose(); } catch (_) {}
    try { _musicPlayer?.dispose(); } catch (_) {}
  }
}
