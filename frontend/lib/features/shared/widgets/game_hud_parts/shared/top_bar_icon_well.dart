part of '../../game_hud.dart';

class TopBarIconWell extends StatelessWidget {
  const TopBarIconWell({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 34,
      decoration: BoxDecoration(
        color: const Color(0x44221810),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0x665E5138), width: 1.1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 0,
            offset: Offset(1, 1),
          ),
          BoxShadow(
            color: Color(0x226D6246),
            blurRadius: 0,
            offset: Offset(-1, -1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0x22110D08),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0x444D422F), width: 0.9),
          ),
          child: child,
        ),
      ),
    );
  }
}
