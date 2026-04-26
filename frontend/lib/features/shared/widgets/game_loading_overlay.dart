import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../entities/data/entity_repository.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../map/application/map_controller.dart';
import '../../player/application/player_controller.dart';
import '../../../core/realtime/game_socket.dart';
import 'registration_popup.dart';

class GameLoadingOverlay extends StatelessWidget {
  const GameLoadingOverlay({
    super.key,
    required this.assetsReady,
    required this.mapReady,
    required this.resourcesReady,
    required this.playerReady,
    required this.inventoryReady,
    required this.errorMessage,
    required this.onRetry,
  });

  final bool assetsReady;
  final bool mapReady;
  final bool resourcesReady;
  final bool playerReady;
  final bool inventoryReady;
  final String? errorMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final hasError = errorMessage != null;

    return PopupPanel(
      key: const ValueKey('game-loading-overlay'),
      title: 'Loading',
      overlayColor: const Color(0xCC120D08),
      maxWidth: 440,
      maxHeightFactor: 0.82,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            hasError ? 'The world failed to load.' : 'Preparing the world...',
            style: const TextStyle(
              color: Color(0xFFE3D8C3),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 12),
          _LoadingStatusRow(
            label: 'Assets',
            ready: assetsReady,
            failed: hasError && !assetsReady,
          ),
          const SizedBox(height: 6),
          _LoadingStatusRow(
            label: 'Map',
            ready: mapReady,
            failed: hasError && !mapReady,
          ),
          const SizedBox(height: 6),
          _LoadingStatusRow(
            label: 'Resources',
            ready: resourcesReady,
            failed: hasError && !resourcesReady,
          ),
          const SizedBox(height: 6),
          _LoadingStatusRow(
            label: 'Player',
            ready: playerReady,
            failed: hasError && !playerReady,
          ),
          const SizedBox(height: 6),
          _LoadingStatusRow(
            label: 'Inventory',
            ready: inventoryReady,
            failed: hasError && !inventoryReady,
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              errorMessage!,
              style: const TextStyle(
                color: Color(0xFFF28F7A),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!hasError)
                const Padding(
                  padding: EdgeInsets.only(right: 10),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Color(0xFFE2BF63)),
                    ),
                  ),
                ),
              if (hasError)
                PopupButton(
                  label: 'Retry',
                  highlighted: true,
                  onPressed: onRetry,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoadingStatusRow extends StatelessWidget {
  const _LoadingStatusRow({
    required this.label,
    required this.ready,
    required this.failed,
  });

  final String label;
  final bool ready;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final status =
        failed
            ? 'Failed'
            : ready
            ? 'Ready'
            : 'Loading';
    final color =
        failed
            ? const Color(0xFFF28F7A)
            : ready
            ? const Color(0xFF6FCF38)
            : const Color(0xFFE2BF63);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x33150F08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0x665B503A), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFFE3D8C3),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

void retryGameLoad(WidgetRef ref) {
  ref.invalidate(mapControllerProvider);
  ref.invalidate(worldEntitiesProvider);
  ref.invalidate(playerControllerProvider);
  ref.invalidate(inventoryProvider);
}

class GameConnectionBanner extends StatelessWidget {
  const GameConnectionBanner({super.key, required this.state});

  final GameSocketConnectionState state;

  @override
  Widget build(BuildContext context) {
    final label = switch (state) {
      GameSocketConnectionState.connecting => 'Connecting...',
      GameSocketConnectionState.reconnecting => 'Reconnecting...',
      GameSocketConnectionState.disconnected => 'Offline',
      GameSocketConnectionState.connected => 'Connected',
    };
    final color = switch (state) {
      GameSocketConnectionState.disconnected => const Color(0xFFF28F7A),
      GameSocketConnectionState.connected => const Color(0xFF6FCF38),
      _ => const Color(0xFFE2BF63),
    };

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF2A2419),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xAA7C6B48), width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (state != GameSocketConnectionState.disconnected)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(color),
                        ),
                      ),
                    ),
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
