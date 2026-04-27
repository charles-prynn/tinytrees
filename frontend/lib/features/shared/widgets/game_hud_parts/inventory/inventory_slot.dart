part of '../../game_hud.dart';

class InventorySlot extends StatelessWidget {
  const InventorySlot({super.key, this.item});

  final InventoryItem? item;

  @override
  Widget build(BuildContext context) {
    final label = item == null ? '' : item!.itemKey.replaceAll('_', ' ').trim();
    final initials =
        label.isEmpty
            ? ''
            : label
                .split(' ')
                .where((part) => part.isNotEmpty)
                .take(2)
                .map((part) => part.substring(0, 1).toUpperCase())
                .join();
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x331A140C),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0x995B503A), width: 1),
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
                        Text(
                          initials,
                          style: const TextStyle(
                            color: Color(0xFFE3D8C3),
                            fontSize: 7.5,
                            fontWeight: FontWeight.w700,
                            height: 1,
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
    );
  }
}
