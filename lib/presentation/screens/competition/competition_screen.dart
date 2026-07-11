import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/competition_model.dart';
import '../../../services/competition_service.dart';
import 'registration_screen.dart';

class CompetitionScreen extends StatefulWidget {
  const CompetitionScreen({super.key});
  @override
  State<CompetitionScreen> createState() => _CompetitionScreenState();
}

class _CompetitionScreenState extends State<CompetitionScreen> {
  final Map<String, int>  _prevPositions = {};
  final Map<String, bool> _movedUp       = {};
  Timer? _arrowFade;
  // Entrance fade-in should only play once per screen visit, not on every
  // background refresh (position shuffle every 3 min, live events every
  // ~55-125s). Re-triggering a fade on every visible row on every refresh
  // was causing a repeating flicker across the whole leaderboard.
  bool _hasAnimatedIn = false;

  void _snapshot(List<LeaderboardEntry> board) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final e in board) {
        final prev = _prevPositions[e.id];
        if (prev != null && prev != e.position) {
          _movedUp[e.id] = e.position < prev;
        }
      }
      _prevPositions
        ..clear()
        ..addAll({for (var e in board) e.id: e.position});

      _arrowFade?.cancel();
      _arrowFade = Timer(const Duration(seconds: 9), () {
        if (mounted) setState(() => _movedUp.clear());
      });
    });
  }

  @override
  void dispose() {
    _arrowFade?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<CompetitionService>();
    _snapshot(svc.leaderboard);

    if (!svc.isRegistered) {
      return RegistrationScreen(onRegistered: () => setState(() {}));
    }

    final board  = svc.leaderboard;
    final events = svc.liveEvents;
    // Capture once — rows built on this pass animate in; later rebuilds
    // (triggered by CompetitionService refreshes) render instantly, no fade.
    final playEntrance = !_hasAnimatedIn;
    if (!_hasAnimatedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _hasAnimatedIn = true;
      });
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.gradientBg),
        child: SafeArea(
          child: Column(children: [
            // ── Header ──────────────────────────────────────────────────────
            const _Header(),
            const SizedBox(height: 6),

            // ── Top-10 prize hint ────────────────────────────────────────────
            _PrizeHint(),
            const SizedBox(height: 4),

            // ── Leaderboard list ─────────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
                itemCount: board.length,
                itemBuilder: (ctx, i) {
                  final e      = board[i];
                  final isUser = !e.isBot;
                  final moved  = _movedUp[e.id];
                  final row = _Row(
                    key:     ValueKey(e.id),
                    entry:   e,
                    isUser:  isUser,
                    movedUp: moved,
                    prize:   _prize(e.position),
                  );
                  if (!playEntrance) return row;
                  return row
                      .animate(delay: Duration(milliseconds: 15 * i.clamp(0, 20)))
                      .fadeIn(duration: 250.ms);
                },
              ),
            ),

            // ── Pinned user card ─────────────────────────────────────────────
            _YourCard(svc: svc),

            // ── Live feed ─────────────────────────────────────────────────────
            if (events.isNotEmpty) _Feed(events: events),
            const SizedBox(height: 6),
          ]),
        ),
      ),
    );
  }

  String? _prize(int pos) {
    const m = {1: '\$50', 2: '\$40', 3: '\$30', 4: '\$20', 5: '\$10'};
    if (m.containsKey(pos)) return m[pos];
    if (pos <= 10) return '\$5';
    return null;
  }
}

// ── Header ────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.white40, size: 20),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Daily Rankings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                    fontFamily: 'Poppins', color: AppColors.white)),
            Text('Top players worldwide today',
                style: TextStyle(fontSize: 11, fontFamily: 'Poppins',
                    color: AppColors.white40)),
          ]),
        ),
        // Isolated ticking widget — its own Timer, its own setState, scoped
        // to itself only. Ticking the clock never touches the leaderboard,
        // the prize hint, or anything else on this screen.
        const _CountdownChip(),

      ]),
    );
  }
}

// Owns its OWN Timer.periodic + setState, scoped to only this small chip.
// Ticking every second here never rebuilds the leaderboard, prize hint,
// or anything else — that isolation is the whole point of this widget.
// (Previously the countdown lived on the screen's own State object, so
// its per-second setState rebuilt the entire leaderboard ListView too —
// every visible row, every second, forever, while this screen was open.)
class _CountdownChip extends StatefulWidget {
  const _CountdownChip();
  @override
  State<_CountdownChip> createState() => _CountdownChipState();
}

class _CountdownChipState extends State<_CountdownChip> {
  Timer?  _timer;
  String  _countdown = '00:00:00';

  @override
  void initState() {
    super.initState();
    _countdown = CompetitionService().resetCountdown;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _countdown = CompetitionService().resetCountdown);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: AppColors.bgCard,
        border: Border.all(color: AppColors.white10),
      ),
      child: Row(children: [
        const Icon(Icons.refresh_rounded, color: AppColors.white40, size: 12),
        const SizedBox(width: 4),
        Text(_countdown,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                fontFamily: 'Poppins', color: AppColors.white70)),
      ]),
    );
  }
}

// ── Prize hint strip ──────────────────────────────────────────────────────────
class _PrizeHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: const Color(0x18FFD700),
          border: Border.all(color: const Color(0x28FFD700)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🏆  Top 10 earn prizes  ·  ',
                style: TextStyle(fontSize: 11, fontFamily: 'Poppins',
                    color: Color(0xCCFFD700))),
            Text('1st \$50  ·  2nd \$40  ·  3rd \$30  ·  4th \$20  ·  5th \$10  ·  6–10 \$5',
                style: TextStyle(fontSize: 10, fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600, color: Color(0xAAFFD700))),
          ],
        ),
      ),
    );
  }
}

