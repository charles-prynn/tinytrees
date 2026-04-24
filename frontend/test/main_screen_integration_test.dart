import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:starter_frontend/features/auth/data/auth_controller.dart';
import 'package:starter_frontend/features/auth/domain/auth_session.dart';
import 'package:starter_frontend/features/auth/domain/user.dart';
import 'package:starter_frontend/features/entities/data/entity_repository.dart';
import 'package:starter_frontend/features/entities/domain/world_entity.dart';
import 'package:starter_frontend/features/inventory/data/inventory_repository.dart';
import 'package:starter_frontend/features/inventory/domain/inventory_item.dart';
import 'package:starter_frontend/features/map/data/map_repository.dart';
import 'package:starter_frontend/features/map/domain/tile_map.dart';
import 'package:starter_frontend/features/player/data/player_repository.dart';
import 'package:starter_frontend/features/player/domain/player_state.dart';
import 'package:starter_frontend/features/shared/main_screen.dart';
import 'package:starter_frontend/features/state/data/state_repository.dart';
import 'package:starter_frontend/features/state/domain/state_snapshot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          final assetKey = const StringCodec().decodeMessage(message);
          if (assetKey == null) {
            return null;
          }

          final candidates = [
            assetKey,
            'assets/$assetKey',
            'assets/images/$assetKey',
          ];
          for (final candidate in candidates) {
            final file = File(candidate);
            if (await file.exists()) {
              final bytes = await file.readAsBytes();
              return ByteData.sublistView(bytes);
            }
          }
          throw StateError('Missing mocked asset: $assetKey');
        });
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });

  testWidgets('main screen renders idle player summaries', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _buildTestApp(
        player: _playerState(
          skills: const [
            PlayerSkill(
              skillKey: 'woodcutting',
              xp: 350,
              level: 2,
              updatedAt: null,
            ),
          ],
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('State version 7'), findsOneWidget);
    expect(find.text('Idle'), findsOneWidget);
    expect(find.text('Wood 12'), findsOneWidget);
    expect(
      find.text('Woodcutting Lv 2 (350 XP, 450 to next)'),
      findsOneWidget,
    );
  });

  testWidgets('main screen renders active harvest state', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _buildTestApp(
        player: _playerState(
          action: PlayerAction(
            id: 'action-1',
            type: 'harvest',
            entityId: 'tree-1',
            status: 'active',
            startedAt: DateTime.utc(2026, 4, 24, 15, 0),
            endsAt: DateTime.utc(2026, 4, 24, 15, 5),
            nextTickAt: DateTime.utc(2026, 4, 24, 15, 0, 3),
            tickIntervalMs: 3000,
            metadata: const {'reward_item_key': 'wood'},
            updatedAt: DateTime.utc(2026, 4, 24, 15, 0),
          ),
          skills: const [
            PlayerSkill(
              skillKey: 'woodcutting',
              xp: 25,
              level: 1,
              updatedAt: null,
            ),
          ],
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Harvesting wood'), findsOneWidget);
    expect(find.text('Woodcutting Lv 1 (25 XP, 275 to next)'), findsOneWidget);
  });
}

Widget _buildTestApp({required PlayerState player}) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(() => _FakeAuthController()),
      tileMapProvider.overrideWith((ref) async => _tileMap),
      worldEntitiesProvider.overrideWith((ref) async => _entities),
      playerStateProvider.overrideWith((ref) async => player),
      inventoryProvider.overrideWith((ref) async => _inventory),
      stateSnapshotProvider.overrideWith((ref) async => _snapshot),
    ],
    child: const MaterialApp(home: MainScreen()),
  );
}

class _FakeAuthController extends AuthController {
  @override
  Future<AuthSession?> build() async {
    return const AuthSession(
      user: AppUser(id: 'user-1', provider: 'guest', displayName: 'Guest'),
    );
  }

  @override
  Future<void> logout() async {
    state = const AsyncData(null);
  }
}

PlayerState _playerState({
  PlayerAction? action,
  List<PlayerSkill> skills = const [],
}) {
  return PlayerState(
    userId: 'user-1',
    x: 16,
    y: 8,
    movement: null,
    action: action,
    skills: skills,
    updatedAt: DateTime.utc(2026, 4, 24, 15, 0),
  );
}

const _tileMap = TileMap(
  width: 4,
  height: 4,
  tileSize: 32,
  tiles: [
    1, 1, 1, 1,
    1, 1, 1, 1,
    1, 1, 1, 1,
    1, 1, 1, 1,
  ],
  updatedAt: null,
);

const _entities = [
  WorldEntity(
    id: 'tree-1',
    name: 'Tree',
    type: 'resource',
    resourceKey: 'autumn_tree',
    x: 2,
    y: 2,
    width: 1,
    height: 1,
    spriteGid: 5,
    state: 'idle',
  ),
];

const _inventory = [
  InventoryItem(itemKey: 'wood', quantity: 12, updatedAt: null),
];

final _snapshot = StateSnapshot(
  version: 7,
  metadata: const {},
  updatedAt: DateTime.utc(2026, 4, 24, 15, 0),
);
