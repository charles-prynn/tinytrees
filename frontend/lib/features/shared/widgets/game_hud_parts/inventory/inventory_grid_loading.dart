part of '../../game_hud.dart';

class InventoryGridLoading extends StatelessWidget {
  const InventoryGridLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: 5),
            child: InventorySlot(),
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: 5),
            child: InventorySlot(),
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: 5),
            child: InventorySlot(),
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: 5),
            child: InventorySlot(),
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: 5),
            child: InventorySlot(),
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: 5),
            child: InventorySlot(),
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: 5),
            child: InventorySlot(),
          ),
        ),
        Expanded(child: InventorySlot()),
      ],
    );
  }
}
