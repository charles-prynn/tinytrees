part of '../game_loading_overlay.dart';

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
