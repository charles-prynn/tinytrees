part of '../../game_hud.dart';

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
