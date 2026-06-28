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
  Timer?  _clockTimer;
  String  _countdown = '00:00:00';
  // Track previous positions for change arrows
  final Map<String, int> _prevPositions = {};
  final Map<String, bool> _movedUp      = {};
  Timer? _arrowClearTimer;

  @override
  void initState() {
    super.initState();
    _updateCountdown();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _updateCountdown());
    });
  }

  void _updateCountdown() {
    _countdown = CompetitionService().resetCountdown;
  }

  void _snapshotPositions(List<LeaderboardEntry> board) {
    final newPositions = {for (var e in board) e.id: e.position};
    // Detect changes
    for (final e in board) {
      final prev = _prevPositions[e.id];
      if (prev != null && prev != e.position) {
        _movedUp[e.id] = e.position < prev; // lower number = higher rank
      }
    }
    _prevPositions.clear();
    _prevPositions.addAll(newPositions);

    // Clear arrows after 8s
    _arrowClearTimer?.cancel();
    _arrowClearTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) setState(() => _movedUp.clear());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _arrowClearTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<CompetitionService>();

    // Register position snapshots on every rebuild
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _snapshotPositions(svc.leaderboard);
    });

    // Gate: must register first
    if (!svc.isRegistered) {
      return RegistrationScreen(
        onRegistered: () {
          if (mounted) setState(() {});
        },
      );
    }

    final board      = svc.leaderboard;
    final events     = svc.liveEvents;
    final userPos    = svc.userPosition;
    final userScore  = svc.userScore;
    final ptsTop10   = svc.ptsToTop10;
    final ptsNext    = svc.ptsToNextPosition;
    final aboveEntry = svc.entryAboveUser;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.gradientBg),
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ───────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: AppColors.white40, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('🏆 Future Hope Competition',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Poppins',
                                color: AppColors.white)),
                        Text('Resets daily at midnight',
                            style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'Poppins',
                                color: AppColors.white40)),
                      ],
                    ),
                  ),
                  // Countdown
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: AppColors.bgCard,
                      border: Border.all(color: AppColors.white10),
                    ),
                    child: Row(children: [
                      const Icon(Icons.timer_outlined,
                          color: AppColors.neonBlue, size: 13),
                      const SizedBox(width: 4),
                      Text(_countdown,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Poppins',
                              color: AppColors.neonBlue)),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 12),

              // ── Prize strip ──────────────────────────────────────────────────
              _PrizeStrip(),
              const SizedBox(height: 8),

              // ── Leaderboard ──────────────────────────────────────────────────
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: board.length,
                  itemBuilder: (context, i) {
                    final entry   = board[i];
                    final isUser  = !entry.isBot;
                    final moved   = _movedUp[entry.id];

                    return _LeaderboardRow(
                      entry:   entry,
                      isUser:  isUser,
                      movedUp: moved,
                      prize:   _prizeFor(entry.position),
                    ).animate(delay: Duration(milliseconds: 20 * i))
                     .fadeIn(duration: 300.ms);
                  },
                ),
              ),

              // ── Your position card (fixed at bottom) ─────────────────────────
              if (svc.isRegistered) ...[
                _UserPositionCard(
                  userName:  svc.userName ?? '',
                  userFlag:  svc.userFlag ?? '🌍',
                  userScore: userScore,
                  userPos:   userPos,
                  ptsTop10:  ptsTop10,
                  ptsNext:   ptsNext,
                  aboveEntry: aboveEntry,
                ),
              ],

              // ── Live feed ─────────────────────────────────────────────────────
              if (events.isNotEmpty) _LiveFeedPanel(events: events),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  String? _prizeFor(int position) {
    if (position == 1) return '\$50';
    if (position == 2) return '\$40';
    if (position == 3) return '\$30';
    if (position == 4) return '\$20';
    if (position == 5) return '\$10';
    if (position <= 10) return '\$5';
    return null;
  }
}

