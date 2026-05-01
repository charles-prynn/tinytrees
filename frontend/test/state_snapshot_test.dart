import 'package:flutter_test/flutter_test.dart';
import 'package:treescape/features/state/domain/state_snapshot.dart';

void main() {
  test('StateSnapshot.fromJson supports backend and sync payload keys', () {
    final snapshot = StateSnapshot.fromJson({
      'Version': 7,
      'Metadata': {'selected_tree': 'oak'},
      'UpdatedAt': '2026-04-24T15:00:00Z',
    });

    expect(snapshot.version, 7);
    expect(snapshot.metadata['selected_tree'], 'oak');
    expect(snapshot.updatedAt, DateTime.parse('2026-04-24T15:00:00Z'));
  });

  test('StateSnapshot.toSyncJson keeps the sync payload compact', () {
    const snapshot = StateSnapshot(
      version: 3,
      metadata: {'camera_zoom': 2},
      updatedAt: null,
    );

    expect(snapshot.toSyncJson(), {
      'version': 3,
      'metadata': {'camera_zoom': 2},
    });
  });
}
