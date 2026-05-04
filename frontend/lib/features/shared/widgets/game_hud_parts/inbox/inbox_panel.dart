part of '../../game_hud.dart';

class InboxPanel extends StatelessWidget {
  const InboxPanel({
    super.key,
    required this.inbox,
    required this.onClose,
    required this.onMarkAllRead,
  });

  final AsyncValue<List<PlayerInboxItem>> inbox;
  final VoidCallback onClose;
  final VoidCallback onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    final items = inbox.asData?.value ?? const <PlayerInboxItem>[];
    final unreadCount = items.where((item) => !item.isRead).length;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420, maxHeight: 320),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF2D241B), Color(0xFF1D1711)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: const Color(0xFFC9A06B), width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        color: Color(0xFFF4E6CE),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (unreadCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _UserActionButton(
                        label: 'Read all',
                        onPressed: onMarkAllRead,
                      ),
                    ),
                  _UserActionButton(label: 'Close', onPressed: onClose),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                unreadCount > 0
                    ? (unreadCount == 1
                        ? '1 unread update'
                        : '$unreadCount unread updates')
                    : 'All caught up',
                style: TextStyle(
                  color:
                      unreadCount > 0
                          ? const Color(0xFFF0C56D)
                          : const Color(0xFFD5C4AA),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(child: _buildBody(items)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(List<PlayerInboxItem> items) {
    if (inbox.isLoading && items.isEmpty) {
      return const Center(
        child: SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFFF0C56D),
          ),
        ),
      );
    }
    if (inbox.hasError && items.isEmpty) {
      return const Center(
        child: Text(
          'Notifications are unavailable right now.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFFE7D7BF),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'No completed actions yet.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFFE7D7BF),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color:
                item.isRead ? const Color(0x221D140C) : const Color(0x334D341D),
            border: Border.all(
              color:
                  item.isRead
                      ? const Color(0x666D5741)
                      : const Color(0xFFC9A06B),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: TextStyle(
                        color:
                            item.isRead
                                ? const Color(0xFFE7D7BF)
                                : const Color(0xFFF7E7C9),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _relativeTimeLabel(item.deliveredAt),
                    style: const TextStyle(
                      color: Color(0xFFD0B48A),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                item.summary,
                style: const TextStyle(
                  color: Color(0xFFE3D8C3),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

String _relativeTimeLabel(DateTime timestamp) {
  final now = DateTime.now().toUtc();
  final diff = now.difference(timestamp);
  if (diff.inSeconds < 60) {
    return 'Just now';
  }
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes}m ago';
  }
  if (diff.inHours < 24) {
    return '${diff.inHours}h ago';
  }
  return '${diff.inDays}d ago';
}
