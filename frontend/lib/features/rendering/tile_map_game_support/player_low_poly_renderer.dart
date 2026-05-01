part of '../tile_map_game.dart';

const _playerShadowColor = Color(0xFF0B120E);
const _playerOutlineColor = Color(0xFF22150D);
const _playerSkinColor = Color(0xFFD7B08A);
const _playerShirtColor = Color(0xFFB87A4C);
const _playerPantsColor = Color(0xFF526B45);
const _playerBootsColor = Color(0xFF40281A);
const _playerBeltColor = Color(0xFF5F3B27);
const _playerAxeWoodColor = Color(0xFF8D6239);
const _playerAxeMetalColor = Color(0xFFC8D3D9);
final _playerModelViewDirection =
    const _PlayerModelVector3(-0.72, -0.94, -0.48).normalized();
final _playerModelViewRight =
    const _PlayerModelVector3(
      0,
      1,
      0,
    ).cross(_playerModelViewDirection).normalized();
final _playerModelViewUp =
    _playerModelViewDirection.cross(_playerModelViewRight).normalized();
final _playerModelLightDirection =
    const _PlayerModelVector3(-0.35, 0.92, 0.28).normalized();

void _drawLowPolyPlayer({
  required Canvas canvas,
  required _PlayerPose pose,
  required Offset offset,
  required double drawTileSize,
  required double elapsedSeconds,
  required PlayerCharacterAnimation animation,
}) {
  final unit = drawTileSize * 0.44;
  final footX = offset.dx + (pose.position.dx + 0.5) * drawTileSize;
  final footY = offset.dy + (pose.position.dy + 1) * drawTileSize;
  final rig = _buildPlayerRig(
    rootYaw: pose.modelYaw,
    elapsedSeconds: elapsedSeconds,
    animation: animation,
  );

  final shadowPaint =
      Paint()
        ..color = _playerShadowColor.withValues(alpha: rig.shadowOpacity)
        ..style = PaintingStyle.fill;
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(footX, footY - drawTileSize * 0.05),
      width: drawTileSize * rig.shadowWidthTiles,
      height: drawTileSize * rig.shadowHeightTiles,
    ),
    shadowPaint,
  );

  final faces = <_PlayerProjectedFace>[];
  final rootTransform = _PlayerModelTransform(
    translation: _PlayerModelVector3(0, rig.bodyLift, 0),
    pitch: rig.bodyPitch,
    yaw: rig.rootYaw + rig.bodyYaw,
    roll: rig.bodyRoll,
  );

  _appendCuboidFaces(
    faces,
    min: const _PlayerModelVector3(-0.18, 1.02, -0.26),
    max: const _PlayerModelVector3(0.18, 1.28, 0.26),
    color: _playerBeltColor,
    transforms: [rootTransform],
    footX: footX,
    footY: footY,
    unit: unit,
  );
  _appendCuboidFaces(
    faces,
    min: const _PlayerModelVector3(-0.46, 1.16, -0.29),
    max: const _PlayerModelVector3(0.46, 2.32, 0.29),
    color: _playerShirtColor,
    transforms: [rootTransform],
    footX: footX,
    footY: footY,
    unit: unit,
  );
  _appendCuboidFaces(
    faces,
    min: const _PlayerModelVector3(-0.44, 1.0, -0.31),
    max: const _PlayerModelVector3(0.44, 1.18, 0.31),
    color: _playerPantsColor,
    transforms: [rootTransform],
    footX: footX,
    footY: footY,
    unit: unit,
  );

  final headTransform = _PlayerModelTransform(
    translation: const _PlayerModelVector3(0, 2.32, 0.02),
    pitch: rig.headPitch,
    roll: -rig.bodyRoll * 0.25,
  );
  _appendCuboidFaces(
    faces,
    min: const _PlayerModelVector3(-0.36, 0, -0.36),
    max: const _PlayerModelVector3(0.36, 0.72, 0.36),
    color: _playerSkinColor,
    transforms: [headTransform, rootTransform],
    footX: footX,
    footY: footY,
    unit: unit,
  );

  final leftLegTransform = _PlayerModelTransform(
    translation: const _PlayerModelVector3(-0.22, 1.04, 0),
    pitch: rig.leftLegPitch,
    roll: -0.05,
  );
  final rightLegTransform = _PlayerModelTransform(
    translation: const _PlayerModelVector3(0.22, 1.04, 0),
    pitch: rig.rightLegPitch,
    roll: 0.05,
  );
  _appendCuboidFaces(
    faces,
    min: const _PlayerModelVector3(-0.17, -1.02, -0.18),
    max: const _PlayerModelVector3(0.17, 0, 0.18),
    color: _playerPantsColor,
    transforms: [leftLegTransform, rootTransform],
    footX: footX,
    footY: footY,
    unit: unit,
  );
  _appendCuboidFaces(
    faces,
    min: const _PlayerModelVector3(-0.17, -1.02, -0.18),
    max: const _PlayerModelVector3(0.17, 0, 0.18),
    color: _playerPantsColor,
    transforms: [rightLegTransform, rootTransform],
    footX: footX,
    footY: footY,
    unit: unit,
  );
  _appendCuboidFaces(
    faces,
    min: const _PlayerModelVector3(-0.19, -0.22, -0.24),
    max: const _PlayerModelVector3(0.19, 0, 0.24),
    color: _playerBootsColor,
    transforms: [leftLegTransform, rootTransform],
    footX: footX,
    footY: footY,
    unit: unit,
  );
  _appendCuboidFaces(
    faces,
    min: const _PlayerModelVector3(-0.19, -0.22, -0.24),
    max: const _PlayerModelVector3(0.19, 0, 0.24),
    color: _playerBootsColor,
    transforms: [rightLegTransform, rootTransform],
    footX: footX,
    footY: footY,
    unit: unit,
  );

  final leftArmTransform = _PlayerModelTransform(
    translation: const _PlayerModelVector3(-0.58, 2.18, 0),
    pitch: rig.leftArmPitch,
    yaw: rig.leftArmYaw,
    roll: rig.leftArmRoll,
  );
  final rightArmTransform = _PlayerModelTransform(
    translation: const _PlayerModelVector3(0.58, 2.18, 0),
    pitch: rig.rightArmPitch,
    yaw: rig.rightArmYaw,
    roll: rig.rightArmRoll,
  );
  _appendCuboidFaces(
    faces,
    min: const _PlayerModelVector3(-0.13, -0.92, -0.13),
    max: const _PlayerModelVector3(0.13, 0, 0.13),
    color: _playerShirtColor,
    transforms: [leftArmTransform, rootTransform],
    footX: footX,
    footY: footY,
    unit: unit,
  );
  _appendCuboidFaces(
    faces,
    min: const _PlayerModelVector3(-0.13, -0.92, -0.13),
    max: const _PlayerModelVector3(0.13, 0, 0.13),
    color: _playerShirtColor,
    transforms: [rightArmTransform, rootTransform],
    footX: footX,
    footY: footY,
    unit: unit,
  );
  _appendCuboidFaces(
    faces,
    min: const _PlayerModelVector3(0.03, -1.44, -0.06),
    max: const _PlayerModelVector3(0.15, -0.10, 0.06),
    color: _playerAxeWoodColor,
    transforms: [rightArmTransform, rootTransform],
    footX: footX,
    footY: footY,
    unit: unit,
  );
  _appendCuboidFaces(
    faces,
    min: const _PlayerModelVector3(-0.06, -1.42, -0.12),
    max: const _PlayerModelVector3(0.36, -1.02, 0.12),
    color: _playerAxeMetalColor,
    transforms: [rightArmTransform, rootTransform],
    footX: footX,
    footY: footY,
    unit: unit,
  );

  faces.sort((a, b) => b.depth.compareTo(a.depth));
  final fillPaint = Paint()..style = PaintingStyle.fill;
  final outlinePaint =
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, drawTileSize * 0.028)
        ..strokeJoin = StrokeJoin.round
        ..color = _playerOutlineColor.withValues(alpha: 0.62);
  for (final face in faces) {
    fillPaint.color = face.color;
    canvas.drawPath(face.path, fillPaint);
    canvas.drawPath(face.path, outlinePaint);
  }
}

