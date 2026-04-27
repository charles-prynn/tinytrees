part of '../../game_hud.dart';

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
