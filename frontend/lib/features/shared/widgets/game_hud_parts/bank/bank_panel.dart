part of '../../game_hud.dart';

class BankPanel extends StatelessWidget {
  const BankPanel({super.key, required this.bank, required this.onClose});

  final AsyncValue<List<InventoryItem>> bank;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 540, maxHeight: 380),
      child: Material(
        color: Colors.transparent,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF4F3722), Color(0xFF24170F)],
            ),
            border: Border.all(color: const Color(0xFFC79C59), width: 1.4),
            boxShadow: const [
              BoxShadow(
                color: Color(0xAA000000),
                blurRadius: 22,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              key: const ValueKey('bank-panel'),
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const _BankChestBadge(),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bank',
                            style: TextStyle(
                              color: Color(0xFFF4E5C5),
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                              height: 1,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Stored items',
                            style: TextStyle(
                              color: Color(0xFFE0C88A),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onClose,
                        borderRadius: BorderRadius.circular(12),
                        child: Ink(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0x22110D08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0x886E5A3E),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: Color(0xFFF2DEC0),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x2A120D08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0x665D4930),
                      width: 1,
                    ),
                  ),
                  child: const Text(
                    'Tap an inventory item below to deposit it into your bank.',
                    style: TextStyle(
                      color: Color(0xFFE8D7B8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0x44120D08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0x996E5A3C),
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: bank.when(
                        data:
                            (items) =>
                                items.isEmpty
                                    ? const _BankEmptyState()
                                    : LayoutBuilder(
                                      builder: (context, constraints) {
                                        final tileWidth =
                                            constraints.maxWidth > 420
                                                ? 88.0
                                                : 76.0;
                                        return GridView.builder(
                                          gridDelegate:
                                              SliverGridDelegateWithMaxCrossAxisExtent(
                                                maxCrossAxisExtent: tileWidth,
                                                mainAxisSpacing: 10,
                                                crossAxisSpacing: 10,
                                                childAspectRatio: 0.9,
                                              ),
                                          itemCount: items.length,
                                          itemBuilder:
                                              (context, index) => _BankItemTile(
                                                item: items[index],
                                              ),
                                        );
                                      },
                                    ),
                        loading:
                            () => const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFFE0C88A),
                                strokeWidth: 2.2,
                              ),
                            ),
                        error:
                            (_, _) => const Center(
                              child: Text(
                                'Unable to load bank items.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFFF4D6A0),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                      ),
                    ),
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

class _BankEmptyState extends StatelessWidget {
  const _BankEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BankChestBadge(size: 62),
          SizedBox(height: 14),
          Text(
            'Your bank is empty.',
            style: TextStyle(
              color: Color(0xFFF4E5C5),
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Gather materials, then deposit them from your inventory.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFD5C5A8),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _BankChestBadge extends StatelessWidget {
  const _BankChestBadge({this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.22),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF83552E), Color(0xFF51331D)],
          ),
          border: Border.all(color: const Color(0xFFE4C46F), width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: size * 0.16,
              left: size * 0.12,
              right: size * 0.12,
              child: Container(
                height: size * 0.2,
                decoration: BoxDecoration(
                  color: const Color(0xFFB57C46),
                  borderRadius: BorderRadius.circular(size * 0.12),
                ),
              ),
            ),
            Positioned(
              top: size * 0.43,
              left: 0,
              right: 0,
              child: Container(
                height: size * 0.12,
                color: const Color(0xFFE4C46F),
              ),
            ),
            Positioned(
              top: size * 0.3,
              bottom: size * 0.16,
              child: Container(
                width: size * 0.12,
                color: const Color(0xFFE4C46F),
              ),
            ),
            Positioned(
              bottom: size * 0.18,
              child: Container(
                width: size * 0.16,
                height: size * 0.16,
                decoration: BoxDecoration(
                  color: const Color(0xFFE9D89D),
                  borderRadius: BorderRadius.circular(size * 0.04),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BankItemTile extends StatelessWidget {
  const _BankItemTile({required this.item});

  final InventoryItem item;

  @override
  Widget build(BuildContext context) {
    final label = item.itemKey.replaceAll('_', ' ').trim();
    final usesLogIcon = logItemResourceKeys.containsKey(item.itemKey);
    final tintColor = logItemTintColor(item.itemKey);
    final initials =
        label.isEmpty
            ? ''
            : label
                .split(' ')
                .where((part) => part.isNotEmpty)
                .take(2)
                .map((part) => part.substring(0, 1).toUpperCase())
                .join();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x33150F08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xAA8A6A3A), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
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
                            width: 40,
                            height: 40,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.none,
                          ),
                        )
                        : Text(
                          initials,
                          style: const TextStyle(
                            color: Color(0xFFF4E5C5),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label.isEmpty ? item.itemKey : label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFE8D7B8),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'x${item.quantity}',
              style: const TextStyle(
                color: Color(0xFF83E04C),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
