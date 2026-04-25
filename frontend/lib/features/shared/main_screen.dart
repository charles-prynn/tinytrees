import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/realtime/game_socket.dart';
import '../auth/data/auth_controller.dart';
import '../entities/data/entity_repository.dart';
import '../entities/domain/world_entity.dart';
import '../inventory/data/inventory_repository.dart';
import '../map/application/map_controller.dart';
import '../map/domain/tile_map.dart';
import '../player/application/player_controller.dart';
import '../player/domain/player_state.dart';
import '../rendering/tile_map_game.dart';
import 'widgets/game_loading_overlay.dart';
import 'widgets/game_hud.dart';

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
  bool _inventoryOpen = false;
  bool _loginOpen = false;
  bool _registrationOpen = false;

  @override
  void initState() {
    super.initState();
    final config = ref.read(appConfigProvider);
    _game = TileMapGame(
      showFps: config.debugFps,
      showCoordinateDebug: config.debugCord,
    );
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
    ref.listenManual(authControllerProvider, (_, next) {
      next.whenData((value) {
        if (value?.user.provider != 'guest' &&
            (_registrationOpen || _loginOpen) &&
            mounted) {
          setState(() {
            _loginOpen = false;
            _registrationOpen = false;
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final map = ref.watch(mapControllerProvider);
    final entities = ref.watch(worldEntitiesProvider);
    final player = ref.watch(playerControllerProvider);
    final inventory = ref.watch(inventoryProvider);
    final connectionState = ref.watch(gameSocketConnectionProvider);
    final socketState = connectionState.asData?.value;
    final loadingError = _loadingErrorMessage(
      map: map,
      entities: entities,
      player: player,
      inventory: inventory,
    );
    final loading =
        loadingError != null ||
        map.isLoading ||
        !map.hasValue ||
        entities.isLoading ||
        !entities.hasValue ||
        player.isLoading ||
        !player.hasValue ||
        inventory.isLoading ||
        !inventory.hasValue;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPressStart:
                  (details) =>
                      _setHoldLabel(_game.holdLabelAt(details.localPosition)),
              onLongPressMoveUpdate:
                  (details) =>
                      _setHoldLabel(_game.holdLabelAt(details.localPosition)),
              onLongPressEnd: (_) => _setHoldLabel(null),
              onLongPressUp: () => _setHoldLabel(null),
              onLongPressCancel: () => _setHoldLabel(null),
              onTapUp: _handleTapUp,
              child: GameWidget(game: _game),
            ),
          ),
          GameHud(
            inventoryOpen: _inventoryOpen,
            loginOpen: _loginOpen,
            registrationOpen: _registrationOpen,
            showCoordinateDebug: ref.watch(appConfigProvider).debugCord,
            onInventoryPressed: _toggleInventory,
            onInventoryClosed: _toggleInventory,
            onLoginPressed: _openLogin,
            onLoginClosed: _closeLogin,
            onRegistrationPressed: _openRegistration,
            onRegistrationClosed: _closeRegistration,
          ),
          if (loading)
            GameLoadingOverlay(
              mapReady: map.hasValue,
              resourcesReady: entities.hasValue,
              playerReady: player.hasValue,
              inventoryReady: inventory.hasValue,
              errorMessage: loadingError,
              onRetry: () => retryGameLoad(ref),
            ),
          if (!loading && socketState != null)
            if (socketState != GameSocketConnectionState.connected)
              GameConnectionBanner(state: socketState),
        ],
      ),
    );
  }

  String? _loadingErrorMessage({
    required AsyncValue<TileMap> map,
    required AsyncValue<List<WorldEntity>> entities,
    required AsyncValue<PlayerState> player,
    required AsyncValue<dynamic> inventory,
  }) {
    final error =
        map.asError?.error ??
        entities.asError?.error ??
        player.asError?.error ??
        inventory.asError?.error;
    if (error == null) {
      return null;
    }
    return '$error';
  }

  Future<void> _handleTapUp(TapUpDetails details) async {
    final interactionTarget = _game.entityInteractionTargetAtLocalPosition(
      details.localPosition,
    );
    if (interactionTarget != null) {
      await _moveAndHarvest(interactionTarget);
      return;
    }

    final tile = _game.tileAtLocalPosition(details.localPosition);
    if (tile == null ||
        !_game.isWalkableTileAtLocalPosition(details.localPosition)) {
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
  }

  void _setHoldLabel(String? value) {
    if (_holdLabel == value || !mounted) {
      return;
    }
    setState(() {
      _holdLabel = value;
    });
  }

  void _toggleInventory() {
    if (!mounted) {
      return;
    }
    setState(() {
      _inventoryOpen = !_inventoryOpen;
    });
  }

  void _openRegistration() {
    if (!mounted) {
      return;
    }
    setState(() {
      _loginOpen = false;
      _registrationOpen = true;
    });
  }

  void _closeRegistration() {
    if (!mounted) {
      return;
    }
    setState(() {
      _registrationOpen = false;
    });
  }

  void _openLogin() {
    if (!mounted) {
      return;
    }
    setState(() {
      _registrationOpen = false;
      _loginOpen = true;
    });
  }

  void _closeLogin() {
    if (!mounted) {
      return;
    }
    setState(() {
      _loginOpen = false;
    });
  }

  Future<void> _moveAndHarvest(EntityInteractionTarget target) async {
    final sequence = ++_interactionSequence;
    final controller = ref.read(playerControllerProvider.notifier);
    final moved = await controller.moveTo(x: target.tile.x, y: target.tile.y);
    if (!mounted || !moved || sequence != _interactionSequence) {
      return;
    }

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

    _game.facePlayer(target.facing);
    final started = await controller.startHarvest(entityId: target.entityId);
    if (!mounted || !started || sequence != _interactionSequence) {
      return;
    }
  }
}