_PlayerRig _buildPlayerRig({
  required double rootYaw,
  required double elapsedSeconds,
  required PlayerCharacterAnimation animation,
}) {
  final idlePulse = math.sin(elapsedSeconds * 2.2);
  final walkPhase = elapsedSeconds * 8.4;
  final walkSwing =
      animation == PlayerCharacterAnimation.walk ? math.sin(walkPhase) : 0.0;
  final walkBounce =
      animation == PlayerCharacterAnimation.walk
          ? (0.5 - 0.5 * math.cos(walkPhase * 2))
          : 0.0;
  final slashPhase =
      animation == PlayerCharacterAnimation.slash
          ? (elapsedSeconds * 1.6) % 1.0
          : 0.0;

  var bodyLift = 0.05 + idlePulse * 0.03 + walkBounce * 0.12;
  var bodyPitch = 0.03 + walkBounce * 0.06;
  var bodyYaw = walkSwing * 0.06;
  var bodyRoll = walkSwing * 0.05;
  var headPitch = -idlePulse * 0.03 - walkBounce * 0.04;
  var leftArmPitch = walkSwing * 0.75 - 0.08;
  var rightArmPitch = -walkSwing * 0.75 - 0.12;
  var leftArmYaw = 0.0;
  var rightArmYaw = 0.0;
  var leftArmRoll = -0.10 - walkSwing * 0.06;
  var rightArmRoll = 0.10 + walkSwing * 0.06;
  var leftLegPitch = -walkSwing * 0.88;
  var rightLegPitch = walkSwing * 0.88;
  var shadowOpacity = 0.18 + walkBounce * 0.04;
  var shadowWidthTiles = 0.88 - walkBounce * 0.05;
  const shadowHeightTiles = 0.2;

  if (animation == PlayerCharacterAnimation.idle) {
    leftArmPitch = 0.02 + idlePulse * 0.06;
    rightArmPitch = -0.22 - idlePulse * 0.08;
    leftLegPitch = idlePulse * 0.04;
    rightLegPitch = -idlePulse * 0.04;
    bodyRoll = idlePulse * 0.03;
    bodyYaw = idlePulse * 0.025;
  }

  if (animation == PlayerCharacterAnimation.slash) {
    final windup = slashPhase < 0.36 ? _easeInOut(slashPhase / 0.36) : 1.0;
    final strike =
        slashPhase >= 0.36 ? _easeInOut((slashPhase - 0.36) / 0.64) : 0.0;
    bodyLift += 0.03 + strike * 0.08;
    bodyPitch += 0.08 + strike * 0.10;
    bodyYaw += windup * 0.32 - strike * 0.48;
    bodyRoll += windup * 0.05 - strike * 0.12;
    headPitch += windup * 0.08 - strike * 0.16;
    leftArmPitch = 0.16 + windup * 0.22 - strike * 0.42;
    leftArmYaw = -0.06 - strike * 0.14;
    leftArmRoll = -0.25 - strike * 0.12;
    rightArmPitch = -0.45 - windup * 1.35 + strike * 2.15;
    rightArmYaw = windup * 0.08 - strike * 0.32;
    rightArmRoll = 0.28 + windup * 0.22 - strike * 0.64;
    leftLegPitch = 0.08 - strike * 0.18;
    rightLegPitch = -0.12 + strike * 0.26;
    shadowOpacity = 0.24;
    shadowWidthTiles = 0.98;
  }

  return _PlayerRig(
    rootYaw: rootYaw,
    bodyLift: bodyLift,
    bodyPitch: bodyPitch,
    bodyYaw: bodyYaw,
    bodyRoll: bodyRoll,
    headPitch: headPitch,
    leftArmPitch: leftArmPitch,
    rightArmPitch: rightArmPitch,
    leftArmYaw: leftArmYaw,
    rightArmYaw: rightArmYaw,
    leftArmRoll: leftArmRoll,
    rightArmRoll: rightArmRoll,
    leftLegPitch: leftLegPitch,
    rightLegPitch: rightLegPitch,
    shadowOpacity: shadowOpacity.clamp(0.12, 0.32).toDouble(),
    shadowWidthTiles: shadowWidthTiles.clamp(0.76, 1.02).toDouble(),
    shadowHeightTiles: shadowHeightTiles,
  );
}

