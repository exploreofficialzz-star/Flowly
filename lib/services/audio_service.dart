import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final _sfx = AudioPlayer();
  final _music = AudioPlayer();
  bool _soundEnabled = true;
  bool _musicEnabled = true;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _soundEnabled = prefs.getBool(AppConstants.keySoundEnabled) ?? true;
    _musicEnabled = prefs.getBool(AppConstants.keyMusicEnabled) ?? true;
    await _music.setReleaseMode(ReleaseMode.loop);
    await _music.setVolume(0.35);
    if (_musicEnabled) await playMusic();
  }

  Future<void> playMusic() async {
    await _music.play(AssetSource('audio/bg_music.wav'));
  }

  Future<void> stopMusic() async => await _music.stop();

  Future<void> _playSfx(String file) async {
    if (!_soundEnabled) return;
    await _sfx.stop();
    await _sfx.play(AssetSource('audio/$file'));
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
    _soundEnabled = !_soundEnabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keySoundEnabled, _soundEnabled);
  }

  Future<void> toggleMusic() async {
    _musicEnabled = !_musicEnabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyMusicEnabled, _musicEnabled);
    if (_musicEnabled) await playMusic(); else await stopMusic();
  }

  void dispose() {
    _sfx.dispose();
    _music.dispose();
  }
}
