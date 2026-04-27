part of '../player_state.dart';

class PlayerState {
  const PlayerState({
    required this.userId,
    required this.x,
    required this.y,
    required this.renderX,
    required this.renderY,
    required this.movement,
    required this.action,
    required this.skills,
    required this.updatedAt,
  });

  final String userId;
  final int x;
  final int y;
  final double renderX;
  final double renderY;
  final PlayerMovement? movement;
  final PlayerAction? action;
  final List<PlayerSkill> skills;
  final DateTime? updatedAt;

  factory PlayerState.fromJson(Map<String, dynamic> json) {
    final movement = json['movement'];
    final action = json['action'];
    return PlayerState(
      userId: json['user_id'] as String? ?? '',
      x: (json['x'] as num?)?.toInt() ?? 0,
      y: (json['y'] as num?)?.toInt() ?? 0,
      renderX:
          (json['render_x'] as num?)?.toDouble() ??
          ((json['x'] as num?)?.toDouble() ?? 0),
      renderY:
          (json['render_y'] as num?)?.toDouble() ??
          ((json['y'] as num?)?.toDouble() ?? 0),
      movement:
          movement is Map<String, dynamic>
              ? PlayerMovement.fromJson(movement)
              : null,
      action:
          action is Map<String, dynamic> ? PlayerAction.fromJson(action) : null,
      skills:
          (json['skills'] as List<dynamic>? ?? const [])
              .map(
                (skill) => PlayerSkill.fromJson(skill as Map<String, dynamic>),
              )
              .toList(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
    );
  }

  PlayerState copyWith({
    int? x,
    int? y,
    double? renderX,
    double? renderY,
    PlayerMovement? movement,
    bool clearMovement = false,
    PlayerAction? action,
    bool clearAction = false,
    List<PlayerSkill>? skills,
    DateTime? updatedAt,
  }) {
    return PlayerState(
      userId: userId,
      x: x ?? this.x,
      y: y ?? this.y,
      renderX: renderX ?? this.renderX,
      renderY: renderY ?? this.renderY,
      movement: clearMovement ? null : (movement ?? this.movement),
      action: clearAction ? null : (action ?? this.action),
      skills: skills ?? this.skills,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  PlayerSkill? skillByKey(String skillKey) {
    for (final skill in skills) {
      if (skill.skillKey == skillKey) {
        return skill;
      }
    }
    return null;
  }
}
