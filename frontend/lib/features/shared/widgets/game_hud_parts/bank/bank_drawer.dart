part of '../../game_hud.dart';

class BankDrawer extends StatelessWidget {
  const BankDrawer({
    super.key,
    required this.inventory,
    required this.bank,
    required this.onClose,
    required this.onDeposit,
  });

  final AsyncValue<List<InventoryItem>> inventory;
  final AsyncValue<List<InventoryItem>> bank;
  final VoidCallback onClose;
  final Future<void> Function(InventoryItem item) onDeposit;

  @override
  Widget build(BuildContext context) {
    final width =
        MediaQuery.sizeOf(context).width.clamp(320.0, 840.0).toDouble();
    return Container(
      key: const ValueKey('bank-drawer'),
      width: width,
      constraints: const BoxConstraints(maxHeight: 240),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3C2516), Color(0xFF21150D)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFB88948), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bank',
                        style: TextStyle(
                          color: Color(0xFFF1DEC4),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Tap an inventory stack to deposit it',
                        style: TextStyle(
                          color: Color(0xCCF1DEC4),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                InventoryCloseButton(onPressed: onClose),
              ],
            ),
            const SizedBox(height: 12),
            _BankSection(
              title: 'Inventory',
              subtitle: '1024 per slot',
              child: inventory.when(
                data:
                    (items) =>
                        _BankInventoryRow(items: items, onDeposit: onDeposit),
                loading: () => const InventoryGridLoading(),
                error: (_, _) => const InventoryGridError(),
              ),
            ),
            const SizedBox(height: 12),
            _BankSection(
              title: 'Bank',
              subtitle: 'Unlimited slots',
              child: bank.when(
                data: (items) => _BankStorageRow(items: items),
                loading: () => const InventoryGridLoading(),
                error: (_, _) => const InventoryGridError(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BankSection extends StatelessWidget {
  const _BankSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFFF1DEC4),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xBFD7B56D),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _BankInventoryRow extends StatelessWidget {
  const _BankInventoryRow({required this.items, required this.onDeposit});

  final List<InventoryItem> items;
  final Future<void> Function(InventoryItem item) onDeposit;

  @override
  Widget build(BuildContext context) {
    final visibleItems = items.take(8).toList(growable: false);
    return SizedBox(
      height: 58,
      child: Row(
        children: List.generate(
          8,
          (index) => Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: index == 7 ? 0 : 5),
              child: InventorySlot(
                item: index < visibleItems.length ? visibleItems[index] : null,
                onTap:
                    index < visibleItems.length
                        ? () => unawaited(onDeposit(visibleItems[index]))
                        : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BankStorageRow extends StatelessWidget {
  const _BankStorageRow({required this.items});

  final List<InventoryItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        height: 58,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0x22110D08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x444D422F)),
        ),
        child: const Text(
          'No items banked yet',
          style: TextStyle(
            color: Color(0xCCF1DEC4),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return SizedBox(
      height: 58,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var index = 0; index < items.length; index++)
              Padding(
                padding: EdgeInsets.only(
                  right: index == items.length - 1 ? 0 : 5,
                ),
                child: SizedBox(
                  width: 58,
                  child: InventorySlot(item: items[index]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
