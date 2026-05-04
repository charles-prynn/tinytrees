import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/realtime/game_socket.dart';
import '../../bootstrap/data/bootstrap_repository.dart';
import '../data/event_repository.dart';
import '../domain/player_inbox_item.dart';

final eventInboxControllerProvider =
    AsyncNotifierProvider<EventInboxController, List<PlayerInboxItem>>(
      EventInboxController.new,
    );

final unreadInboxCountProvider = Provider<int>((ref) {
  final items =
      ref.watch(eventInboxControllerProvider).asData?.value ?? const [];
  return items.where((item) => !item.isRead).length;
});

class EventInboxController extends AsyncNotifier<List<PlayerInboxItem>> {
  StreamSubscription<Map<String, dynamic>>? _inboxSubscription;
  StreamSubscription<GameSocketConnectionState>? _connectionSubscription;
  GameSocketConnectionState _lastConnectionState =
      GameSocketConnectionState.disconnected;

  @override
  Future<List<PlayerInboxItem>> build() async {
    await ref.watch(appBootstrapProvider.future);
    final socket = ref.watch(gameSocketProvider);
    final repository = ref.watch(eventRepositoryProvider);

    unawaited(_inboxSubscription?.cancel());
    unawaited(_connectionSubscription?.cancel());

    _inboxSubscription = socket.messagesOfType('events.updated').listen((data) {
      state = AsyncData(repository.parseInbox(data));
    });
    _connectionSubscription = socket.connectionStates.listen((next) {
      final shouldRefresh =
          next == GameSocketConnectionState.connected &&
          _lastConnectionState != GameSocketConnectionState.connected;
      _lastConnectionState = next;
      if (shouldRefresh) {
        unawaited(refresh());
      }
    });

    ref.onDispose(() {
      unawaited(_inboxSubscription?.cancel() ?? Future<void>.value());
      unawaited(_connectionSubscription?.cancel() ?? Future<void>.value());
    });

    return repository.fetchInbox();
  }

  Future<void> refresh() async {
    final repository = ref.read(eventRepositoryProvider);
    try {
      final items = await repository.fetchInbox();
      state = AsyncData(items);
    } catch (error, stackTrace) {
      if (state.hasValue) {
        return;
      }
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> ackUnread() async {
    final unreadIDs =
        (state.asData?.value ?? const <PlayerInboxItem>[])
            .where((item) => !item.isRead)
            .map((item) => item.id)
            .toList();
    await ack(unreadIDs);
  }

  Future<void> ack(List<int> ids) async {
    final normalized = ids.where((id) => id > 0).toSet().toList()..sort();
    if (normalized.isEmpty) {
      return;
    }

    final previous = state.asData?.value ?? const <PlayerInboxItem>[];
    final optimistic = _markRead(previous, normalized, DateTime.now().toUtc());
    state = AsyncData(optimistic);

    try {
      final acked = await ref
          .read(eventRepositoryProvider)
          .ackInbox(normalized);
      state = AsyncData(_mergeAcked(optimistic, acked));
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      state = AsyncData(previous);
    }
  }

  List<PlayerInboxItem> _markRead(
    List<PlayerInboxItem> items,
    List<int> ids,
    DateTime timestamp,
  ) {
    final selected = ids.toSet();
    return [
      for (final item in items)
        selected.contains(item.id) ? item.markRead(timestamp) : item,
    ];
  }

  List<PlayerInboxItem> _mergeAcked(
    List<PlayerInboxItem> items,
    List<PlayerInboxItem> acked,
  ) {
    if (acked.isEmpty) {
      return items;
    }
    final byID = {for (final item in acked) item.id: item};
    return [for (final item in items) byID[item.id] ?? item];
  }
}
