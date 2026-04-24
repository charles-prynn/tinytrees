import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../entities/data/entity_repository.dart';
import '../entities/domain/world_entity.dart';
import '../inventory/data/inventory_repository.dart';
import '../inventory/domain/inventory_item.dart';
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
  int _interactionSequence = 0;
  Timer? _actionPoller;

  @override
  void initState() {
    super.initState();
    _game = TileMapGame(showFps: ref.read(appConfigProvider).debugFps);
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
        _syncActionPoller(value.action);
      });
    });
  }

  @override
  void dispose() {
    _actionPoller?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(stateSnapshotProvider);
    final player = ref.watch(playerControllerProvider);
    final inventory = ref.watch(inventoryProvider);
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
                  await _moveAndHarvest(interactionTarget);
                  return;
                }

                final tile = _game.tileAtLocalPosition(details.localPosition);
                if (tile == null ||
                    !_game.isWalkableTileAtLocalPosition(
                      details.localPosition,
                    )) {
                  return;
                }
                _interactionSequence++;
                _game.showWalkIconAt(tile);
                final moved = await ref
                    .read(playerControllerProvider.notifier)
                    .moveTo(x: tile.x, y: tile.y);
                if (!mounted || !moved) {
                  return;
                }
              },
              child: GameWidget(game: _game),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: const _TopBar(),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: _StatePanel(
                  snapshot: snapshot,
                  player: player,
                  inventory: inventory,
                ),
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

  Future<void> _moveAndHarvest(EntityInteractionTarget target) async {
    final sequence = ++_interactionSequence;
    final controller = ref.read(playerControllerProvider.notifier);
    _game.showWalkIconAt(target.tile);
    final moved = await controller.moveTo(x: target.tile.x, y: target.tile.y);
    if (!mounted || !moved || sequence != _interactionSequence) {
      return;
    }
    _game.facePlayer(target.facing);

    final movement = ref.read(playerControllerProvider).value?.movement;
    if (movement != null) {
      final delay = movement.arrivesAt.difference(DateTime.now().toUtc());
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay + const Duration(milliseconds: 100));
      }
    }
    if (!mounted || sequence != _interactionSequence) {
      return;
    }

    final started = await controller.startHarvest(entityId: target.entityId);
    if (!mounted || !started || sequence != _interactionSequence) {
      return;
    }
    ref.invalidate(inventoryProvider);
  }

  void _syncActionPoller(PlayerAction? action) {
    if (action == null) {
      _actionPoller?.cancel();
      _actionPoller = null;
      return;
    }
    if (_actionPoller != null) {
      return;
    }
    _actionPoller = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) {
        return;
      }
      ref.invalidate(inventoryProvider);
      ref.invalidate(playerControllerProvider);
      if (!DateTime.now().toUtc().isBefore(action.endsAt)) {
        _actionPoller?.cancel();
        _actionPoller = null;
      }
    });
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  static const _barHeight = 50.0;
  static const _capSourceWidth = 25.0;
  static const _sourceHeight = 130.0;

  double get _capWidth => _barHeight * (_capSourceWidth / _sourceHeight);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        height: _barHeight,
        width: double.infinity,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: _capWidth,
              child: const Image(
                image: AssetImage('assets/images/ui/bar/left-bar.png'),
                fit: BoxFit.fill,
                filterQuality: FilterQuality.none,
              ),
            ),
            Expanded(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/ui/bar/middle-bar.png'),
                    repeat: ImageRepeat.repeatX,
                    fit: BoxFit.fitHeight,
                    alignment: Alignment.centerLeft,
                    filterQuality: FilterQuality.none,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: _capWidth,
              child: const Image(
                image: AssetImage('assets/images/ui/bar/right-bar.png'),
                fit: BoxFit.fill,
                filterQuality: FilterQuality.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatePanel extends ConsumerWidget {
  const _StatePanel({
    required this.snapshot,
    required this.player,
    required this.inventory,
  });

  final AsyncValue snapshot;
  final AsyncValue<PlayerState> player;
  final AsyncValue<List<InventoryItem>> inventory;

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
                        (value) => Text(
                          value.action != null
                              ? 'Harvesting ${value.action!.rewardItemKey}'
                              : value.movement == null
                              ? 'Idle'
                              : 'Walking',
                        ),
                    loading:
                        () => const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    error: (_, _) => const Text('Player offline'),
                  ),
                  const SizedBox(width: 12),
                  inventory.when(
                    data: (items) => Text(_inventorySummary(items)),
                    loading:
                        () => const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    error: (_, _) => const Text('Inventory offline'),
                  ),
                  const SizedBox(width: 12),
                  player.when(
                    data: (value) => Text(_woodcuttingSummary(value)),
                    loading:
                        () => const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    error: (_, _) => const Text('Skills offline'),
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

  String _inventorySummary(List<InventoryItem> items) {
    final wood = items
        .where((item) => item.itemKey == 'wood')
        .fold<int>(0, (total, item) => total + item.quantity);
    return 'Wood $wood';
  }

  String _woodcuttingSummary(PlayerState player) {
    final skill = player.skillByKey('woodcutting');
    if (skill == null) {
      return 'Woodcutting Lv 1 (0 XP)';
    }
    final remaining = skill.nextLevelXP - skill.xp;
    return 'Woodcutting Lv ${skill.level} (${skill.xp} XP, ${remaining > 0 ? remaining : 0} to next)';
  }
}