void _appendCuboidFaces(
  List<_PlayerProjectedFace> faces, {
  required _PlayerModelVector3 min,
  required _PlayerModelVector3 max,
  required Color color,
  required List<_PlayerModelTransform> transforms,
  required double footX,
  required double footY,
  required double unit,
}) {
  final vertices = [
    _PlayerModelVector3(min.x, min.y, min.z),
    _PlayerModelVector3(max.x, min.y, min.z),
    _PlayerModelVector3(max.x, max.y, min.z),
    _PlayerModelVector3(min.x, max.y, min.z),
    _PlayerModelVector3(min.x, min.y, max.z),
    _PlayerModelVector3(max.x, min.y, max.z),
    _PlayerModelVector3(max.x, max.y, max.z),
    _PlayerModelVector3(min.x, max.y, max.z),
  ];
  final transformed = [
    for (final vertex in vertices) _applyPlayerTransforms(vertex, transforms),
  ];
  final quads = <List<int>>[
    [4, 5, 6, 7],
    [1, 0, 3, 2],
    [5, 1, 2, 6],
    [0, 4, 7, 3],
    [7, 6, 2, 3],
    [0, 1, 5, 4],
  ];

  for (final quad in quads) {
    final a = transformed[quad[0]];
    final b = transformed[quad[1]];
    final c = transformed[quad[2]];
    final normal = (b - a).cross(c - a).normalized();
    if (normal.dot(_playerModelViewDirection) >= -0.02) {
      continue;
    }
    final projected = [
      for (final index in quad)
        _projectPlayerPoint(
          transformed[index],
          footX: footX,
          footY: footY,
          unit: unit,
        ),
    ];
    final path =
        Path()
          ..moveTo(projected[0].dx, projected[0].dy)
          ..lineTo(projected[1].dx, projected[1].dy)
          ..lineTo(projected[2].dx, projected[2].dy)
          ..lineTo(projected[3].dx, projected[3].dy)
          ..close();
    final light = normal.dot(_playerModelLightDirection).clamp(-1, 1);
    final brightness = (0.56 + math.max(0, light) * 0.34).clamp(0.42, 1.0);
    final depth =
        quad
            .map((index) => transformed[index].dot(_playerModelViewDirection))
            .reduce((sum, value) => sum + value) /
        quad.length;
    faces.add(
      _PlayerProjectedFace(
        path: path,
        depth: depth,
        color: _shadePlayerColor(color, brightness),
      ),
    );
  }
}

