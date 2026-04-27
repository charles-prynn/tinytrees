part of '../../game_hud.dart';

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
