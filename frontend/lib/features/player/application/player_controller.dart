import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/player_repository.dart';
import '../domain/player_state.dart';

final playerControllerProvider =
    AsyncNotifierProvider<PlayerController, PlayerState>(PlayerController.new);

class PlayerController extends AsyncNotifier<PlayerState> {
  int _moveSequence = 0;

  @override
  Future<PlayerState> build() {
    return ref.watch(playerStateProvider.future);
  }

  Future<bool> moveTo({required int x, required int y}) async {
    final sequence = ++_moveSequence;
    final repository = ref.read(playerRepositoryProvider);
    final previous = state.value;
    try {
      final next = await repository.moveTo(x: x, y: y);
      if (sequence == _moveSequence) {
        state = AsyncData(next);
        return true;
      }
      return false;
    } catch (error, stackTrace) {
      if (sequence == _moveSequence) {
        state =
            previous == null
                ? AsyncError(error, stackTrace)
                : AsyncData(previous);
      }
      return false;
    }
  }
}
