part of '../../game_hud.dart';

enum _TopBarSectionSlot { woodcutting, inventory, activity, inbox, user }

class TopBar extends ConsumerWidget {
  const TopBar({
    super.key,
    required this.layout,
    required this.inventoryOpen,
    required this.inboxOpen,
    required this.showCoordinateDebug,
    required this.onInventoryPressed,
    required this.onInboxPressed,
    required this.onLoginPressed,
    required this.onRegistrationPressed,
  });

  static const barHeight = 50.0;
  static const contentInset = 4.0;
  static const _capSourceWidth = 25.0;
  static const _sourceHeight = 130.0;

  final _HudLayout layout;
  final bool inventoryOpen;
  final bool inboxOpen;
  final bool showCoordinateDebug;
  final VoidCallback onInventoryPressed;
  final VoidCallback onInboxPressed;
  final VoidCallback onLoginPressed;
  final VoidCallback onRegistrationPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerControllerProvider);
    final auth = ref.watch(authControllerProvider);
    final inbox = ref.watch(eventInboxControllerProvider);
    final onLogout = () => ref.read(authControllerProvider.notifier).logout();

    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        key: const ValueKey('hud-top-bar'),
        height: barHeight,
        width: double.infinity,
        child: _TopBarFrame(
          layout: layout,
          player: player,
          auth: auth,
          inbox: inbox,
          inventoryOpen: inventoryOpen,
          inboxOpen: inboxOpen,
          showCoordinateDebug: showCoordinateDebug,
          onInventoryPressed: onInventoryPressed,
          onInboxPressed: onInboxPressed,
          onLoginPressed: onLoginPressed,
          onRegistrationPressed: onRegistrationPressed,
          onLogout: onLogout,
        ),
      ),
    );
  }
}

class _TopBarFrame extends StatelessWidget {
  const _TopBarFrame({
    required this.layout,
    required this.player,
    required this.auth,
    required this.inbox,
    required this.inventoryOpen,
    required this.inboxOpen,
    required this.showCoordinateDebug,
    required this.onInventoryPressed,
    required this.onInboxPressed,
    required this.onLoginPressed,
    required this.onRegistrationPressed,
    required this.onLogout,
  });

  static const _slots = [
    _TopBarSectionSlot.woodcutting,
    _TopBarSectionSlot.inventory,
    _TopBarSectionSlot.activity,
    _TopBarSectionSlot.inbox,
    _TopBarSectionSlot.user,
  ];

  final _HudLayout layout;
  final AsyncValue<PlayerState> player;
  final AsyncValue<AuthSession?> auth;
  final AsyncValue<List<PlayerInboxItem>> inbox;
  final bool inventoryOpen;
  final bool inboxOpen;
  final bool showCoordinateDebug;
  final VoidCallback onInventoryPressed;
  final VoidCallback onInboxPressed;
  final VoidCallback onLoginPressed;
  final VoidCallback onRegistrationPressed;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: TopBar.barHeight,
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
                _capWidth + 8,
                TopBar.contentInset,
                _capWidth + 8,
                TopBar.contentInset,
              ),
              child: Row(
                children: List.generate(
                  _slots.length,
                  (index) => Expanded(
                    child: _ScaledTopBarSection(
                      designWidth: layout.topBarDesignWidths[index],
                      child: _buildSection(
                        slot: _slots[index],
                        showDivider: index > 0,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double get _capWidth =>
      TopBar.barHeight * (TopBar._capSourceWidth / TopBar._sourceHeight);

  Widget _buildSection({
    required _TopBarSectionSlot slot,
    required bool showDivider,
  }) {
    switch (slot) {
      case _TopBarSectionSlot.woodcutting:
        return WoodcuttingTopBarSection(
          showDivider: showDivider,
          player: player,
        );
      case _TopBarSectionSlot.inventory:
        return InventoryTopBarSection(
          showDivider: showDivider,
          inventoryOpen: inventoryOpen,
          onPressed: onInventoryPressed,
        );
      case _TopBarSectionSlot.activity:
        return ActivityTopBarSection(showDivider: showDivider, player: player);
      case _TopBarSectionSlot.inbox:
        return InboxTopBarSection(
          showDivider: showDivider,
          inbox: inbox,
          inboxOpen: inboxOpen,
          onPressed: onInboxPressed,
        );
      case _TopBarSectionSlot.user:
        return UserTopBarSection(
          showDivider: showDivider,
          auth: auth,
          player: player,
          showCoordinateDebug: showCoordinateDebug,
          onLoginPressed: onLoginPressed,
          onRegisterPressed: onRegistrationPressed,
          onLogout: onLogout,
        );
    }
  }
}

class _ScaledTopBarSection extends StatelessWidget {
  const _ScaledTopBarSection({required this.designWidth, required this.child});

  final double designWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(designWidth, constraints.maxWidth);
        return Align(
          alignment: Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: width,
              height: TopBar.barHeight - (TopBar.contentInset * 2),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