// ── Leaderboard row ───────────────────────────────────────────────────────────
class _Row extends StatelessWidget {
  final LeaderboardEntry entry;
  final bool isUser;
  final bool? movedUp;
  final String? prize;
  const _Row({super.key, required this.entry, required this.isUser,
      this.movedUp, this.prize});

  @override
  Widget build(BuildContext context) {
    final isElite = entry.isElite;
    final pos     = entry.position;

    // Row styling
    Color rowBg    = Colors.transparent;
    Color border   = Colors.transparent;
    if (isUser) {
      rowBg  = AppColors.neonBlue.withOpacity(0.07);
      border = AppColors.neonBlue.withOpacity(0.45);
    } else if (isElite && pos <= 3) {
      rowBg  = const Color(0xFFFFD700).withOpacity(0.04);
      border = const Color(0xFFFFD700).withOpacity(0.14);
    }

    // Position badge
    Widget posBadge;
    if (pos == 1)      posBadge = const Text('👑', style: TextStyle(fontSize: 17));
    else if (pos == 2) posBadge = const Text('🥈', style: TextStyle(fontSize: 15));
    else if (pos == 3) posBadge = const Text('🥉', style: TextStyle(fontSize: 15));
    else posBadge = SizedBox(width: 26,
        child: Text('$pos', textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                fontFamily: 'Poppins',
                color: isElite ? const Color(0xFFFFD700) : AppColors.white40)));

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1.5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: rowBg, border: Border.all(color: border),
      ),
      child: Row(children: [
        SizedBox(width: 30, child: posBadge),
        const SizedBox(width: 5),
        Text(entry.flag, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            isUser ? '${entry.name}  (You)' : entry.name,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 13,
                fontWeight: isUser || isElite ? FontWeight.w700 : FontWeight.w500,
                fontFamily: 'Poppins',
                color: isUser ? AppColors.neonBlue
                    : isElite ? const Color(0xFFFFE580) : AppColors.white),
          ),
        ),
        // Score
        Text(_fmt(entry.score),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                fontFamily: 'Poppins',
                color: isUser ? AppColors.neonBlue
                    : isElite ? const Color(0xFFFFD700) : AppColors.white70)),
        // Prize badge
        if (prize != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              color: const Color(0x1AFFD700),
            ),
            child: Text(prize!,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins', color: Color(0xFFFFD700))),
          ),
        ],
        // Change arrow
        if (movedUp != null) ...[
          const SizedBox(width: 3),
          Icon(
            movedUp! ? Icons.north_rounded : Icons.south_rounded,
            size: 11,
            color: movedUp! ? AppColors.neonGreen : AppColors.neonRed,
          ).animate().fadeIn(duration: 200.ms),
        ],
      ]),
    );
  }

  String _fmt(int v) {
    if (v >= 1000) {
      final k = v / 1000;
      return '${k.toStringAsFixed(k.truncate() == k ? 0 : 1)}k';
    }
    return v.toString();
  }
}

// ── Pinned user card ──────────────────────────────────────────────────────────
class _YourCard extends StatelessWidget {
  final CompetitionService svc;
  const _YourCard({required this.svc});

  @override
  Widget build(BuildContext context) {
    final pos      = svc.userPosition;
    final score    = svc.userScore;
    final ptsTop10 = svc.ptsToTop10;
    final above    = svc.entryAboveUser;

    String msg;
    if (score == 0)         msg = 'Play a level to appear on the board!';
    else if (pos <= 10)     msg = '🏆 You\'re in the prize zone!';
    else if (ptsTop10 < 150) msg = '🔥 ${ptsTop10}pts to Top 10!';
    else if (above != null) msg = '↑ ${svc.ptsToNextPosition}pts to pass ${above.name.split(' ').first}';
    else                    msg = 'Keep playing to climb!';

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.bgCard,
        border: Border.all(color: AppColors.neonBlue.withOpacity(0.35)),
        boxShadow: [BoxShadow(color: AppColors.neonBlue.withOpacity(0.10),
            blurRadius: 10)],
      ),
      child: Row(children: [
        Text(svc.userFlag ?? '🌍', style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(svc.userName ?? '',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins', color: AppColors.neonBlue)),
            Text(msg, style: const TextStyle(fontSize: 11, fontFamily: 'Poppins',
                color: AppColors.white40)),
          ],
        )),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(pos > 0 ? 'Rank #$pos' : 'Unranked',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins', color: AppColors.white70)),
          Text('$score pts',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                  fontFamily: 'Poppins', color: AppColors.neonBlue)),
        ]),
      ]),
    );
  }
}

// ── Live feed ─────────────────────────────────────────────────────────────────
class _Feed extends StatelessWidget {
  final List<LiveEvent> events;
  const _Feed({required this.events});

  @override
  Widget build(BuildContext context) {
    final shown = events.take(3).toList();
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 0),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: AppColors.bgCard,
        border: Border.all(color: AppColors.white10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 6, height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: AppColors.neonRed,
                boxShadow: [BoxShadow(color: AppColors.neonRed.withOpacity(0.5),
                    blurRadius: 5)]),
          ).animate(onPlay: (c) => c.repeat())
           .fadeOut(duration: 700.ms).then().fadeIn(duration: 700.ms),
          const SizedBox(width: 5),
          const Text('LIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
              fontFamily: 'Poppins', color: AppColors.neonRed, letterSpacing: 1.4)),
        ]),
        const SizedBox(height: 5),
        ...shown.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(children: [
            Text(e.flag, style: const TextStyle(fontSize: 11)),
            const SizedBox(width: 5),
            Expanded(child: Text(e.text, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontFamily: 'Poppins',
                    color: AppColors.white70))),
          ]),
        )),
      ]),
    );
  }
}