_PlayerModelVector3 _applyPlayerTransforms(
  _PlayerModelVector3 point,
  List<_PlayerModelTransform> transforms,
) {
  var transformed = point;
  for (final transform in transforms) {
    transformed = _rotatePlayerPoint(
      transformed,
      pitch: transform.pitch,
      yaw: transform.yaw,
      roll: transform.roll,
    );
    transformed = transformed + transform.translation;
  }
  return transformed;
}

_PlayerModelVector3 _rotatePlayerPoint(
  _PlayerModelVector3 point, {
  double pitch = 0,
  double yaw = 0,
  double roll = 0,
}) {
  var rotated = point;
  if (pitch != 0) {
    final sinPitch = math.sin(pitch);
    final cosPitch = math.cos(pitch);
    rotated = _PlayerModelVector3(
      rotated.x,
      rotated.y * cosPitch - rotated.z * sinPitch,
      rotated.y * sinPitch + rotated.z * cosPitch,
    );
  }
  if (yaw != 0) {
    final sinYaw = math.sin(yaw);
    final cosYaw = math.cos(yaw);
    rotated = _PlayerModelVector3(
      rotated.x * cosYaw + rotated.z * sinYaw,
      rotated.y,
      -rotated.x * sinYaw + rotated.z * cosYaw,
    );
  }
  if (roll != 0) {
    final sinRoll = math.sin(roll);
    final cosRoll = math.cos(roll);
    rotated = _PlayerModelVector3(
      rotated.x * cosRoll - rotated.y * sinRoll,
      rotated.x * sinRoll + rotated.y * cosRoll,
      rotated.z,
    );
  }
  return rotated;
}

