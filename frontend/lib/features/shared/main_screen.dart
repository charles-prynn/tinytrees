import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/data/auth_controller.dart';
import '../entities/data/entity_repository.dart';
import '../entities/domain/world_entity.dart';
import '../map/application/map_controller.dart';
import '../map/domain/tile_map.dart';
import '../player/application/player_controller.dart';
import '../player/domain/player_state.dart';
import '../rendering/tile_map_game.dart';
import '../state/data/state_repository.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  late final TileMapGame _game;
  TileMap? _lastTileMap;
  List<WorldEntity>? _lastEntities;
  PlayerState? _lastPlayer;
  String? _holdLabel;

  @override
  void initState() {
    super.initState();
    _game = TileMapGame();
    ref.listenManual<AsyncValue<TileMap>>(mapControllerProvider, (_, next) {
      next.whenData((value) {
        if (!identical(_lastTileMap, value)) {
          _lastTileMap = value;
          _game.setTileMap(value);
        }
      });
    });
    ref.listenManual<AsyncValue<List<WorldEntity>>>(worldEntitiesProvider, (
      _,
      next,
    ) {
      next.whenData((value) {
        if (!identical(_lastEntities, value)) {
          _lastEntities = value;
          _game.setEntities(value);
        }
      });
    });
    ref.listenManual<AsyncValue<PlayerState>>(playerControllerProvider, (
      _,
      next,
    ) {
      next.whenData((value) {
        if (!identical(_lastPlayer, value)) {
          _lastPlayer = value;
          _game.setPlayer(value);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider).value;
    final snapshot = ref.watch(stateSnapshotProvider);
    final tileMap = ref.watch(mapControllerProvider);
    final player = ref.watch(playerControllerProvider);
    ref.watch(worldEntitiesProvider);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPressStart: (details) {
                _setHoldLabel(_game.holdLabelAt(details.localPosition));
              },
              onLongPressMoveUpdate: (details) {
                _setHoldLabel(_game.holdLabelAt(details.localPosition));
              },
              onLongPressEnd: (_) => _setHoldLabel(null),
              onLongPressUp: () => _setHoldLabel(null),
              onLongPressCancel: () => _setHoldLabel(null),
              onTapUp: (details) async {
                final interactionTarget = _game
                    .entityInteractionTargetAtLocalPosition(
                      details.localPosition,
                    );
                if (interactionTarget != null) {
                  final moved = await ref
                      .read(playerControllerProvider.notifier)
                      .moveTo(
                        x: interactionTarget.tile.x,
                        y: interactionTarget.tile.y,
                      );
                  if (!mounted || !moved) {
                    return;
                  }
                  _game.facePlayer(interactionTarget.facing);
                  return;
                }

                final tile = _game.tileAtLocalPosition(details.localPosition);
                if (tile == null ||
                    !_game.isWalkableTileAtLocalPosition(
                      details.localPosition,
                    )) {
                  return;
                }
                final moved = await ref
                    .read(playerControllerProvider.notifier)
                    .moveTo(x: tile.x, y: tile.y);
                if (!mounted || !moved) {
                  return;
                }
                _game.showWalkIconAt(tile);
              },
              child: GameWidget(game: _game),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: _TopBar(
                holdLabel: _holdLabel,
                displayName: auth?.user.displayName,
                onLogout:
                    () => ref.read(authControllerProvider.notifier).logout(),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 60, 12, 0),
              child: Align(
                alignment: Alignment.topCenter,
                child: _MapPanel(tileMap: tileMap),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: _StatePanel(snapshot: snapshot, player: player),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _setHoldLabel(String? value) {
    if (_holdLabel == value || !mounted) {
      return;
    }
    setState(() {
      _holdLabel = value;
    });
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.holdLabel,
    required this.displayName,
    required this.onLogout,
  });

  final String? holdLabel;
  final String? displayName;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            holdLabel ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(width: 12),
        if (displayName != null) ...[
          Text(displayName!),
          const SizedBox(width: 12),
        ],
        TextButton(onPressed: onLogout, child: const Text('Logout')),
      ],
    );
  }
}

class _MapPanel extends ConsumerWidget {
  const _MapPanel({required this.tileMap});

  final AsyncValue<TileMap> tileMap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      borderRadius: BorderRadius.circular(8),
      color: Theme.of(context).colorScheme.surface,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: tileMap.when(
          data:
              (value) => Text(
                'Map ${value.width}x${value.height} | source tile ${value.tileSize}px',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          loading: () => const LinearProgressIndicator(),
          error:
              (error, _) => Row(
                children: [
                  Expanded(
                    child: Text(
                      'Map load failed: $error',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(mapControllerProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
        ),
      ),
    );
  }
}

class _StatePanel extends ConsumerWidget {
  const _StatePanel({required this.snapshot, required this.player});

  final AsyncValue snapshot;
  final AsyncValue<PlayerState> player;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      borderRadius: BorderRadius.circular(8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: snapshot.when(
          data:
              (value) => Row(
                children: [
                  Text('State version ${value.version}'),
                  const SizedBox(width: 12),
                  player.when(
                    data:
                        (value) =>
                            Text(value.movement == null ? 'Idle' : 'Walking'),
                    loading:
                        () => const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    error: (_, _) => const Text('Player offline'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      value.updatedAt == null
                          ? 'No sync yet'
                          : 'Updated ${value.updatedAt!.toLocal()}',
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
          loading: () => const LinearProgressIndicator(),
          error:
              (error, _) => Row(
                children: [
                  Expanded(
                    child: Text(
                      'State load failed: $error',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(stateSnapshotProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
        ),
      ),
    );
  }
}
