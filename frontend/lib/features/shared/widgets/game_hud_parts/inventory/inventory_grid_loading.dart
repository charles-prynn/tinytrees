part of '../../game_hud.dart';

class InventoryGridLoading extends StatelessWidget {
  const InventoryGridLoading({super.key, this.columns = 8});

  final int columns;

  @override
  Widget build(BuildContext context) {
    return _InventorySlotLayout(
      columns: columns,
      children: List.generate(8, (_) => const InventorySlot()),
    );
  }
}
