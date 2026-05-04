class PlayerInboxItem {
  const PlayerInboxItem({
    required this.id,
    required this.eventId,
    required this.aggregateType,
    required this.aggregateId,
    required this.eventType,
    required this.status,
    required this.payload,
    required this.deliveredAt,
    required this.readAt,
    required this.createdAt,
  });

  final int id;
  final int eventId;
  final String aggregateType;
  final String? aggregateId;
  final String eventType;
  final String status;
  final Map<String, dynamic> payload;
  final DateTime deliveredAt;
  final DateTime? readAt;
  final DateTime createdAt;

  factory PlayerInboxItem.fromJson(Map<String, dynamic> json) {
    return PlayerInboxItem(
      id: _intValue(json['id']),
      eventId: _intValue(json['event_id']),
      aggregateType: json['aggregate_type'] as String? ?? '',
      aggregateId: json['aggregate_id'] as String?,
      eventType: json['event_type'] as String? ?? '',
      status: json['status'] as String? ?? 'unread',
      payload: Map<String, dynamic>.from(
        json['payload'] as Map? ?? const <String, dynamic>{},
      ),
      deliveredAt:
          DateTime.tryParse(json['delivered_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      readAt: DateTime.tryParse(json['read_at'] as String? ?? ''),
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  bool get isRead => status == 'read' || readAt != null;

  PlayerInboxItem markRead(DateTime timestamp) {
    return PlayerInboxItem(
      id: id,
      eventId: eventId,
      aggregateType: aggregateType,
      aggregateId: aggregateId,
      eventType: eventType,
      status: 'read',
      payload: payload,
      deliveredAt: deliveredAt,
      readAt: readAt ?? timestamp,
      createdAt: createdAt,
    );
  }

  String get title {
    switch (eventType) {
      case 'action.completed':
        final resourceKey = payload['resource_key'] as String? ?? '';
        final actionType = payload['action_type'] as String? ?? 'action';
        if (resourceKey.isNotEmpty) {
          return '${_humanizeKey(resourceKey)} finished';
        }
        return '${_humanizeKey(actionType)} complete';
      default:
        return _humanizeKey(eventType.replaceAll('.', '_'));
    }
  }

  String get summary {
    switch (eventType) {
      case 'action.completed':
        final rewardsGranted = _intValue(payload['rewards_granted']);
        final xpGranted = _intValue(payload['xp_granted']);
        final levelUps = _intValue(payload['level_ups']);
        final rewardItemKey = _rewardItemKey(payload);
        final parts = <String>[];
        if (rewardsGranted > 0) {
          final rewardLabel =
              rewardItemKey.isEmpty ? 'rewards' : _humanizeKey(rewardItemKey);
          parts.add('+$rewardsGranted $rewardLabel');
        }
        if (xpGranted > 0) {
          parts.add('+$xpGranted XP');
        }
        if (levelUps > 0) {
          parts.add(levelUps == 1 ? 'Level up' : '$levelUps levels gained');
        }
        if (parts.isEmpty) {
          return 'Your current action completed.';
        }
        return parts.join(' | ');
      default:
        return 'A new event was recorded for your account.';
    }
  }
}

String _rewardItemKey(Map<String, dynamic> payload) {
  final metadata = payload['action_metadata'];
  if (metadata is Map) {
    return metadata['reward_item_key'] as String? ?? '';
  }
  return '';
}

int _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}

String _humanizeKey(String value) {
  if (value.isEmpty) {
    return '';
  }
  final words =
      value
          .replaceAll('-', '_')
          .split('_')
          .where((part) => part.isNotEmpty)
          .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
          .toList();
  return words.join(' ');
}
