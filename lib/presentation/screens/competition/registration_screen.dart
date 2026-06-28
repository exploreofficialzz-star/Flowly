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
  String _selectedCountry = 'Nigeria';
  String _selectedFlag    = '🇳🇬';
  bool   _loading         = false;
  String? _error;

  static const _countries = [
    ('Nigeria',       '🇳🇬'), ('Ghana',         '🇬🇭'), ('Kenya',         '🇰🇪'),
    ('South Africa',  '🇿🇦'), ('Tanzania',      '🇹🇿'), ('Uganda',        '🇺🇬'),
    ('Rwanda',        '🇷🇼'), ('Ethiopia',      '🇪🇹'), ('Cameroon',      '🇨🇲'),
    ('Senegal',       '🇸🇳'), ('USA',           '🇺🇸'), ('UK',            '🇬🇧'),
    ('Canada',        '🇨🇦'), ('Australia',     '🇦🇺'), ('Germany',       '🇩🇪'),
    ('France',        '🇫🇷'), ('Italy',         '🇮🇹'), ('Spain',         '🇪🇸'),
    ('Brazil',        '🇧🇷'), ('Mexico',        '🇲🇽'), ('India',         '🇮🇳'),
    ('Pakistan',      '🇵🇰'), ('UAE',           '🇦🇪'), ('Philippines',   '🇵🇭'),
    ('Indonesia',     '🇮🇩'), ('Other',         '🌍'),
  ];

  Future<void> _register() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter your display name');
      return;
    }
    if (name.length < 2) {
      setState(() => _error = 'Name must be at least 2 characters');
      return;
    }
    setState(() { _loading = true; _error = null; });
    await CompetitionService().register(
      name:    name,
      country: _selectedCountry,
      flag:    _selectedFlag,
    );
    if (mounted) {
      setState(() => _loading = false);
      widget.onRegistered();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.gradientBg),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back arrow
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: AppColors.white40, size: 22),
                ),
                const SizedBox(height: 32),

                // Header
                Center(
                  child: Column(children: [
                    const Text('🏆', style: TextStyle(fontSize: 56))
                        .animate().scale(duration: 600.ms, curve: Curves.elasticOut),
                    const SizedBox(height: 12),
                    ShaderMask(
                      shaderCallback: (r) =>
                          AppColors.gradientPrimary.createShader(r),
                      child: const Text('Future Hope',
                          style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Poppins',
                              color: Colors.white)),
                    ),
                    const Text('Competition',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Poppins',
                            color: AppColors.white70)),
                    const SizedBox(height: 8),
                    const Text('Compete daily for real prizes',
                        style: TextStyle(
                            fontSize: 13,
                            fontFamily: 'Poppins',
                            color: AppColors.white40)),
                  ]),
                ).animate().fadeIn(delay: 100.ms),
                const SizedBox(height: 40),

                // Prize summary strip
                _PrizeSummary().animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 32),

                // Name field
                _Label('Your display name'),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: AppColors.bgCard,
                    border: Border.all(color: AppColors.white10),
                  ),
                  child: TextField(
                    controller: _nameCtrl,
                    style: const TextStyle(
                        fontSize: 16,
                        fontFamily: 'Poppins',
                        color: AppColors.white),
                    maxLength: 20,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Emmanuel',
                      hintStyle: TextStyle(
                          fontSize: 15,
                          fontFamily: 'Poppins',
                          color: AppColors.white40),
                      prefixIcon: Padding(
                          padding: EdgeInsets.only(left: 14, right: 10),
                          child: Text('👤', style: TextStyle(fontSize: 20))),
                      prefixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      counterText: '',
                    ),
                    onChanged: (_) { if (_error != null) setState(() => _error = null); },
                  ),
                ).animate().fadeIn(delay: 250.ms),

                if (_error != null) ...[
                  const SizedBox(height: 6),
                  Text(_error!,
                      style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'Poppins',
                          color: AppColors.neonRed)),
                ],
                const SizedBox(height: 20),

                // Country picker
                _Label('Your country'),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: AppColors.bgCard,
                    border: Border.all(color: AppColors.white10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCountry,
                      isExpanded: true,
                      dropdownColor: AppColors.bgSurface,
                      style: const TextStyle(
                          fontSize: 15,
                          fontFamily: 'Poppins',
                          color: AppColors.white),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: AppColors.white40),
                      items: _countries.map((c) {
                        return DropdownMenuItem<String>(
                          value: c.$1,
                          child: Text('${c.$2}  ${c.$1}',
                              style: const TextStyle(
                                  fontSize: 15, fontFamily: 'Poppins',
                                  color: AppColors.white)),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        final entry = _countries.firstWhere((c) => c.$1 == v);
                        setState(() {
                          _selectedCountry = entry.$1;
                          _selectedFlag    = entry.$2;
                        });
                      },
                    ),
                  ),
                ).animate().fadeIn(delay: 300.ms),
                const SizedBox(height: 36),

                // CTA button
                GestureDetector(
                  onTap: _loading ? null : _register,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: AppColors.gradientPrimary,
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.neonBlue.withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 1)
                      ],
                    ),
                    child: _loading
                        ? const Center(
                            child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white)))
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('▶  Start Competing',
                                  style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'Poppins',
                                      color: Colors.white)),
                            ]),
                  ),
                ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.3),
                const SizedBox(height: 12),
                Center(
                  child: Text('Free to enter · Resets daily at midnight',
                      style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Poppins',
                          color: AppColors.white40)),
                ),
                const SizedBox(height: 40),

                // Support
                Center(
                  child: Column(children: [
                    Text('Questions or prize enquiries:',
                        style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'Poppins',
                            color: AppColors.white40)),
                    const SizedBox(height: 4),
                    ShaderMask(
                      shaderCallback: (r) =>
                          AppColors.gradientPrimary.createShader(r),
                      child: const Text('chastechnologiesllc@gmail.com',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Poppins',
                              color: Colors.white)),
                    ),
                  ]),
                ).animate().fadeIn(delay: 400.ms),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          fontFamily: 'Poppins',
          color: AppColors.white70));
}

class _PrizeSummary extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [Color(0x22FFD700), Color(0x11FF8C00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0x44FFD700)),
      ),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('💰', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            const Text('Daily Prize Pool',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins',
                    color: Color(0xFFFFD700))),
          ],
        ),
        const SizedBox(height: 10),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _PrizeBadge(rank: '🥇', prize: '\$50'),
            _PrizeBadge(rank: '🥈', prize: '\$40'),
            _PrizeBadge(rank: '🥉', prize: '\$30'),
            _PrizeBadge(rank: '4th', prize: '\$20'),
            _PrizeBadge(rank: '5th', prize: '\$10'),
          ],
        ),
        const SizedBox(height: 4),
        const Text('6th–10th place → \$5 each',
            style: TextStyle(
                fontSize: 11,
                fontFamily: 'Poppins',
                color: Color(0xAAFFD700))),
      ]),
    );
  }
}

class _PrizeBadge extends StatelessWidget {
  final String rank, prize;
  const _PrizeBadge({required this.rank, required this.prize});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(rank,
          style: const TextStyle(
              fontSize: 15, fontFamily: 'Poppins', color: AppColors.white)),
      Text(prize,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFamily: 'Poppins',
              color: Color(0xFFFFD700))),
    ]);
  }
}
