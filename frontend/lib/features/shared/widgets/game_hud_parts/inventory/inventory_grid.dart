part of '../../game_hud.dart';

class InventoryGrid extends StatelessWidget {
  const InventoryGrid({super.key, required this.items, this.onItemTap});

  final List<InventoryItem> items;
  final ValueChanged<InventoryItem>? onItemTap;

  @override
  Widget build(BuildContext context) {
    final visibleItems = items.take(8).toList(growable: false);
    return Row(
      children: List.generate(
        8,
        (index) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == 7 ? 0 : 5),
            child: InventorySlot(
              item: index < visibleItems.length ? visibleItems[index] : null,
              onTap:
                  index < visibleItems.length && onItemTap != null
                      ? () => onItemTap!(visibleItems[index])
                      : null,
            ),
          ),
        ),
      ),
    );
  }
}
