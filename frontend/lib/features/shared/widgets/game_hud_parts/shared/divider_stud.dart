part of '../../game_hud.dart';

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
