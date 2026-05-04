import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/realtime/game_socket.dart';
import '../domain/player_inbox_item.dart';

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepository(ref.watch(gameSocketProvider));
});

class EventRepository {
  const EventRepository(this._socket);

  final GameSocket _socket;

  Future<List<PlayerInboxItem>> fetchInbox() async {
    final data = await _socket.request('events.inbox');
    return parseInbox(data);
  }

  Future<List<PlayerInboxItem>> ackInbox(List<int> ids) async {
    final data = await _socket.request('events.ack', payload: {'ids': ids});
    return parseInbox(data);
  }

  List<PlayerInboxItem> parseInbox(Map<String, dynamic> data) {
    final items = data['items'] as List<dynamic>? ?? const [];
    return items
        .map((item) => PlayerInboxItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
