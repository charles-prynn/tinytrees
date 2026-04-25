import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_controller.dart';
import '../../auth/domain/auth_session.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../inventory/domain/inventory_item.dart';
import '../../player/application/player_controller.dart';
import '../../player/domain/player_state.dart';
import 'login_popup.dart';
import 'registration_popup.dart';

class GameHud extends ConsumerWidget {
  const GameHud({
    super.key,
    required this.inventoryOpen,
    required this.loginOpen,
    required this.registrationOpen,
    required this.showCoordinateDebug,
    required this.onInventoryPressed,
    required this.onInventoryClosed,
    required this.onLoginPressed,
    required this.onLoginClosed,
    required this.onRegistrationPressed,
    required this.onRegistrationClosed,
  });

  final bool inventoryOpen;
  final bool loginOpen;
  final bool registrationOpen;
  final bool showCoordinateDebug;
  final VoidCallback onInventoryPressed;
  final VoidCallback onInventoryClosed;
  final VoidCallback onLoginPressed;
  final VoidCallback onLoginClosed;
  final VoidCallback onRegistrationPressed;
  final VoidCallback onRegistrationClosed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventory = ref.watch(inventoryProvider);
    return Stack(
      children: [
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TopBar(
              inventoryOpen: inventoryOpen,
              showCoordinateDebug: showCoordinateDebug,
              onInventoryPressed: onInventoryPressed,
              onLoginPressed: onLoginPressed,
              onRegistrationPressed: onRegistrationPressed,
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Align(
              alignment: Alignment.bottomCenter,
              child:
                  inventoryOpen
                      ? InventoryDrawer(
                        inventory: inventory,
                        onClose: onInventoryClosed,
                      )
                      : const SizedBox.shrink(),
            ),
          ),
        ),
        if (loginOpen) LoginPopup(onClose: onLoginClosed),
        if (registrationOpen) RegistrationPopup(onClose: onRegistrationClosed),
      ],
    );
  }
}

class TopBar extends ConsumerWidget {
  const TopBar({
    super.key,
    required this.inventoryOpen,
    required this.showCoordinateDebug,
    required this.onInventoryPressed,
    required this.onLoginPressed,
    required this.onRegistrationPressed,
  });

  static const barHeight = 50.0;
  static const contentInset = 4.0;
  static const _capSourceWidth = 25.0;
  static const _sourceHeight = 130.0;
  static const _segmentCount = 4;

  final bool inventoryOpen;
  final bool showCoordinateDebug;
  final VoidCallback onInventoryPressed;
  final VoidCallback onLoginPressed;
  final VoidCallback onRegistrationPressed;

