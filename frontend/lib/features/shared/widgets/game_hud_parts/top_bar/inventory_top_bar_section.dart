part of '../../game_hud.dart';

class InventoryTopBarSection extends StatelessWidget {
  const InventoryTopBarSection({
    super.key,
    required this.showDivider,
    required this.inventoryOpen,
    required this.onPressed,
  });

  final bool showDivider;
  final bool inventoryOpen;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (showDivider)
          const Positioned(
            left: -9,
            top: -6,
            bottom: -6,
            child: TopBarDivider(),
          ),
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.only(left: showDivider ? 14 : 0, right: 10),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  children: [
                    const TopBarIconWell(
                      child: Padding(
                        padding: EdgeInsets.all(4),
                        child: Image(
                          image: AssetImage(
                            'assets/images/ui/bar/icons/Inventory-icon.png',
                          ),
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.none,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Inventory',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xFFE3D8C3),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            inventoryOpen ? 'Hide' : 'Open',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color:
                                  inventoryOpen
                                      ? const Color(0xFFE2BF63)
                                      : const Color(0xFFDBCDB4),
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
