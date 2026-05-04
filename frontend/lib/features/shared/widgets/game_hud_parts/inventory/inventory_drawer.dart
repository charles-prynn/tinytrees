part of '../../game_hud.dart';

class InventoryDrawer extends StatelessWidget {
  const InventoryDrawer({
    super.key,
    required this.layout,
    required this.inventory,
    required this.onClose,
    required this.title,
    this.onItemTap,
  });

  static const _capSourceWidth = 25.0;
  static const _sourceHeight = 130.0;

  final _HudLayout layout;
  final AsyncValue<List<InventoryItem>> inventory;
  final VoidCallback onClose;
  final String title;
  final ValueChanged<InventoryItem>? onItemTap;

  @override
  Widget build(BuildContext context) {
    final height = layout.inventoryHeight;
    final capWidth = height * (_capSourceWidth / _sourceHeight);
    return SizedBox(
      key: const ValueKey('inventory-drawer'),
      height: height,
      width: double.infinity,
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: capWidth,
                child: const Image(
                  image: AssetImage('assets/images/ui/bar/left-bar.png'),
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.none,
                ),
              ),
              const Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/ui/bar/middle-bar.png'),
                      repeat: ImageRepeat.repeatX,
                      fit: BoxFit.fitHeight,
                      alignment: Alignment.centerLeft,
                      filterQuality: FilterQuality.none,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: capWidth,
                child: const Image(
                  image: AssetImage('assets/images/ui/bar/right-bar.png'),
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.none,
                ),
              ),
            ],
          ),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                capWidth + (layout.compactInventory ? 12 : 14),
                6,
                capWidth + (layout.compactInventory ? 12 : 14),
                layout.compactInventory ? 8 : 6,
              ),
              child:
                  layout.compactInventory
                      ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  color: Color(0xFFE3D8C3),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                ),
                              ),
                              const Spacer(),
                              InventoryCloseButton(onPressed: onClose),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Expanded(child: _buildInventoryBody()),
                        ],
                      )
                      : Row(
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Color(0xFFE3D8C3),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: _buildInventoryBody()),
                          const SizedBox(width: 8),
                          InventoryCloseButton(onPressed: onClose),
                        ],
                      ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryBody() {
    return inventory.when(
      data:
          (items) => InventoryGrid(
            items: items,
            onItemTap: onItemTap,
            columns: layout.inventoryColumns,
          ),
      loading: () => InventoryGridLoading(columns: layout.inventoryColumns),
      error: (_, _) => const InventoryGridError(),
    );
  }
}
