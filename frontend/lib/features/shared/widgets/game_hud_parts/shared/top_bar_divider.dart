part of '../../game_hud.dart';

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
