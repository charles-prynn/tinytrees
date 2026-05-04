part of '../../game_hud.dart';

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

String activityLabel(PlayerState player) {
  if (player.action != null) {
    return 'Harvesting';
  }
  if (player.hasActiveMovementAt(DateTime.now().toUtc())) {
    return 'Walking';
  }
  return 'Idle';
}

Color activityColor(PlayerState player) {
  if (player.action != null) {
    return const Color(0xFF6FCF38);
  }
  if (player.hasActiveMovementAt(DateTime.now().toUtc())) {
    return const Color(0xFFE2BF63);
  }
  return const Color(0xFFE3D8C3);
}
