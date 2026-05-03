part of '../../game_hud.dart';

class InventorySlot extends StatelessWidget {
  const InventorySlot({super.key, this.item, this.onTap});

  final InventoryItem? item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = item == null ? '' : item!.itemKey.replaceAll('_', ' ').trim();
    final usesLogIcon =
        item != null && logItemResourceKeys.containsKey(item!.itemKey);
    final tintColor = item == null ? null : logItemTintColor(item!.itemKey);
    final initials =
        label.isEmpty
            ? ''
            : label
                .split(' ')
                .where((part) => part.isNotEmpty)
                .take(2)
                .map((part) => part.substring(0, 1).toUpperCase())
                .join();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item == null ? null : onTap,
        borderRadius: BorderRadius.circular(6),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0x331A140C),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color:
                  onTap == null
                      ? const Color(0x995B503A)
                      : const Color(0xFFB88948),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0x22110D08),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0x444D422F), width: 0.8),
              ),
              child:
                  item == null
                      ? const SizedBox.expand()
                      : Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 3,
                          vertical: 2,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Center(
                                child:
                                    usesLogIcon
                                        ? ColorFiltered(
                                          colorFilter:
                                              tintColor == null
                                                  ? const ColorFilter.mode(
                                                    Colors.white,
                                                    BlendMode.modulate,
                                                  )
                                                  : ColorFilter.mode(
                                                    tintColor,
                                                    BlendMode.modulate,
                                                  ),
                                          child: Image.asset(
                                            'assets/images/entities/inventory_log.png',
                                            width: 28,
                                            height: 28,
                                            fit: BoxFit.contain,
                                            filterQuality: FilterQuality.none,
                                          ),
                                        )
                                        : Text(
                                          initials,
                                          style: const TextStyle(
                                            color: Color(0xFFE3D8C3),
                                            fontSize: 7.5,
                                            fontWeight: FontWeight.w700,
                                            height: 1,
                                          ),
                                        ),
                              ),
                            ),
                            Text(
                              'x${item!.quantity}',
                              style: const TextStyle(
                                color: Color(0xFF6FCF38),
                                fontSize: 6.6,
                                fontWeight: FontWeight.w700,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
            ),
          ),
        ),
      ),
    );
  }
}