// ── Prize strip ───────────────────────────────────────────────────────────────
class _PrizeStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [Color(0x33FFD700), Color(0x11FF8C00)],
        ),
        border: Border.all(color: const Color(0x33FFD700)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          const _PrizeChip(label: '💰 Daily Prizes', isTitle: true),
          const _PrizeChip(label: '🥇 \$50'),
          const _PrizeChip(label: '🥈 \$40'),
          const _PrizeChip(label: '🥉 \$30'),
          const _PrizeChip(label: '4th \$20'),
          const _PrizeChip(label: '5th \$10'),
          const _PrizeChip(label: '6-10th \$5 each'),
          const SizedBox(width: 8),
          Center(
            child: Text('📧 chastechnologiesllc@gmail.com',
                style: const TextStyle(
                    fontSize: 10,
                    fontFamily: 'Poppins',
                    color: AppColors.white40)),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _PrizeChip extends StatelessWidget {
  final String label;
  final bool   isTitle;
  const _PrizeChip({required this.label, this.isTitle = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Center(
        child: Text(label,
            style: TextStyle(
                fontSize: isTitle ? 12 : 11,
                fontWeight: isTitle ? FontWeight.w700 : FontWeight.w600,
                fontFamily: 'Poppins',
                color: isTitle
                    ? const Color(0xFFFFD700)
                    : const Color(0xCCFFD700))),
      ),
    );
  }
}

// ── Leaderboard row ───────────────────────────────────────────────────────────
class _LeaderboardRow extends StatelessWidget {
  final LeaderboardEntry entry;
  final bool             isUser;
  final bool?            movedUp;
  final String?          prize;

  const _LeaderboardRow({
    required this.entry,
    required this.isUser,
    this.movedUp,
    this.prize,
  });

  @override
  Widget build(BuildContext context) {
    final isElite  = entry.isElite;
    final pos      = entry.position;

    // Colors
    Color rowBg   = Colors.transparent;
    Color border  = Colors.transparent;
    if (isUser) {
      rowBg  = AppColors.neonBlue.withOpacity(0.08);
      border = AppColors.neonBlue.withOpacity(0.5);
    } else if (isElite) {
      rowBg  = const Color(0xFFFFD700).withOpacity(0.05);
      border = const Color(0xFFFFD700).withOpacity(0.18);
    }

    // Position medal / number
    Widget posWidget;
    if      (pos == 1) posWidget = const Text('👑', style: TextStyle(fontSize: 18));
    else if (pos == 2) posWidget = const Text('🥈', style: TextStyle(fontSize: 16));
    else if (pos == 3) posWidget = const Text('🥉', style: TextStyle(fontSize: 16));
    else               posWidget = SizedBox(
                            width: 28,
                            child: Text('$pos',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: isElite ? 14 : 13,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Poppins',
                                    color: isElite
                                        ? const Color(0xFFFFD700)
                                        : AppColors.white40)));

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: rowBg,
        border: Border.all(color: border, width: 1),
      ),
      child: Row(children: [
        // Position
        SizedBox(width: 32, child: posWidget),
        const SizedBox(width: 6),

        // Flag
        Text(entry.flag, style: const TextStyle(fontSize: 15)),
        const SizedBox(width: 8),

        // Name + country
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                if (isUser) ...[
                  const Text('★ ', style: TextStyle(
                      fontSize: 12, color: AppColors.neonBlue)),
                ],
                Flexible(
                  child: Text(
                    isUser ? '${entry.name} (You)' : entry.name,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: isUser || isElite
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontFamily: 'Poppins',
                        color: isUser
                            ? AppColors.neonBlue
                            : isElite
                                ? const Color(0xFFFFE066)
                                : AppColors.white),
                  ),
                ),
              ]),
              Text(entry.country,
                  style: const TextStyle(
                      fontSize: 10,
                      fontFamily: 'Poppins',
                      color: AppColors.white40)),
            ],
          ),
        ),

        // Score
        Text(_fmt(entry.score),
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontFamily: 'Poppins',
                color: isUser
                    ? AppColors.neonBlue
                    : isElite
                        ? const Color(0xFFFFD700)
                        : AppColors.white70)),
        const SizedBox(width: 6),

        // Prize
        if (prize != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: const Color(0x22FFD700),
            ),
            child: Text(prize!,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins',
                    color: Color(0xFFFFD700))),
          ),
        const SizedBox(width: 4),

        // Change arrow
        if (movedUp != null)
          Icon(
            movedUp! ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 12,
            color: movedUp!
                ? AppColors.neonGreen
                : AppColors.neonRed,
          ).animate().fadeIn(duration: 300.ms),

      ]),
    );
  }

  String _fmt(int v) {
    if (v >= 1000) {
      final k = v / 1000;
      return '${k.toStringAsFixed(k == k.floor() ? 0 : 1)}k';
    }
    return v.toString();
  }
}

