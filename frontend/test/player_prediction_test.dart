import 'package:flutter_test/flutter_test.dart';
import 'package:treescape/features/entities/domain/world_entity.dart';
import 'package:treescape/features/map/domain/tile_map.dart';
import 'package:treescape/features/player/application/player_prediction.dart';
import 'package:treescape/features/player/domain/player_state.dart';

void main() {
  test('predictPlayerMove reroutes from the current logical tile', () {
    final current = PlayerState.fromJson({
      'user_id': 'user-1',
      'x': 10,
      'y': 5,
      'render_x': 10,
      'render_y': 5,
      'movement': {
        'client_move_id': 'move-1',
        'from_x': 10,
        'from_y': 5,
        'target_x': 12,
        'target_y': 5,
        'path': [
          {'x': 10, 'y': 5},
          {'x': 11, 'y': 5},
          {'x': 12, 'y': 5},
        ],
        'started_at': '2026-05-04T10:00:00Z',
        'arrives_at': '2026-05-04T10:00:02Z',
        'speed_tiles_per_second': 1,
      },
    });

    final predicted = predictPlayerMove(
      current: current,
      map: TileMap(
        width: 20,
        height: 20,
        tileSize: 32,
        tiles: List<int>.filled(400, 1),
        updatedAt: null,
      ),
      entities: const <WorldEntity>[],
      targetX: 14,
      targetY: 5,
      clientMoveId: 'move-2',
      now: DateTime.utc(2026, 5, 4, 10, 0, 1, 500),
    );
    final predictedPosition = predicted?.renderPositionAt(
      DateTime.utc(2026, 5, 4, 10, 0, 1, 500),
    );

    expect(predicted, isNotNull);
    expect(predicted!.movement?.clientMoveId, 'move-2');
    expect(predicted.x, 11);
    expect(predicted.y, 5);
    expect(predicted.renderX, closeTo(11.5, 0.0001));
    expect(predicted.renderY, closeTo(5, 0.0001));
    expect(predictedPosition?.x, closeTo(11.5, 0.0001));
    expect(predictedPosition?.y, closeTo(5, 0.0001));
    expect(predicted.movement?.path.first.x, 11);
    expect(predicted.movement?.path.first.y, 5);
    expect(predicted.movement?.path.last.x, 14);
    expect(predicted.movement?.path.last.y, 5);
  });

  test('movementPlansMatch compares route shape and speed', () {
    final first = PlayerMovement.fromJson({
      'client_move_id': 'move-1',
      'from_x': 10,
      'from_y': 5,
      'target_x': 12,
      'target_y': 5,
      'path': [
        {'x': 10, 'y': 5},
        {'x': 11, 'y': 5},
        {'x': 12, 'y': 5},
      ],
      'started_at': '2026-05-04T10:00:00Z',
      'arrives_at': '2026-05-04T10:00:02Z',
      'speed_tiles_per_second': 1,
    });
    final second = PlayerMovement.fromJson({
      'client_move_id': 'move-2',
      'from_x': 10,
      'from_y': 5,
      'target_x': 12,
      'target_y': 5,
      'path': [
        {'x': 10, 'y': 5},
        {'x': 11, 'y': 5},
        {'x': 12, 'y': 5},
      ],
      'started_at': '2026-05-04T10:00:01Z',
      'arrives_at': '2026-05-04T10:00:03Z',
      'speed_tiles_per_second': 1,
    });
    final different = PlayerMovement.fromJson({
      'client_move_id': 'move-3',
      'from_x': 10,
      'from_y': 5,
      'target_x': 12,
      'target_y': 6,
      'path': [
        {'x': 10, 'y': 5},
        {'x': 11, 'y': 6},
        {'x': 12, 'y': 6},
      ],
      'started_at': '2026-05-04T10:00:01Z',
      'arrives_at': '2026-05-04T10:00:03Z',
      'speed_tiles_per_second': 1,
    });

    expect(movementPlansMatch(first, second), isTrue);
    expect(movementPlansMatch(first, different), isFalse);
  });
}
