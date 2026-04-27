part of '../../game_hud.dart';

class InventoryGridError extends StatelessWidget {
  const InventoryGridError({super.key});

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Text(
        'Inventory offline',
        style: TextStyle(
          color: Color(0xFFE3D8C3),
          fontSize: 8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
