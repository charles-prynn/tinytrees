part of '../../game_hud.dart';

class InventoryGrid extends StatelessWidget {
  const InventoryGrid({
    super.key,
    required this.items,
    this.onItemTap,
    this.columns = 8,
  });

  final List<InventoryItem> items;
  final ValueChanged<InventoryItem>? onItemTap;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final visibleItems = items.take(8).toList(growable: false);
    return _InventorySlotLayout(
      columns: columns,
      children: List.generate(
        8,
        (index) => InventorySlot(
          item: index < visibleItems.length ? visibleItems[index] : null,
          onTap:
              index < visibleItems.length && onItemTap != null
                  ? () => onItemTap!(visibleItems[index])
                  : null,
        ),
      ),
    );
  }
}

class _InventorySlotLayout extends StatelessWidget {
  const _InventorySlotLayout({
    required this.columns,
    required this.children,
    this.columnSpacing = 5,
    this.rowSpacing = 5,
  });

  final int columns;
  final List<Widget> children;
  final double columnSpacing;
  final double rowSpacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final safeColumns = math.max(1, math.min(columns, children.length));
        final rowCount = (children.length / safeColumns).ceil();
        final width =
            (constraints.maxWidth - ((safeColumns - 1) * columnSpacing)) /
            safeColumns;
        final availableHeight =
            constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : (width * rowCount) + ((rowCount - 1) * rowSpacing);
        final height =
            (availableHeight - ((rowCount - 1) * rowSpacing)) / rowCount;

        return Wrap(
          spacing: columnSpacing,
          runSpacing: rowSpacing,
          children: [
            for (final child in children)
              SizedBox(width: width, height: math.max(height, 0), child: child),
          ],
        );
      },
    );
  }
}
