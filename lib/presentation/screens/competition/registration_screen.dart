import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/competition_service.dart';

class RegistrationScreen extends StatefulWidget {
  final VoidCallback onRegistered;
  const RegistrationScreen({super.key, required this.onRegistered});
  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _nameCtrl = TextEditingController();
  String  _country = 'Nigeria';
  String  _flag    = '🇳🇬';
  bool    _loading = false;
  String? _error;

  static const _countries = [
    ('Nigeria','🇳🇬'),('Ghana','🇬🇭'),('Kenya','🇰🇪'),('South Africa','🇿🇦'),
    ('Tanzania','🇹🇿'),('Uganda','🇺🇬'),('Rwanda','🇷🇼'),('Ethiopia','🇪🇹'),
    ('Cameroon','🇨🇲'),('Senegal','🇸🇳'),('USA','🇺🇸'),('UK','🇬🇧'),
    ('Canada','🇨🇦'),('Australia','🇦🇺'),('Germany','🇩🇪'),('France','🇫🇷'),
    ('Brazil','🇧🇷'),('Mexico','🇲🇽'),('India','🇮🇳'),('Pakistan','🇵🇰'),
    ('UAE','🇦🇪'),('Philippines','🇵🇭'),('Indonesia','🇮🇩'),('Other','🌍'),
  ];

  Future<void> _join() async {
    final name = _nameCtrl.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'Please enter at least 2 characters');
      return;
    }
    setState(() { _loading = true; _error = null; });
    await CompetitionService().register(name: name, country: _country, flag: _flag);
    if (mounted) { setState(() => _loading = false); widget.onRegistered(); }
  }

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.gradientBg),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: AppColors.white40, size: 22),
              ),
              const SizedBox(height: 30),

              // Hero
              Center(child: Column(children: [
                const Text('🌍', style: TextStyle(fontSize: 52))
                    .animate().scale(duration: 500.ms, curve: Curves.elasticOut),
                const SizedBox(height: 10),
                const Text('Daily Rankings',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
                        fontFamily: 'Poppins', color: AppColors.white)),
                const SizedBox(height: 4),
                const Text('Compete with players worldwide',
                    style: TextStyle(fontSize: 13, fontFamily: 'Poppins',
                        color: AppColors.white40)),
              ]).animate().fadeIn(delay: 100.ms)),
              const SizedBox(height: 28),

              // Prize strip
              _PrizeRow().animate().fadeIn(delay: 180.ms),
              const SizedBox(height: 28),

              // Name
              _label('Your name on the board'),
              const SizedBox(height: 6),
              _field(
                controller: _nameCtrl,
                hint: 'e.g. Emmanuel',
                prefix: '👤',
                onChanged: (_) { if (_error != null) setState(() => _error = null); },
              ).animate().fadeIn(delay: 220.ms),
              if (_error != null) ...[
                const SizedBox(height: 5),
                Text(_error!, style: const TextStyle(fontSize: 11,
                    fontFamily: 'Poppins', color: AppColors.neonRed)),
              ],
              const SizedBox(height: 18),

              // Country
              _label('Your country'),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
                    color: AppColors.bgCard,
                    border: Border.all(color: AppColors.white10)),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _country,
                    isExpanded: true,
                    dropdownColor: AppColors.bgSurface,
                    style: const TextStyle(fontSize: 15, fontFamily: 'Poppins',
                        color: AppColors.white),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppColors.white40),
                    items: _countries.map((c) => DropdownMenuItem<String>(
                      value: c.$1,
                      child: Text('${c.$2}  ${c.$1}',
                          style: const TextStyle(fontSize: 15,
                              fontFamily: 'Poppins', color: AppColors.white)),
                    )).toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      final e = _countries.firstWhere((c) => c.$1 == v);
                      setState(() { _country = e.$1; _flag = e.$2; });
                    },
                  ),
                ),
              ).animate().fadeIn(delay: 260.ms),
              const SizedBox(height: 32),

              // CTA
              GestureDetector(
                onTap: _loading ? null : _join,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: AppColors.gradientPrimary,
                    boxShadow: [BoxShadow(
                        color: AppColors.neonBlue.withOpacity(0.35),
                        blurRadius: 18, spreadRadius: 1)],
                  ),
                  child: _loading
                      ? const Center(child: SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white)))
                      : const Text('▶  Join Rankings',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                              fontFamily: 'Poppins', color: Colors.white)),
                ),
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.3),
              const SizedBox(height: 10),
              const Center(child: Text('Free · Resets daily at midnight',
                  style: TextStyle(fontSize: 11, fontFamily: 'Poppins',
                      color: AppColors.white40))),
              const SizedBox(height: 36),

              // Support
              Center(child: Column(children: [
                const Text('Prize enquiries:',
                    style: TextStyle(fontSize: 11, fontFamily: 'Poppins',
                        color: AppColors.white40)),
                const SizedBox(height: 3),
                ShaderMask(
                  shaderCallback: (r) => AppColors.gradientPrimary.createShader(r),
                  child: const Text('chastechnologiesllc@gmail.com',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                          fontFamily: 'Poppins', color: Colors.white)),
                ),
              ]).animate().fadeIn(delay: 360.ms)),
              const SizedBox(height: 20),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Text(t, style: const TextStyle(fontSize: 12,
      fontWeight: FontWeight.w600, fontFamily: 'Poppins', color: AppColors.white70));

  Widget _field({required TextEditingController controller, required String hint,
      required String prefix, void Function(String)? onChanged}) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
          color: AppColors.bgCard, border: Border.all(color: AppColors.white10)),
      child: TextField(
        controller: controller,
        maxLength: 20,
        style: const TextStyle(fontSize: 15, fontFamily: 'Poppins',
            color: AppColors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 14, fontFamily: 'Poppins',
              color: AppColors.white40),
          prefixIcon: Padding(padding: const EdgeInsets.only(left: 14, right: 10),
              child: Text(prefix, style: const TextStyle(fontSize: 18))),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          counterText: '',
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _PrizeRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
          color: const Color(0x14FFD700),
          border: Border.all(color: const Color(0x30FFD700))),
      child: const Column(children: [
        Text('🏆  Daily Prize Pool',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                fontFamily: 'Poppins', color: Color(0xFFFFD700))),
        SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _P('🥇', '\$50'), _P('🥈', '\$40'), _P('🥉', '\$30'),
          _P('4th', '\$20'), _P('5th', '\$10'),
        ]),
        SizedBox(height: 4),
        Text('6th–10th place · \$5 each',
            style: TextStyle(fontSize: 10, fontFamily: 'Poppins',
                color: Color(0x88FFD700))),
      ]),
    );
  }
}

class _P extends StatelessWidget {
  final String r, p;
  const _P(this.r, this.p);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(r, style: const TextStyle(fontSize: 14, fontFamily: 'Poppins',
        color: AppColors.white)),
    Text(p, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
        fontFamily: 'Poppins', color: Color(0xFFFFD700))),
  ]);
}
