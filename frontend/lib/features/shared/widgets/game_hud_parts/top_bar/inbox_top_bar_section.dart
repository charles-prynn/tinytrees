part of '../../game_hud.dart';

class InboxTopBarSection extends StatelessWidget {
  const InboxTopBarSection({
    super.key,
    required this.showDivider,
    required this.inbox,
    required this.inboxOpen,
    required this.onPressed,
  });

  final bool showDivider;
  final AsyncValue<List<PlayerInboxItem>> inbox;
  final bool inboxOpen;
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
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  TopBarIconWell(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.notifications_none_rounded,
                            size: 15,
                            color: Color(0xFFF0E1C9),
                          ),
                        ),
                        if (_unreadCount > 0)
                          Positioned(
                            right: -3,
                            top: -3,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFB33B2E),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: const Color(0xFFF6D3C5),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                _badgeLabel(_unreadCount),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 6.5,
                                  fontWeight: FontWeight.w800,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Inbox',
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
                          _statusLabel(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _statusColor(),
                            fontSize: 8.3,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  _UserActionButton(
                    label: inboxOpen ? 'Close' : 'Open',
                    onPressed: onPressed,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  int get _unreadCount {
    final items = inbox.asData?.value ?? const <PlayerInboxItem>[];
    return items.where((item) => !item.isRead).length;
  }

  String _statusLabel() {
    final items = inbox.asData?.value;
    if (inbox.isLoading && items == null) {
      return 'Loading';
    }
    if (inbox.hasError && (items?.isEmpty ?? true)) {
      return 'Unavailable';
    }
    if (_unreadCount > 0) {
      return _unreadCount == 1 ? '1 unread' : '$_unreadCount unread';
    }
    final loadedItems = items ?? const <PlayerInboxItem>[];
    if (loadedItems.isEmpty) {
      return 'No updates';
    }
    return 'All caught up';
  }

  Color _statusColor() {
    final items = inbox.asData?.value;
    if (_unreadCount > 0) {
      return const Color(0xFFF0C56D);
    }
    if (inbox.hasError && (items?.isEmpty ?? true)) {
      return const Color(0xFFE68A7A);
    }
    return const Color(0xFFE3D8C3);
  }
}

String _badgeLabel(int count) {
  if (count > 99) {
    return '99+';
  }
  return '$count';
}
