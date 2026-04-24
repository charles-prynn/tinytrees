import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../auth/data/auth_controller.dart';
import '../entities/data/entity_repository.dart';
import '../entities/domain/world_entity.dart';
import '../inventory/data/inventory_repository.dart';
import '../inventory/domain/inventory_item.dart';
import '../map/application/map_controller.dart';
import '../map/domain/tile_map.dart';
import '../player/application/player_controller.dart';
import '../player/domain/player_state.dart';
import '../rendering/tile_map_game.dart';

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
  bool _inventoryOpen = false;

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
              child: _TopBar(
                inventoryOpen: _inventoryOpen,
                onInventoryPressed: _toggleInventory,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Align(
                alignment: Alignment.bottomCenter,
                child:
                    _inventoryOpen
                        ? _InventoryDrawer(
                          inventory: inventory,
                          onClose: _toggleInventory,
                        )
                        : const SizedBox.shrink(),
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

  void _toggleInventory() {
    if (!mounted) {
      return;
    }
    setState(() {
      _inventoryOpen = !_inventoryOpen;
    });
  }

  Future<void> _moveAndHarvest(EntityInteractionTarget target) async {
    final sequence = ++_interactionSequence;
    final controller = ref.read(playerControllerProvider.notifier);
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

class _TopBar extends ConsumerWidget {
  const _TopBar({
    required this.inventoryOpen,
    required this.onInventoryPressed,
  });

  static const _barHeight = 65.0;
  static const _capSourceWidth = 25.0;
  static const _sourceHeight = 130.0;
  static const _segmentCount = 4;

  final bool inventoryOpen;
  final VoidCallback onInventoryPressed;

  double get _capWidth => _barHeight * (_capSourceWidth / _sourceHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerControllerProvider);
    final auth = ref.watch(authControllerProvider);

    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        height: _barHeight,
        width: double.infinity,
        child: Stack(
          children: [
            Row(
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
                        image: AssetImage(
                          'assets/images/ui/bar/middle-bar.png',
                        ),
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
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  _capWidth + 8,
                  6,
                  _capWidth + 8,
                  6,
                ),
                child: Row(
                  children: List.generate(
                    _segmentCount,
                    (index) => Expanded(
                      child:
                          index == 0
                              ? _WoodcuttingTopBarSection(
                                showDivider: false,
                                player: player,
                              )
                              : index == 1
                              ? _InventoryTopBarSection(
                                showDivider: true,
                                inventoryOpen: inventoryOpen,
                                onPressed: onInventoryPressed,
                              )
                              : index == 2
                              ? _ActivityTopBarSection(
                                showDivider: true,
                                player: player,
                              )
                              : index == 3
                              ? _UserTopBarSection(
                                showDivider: true,
                                auth: auth,
                                onLogout:
                                    () =>
                                        ref
                                            .read(
                                              authControllerProvider.notifier,
                                            )
                                            .logout(),
                              )
                              : _TopBarSection(showDivider: index > 0),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryTopBarSection extends StatelessWidget {
  const _InventoryTopBarSection({
    required this.showDivider,
    required this.inventoryOpen,
    required this.onPressed,
  });

  final bool showDivider;
  final bool inventoryOpen;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (showDivider)
          const Positioned(
            left: -9,
            top: -6,
            bottom: -6,
            child: _TopBarDivider(),
          ),
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.only(left: showDivider ? 14 : 0, right: 10),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  children: [
                    const _TopBarIconWell(
                      child: Center(
                        child: Text(
                          'Bag',
                          style: TextStyle(
                            color: Color(0xFFDBCDB4),
                            fontSize: 7.5,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Inventory',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xFFE3D8C3),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            inventoryOpen ? 'Hide' : 'Open',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color:
                                  inventoryOpen
                                      ? const Color(0xFFE2BF63)
                                      : const Color(0xFFDBCDB4),
                              fontSize: 9.2,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TopBarSection extends StatelessWidget {
  const _TopBarSection({required this.showDivider});

  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (showDivider)
          const Positioned(
            left: -9,
            top: -6,
            bottom: -6,
            child: _TopBarDivider(),
          ),
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.only(left: showDivider ? 14 : 0, right: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  const _TopBarIconWell(),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        _TopBarPlaceholderLine(widthFactor: 0.62, bright: true),
                        SizedBox(height: 7),
                        _TopBarPlaceholderLine(widthFactor: 0.42),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InventoryDrawer extends StatelessWidget {
  const _InventoryDrawer({required this.inventory, required this.onClose});

  static const _height = 65.0;
  static const _capSourceWidth = 25.0;
  static const _sourceHeight = 130.0;

  final AsyncValue<List<InventoryItem>> inventory;
  final VoidCallback onClose;

  double get _capWidth => _height * (_capSourceWidth / _sourceHeight);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('inventory-drawer'),
      height: _height,
      width: double.infinity,
      child: Stack(
        children: [
          Row(
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
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                _capWidth + 14,
                8,
                _capWidth + 14,
                8,
              ),
              child: Row(
                children: [
                  const Text(
                    'Inventory',
                    style: TextStyle(
                      color: Color(0xFFE3D8C3),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: inventory.when(
                      data: (items) => _InventoryGrid(items: items),
                      loading: () => const _InventoryGridLoading(),
                      error: (_, _) => const _InventoryGridError(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _InventoryCloseButton(onPressed: onClose),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryCloseButton extends StatelessWidget {
  const _InventoryCloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(24, 24),
          side: const BorderSide(color: Color(0xAA7C6B48), width: 0.8),
          backgroundColor: const Color(0x33150F08),
          foregroundColor: const Color(0xFFE3D8C3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        ),
        child: const Text(
          '×',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _InventoryGrid extends StatelessWidget {
  const _InventoryGrid({required this.items});

  final List<InventoryItem> items;

  @override
  Widget build(BuildContext context) {
    final visibleItems = items.take(8).toList(growable: false);
    return Row(
      children: List.generate(
        8,
        (index) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == 7 ? 0 : 8),
            child: _InventorySlot(
              item: index < visibleItems.length ? visibleItems[index] : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _InventoryGridLoading extends StatelessWidget {
  const _InventoryGridLoading();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: 8),
            child: _InventorySlot(),
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: 8),
            child: _InventorySlot(),
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: 8),
            child: _InventorySlot(),
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: 8),
            child: _InventorySlot(),
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: 8),
            child: _InventorySlot(),
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: 8),
            child: _InventorySlot(),
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: 8),
            child: _InventorySlot(),
          ),
        ),
        Expanded(child: _InventorySlot()),
      ],
    );
  }
}

class _InventoryGridError extends StatelessWidget {
  const _InventoryGridError();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Text(
        'Inventory offline',
        style: TextStyle(
          color: Color(0xFFE3D8C3),
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InventorySlot extends StatelessWidget {
  const _InventorySlot({this.item});

  final InventoryItem? item;

  @override
  Widget build(BuildContext context) {
    final label = item == null ? '' : item!.itemKey.replaceAll('_', ' ').trim();
    final initials =
        label.isEmpty
            ? ''
            : label
                .split(' ')
                .where((part) => part.isNotEmpty)
                .take(2)
                .map((part) => part.substring(0, 1).toUpperCase())
                .join();
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x331A140C),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0x995B503A), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0x22110D08),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0x444D422F), width: 0.8),
          ),
          child:
              item == null
                  ? const SizedBox.expand()
                  : Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 3,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          initials,
                          style: const TextStyle(
                            color: Color(0xFFE3D8C3),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                        Text(
                          'x${item!.quantity}',
                          style: const TextStyle(
                            color: Color(0xFF6FCF38),
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
        ),
      ),
    );
  }
}

class _UserTopBarSection extends StatelessWidget {
  const _UserTopBarSection({
    required this.showDivider,
    required this.auth,
    required this.onLogout,
  });

  final bool showDivider;
  final AsyncValue auth;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (showDivider)
          const Positioned(
            left: -9,
            top: -6,
            bottom: -6,
            child: _TopBarDivider(),
          ),
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.only(left: showDivider ? 14 : 0, right: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: auth.when(
                data:
                    (value) => _UserDetails(
                      username: value?.user.displayName ?? 'Guest',
                      onLogout: onLogout,
                    ),
                loading:
                    () => const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _TopBarPlaceholderLine(widthFactor: 0.54, bright: true),
                        SizedBox(height: 7),
                        _TopBarPlaceholderLine(widthFactor: 0.3),
                      ],
                    ),
                error:
                    (_, _) =>
                        _UserDetails(username: 'Offline', onLogout: onLogout),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActivityTopBarSection extends StatelessWidget {
  const _ActivityTopBarSection({
    required this.showDivider,
    required this.player,
  });

  final bool showDivider;
  final AsyncValue<PlayerState> player;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (showDivider)
          const Positioned(
            left: -9,
            top: -6,
            bottom: -6,
            child: _TopBarDivider(),
          ),
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.only(left: showDivider ? 14 : 0, right: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: player.when(
                data: (value) => _ActivityDetails(player: value),
                loading:
                    () => const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _TopBarPlaceholderLine(widthFactor: 0.5, bright: true),
                        SizedBox(height: 7),
                        _TopBarPlaceholderLine(widthFactor: 0.58),
                      ],
                    ),
                error:
                    (_, _) => const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _TopBarPlaceholderLine(widthFactor: 0.44, bright: true),
                        SizedBox(height: 7),
                        _TopBarPlaceholderLine(widthFactor: 0.36),
                      ],
                    ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WoodcuttingTopBarSection extends StatelessWidget {
  const _WoodcuttingTopBarSection({
    required this.showDivider,
    required this.player,
  });

  final bool showDivider;
  final AsyncValue<PlayerState> player;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (showDivider)
          const Positioned(
            left: -9,
            top: -6,
            bottom: -6,
            child: _TopBarDivider(),
          ),
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.only(left: showDivider ? 14 : 0, right: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  const _TopBarIconWell(
                    child: Padding(
                      padding: EdgeInsets.all(4),
                      child: Image(
                        image: AssetImage(
                          'assets/images/ui/bar/skills/skill-woodcutting.png',
                        ),
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.none,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: player.when(
                      data: (value) => _WoodcuttingDetails(player: value),
                      loading:
                          () => const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _TopBarPlaceholderLine(
                                widthFactor: 0.62,
                                bright: true,
                              ),
                              SizedBox(height: 7),
                              _TopBarPlaceholderLine(widthFactor: 0.42),
                            ],
                          ),
                      error:
                          (_, _) => const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _TopBarPlaceholderLine(
                                widthFactor: 0.48,
                                bright: true,
                              ),
                              SizedBox(height: 7),
                              _TopBarPlaceholderLine(widthFactor: 0.32),
                            ],
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActivityDetails extends StatelessWidget {
  const _ActivityDetails({required this.player});

  final PlayerState player;

  @override
  Widget build(BuildContext context) {
    final status = _activityLabel(player);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Activity',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Color(0xFFE3D8C3),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          status,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _activityColor(player),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            height: 1,
            shadows: const [
              Shadow(
                color: Color(0xAA000000),
                offset: Offset(0, 1),
                blurRadius: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UserDetails extends StatelessWidget {
  const _UserDetails({required this.username, required this.onLogout});

  final String username;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'User',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Color(0xFFE3D8C3),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          username,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFDBCDB4),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 16,
          child: OutlinedButton(
            onPressed: onLogout,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              minimumSize: const Size(0, 16),
              side: const BorderSide(color: Color(0xAA7C6B48), width: 0.8),
              backgroundColor: const Color(0x33150F08),
              foregroundColor: const Color(0xFFE6D9C2),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            child: const Text(
              'Logout',
              style: TextStyle(
                fontSize: 7.5,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WoodcuttingDetails extends StatelessWidget {
  const _WoodcuttingDetails({required this.player});

  final PlayerState player;

  @override
  Widget build(BuildContext context) {
    final skill = player.skillByKey('woodcutting');
    final level = skill?.level ?? 1;
    final progress = skill?.progressToNextLevel ?? 0;
    final xp = skill?.xp ?? 0;
    final nextXP = skill?.nextLevelXP ?? xpRequiredForLevel(2);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Woodcutting',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Color(0xFF6FCF38),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            height: 1,
            shadows: [
              Shadow(
                color: Color(0xAA000000),
                offset: Offset(0, 1),
                blurRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Level $level',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFE3D8C3),
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
        const SizedBox(height: 5),
        _TopBarProgressBar(progress: progress),
        const SizedBox(height: 3),
        Text(
          '$xp / $nextXP XP',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xBFD7CDBB),
            fontSize: 7.2,
            fontWeight: FontWeight.w500,
            height: 1,
          ),
        ),
      ],
    );
  }
}

String _activityLabel(PlayerState player) {
  if (player.action != null) {
    return 'Harvesting';
  }
  if (player.movement != null) {
    return 'Walking';
  }
  return 'Idle';
}

Color _activityColor(PlayerState player) {
  if (player.action != null) {
    return const Color(0xFF6FCF38);
  }
  if (player.movement != null) {
    return const Color(0xFFE2BF63);
  }
  return const Color(0xFFE3D8C3);
}

class _TopBarDivider extends StatelessWidget {
  const _TopBarDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF2C271C).withValues(alpha: 0.92),
              border: Border.symmetric(
                horizontal: BorderSide(
                  color: const Color(0xAA8E7D59),
                  width: 0.8,
                ),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 2,
                  offset: Offset(1, 0),
                ),
              ],
            ),
          ),
          const Positioned(top: 0, child: _DividerStud()),
          const Positioned(bottom: 0, child: _DividerStud()),
        ],
      ),
    );
  }
}

class _DividerStud extends StatelessWidget {
  const _DividerStud();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: const Color(0xFF5A4E38).withValues(alpha: 0.9),
        border: Border.all(color: const Color(0xCC1A140B), width: 1.1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x668B7B58),
            blurRadius: 0,
            offset: Offset(-1, -1),
          ),
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 0,
            offset: Offset(1, 1),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 4,
          height: 4,
          decoration: const BoxDecoration(
            color: Color(0xFF7D6E4F),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _TopBarIconWell extends StatelessWidget {
  const _TopBarIconWell({this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0x44221810),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0x665E5138), width: 1.1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 0,
            offset: Offset(1, 1),
          ),
          BoxShadow(
            color: Color(0x226D6246),
            blurRadius: 0,
            offset: Offset(-1, -1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0x22110D08),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0x444D422F), width: 0.9),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _TopBarProgressBar extends StatelessWidget {
  const _TopBarProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0, 1).toDouble();
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: const Color(0xFF19140D),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: const Color(0x88574832), width: 0.8),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: clamped,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2.4),
              gradient: const LinearGradient(
                colors: [Color(0xFF78D43A), Color(0xFF4E9224)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBarPlaceholderLine extends StatelessWidget {
  const _TopBarPlaceholderLine({
    required this.widthFactor,
    this.bright = false,
  });

  final double widthFactor;
  final bool bright;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: bright ? 8 : 6,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          gradient: LinearGradient(
            colors:
                bright
                    ? const [Color(0xFF6FA031), Color(0xFF4E7422)]
                    : const [Color(0xBBCEC2AD), Color(0x889F947F)],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 1,
              offset: Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }
}