Offset _projectPlayerPoint(
  _PlayerModelVector3 point, {
  required double footX,
  required double footY,
  required double unit,
}) {
  return Offset(
    footX + point.dot(_playerModelViewRight) * unit,
    footY - point.dot(_playerModelViewUp) * unit,
  );
}

Color _shadePlayerColor(Color base, double brightness) {
  final shadowed =
      Color.lerp(_playerOutlineColor, base, brightness.clamp(0, 1)) ?? base;
  final highlight = ((brightness - 1) * 0.45).clamp(0, 0.14).toDouble();
  return Color.lerp(shadowed, const Color(0xFFFFFFFF), highlight) ?? shadowed;
}

double _easeInOut(double t) {
  final clamped = t.clamp(0, 1).toDouble();
  return clamped * clamped * (3 - 2 * clamped);
}

class _PlayerRig {
  const _PlayerRig({
    required this.rootYaw,
    required this.bodyLift,
    required this.bodyPitch,
    required this.bodyYaw,
    required this.bodyRoll,
    required this.headPitch,
    required this.leftArmPitch,
    required this.rightArmPitch,
    required this.leftArmYaw,
    required this.rightArmYaw,
    required this.leftArmRoll,
    required this.rightArmRoll,
    required this.leftLegPitch,
    required this.rightLegPitch,
    required this.shadowOpacity,
    required this.shadowWidthTiles,
    required this.shadowHeightTiles,
  });

  final double rootYaw;
  final double bodyLift;
  final double bodyPitch;
  final double bodyYaw;
  final double bodyRoll;
  final double headPitch;
  final double leftArmPitch;
  final double rightArmPitch;
  final double leftArmYaw;
  final double rightArmYaw;
  final double leftArmRoll;
  final double rightArmRoll;
  final double leftLegPitch;
  final double rightLegPitch;
  final double shadowOpacity;
  final double shadowWidthTiles;
  final double shadowHeightTiles;
}

class _PlayerProjectedFace {
  const _PlayerProjectedFace({
    required this.path,
    required this.depth,
    required this.color,
  });

  final Path path;
  final double depth;
  final Color color;
}

class _PlayerModelTransform {
  const _PlayerModelTransform({
    this.translation = _PlayerModelVector3.zero,
    this.pitch = 0,
    this.yaw = 0,
    this.roll = 0,
  });

  final _PlayerModelVector3 translation;
  final double pitch;
  final double yaw;
  final double roll;
}

class _PlayerModelVector3 {
  const _PlayerModelVector3(this.x, this.y, this.z);

  static const zero = _PlayerModelVector3(0, 0, 0);

  final double x;
  final double y;
  final double z;

  _PlayerModelVector3 operator +(_PlayerModelVector3 other) {
    return _PlayerModelVector3(x + other.x, y + other.y, z + other.z);
  }

  _PlayerModelVector3 operator -(_PlayerModelVector3 other) {
    return _PlayerModelVector3(x - other.x, y - other.y, z - other.z);
  }

  _PlayerModelVector3 scale(double factor) {
    return _PlayerModelVector3(x * factor, y * factor, z * factor);
  }

  double dot(_PlayerModelVector3 other) {
    return x * other.x + y * other.y + z * other.z;
  }

  _PlayerModelVector3 cross(_PlayerModelVector3 other) {
    return _PlayerModelVector3(
      y * other.z - z * other.y,
      z * other.x - x * other.z,
      x * other.y - y * other.x,
    );
  }

  double get magnitude => math.sqrt(x * x + y * y + z * z);

  _PlayerModelVector3 normalized() {
    final length = magnitude;
    if (length == 0) {
      return this;
    }
    return scale(1 / length);
  }
}