// ── User pinned card ──────────────────────────────────────────────────────────
class _UserPositionCard extends StatelessWidget {
  final String  userName, userFlag;
  final int     userScore, userPos, ptsTop10, ptsNext;
  final LeaderboardEntry? aboveEntry;

  const _UserPositionCard({
    required this.userName,
    required this.userFlag,
    required this.userScore,
    required this.userPos,
    required this.ptsTop10,
    required this.ptsNext,
    this.aboveEntry,
  });

  @override
  Widget build(BuildContext context) {
    final String motivation;
    if (userPos == 0) {
      motivation = 'Play a level to enter the board!';
    } else if (userPos <= 10) {
      motivation = '🏆 You\'re in the prize zone!';
    } else if (ptsTop10 < 200) {
      motivation = '🔥 ${ptsTop10}pts to enter Top 10!';
    } else if (aboveEntry != null) {
      motivation = '⬆ ${ptsNext}pts to pass ${aboveEntry!.name.split(' ').first}';
    } else {
      motivation = 'Keep playing to climb the board!';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: AppColors.bgCard,
        border: Border.all(color: AppColors.neonBlue.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
              color: AppColors.neonBlue.withOpacity(0.12),
              blurRadius: 12,
              spreadRadius: 1)
        ],
      ),
      child: Row(children: [
        Text(userFlag, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Text('★ ', style: TextStyle(
                    fontSize: 12, color: AppColors.neonBlue)),
                Text(userName,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Poppins',
                        color: AppColors.neonBlue)),
              ]),
              Text(motivation,
                  style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'Poppins',
                      color: AppColors.white40)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(userPos > 0 ? 'Rank #$userPos' : 'Unranked',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins',
                    color: AppColors.white70)),
            Text('$userScore pts',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Poppins',
                    color: AppColors.neonBlue)),
          ],
        ),
      ]),
    );
  }
}

// ── Live feed ─────────────────────────────────────────────────────────────────
class _LiveFeedPanel extends StatefulWidget {
  final List<LiveEvent> events;
  const _LiveFeedPanel({required this.events});
  @override
  State<_LiveFeedPanel> createState() => _LiveFeedPanelState();
}

class _LiveFeedPanelState extends State<_LiveFeedPanel> {
  @override
  Widget build(BuildContext context) {
    final shown = widget.events.take(3).toList();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.bgCard,
        border: Border.all(color: AppColors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 7, height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.neonRed,
                boxShadow: [BoxShadow(
                    color: AppColors.neonRed.withOpacity(0.6),
                    blurRadius: 6)],
              ),
            ).animate(onPlay: (c) => c.repeat())
             .fadeOut(duration: 800.ms)
             .then()
             .fadeIn(duration: 800.ms),
            const SizedBox(width: 6),
            const Text('LIVE',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Poppins',
                    color: AppColors.neonRed,
                    letterSpacing: 1.5)),
          ]),
          const SizedBox(height: 6),
          ...shown.asMap().entries.map((e) {
            final event = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(children: [
                Text(event.flag, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(event.text,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'Poppins',
                          color: AppColors.white70)),
                ),
              ]),
            );
          }),
        ],
      ),
    );
  }
}