  double get _capWidth => barHeight * (_capSourceWidth / _sourceHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerControllerProvider);
    final auth = ref.watch(authControllerProvider);

    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        height: barHeight,
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
                const Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
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
                  contentInset,
                  _capWidth + 8,
                  contentInset,
                ),
                child: Row(
                  children: List.generate(
                    _segmentCount,
                    (index) => Expanded(
                      child:
                          index == 0
                              ? WoodcuttingTopBarSection(
                                showDivider: false,
                                player: player,
                              )
                              : index == 1
                              ? InventoryTopBarSection(
                                showDivider: true,
                                inventoryOpen: inventoryOpen,
                                onPressed: onInventoryPressed,
                              )
                              : index == 2
                              ? ActivityTopBarSection(
                                showDivider: true,
                                player: player,
                              )
                              : UserTopBarSection(
                                showDivider: true,
                                auth: auth,
                                player: player,
                                showCoordinateDebug: showCoordinateDebug,
                                onLoginPressed: onLoginPressed,
                                onRegisterPressed: onRegistrationPressed,
                                onLogout:
                                    () =>
                                        ref
                                            .read(
                                              authControllerProvider.notifier,
                                            )
                                            .logout(),
                              ),
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

class InventoryTopBarSection extends StatelessWidget {
  const InventoryTopBarSection({
    super.key,
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
            child: TopBarDivider(),
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
                    const TopBarIconWell(
                      child: Padding(
                        padding: EdgeInsets.all(4),
                        child: Image(
                          image: AssetImage(
                            'assets/images/ui/bar/icons/Inventory-icon.png',
                          ),
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.none,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
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
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            inventoryOpen ? 'Hide' : 'Open',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color:
                                  inventoryOpen
                                      ? const Color(0xFFE2BF63)
                                      : const Color(0xFFDBCDB4),
                              fontSize: 8,
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

class InventoryDrawer extends StatelessWidget {
  const InventoryDrawer({
    super.key,
    required this.inventory,
    required this.onClose,
  });

  static const _height = TopBar.barHeight;
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
              const Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
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
                6,
                _capWidth + 14,
                6,
              ),
              child: Row(
                children: [
                  const Text(
                    'Inventory',
                    style: TextStyle(
                      color: Color(0xFFE3D8C3),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: inventory.when(
                      data: (items) => InventoryGrid(items: items),
                      loading: () => const InventoryGridLoading(),
                      error: (_, _) => const InventoryGridError(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InventoryCloseButton(onPressed: onClose),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class InventoryCloseButton extends StatelessWidget {
  const InventoryCloseButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(20, 20),
          side: const BorderSide(color: Color(0xAA7C6B48), width: 0.8),
          backgroundColor: const Color(0x33150F08),
          foregroundColor: const Color(0xFFE3D8C3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        ),
        child: const Text(
          '×',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class InventoryGrid extends StatelessWidget {
  const InventoryGrid({super.key, required this.items});

  final List<InventoryItem> items;

  @override
  Widget build(BuildContext context) {
    final visibleItems = items.take(8).toList(growable: false);
    return Row(
      children: List.generate(
        8,
        (index) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == 7 ? 0 : 5),
            child: InventorySlot(
              item: index < visibleItems.length ? visibleItems[index] : null,
            ),
          ),
        ),
      ),
    );
  }
}

class InventoryGridLoading extends StatelessWidget {
  const InventoryGridLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: 5),
            child: InventorySlot(),
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: 5),
            child: InventorySlot(),
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: 5),
            child: InventorySlot(),
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: 5),
            child: InventorySlot(),
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: 5),
            child: InventorySlot(),
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: 5),
            child: InventorySlot(),
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: 5),
            child: InventorySlot(),
          ),
        ),
        Expanded(child: InventorySlot()),
      ],
    );
  }
}

class InventoryGridError extends StatelessWidget {
  const InventoryGridError({super.key});

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Text(
        'Inventory offline',
        style: TextStyle(
          color: Color(0xFFE3D8C3),
          fontSize: 8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class InventorySlot extends StatelessWidget {
  const InventorySlot({super.key, this.item});

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
        padding: const EdgeInsets.all(2),
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
                      horizontal: 3,
                      vertical: 2,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          initials,
                          style: const TextStyle(
                            color: Color(0xFFE3D8C3),
                            fontSize: 7.5,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                        Text(
                          'x${item!.quantity}',
                          style: const TextStyle(
                            color: Color(0xFF6FCF38),
                            fontSize: 6.6,
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

class UserTopBarSection extends StatelessWidget {
  const UserTopBarSection({
    super.key,
    required this.showDivider,
    required this.auth,
    required this.player,
    required this.showCoordinateDebug,
    required this.onLoginPressed,
    required this.onRegisterPressed,
    required this.onLogout,
  });

  final bool showDivider;
  final AsyncValue<AuthSession?> auth;
  final AsyncValue<PlayerState> player;
  final bool showCoordinateDebug;
  final VoidCallback onLoginPressed;
  final VoidCallback onRegisterPressed;
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
            child: TopBarDivider(),
          ),
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.only(left: showDivider ? 14 : 0, right: 10),
            child: auth.when(
              data:
                  (value) => player.when(
                    data:
                        (playerValue) => _buildUserSection(
                          username: value?.user.displayName ?? 'Guest',
                          dbPositionLabel:
                              showCoordinateDebug
                                  ? dbPositionLabel(playerValue)
                                  : null,
                          showRegister: value?.user.provider == 'guest',
                          showLogout: value?.user.provider != 'guest',
                        ),
                    loading:
                        () => _buildUserSection(
                          username: value?.user.displayName ?? 'Guest',
                          showRegister: value?.user.provider == 'guest',
                          showLogout: value?.user.provider != 'guest',
                        ),
                    error:
                        (_, _) => _buildUserSection(
                          username: value?.user.displayName ?? 'Guest',
                          showRegister: value?.user.provider == 'guest',
                          showLogout: value?.user.provider != 'guest',
                        ),
                  ),
              loading:
                  () => const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TopBarPlaceholderLine(widthFactor: 0.54, bright: true),
                      SizedBox(height: 4),
                      TopBarPlaceholderLine(widthFactor: 0.3),
                    ],
                  ),
              error:
                  (_, _) =>
                      _buildUserSection(username: 'Offline', showLogout: true),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserSection({
    required String username,
    String? dbPositionLabel,
    bool showRegister = false,
    bool showLogout = true,
  }) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          const TopBarIconWell(
            child: Padding(
              padding: EdgeInsets.all(4),
              child: Image(
                image: AssetImage(
                  'assets/images/ui/bar/icons/user-icon.png.png',
                ),
                fit: BoxFit.contain,
                filterQuality: FilterQuality.none,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: UserDetails(
              username: username,
              dbPositionLabel: dbPositionLabel,
              showRegister: showRegister,
              showLogout: showLogout,
              onLogin: onLoginPressed,
              onRegister: onRegisterPressed,
              onLogout: onLogout,
            ),
          ),
        ],
      ),
    );
  }
}

class ActivityTopBarSection extends StatelessWidget {
  const ActivityTopBarSection({
    super.key,
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
            child: TopBarDivider(),
          ),
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.only(left: showDivider ? 14 : 0, right: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: player.when(
                data: (value) => ActivityDetails(player: value),
                loading:
                    () => const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TopBarPlaceholderLine(widthFactor: 0.5, bright: true),
                        SizedBox(height: 4),
                        TopBarPlaceholderLine(widthFactor: 0.58),
                      ],
                    ),
                error:
                    (_, _) => const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TopBarPlaceholderLine(widthFactor: 0.44, bright: true),
                        SizedBox(height: 4),
                        TopBarPlaceholderLine(widthFactor: 0.36),
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

class WoodcuttingTopBarSection extends StatelessWidget {
  const WoodcuttingTopBarSection({
    super.key,
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
            child: TopBarDivider(),
          ),
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.only(left: showDivider ? 14 : 0, right: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  const TopBarIconWell(
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
                  const SizedBox(width: 8),
                  Expanded(
                    child: player.when(
                      data: (value) => WoodcuttingDetails(player: value),
                      loading:
                          () => const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TopBarPlaceholderLine(
                                widthFactor: 0.62,
                                bright: true,
                              ),
                              SizedBox(height: 4),
                              TopBarPlaceholderLine(widthFactor: 0.42),
                            ],
                          ),
                      error:
                          (_, _) => const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TopBarPlaceholderLine(
                                widthFactor: 0.48,
                                bright: true,
                              ),
                              SizedBox(height: 4),
                              TopBarPlaceholderLine(widthFactor: 0.32),
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

class ActivityDetails extends StatelessWidget {
  const ActivityDetails({super.key, required this.player});

  final PlayerState player;

  @override
  Widget build(BuildContext context) {
    final status = activityLabel(player);
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
            fontSize: 9,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          status,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: activityColor(player),
            fontSize: 8.5,
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

class UserDetails extends StatelessWidget {
  const UserDetails({
    super.key,
    required this.username,
    this.dbPositionLabel,
    this.showRegister = false,
    this.showLogout = true,
    this.onLogin,
    this.onRegister,
    required this.onLogout,
  });

  final String username;
  final String? dbPositionLabel;
  final bool showRegister;
  final bool showLogout;
  final VoidCallback? onLogin;
  final VoidCallback? onRegister;
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
            fontSize: 9,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          dbPositionLabel == null ? username : '$username  $dbPositionLabel',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFDBCDB4),
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (showRegister) ...[
              _UserActionButton(label: 'Register', onPressed: onRegister),
              const SizedBox(width: 4),
              _UserActionButton(label: 'Login', onPressed: onLogin),
            ],
            if (showLogout) ...[
              if (showRegister) const SizedBox(width: 4),
              _UserActionButton(label: 'Logout', onPressed: onLogout),
            ],
          ],
        ),
      ],
    );
  }
}

String dbPositionLabel(PlayerState player) {
  final dbX = player.movement?.fromX ?? player.x;
  final dbY = player.movement?.fromY ?? player.y;
  return 'DB $dbX,$dbY';
}

class _UserActionButton extends StatelessWidget {
  const _UserActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 14,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
          minimumSize: const Size(0, 14),
          side: const BorderSide(color: Color(0xAA7C6B48), width: 0.8),
          backgroundColor: const Color(0x33150F08),
          foregroundColor: const Color(0xFFE6D9C2),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 6.7,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class WoodcuttingDetails extends StatelessWidget {
  const WoodcuttingDetails({super.key, required this.player});

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
            fontSize: 9,
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
        const SizedBox(height: 2),
        Text(
          'Level $level',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFE3D8C3),
            fontSize: 8,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
        const SizedBox(height: 3),
        TopBarProgressBar(progress: progress),
        const SizedBox(height: 2),
        Text(
          '$xp / $nextXP XP',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xBFD7CDBB),
            fontSize: 6.3,
            fontWeight: FontWeight.w500,
            height: 1,
          ),
        ),
      ],
    );
  }
}

String activityLabel(PlayerState player) {
  if (player.action != null) {
    return 'Harvesting';
  }
  if (player.movement != null) {
    return 'Walking';
  }
  return 'Idle';
}

Color activityColor(PlayerState player) {
  if (player.action != null) {
    return const Color(0xFF6FCF38);
  }
  if (player.movement != null) {
    return const Color(0xFFE2BF63);
  }
  return const Color(0xFFE3D8C3);
}

class TopBarDivider extends StatelessWidget {
  const TopBarDivider({super.key});

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
          const Positioned(top: 1, child: DividerStud()),
          const Positioned(bottom: 1, child: DividerStud()),
        ],
      ),
    );
  }
}

class DividerStud extends StatelessWidget {
  const DividerStud({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 14,
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

class TopBarIconWell extends StatelessWidget {
  const TopBarIconWell({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 34,
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
        padding: const EdgeInsets.all(3),
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

class TopBarProgressBar extends StatelessWidget {
  const TopBarProgressBar({super.key, required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0, 1).toDouble();
    return Container(
      height: 5,
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

class TopBarPlaceholderLine extends StatelessWidget {
  const TopBarPlaceholderLine({
    super.key,
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
        height: bright ? 6 : 4,
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
