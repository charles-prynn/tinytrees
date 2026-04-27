part of '../../game_hud.dart';

class InventoryDrawer extends StatelessWidget {
  const InventoryDrawer({
    super.key,
    required this.inventory,
    required this.onClose,
  });

  static const _height = TopBar.barHeight;
  static const _capSourceWidth = 25.0;
  static const _sourceHeight = 130.0;

  final AsyncValue<List<InventoryItem>> inventory;
  final VoidCallback onClose;

  double get _capWidth => _height * (_capSourceWidth / _sourceHeight);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('inventory-drawer'),
      height: _height,
      width: double.infinity,
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: _capWidth,
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
                width: _capWidth,
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
                _capWidth + 14,
                6,
                _capWidth + 14,
                6,
              ),
              child: Row(
                children: [
                  const Text(
                    'Inventory',
                    style: TextStyle(
                      color: Color(0xFFE3D8C3),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: inventory.when(
                      data: (items) => InventoryGrid(items: items),
                      loading: () => const InventoryGridLoading(),
                      error: (_, _) => const InventoryGridError(),
                    ),
                  ),
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
}
