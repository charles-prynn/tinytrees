part of '../../game_hud.dart';

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
