part of '../player_state.dart';

class PlayerSkill {
  const PlayerSkill({
    required this.skillKey,
    required this.xp,
    required this.level,
    required this.updatedAt,
  });

  final String skillKey;
  final int xp;
  final int level;
  final DateTime? updatedAt;

  factory PlayerSkill.fromJson(Map<String, dynamic> json) {
    return PlayerSkill(
      skillKey: json['skill_key'] as String? ?? '',
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 1,
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
    );
  }

  int get nextLevel => level + 1;

  int get currentLevelXP => xpRequiredForLevel(level);

  int get nextLevelXP => xpRequiredForLevel(nextLevel);

  double get progressToNextLevel {
    final span = nextLevelXP - currentLevelXP;
    if (span <= 0) {
      return 1;
    }
    final earned = (xp - currentLevelXP).clamp(0, span);
    return earned / span;
  }
}
