part of '../main_screen.dart';

class _MainScreenState extends ConsumerState<MainScreen> {
  static const _uiWarmupImages = <AssetImage>[
    AssetImage('assets/images/ui/bar/left-bar.png'),
    AssetImage('assets/images/ui/bar/middle-bar.png'),
    AssetImage('assets/images/ui/bar/right-bar.png'),
    AssetImage('assets/images/ui/bar/icons/Inventory-icon.png'),
  ];

  late final TileMapGame _game;
  bool _gameAssetsReady = false;
  String? _gameAssetsError;
  TileMap? _lastTileMap;
  List<WorldEntity>? _lastEntities;
  PlayerState? _lastPlayer;
  String? _holdLabel;
  int _interactionSequence = 0;
  bool _inventoryOpen = false;
  bool _bankOpen = false;
  String? _activeBankEntityId;
  bool _loginOpen = false;
  bool _registrationOpen = false;
  bool _minimapVisible = true;
  bool _useLowPolyPlayer = false;
  math.Point<int>? _selectedMinimapTile;
  bool _animationDebugOpen = false;
  PlayerCharacterAnimation? _debugAnimationOverride;
  final List<DateTime> _tripleThreePresses = <DateTime>[];
  final FocusNode _keyboardFocusNode = FocusNode(debugLabel: 'main-screen');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _keyboardFocusNode.requestFocus();
        unawaited(_warmUpUiAssets());
      }
    });
    final config = ref.read(appConfigProvider);
    _game = TileMapGame(
      showFps: config.debugFps,
      showCoordinateDebug: config.debugCord,
    );
    if (widget.waitForGameAssetsDuringLoad) {
      unawaited(_awaitGameAssets());
    } else {
      _gameAssetsReady = true;
    }
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
          _syncSelectedMinimapTile(value);
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
  void dispose() {
    _keyboardFocusNode.dispose();
    super.dispose();
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
        _gameAssetsError != null ||
        !_gameAssetsReady ||
        map.isLoading ||
        !map.hasValue ||
        entities.isLoading ||
        !entities.hasValue ||
        player.isLoading ||
        !player.hasValue ||
        inventory.isLoading ||
        !inventory.hasValue;

    return Scaffold(
      body: KeyboardListener(
        autofocus: true,
        focusNode: _keyboardFocusNode,
        onKeyEvent: _handleKeyEvent,
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _refocusKeyboardListener(),
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _refocusKeyboardListener,
                  onLongPressStart:
                      (details) => _setHoldLabel(
                        _game.holdLabelAt(details.localPosition),
                      ),
                  onLongPressMoveUpdate:
                      (details) => _setHoldLabel(
                        _game.holdLabelAt(details.localPosition),
                      ),
                  onLongPressEnd: (_) => _setHoldLabel(null),
                  onLongPressUp: () => _setHoldLabel(null),
                  onLongPressCancel: () => _setHoldLabel(null),
                  onTapUp: _handleTapUp,
                  child: GameWidget(game: _game),
                ),
              ),
              GameHud(
                inventoryOpen: _inventoryOpen,
                bankOpen: _bankOpen,
                loginOpen: _loginOpen,
                registrationOpen: _registrationOpen,
                minimapVisible: _minimapVisible,
                useLowPolyPlayer: _useLowPolyPlayer,
                showCoordinateDebug: ref.watch(appConfigProvider).debugCord,
                selectedMinimapTile: _selectedMinimapTile,
                onMinimapTileSelected: _handleMinimapTileSelected,
                onInventoryPressed: _toggleInventory,
                onInventoryClosed: _toggleInventory,
                onBankClosed: _closeBank,
                onBankDeposit: _depositBankItem,
                onPlayerRenderModeToggle: _togglePlayerRenderMode,
                onLoginPressed: _openLogin,
                onLoginClosed: _closeLogin,
                onRegistrationPressed: _openRegistration,
                onRegistrationClosed: _closeRegistration,
              ),
              if (loading)
                GameLoadingOverlay(
                  assetsReady: _gameAssetsReady,
                  mapReady: map.hasValue,
                  resourcesReady: entities.hasValue,
                  playerReady: player.hasValue,
                  inventoryReady: inventory.hasValue,
                  errorMessage: loadingError ?? _gameAssetsError,
                  onRetry: () => retryGameLoad(ref),
                ),
              if (!loading && socketState != null)
                if (socketState != GameSocketConnectionState.connected)
                  GameConnectionBanner(state: socketState),
              if (_animationDebugOpen)
                AnimationDebugPanel(
                  selectedAnimation: _debugAnimationOverride,
                  onSelectedAnimation: _setDebugAnimationOverride,
                  onClose: _toggleAnimationDebugPanel,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _refocusKeyboardListener() {
    if (_keyboardFocusNode.hasFocus) {
      return;
    }
    _keyboardFocusNode.requestFocus();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return;
    }
    if (event.logicalKey == LogicalKeyboardKey.digit4 ||
        event.logicalKey == LogicalKeyboardKey.numpad4) {
      _toggleMinimap();
      return;
    }
    if (event.logicalKey == LogicalKeyboardKey.digit5 ||
        event.logicalKey == LogicalKeyboardKey.numpad5) {
      _togglePlayerRenderMode();
      return;
    }
    if (event.logicalKey != LogicalKeyboardKey.digit3 &&
        event.logicalKey != LogicalKeyboardKey.numpad3) {
      return;
    }
    final now = DateTime.now();
    _tripleThreePresses.removeWhere(
      (pressedAt) =>
          now.difference(pressedAt) > const Duration(milliseconds: 800),
    );
    _tripleThreePresses.add(now);
    if (_tripleThreePresses.length >= 3) {
      _tripleThreePresses.clear();
      _toggleAnimationDebugPanel();
    }
  }

  void _toggleAnimationDebugPanel() {
    if (!mounted) {
      return;
    }
    setState(() {
      _animationDebugOpen = !_animationDebugOpen;
    });
  }

  void _toggleMinimap() {
    if (!mounted) {
      return;
    }
    setState(() {
      _minimapVisible = !_minimapVisible;
    });
  }

  void _togglePlayerRenderMode() {
    _game.togglePlayerRenderMode();
    if (!mounted) {
      return;
    }
    setState(() {
      _useLowPolyPlayer = !_useLowPolyPlayer;
    });
  }

  void _setDebugAnimationOverride(PlayerCharacterAnimation? animation) {
    _game.setDebugAnimationOverride(animation);
    if (!mounted) {
      return;
    }
    setState(() {
      _debugAnimationOverride = animation;
    });
  }

  Future<void> _awaitGameAssets() async {
    try {
      await _game.assetsLoaded;
      if (!mounted) {
        return;
      }
      setState(() {
        _gameAssetsReady = true;
        _gameAssetsError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _gameAssetsReady = false;
        _gameAssetsError = '$error';
      });
    }
  }

  Future<void> _warmUpUiAssets() async {
    for (final image in _uiWarmupImages) {
      await precacheImage(image, context);
    }
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
      await _handleEntityInteraction(interactionTarget);
      return;
    }

    final tile = _game.tileAtLocalPosition(details.localPosition);
    if (tile == null ||
        !_game.isWalkableTileAtLocalPosition(details.localPosition)) {
      return;
    }

    _interactionSequence++;
    _closeBank();
    _game.showWalkIconAt(tile);
    final moved = await ref
        .read(playerControllerProvider.notifier)
        .moveTo(x: tile.x, y: tile.y);
    if (!mounted || !moved) {
      return;
    }
  }

  void _handleMinimapTileSelected(math.Point<int> tile) {
    if (mounted) {
      setState(() {
        _selectedMinimapTile = tile;
      });
    }
    unawaited(_moveToTile(tile));
  }

  void _syncSelectedMinimapTile(PlayerState player) {
    final selectedTile = _selectedMinimapTile;
    if (selectedTile == null || !mounted) {
      return;
    }

    final movement = player.movement;
    final hasReachedSelectedTile =
        movement == null &&
        player.x == selectedTile.x &&
        player.y == selectedTile.y;
    final destinationChanged =
        movement != null &&
        (movement.targetX != selectedTile.x ||
            movement.targetY != selectedTile.y);

    if (!hasReachedSelectedTile && !destinationChanged) {
      return;
    }

    setState(() {
      _selectedMinimapTile = null;
    });
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
      if (!_inventoryOpen) {
        _bankOpen = false;
        _activeBankEntityId = null;
      }
      _inventoryOpen = !_inventoryOpen;
    });
  }

  void _closeBank() {
    if (!_bankOpen || !mounted) {
      return;
    }
    setState(() {
      _bankOpen = false;
      _activeBankEntityId = null;
    });
  }

  void _openBank(String entityId) {
    if (!mounted) {
      return;
    }
    setState(() {
      _inventoryOpen = false;
      _bankOpen = true;
      _activeBankEntityId = entityId;
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

  Future<void> _handleEntityInteraction(EntityInteractionTarget target) async {
    final sequence = ++_interactionSequence;
    final controller = ref.read(playerControllerProvider.notifier);
    if (target.kind != EntityInteractionKind.bank) {
      _closeBank();
    }
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
    if (target.kind == EntityInteractionKind.bank) {
      _openBank(target.entityId);
      return;
    }
    final harvestError = await controller.startHarvest(
      entityId: target.entityId,
    );
    if (!mounted || sequence != _interactionSequence) {
      return;
    }
    if (harvestError is AppError && harvestError.code == 'insufficient_level') {
      _game.showEntityMessage(target.entityId, 'Level too low');
      return;
    }
    if (harvestError != null) {
      return;
    }
  }

  Future<void> _moveToTile(math.Point<int> tile) async {
    _interactionSequence++;
    _closeBank();
    _game.showWalkIconAt(tile);
    final moved = await ref
        .read(playerControllerProvider.notifier)
        .moveTo(x: tile.x, y: tile.y);
    if (!mounted || !moved) {
      return;
    }
  }

  Future<void> _depositBankItem(InventoryItem item) async {
    final entityId = _activeBankEntityId;
    if (entityId == null || item.quantity <= 0) {
      return;
    }

    try {
      await ref
          .read(bankRepositoryProvider)
          .deposit(
            entityId: entityId,
            itemKey: item.itemKey,
            quantity: item.quantity,
          );
      ref.invalidate(inventoryProvider);
      ref.invalidate(bankProvider);
    } catch (error) {
      final message =
          error is AppError && error.message.isNotEmpty
              ? error.message
              : 'Deposit failed';
      _game.showEntityMessage(
        entityId,
        message,
        color: const Color(0xFFF0C56D),
      );
    }
  }
}
