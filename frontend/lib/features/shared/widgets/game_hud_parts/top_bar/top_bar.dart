part of '../../game_hud.dart';

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
