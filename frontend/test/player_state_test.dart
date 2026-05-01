import 'package:flutter_test/flutter_test.dart';
import 'package:treescape/features/player/domain/player_state.dart';

void main() {
  test('player state parses nested movement, action, and skills', () {
    final player = PlayerState.fromJson({
      'user_id': 'user-1',
      'x': 12,
      'y': 5,
      'movement': {
        'from_x': 10,
        'from_y': 5,
        'target_x': 12,
        'target_y': 5,
        'path': [
          {'x': 11, 'y': 5},
          {'x': 12, 'y': 5},
        ],
        'started_at': '2026-04-24T15:00:00Z',
        'arrives_at': '2026-04-24T15:00:01Z',
        'speed_tiles_per_second': 5,
      },
      'action': {
        'id': 'action-1',
        'type': 'harvest',
        'entity_id': 'tree-1',
        'status': 'active',
        'started_at': '2026-04-24T15:00:00Z',
        'ends_at': '2026-04-24T15:00:10Z',
        'next_tick_at': '2026-04-24T15:00:03Z',
        'tick_interval_ms': 3000,
        'metadata': {'reward_item_key': 'oak_logs'},
        'updated_at': '2026-04-24T15:00:00Z',
      },
      'skills': [
        {
          'skill_key': 'woodcutting',
          'xp': 350,
          'level': 2,
          'updated_at': '2026-04-24T15:00:00Z',
        },
      ],
      'updated_at': '2026-04-24T15:00:00Z',
    });

    expect(player.userId, 'user-1');
    expect(player.renderX, 12);
    expect(player.renderY, 5);
    expect(player.movement?.path.length, 2);
    expect(player.movement?.speedTilesPerSecond, 5);
    expect(player.action?.rewardItemKey, 'oak_logs');
    expect(player.action?.tickIntervalMs, 3000);
    expect(player.skillByKey('woodcutting')?.level, 2);
  });

  test('copyWith can clear transient movement and action state', () {
    final original = PlayerState.fromJson({
      'user_id': 'user-1',
      'x': 1,
      'y': 2,
      'movement': {
        'from_x': 1,
        'from_y': 2,
        'target_x': 3,
        'target_y': 2,
        'path': const [],
        'started_at': '2026-04-24T15:00:00Z',
        'arrives_at': '2026-04-24T15:00:01Z',
      },
      'action': {
        'id': 'action-1',
        'type': 'harvest',
        'status': 'active',
        'started_at': '2026-04-24T15:00:00Z',
        'ends_at': '2026-04-24T15:00:01Z',
        'next_tick_at': '2026-04-24T15:00:01Z',
        'tick_interval_ms': 1000,
        'metadata': const {},
      },
    });

    final next = original.copyWith(
      x: 3,
      renderX: 3,
      clearMovement: true,
      clearAction: true,
    );

    expect(next.x, 3);
    expect(next.renderX, 3);
    expect(next.movement, isNull);
    expect(next.action, isNull);
  });

  test('player action progress clamps and defaults reward item key', () {
    final action = PlayerAction.fromJson({
      'id': 'action-1',
      'type': 'harvest',
      'status': 'active',
      'started_at': '2026-04-24T15:00:00Z',
      'ends_at': '2026-04-24T15:00:10Z',
      'next_tick_at': '2026-04-24T15:00:03Z',
      'tick_interval_ms': 3000,
    });

    expect(action.rewardItemKey, 'wood');
    expect(action.progress(DateTime.utc(2026, 4, 24, 14, 59, 59)), 0);
    expect(action.progress(DateTime.utc(2026, 4, 24, 15, 0, 5)), 0.5);
    expect(action.progress(DateTime.utc(2026, 4, 24, 15, 0, 12)), 1);
  });

  test('player skill progress uses XP thresholds derived from level', () {
    const skill = PlayerSkill(
      skillKey: 'woodcutting',
      xp: 350,
      level: 2,
      updatedAt: null,
    );

    expect(xpRequiredForLevel(1), 0);
    expect(xpRequiredForLevel(2), 300);
    expect(skill.currentLevelXP, 300);
    expect(skill.nextLevelXP, 800);
    expect(skill.progressToNextLevel, closeTo(0.1, 0.0001));
  });
}
