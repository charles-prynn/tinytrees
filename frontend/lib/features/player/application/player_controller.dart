import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/realtime/game_socket.dart';
import '../../entities/data/entity_repository.dart';
import '../../map/application/map_controller.dart';
import '../data/player_repository.dart';
import '../domain/player_state.dart';
import 'player_prediction.dart';

final playerControllerProvider =
    AsyncNotifierProvider<PlayerController, PlayerState>(PlayerController.new);

class PlayerController extends AsyncNotifier<PlayerState> {
  int _moveSequence = 0;
  String? _expectedMoveId;
  Timer? _movementSettleTimer;

  @override
  Future<PlayerState> build() async {
    final socket = ref.watch(gameSocketProvider);
    final subscription = socket.messagesOfType('player.updated').listen((data) {
      final player = data['player'];
      if (player is Map<String, dynamic>) {
        _applyAuthoritativePlayer(PlayerState.fromJson(player));
      }
    });
    ref.onDispose(() {
      _movementSettleTimer?.cancel();
      subscription.cancel();
    });
    return ref.watch(playerStateProvider.future);
  }

  Future<bool> moveTo({required int x, required int y}) async {
    final sequence = ++_moveSequence;
    final repository = ref.read(playerRepositoryProvider);
    final previous = state.value;
    final now = DateTime.now().toUtc();
    final clientMoveId = '$sequence-${now.microsecondsSinceEpoch}';
    _expectedMoveId = clientMoveId;
    final predicted = _predictMove(
      current: previous,
      x: x,
      y: y,
      clientMoveId: clientMoveId,
      now: now,
    );
    if (predicted != null) {
      state = AsyncData(predicted);
      _scheduleMovementSettle(sequence, predicted);
    }
    try {
      final next = await repository.moveTo(
        x: x,
        y: y,
        clientMoveId: clientMoveId,
      );
      if (sequence == _moveSequence) {
        _applyAuthoritativePlayer(next);
        return true;
      }
      return false;
    } catch (error, stackTrace) {
      if (sequence == _moveSequence) {
        _expectedMoveId = null;
        state =
            previous == null
                ? AsyncError(error, stackTrace)
                : AsyncData(previous);
      }
      return false;
    }
  }

  Future<Object?> startHarvest({required String entityId}) async {
    final sequence = ++_moveSequence;
    _movementSettleTimer?.cancel();
    _expectedMoveId = null;
    final repository = ref.read(playerRepositoryProvider);
    final previous = state.value;
    try {
      await repository.startHarvest(entityId: entityId);
      final next = await repository.fetch();
      if (sequence == _moveSequence) {
        state = AsyncData(next);
        return null;
      }
      return null;
    } catch (error, stackTrace) {
      if (sequence == _moveSequence) {
        state =
            previous == null
                ? AsyncError(error, stackTrace)
                : AsyncData(previous);
      }
      if (error is AppError) {
        return error;
      }
      return AppError(error.toString(), cause: error);
    }
  }

  PlayerState? _predictMove({
    required PlayerState? current,
    required int x,
    required int y,
    required String clientMoveId,
    required DateTime now,
  }) {
    if (current == null) {
      return null;
    }

    final map = ref.read(mapControllerProvider).asData?.value;
    final entities = ref.read(worldEntitiesProvider).asData?.value;
    if (map == null || entities == null) {
      return null;
    }

    return predictPlayerMove(
      current: current,
      map: map,
      entities: entities,
      targetX: x,
      targetY: y,
      clientMoveId: clientMoveId,
      now: now,
    );
  }

  void _applyAuthoritativePlayer(PlayerState authoritative) {
    final current = state.value;
    final expectedMoveId = _expectedMoveId?.trim();
    final authoritativeMoveId = authoritative.movement?.clientMoveId.trim() ?? '';
    final now = DateTime.now().toUtc();

    if (expectedMoveId != null && expectedMoveId.isNotEmpty) {
      if (authoritative.movement != null && authoritativeMoveId != expectedMoveId) {
        return;
      }
      if (authoritative.movement == null &&
          current?.movement?.clientMoveId == expectedMoveId &&
          current!.hasActiveMovementAt(now)) {
        return;
      }
    }

    var next = authoritative;
    if (current != null &&
        current.movement != null &&
        authoritative.movement != null &&
        authoritativeMoveId.isNotEmpty &&
        authoritativeMoveId == expectedMoveId &&
        movementPlansMatch(current.movement!, authoritative.movement!)) {
      final livePosition = current.renderPositionAt(now);
      final logicalPosition = current.logicalPositionAt(now);
      next = authoritative.copyWith(
        x: logicalPosition.x,
        y: logicalPosition.y,
        renderX: livePosition.x,
        renderY: livePosition.y,
        movement: current.movement,
      );
    }

    if (next.movement == null) {
      _expectedMoveId = null;
    } else if (next.movement!.clientMoveId.isNotEmpty) {
      _expectedMoveId = next.movement!.clientMoveId;
    }

    state = AsyncData(next);
    _scheduleMovementSettle(_moveSequence, next);
  }

  void _scheduleMovementSettle(int sequence, PlayerState player) {
    _movementSettleTimer?.cancel();

    final movement = player.movement;
    if (movement == null) {
      return;
    }

    final now = DateTime.now().toUtc();
    var delay = movement.arrivesAt.difference(now);
    if (delay.isNegative) {
      delay = Duration.zero;
    }
    delay += const Duration(milliseconds: 100);

    _movementSettleTimer = Timer(delay, () async {
      if (sequence != _moveSequence) {
        return;
      }

      final repository = ref.read(playerRepositoryProvider);
      try {
        final settled = await repository.fetch();
        if (sequence == _moveSequence) {
          state = AsyncData(settled);
        }
      } catch (_) {
        return;
      }
    });
  }
}
