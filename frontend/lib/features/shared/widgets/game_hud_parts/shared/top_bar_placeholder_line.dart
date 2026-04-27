part of '../../game_hud.dart';

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
