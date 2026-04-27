part of '../tile_map_game.dart';

class _PlayerRenderMotion {
  const _PlayerRenderMotion({
    required this.from,
    required this.to,
    required this.startedAtSeconds,
    required this.endsAtSeconds,
  });

  factory _PlayerRenderMotion.snap(Offset position) {
    return _PlayerRenderMotion(
      from: position,
      to: position,
      startedAtSeconds: 0,
      endsAtSeconds: 0,
    );
  }

  final Offset from;
  final Offset to;
  final double startedAtSeconds;
  final double endsAtSeconds;

  bool isActiveAt(double elapsedSeconds) {
    return endsAtSeconds > startedAtSeconds && elapsedSeconds < endsAtSeconds;
  }

  Offset positionAt(double elapsedSeconds) {
    if (endsAtSeconds <= startedAtSeconds) {
      return to;
    }
    final progress =
        ((elapsedSeconds - startedAtSeconds) /
                (endsAtSeconds - startedAtSeconds))
            .clamp(0, 1)
            .toDouble();
    final eased = progress * progress * (3 - 2 * progress);
    return Offset.lerp(from, to, eased) ?? to;
  }
}
