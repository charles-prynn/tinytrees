import 'dart:math' as math;

import '../../entities/domain/world_entity.dart';
import '../../map/domain/tile_map.dart';
import '../domain/player_state.dart';

const predictedPlayerSpeedTilesPerSecond = 3.0;

PlayerState? predictPlayerMove({
  required PlayerState current,
  required TileMap map,
  required List<WorldEntity> entities,
  required int targetX,
  required int targetY,
  required String clientMoveId,
  required DateTime now,
}) {
  final target = MapPoint(x: targetX, y: targetY);
  final blockedTiles = _blockedEntityTiles(entities);
  if (!_isWalkable(map, blockedTiles, target)) {
    return null;
  }

  final from = current.logicalPositionAt(now);
  blockedTiles.remove(_pointKey(from));
  final path = _fastestPath(map, blockedTiles, from, target);
  if (path.length <= 1) {
    return current.copyWith(
      x: targetX,
      y: targetY,
      renderX: targetX.toDouble(),
      renderY: targetY.toDouble(),
      clearMovement: true,
    );
  }

  final livePosition = current.renderPositionAt(now);
  final initialProgressDistance = _resumeDistanceForPrediction(
    path,
    livePosition.x,
    livePosition.y,
  );
  final startedAt = now.subtract(
    Duration(
      microseconds:
          (initialProgressDistance / predictedPlayerSpeedTilesPerSecond *
                  Duration.microsecondsPerSecond)
              .round(),
    ),
  );
  final duration = Duration(
    microseconds:
        (_pathDistance(path) / predictedPlayerSpeedTilesPerSecond *
                Duration.microsecondsPerSecond)
            .round(),
  );
  final movement = PlayerMovement(
    clientMoveId: clientMoveId,
    fromX: from.x,
    fromY: from.y,
    targetX: targetX,
    targetY: targetY,
    path: path,
    startedAt: startedAt,
    arrivesAt: startedAt.add(duration),
    speedTilesPerSecond: predictedPlayerSpeedTilesPerSecond,
  );

  return current.copyWith(
    x: from.x,
    y: from.y,
    renderX: livePosition.x,
    renderY: livePosition.y,
    movement: movement,
  );
}

bool movementPlansMatch(PlayerMovement first, PlayerMovement second) {
  if (first.targetX != second.targetX ||
      first.targetY != second.targetY ||
      first.path.length != second.path.length) {
    return false;
  }
  if ((first.speedTilesPerSecond - second.speedTilesPerSecond).abs() > 0.0001) {
    return false;
  }
  for (var index = 0; index < first.path.length; index++) {
    if (first.path[index].x != second.path[index].x ||
        first.path[index].y != second.path[index].y) {
      return false;
    }
  }
  return true;
}

List<MapPoint> _fastestPath(
  TileMap tileMap,
  Set<String> blockedTiles,
  MapPoint from,
  MapPoint target,
) {
  if (from.x == target.x && from.y == target.y) {
    return [from];
  }

  final open = <_PathNode>[
    _PathNode(point: from, priority: _heuristic(from, target)),
  ];
  final cameFrom = <String, MapPoint>{};
  final costSoFar = <String, double>{_pointKey(from): 0};

  while (open.isNotEmpty) {
    open.sort((left, right) => left.priority.compareTo(right.priority));
    final current = open.removeAt(0).point;
    if (current.x == target.x && current.y == target.y) {
      return _reconstructPath(cameFrom, from, target);
    }

    for (final next in _neighbors(tileMap, blockedTiles, current)) {
      final newCost =
          (costSoFar[_pointKey(current)] ?? 0) + _stepCost(current, next);
      final nextKey = _pointKey(next);
      final knownCost = costSoFar[nextKey];
      if (knownCost != null && newCost >= knownCost) {
        continue;
      }

      costSoFar[nextKey] = newCost;
      cameFrom[nextKey] = current;
      open.add(
        _PathNode(
          point: next,
          priority: newCost + _heuristic(next, target),
        ),
      );
    }
  }

  return [from];
}

