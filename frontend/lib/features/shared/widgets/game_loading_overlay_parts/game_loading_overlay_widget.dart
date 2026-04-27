part of '../game_loading_overlay.dart';

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
