class BotProfile {
  final String name;
  final String country;
  final String flag;
  const BotProfile({required this.name, required this.country, required this.flag});
}

class LeaderboardEntry {
  final String id;
  final String name;
  final String country;
  final String flag;
  final int score;
  final bool isBot;
  final bool isElite; // top 10 zone bots
  final int position;

  const LeaderboardEntry({
    required this.id,
    required this.name,
    required this.country,
    required this.flag,
    required this.score,
    required this.isBot,
    required this.isElite,
    required this.position,
  });

  LeaderboardEntry copyWith({
    String? id,
    String? name,
    String? country,
    String? flag,
    int? score,
    bool? isBot,
    bool? isElite,
    int? position,
  }) {
    return LeaderboardEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      country: country ?? this.country,
      flag: flag ?? this.flag,
      score: score ?? this.score,
      isBot: isBot ?? this.isBot,
      isElite: isElite ?? this.isElite,
      position: position ?? this.position,
    );
  }
}

class LiveEvent {
  final String text;
  final String flag;
  final DateTime timestamp;
  const LiveEvent({
    required this.text,
    required this.flag,
    required this.timestamp,
  });
}