Iterable<MapPoint> _neighbors(
  TileMap tileMap,
  Set<String> blockedTiles,
  MapPoint point,
) sync* {
  const directions = <MapPoint>[
    MapPoint(x: -1, y: -1),
    MapPoint(x: 0, y: -1),
    MapPoint(x: 1, y: -1),
    MapPoint(x: -1, y: 0),
    MapPoint(x: 1, y: 0),
    MapPoint(x: -1, y: 1),
    MapPoint(x: 0, y: 1),
    MapPoint(x: 1, y: 1),
  ];

  for (final direction in directions) {
    final next = MapPoint(x: point.x + direction.x, y: point.y + direction.y);
    if (!_isWalkable(tileMap, blockedTiles, next)) {
      continue;
    }
    if (direction.x != 0 &&
        direction.y != 0 &&
        _cutsBlockedCorner(tileMap, blockedTiles, point, direction)) {
      continue;
    }
    yield next;
  }
}

bool _isWalkable(TileMap tileMap, Set<String> blockedTiles, MapPoint point) {
  if (point.x < 0 ||
      point.y < 0 ||
      point.x >= tileMap.width ||
      point.y >= tileMap.height) {
    return false;
  }
  if (blockedTiles.contains(_pointKey(point))) {
    return false;
  }
  return tileMap.tileAt(point.x, point.y) > 0;
}

bool _cutsBlockedCorner(
  TileMap tileMap,
  Set<String> blockedTiles,
  MapPoint point,
  MapPoint direction,
) {
  final horizontal = MapPoint(x: point.x + direction.x, y: point.y);
  final vertical = MapPoint(x: point.x, y: point.y + direction.y);
  return !_isWalkable(tileMap, blockedTiles, horizontal) ||
      !_isWalkable(tileMap, blockedTiles, vertical);
}

Set<String> _blockedEntityTiles(List<WorldEntity> entities) {
  final blocked = <String>{};
  for (final entity in entities) {
    if (!_entityBlocksMovement(entity)) {
      continue;
    }

    final width = math.max(1, entity.width);
    final height = math.max(1, entity.height);
    for (var y = entity.y; y < entity.y + height; y++) {
      for (var x = entity.x; x < entity.x + width; x++) {
        blocked.add(_pointKey(MapPoint(x: x, y: y)));
      }
    }
  }
  return blocked;
}

bool _entityBlocksMovement(WorldEntity entity) {
  return !entity.isDepleted && (entity.type == 'resource' || entity.isBank);
}

List<MapPoint> _reconstructPath(
  Map<String, MapPoint> cameFrom,
  MapPoint from,
  MapPoint target,
) {
  final path = <MapPoint>[target];
  var current = target;
  while (current.x != from.x || current.y != from.y) {
    final previous = cameFrom[_pointKey(current)];
    if (previous == null) {
      return [from];
    }
    current = previous;
    path.add(current);
  }
  return path.reversed.toList(growable: false);
}

double _pathDistance(List<MapPoint> path) {
  var distance = 0.0;
  for (var index = 0; index < path.length - 1; index++) {
    distance += _stepCost(path[index], path[index + 1]);
  }
  return distance;
}

double _heuristic(MapPoint from, MapPoint target) {
  final dx = (from.x - target.x).abs().toDouble();
  final dy = (from.y - target.y).abs().toDouble();
  final diagonal = math.min(dx, dy);
  final straight = math.max(dx, dy) - diagonal;
  return diagonal * math.sqrt2 + straight;
}

double _stepCost(MapPoint from, MapPoint to) {
  final dx = (from.x - to.x).abs().toDouble();
  final dy = (from.y - to.y).abs().toDouble();
  if (dx == 1 && dy == 1) {
    return math.sqrt2;
  }
  return math.max(dx, dy);
}

double _resumeDistanceForPrediction(
  List<MapPoint> path,
  double liveX,
  double liveY,
) {
  if (path.length < 2) {
    return 0;
  }

  final from = path[0];
  final to = path[1];
  final vx = (to.x - from.x).toDouble();
  final vy = (to.y - from.y).toDouble();
  final lengthSquared = vx * vx + vy * vy;
  if (lengthSquared <= 0) {
    return 0;
  }

  final px = liveX - from.x;
  final py = liveY - from.y;
  final progress = ((px * vx) + (py * vy)) / lengthSquared;
  if (progress <= 0 || progress >= 1) {
    return 0;
  }

  final projectedX = from.x + vx * progress;
  final projectedY = from.y + vy * progress;
  if ((projectedX - liveX).abs() > 0.05 || (projectedY - liveY).abs() > 0.05) {
    return 0;
  }

  return _stepCost(from, to) * progress;
}

String _pointKey(MapPoint point) => '${point.x}:${point.y}';

class _PathNode {
  const _PathNode({required this.point, required this.priority});

  final MapPoint point;
  final double priority;
}
