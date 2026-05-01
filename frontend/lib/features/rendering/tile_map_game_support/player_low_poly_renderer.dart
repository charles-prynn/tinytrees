part of '../tile_map_game.dart';

const _playerShadowColor = Color(0xFF0B120E);
const _playerOutlineColor = Color(0xFF22150D);
const _playerSkinColor = Color(0xFFD7B08A);
const _playerShirtColor = Color(0xFFB87A4C);
const _playerPantsColor = Color(0xFF526B45);
const _playerBootsColor = Color(0xFF40281A);
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
const _playerLowPolyUnitScale = 0.66;
const _playerHeadBodyRollResponse = 0.25;
const _playerLeftLegStanceRoll = -0.05;
const _playerRightLegStanceRoll = 0.05;
const _playerDefaultShadowHeightTiles = 0.2;
const _playerLowPolyModel = _PlayerModelSpec(
  torso: _PlayerBoxSpec(
    center: _PlayerModelVector3(0, 1.74, 0),
    size: _PlayerModelVector3(0.92, 1.16, 0.58),
    color: _playerShirtColor,
  ),
  hips: _PlayerBoxSpec(
    center: _PlayerModelVector3(0, 1.09, 0),
    size: _PlayerModelVector3(0.88, 0.18, 0.62),
    color: _playerPantsColor,
  ),
  head: _PlayerBoxSpec(
    center: _PlayerModelVector3(0, 0.36, 0),
    size: _PlayerModelVector3(0.72, 0.72, 0.72),
    color: _playerSkinColor,
  ),
  arm: _PlayerBoxSpec(
    center: _PlayerModelVector3(0, -0.46, 0),
    size: _PlayerModelVector3(0.26, 0.92, 0.26),
    color: _playerShirtColor,
  ),
  leg: _PlayerBoxSpec(
    center: _PlayerModelVector3(0, -0.51, 0),
    size: _PlayerModelVector3(0.34, 1.02, 0.36),
    color: _playerPantsColor,
  ),
  boot: _PlayerBoxSpec(
    center: _PlayerModelVector3(0, -0.11, 0),
    size: _PlayerModelVector3(0.38, 0.22, 0.48),
    color: _playerBootsColor,
  ),
  headAnchor: _PlayerModelVector3(0, 2.32, 0.02),
  leftShoulderAnchor: _PlayerModelVector3(-0.58, 2.18, 0),
  rightShoulderAnchor: _PlayerModelVector3(0.58, 2.18, 0),
  leftHipAnchor: _PlayerModelVector3(-0.22, 1.04, 0),
  rightHipAnchor: _PlayerModelVector3(0.22, 1.04, 0),
  axe: _PlayerToolMountSpec(
    gripTransform: _PlayerModelTransform(
      translation: _PlayerModelVector3(0.11, -0.84, 0),
      pitch: 0.98,
      roll: -1.37,
    ),
    handle: _PlayerBoxSpec(
      center: _PlayerModelVector3(0.10, 0.55, 0),
      size: _PlayerModelVector3(0.12, 1.30, 0.12),
      color: _playerAxeWoodColor,
    ),
    head: _PlayerBoxSpec(
      center: _PlayerModelVector3(0.21, 1.18, 0),
      size: _PlayerModelVector3(0.42, 0.40, 0.24),
      color: _playerAxeMetalColor,
    ),
  ),
);

void _drawLowPolyPlayer({
  required Canvas canvas,
  required _PlayerPose pose,
  required Offset offset,
  required double drawTileSize,
  required double elapsedSeconds,
  required PlayerCharacterAnimation animation,
}) {
  final unit = drawTileSize * _playerLowPolyUnitScale;
  final footX = offset.dx + (pose.position.dx + 0.5) * drawTileSize;
  final footY = offset.dy + (pose.position.dy + 1) * drawTileSize;
  final model = _playerLowPolyModel;
  final animationPose = _buildPlayerAnimationPose(
    elapsedSeconds: elapsedSeconds,
    animation: animation,
  );
  final rig = _buildPlayerRigPose(
    rootYaw: pose.modelYaw,
    animationPose: animationPose,
  );

  final shadowPaint =
      Paint()
        ..color = _playerShadowColor.withValues(alpha: rig.shadow.opacity)
        ..style = PaintingStyle.fill;
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(footX, footY - drawTileSize * 0.05),
      width: drawTileSize * rig.shadow.widthTiles,
      height: drawTileSize * rig.shadow.heightTiles,
    ),
    shadowPaint,
  );

  final faces = <_PlayerProjectedFace>[];
  _appendCuboidFaces(
    faces,
    box: model.torso,
    transforms: [rig.root],
    footX: footX,
    footY: footY,
    unit: unit,
  );
  _appendCuboidFaces(
    faces,
    box: model.hips,
    transforms: [rig.root],
    footX: footX,
    footY: footY,
    unit: unit,
  );
  _appendCuboidFaces(
    faces,
    box: model.head,
    transforms: [rig.head, rig.root],
    footX: footX,
    footY: footY,
    unit: unit,
  );
  _appendCuboidFaces(
    faces,
    box: model.leg,
    transforms: [rig.leftLeg, rig.root],
    footX: footX,
    footY: footY,
    unit: unit,
  );
  _appendCuboidFaces(
    faces,
    box: model.leg,
    transforms: [rig.rightLeg, rig.root],
    footX: footX,
    footY: footY,
    unit: unit,
  );
  _appendCuboidFaces(
    faces,
    box: model.boot,
    transforms: [rig.leftLeg, rig.root],
    footX: footX,
    footY: footY,
    unit: unit,
  );
  _appendCuboidFaces(
    faces,
    box: model.boot,
    transforms: [rig.rightLeg, rig.root],
    footX: footX,
    footY: footY,
    unit: unit,
  );
  _appendCuboidFaces(
    faces,
    box: model.arm,
    transforms: [rig.leftArm, rig.root],
    footX: footX,
    footY: footY,
    unit: unit,
  );
  _appendCuboidFaces(
    faces,
    box: model.arm,
    transforms: [rig.rightArm, rig.root],
    footX: footX,
    footY: footY,
    unit: unit,
  );
  _appendCuboidFaces(
    faces,
    box: model.axe.handle,
    transforms: [model.axe.gripTransform, rig.rightArm, rig.root],
    footX: footX,
    footY: footY,
    unit: unit,
  );
  _appendCuboidFaces(
    faces,
    box: model.axe.head,
    transforms: [model.axe.gripTransform, rig.rightArm, rig.root],
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

_PlayerAnimationPose _buildPlayerAnimationPose({
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
  var body = _PlayerJointPose(
    pitch: 0.03 + walkBounce * 0.06,
    yaw: walkSwing * 0.06,
    roll: walkSwing * 0.05,
  );
  var head = _PlayerJointPose(pitch: -idlePulse * 0.03 - walkBounce * 0.04);
  var leftArm = _PlayerJointPose(
    pitch: walkSwing * 0.75 - 0.08,
    roll: -0.10 - walkSwing * 0.06,
  );
  var rightArm = _PlayerJointPose(
    pitch: -0.88 - walkSwing * 0.22,
    roll: 0.42 + walkSwing * 0.05,
  );
  var leftLeg = _PlayerJointPose(pitch: -walkSwing * 0.88);
  var rightLeg = _PlayerJointPose(pitch: walkSwing * 0.88);
  var shadow = _PlayerShadowSpec(
    opacity: 0.18 + walkBounce * 0.04,
    widthTiles: 0.88 - walkBounce * 0.05,
    heightTiles: _playerDefaultShadowHeightTiles,
  );

  if (animation == PlayerCharacterAnimation.idle) {
    body = body.copyWith(roll: idlePulse * 0.03, yaw: idlePulse * 0.025);
    head = head.copyWith(pitch: -idlePulse * 0.03);
    leftArm = leftArm.copyWith(pitch: 0.02 + idlePulse * 0.06);
    rightArm = rightArm.copyWith(
      pitch: -0.96 - idlePulse * 0.04,
      roll: 0.46 + idlePulse * 0.03,
    );
    leftLeg = leftLeg.copyWith(pitch: idlePulse * 0.04);
    rightLeg = rightLeg.copyWith(pitch: -idlePulse * 0.04);
  }

  if (animation == PlayerCharacterAnimation.slash) {
    final windup = slashPhase < 0.36 ? _easeInOut(slashPhase / 0.36) : 1.0;
    final strike =
        slashPhase >= 0.36 ? _easeInOut((slashPhase - 0.36) / 0.64) : 0.0;
    bodyLift += 0.03 + strike * 0.08;
    body = body.copyWith(
      pitch: body.pitch + 0.08 + strike * 0.10,
      yaw: body.yaw + windup * 0.32 - strike * 0.48,
      roll: body.roll + windup * 0.05 - strike * 0.12,
    );
    head = head.copyWith(pitch: head.pitch + windup * 0.08 - strike * 0.16);
    leftArm = _PlayerJointPose(
      pitch: 0.16 + windup * 0.22 - strike * 0.42,
      yaw: -0.06 - strike * 0.14,
      roll: -0.25 - strike * 0.12,
    );
    rightArm = _PlayerJointPose(
      pitch: -0.45 - windup * 1.35 + strike * 2.15,
      yaw: windup * 0.08 - strike * 0.32,
      roll: 0.28 + windup * 0.22 - strike * 0.64,
    );
    leftLeg = leftLeg.copyWith(pitch: 0.08 - strike * 0.18);
    rightLeg = rightLeg.copyWith(pitch: -0.12 + strike * 0.26);
    shadow = shadow.copyWith(opacity: 0.24, widthTiles: 0.98);
  }

  return _PlayerAnimationPose(
    bodyLift: bodyLift,
    body: body,
    head: head,
    leftArm: leftArm,
    rightArm: rightArm,
    leftLeg: leftLeg,
    rightLeg: rightLeg,
    shadow: _PlayerShadowSpec(
      opacity: shadow.opacity.clamp(0.12, 0.32).toDouble(),
      widthTiles: shadow.widthTiles.clamp(0.76, 1.02).toDouble(),
      heightTiles: shadow.heightTiles,
    ),
  );
}

_PlayerRigPose _buildPlayerRigPose({
  required double rootYaw,
  required _PlayerAnimationPose animationPose,
}) {
  final model = _playerLowPolyModel;
  return _PlayerRigPose(
    root: _PlayerModelTransform(
      translation: _PlayerModelVector3(0, animationPose.bodyLift, 0),
      pitch: animationPose.body.pitch,
      yaw: rootYaw + animationPose.body.yaw,
      roll: animationPose.body.roll,
    ),
    head: _PlayerModelTransform(
      translation: model.headAnchor,
      pitch: animationPose.head.pitch,
      yaw: animationPose.head.yaw,
      roll:
          animationPose.head.roll -
          animationPose.body.roll * _playerHeadBodyRollResponse,
    ),
    leftArm: _PlayerModelTransform(
      translation: model.leftShoulderAnchor,
      pitch: animationPose.leftArm.pitch,
      yaw: animationPose.leftArm.yaw,
      roll: animationPose.leftArm.roll,
    ),
    rightArm: _PlayerModelTransform(
      translation: model.rightShoulderAnchor,
      pitch: animationPose.rightArm.pitch,
      yaw: animationPose.rightArm.yaw,
      roll: animationPose.rightArm.roll,
    ),
    leftLeg: _PlayerModelTransform(
      translation: model.leftHipAnchor,
      pitch: animationPose.leftLeg.pitch,
      yaw: animationPose.leftLeg.yaw,
      roll: animationPose.leftLeg.roll + _playerLeftLegStanceRoll,
    ),
    rightLeg: _PlayerModelTransform(
      translation: model.rightHipAnchor,
      pitch: animationPose.rightLeg.pitch,
      yaw: animationPose.rightLeg.yaw,
      roll: animationPose.rightLeg.roll + _playerRightLegStanceRoll,
    ),
    shadow: animationPose.shadow,
  );
}

void _appendCuboidFaces(
  List<_PlayerProjectedFace> faces, {
  required _PlayerBoxSpec box,
  required List<_PlayerModelTransform> transforms,
  required double footX,
  required double footY,
  required double unit,
}) {
  final min = box.min;
  final max = box.max;
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
        color: _shadePlayerColor(box.color, brightness),
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

class _PlayerModelSpec {
  const _PlayerModelSpec({
    required this.torso,
    required this.hips,
    required this.head,
    required this.arm,
    required this.leg,
    required this.boot,
    required this.headAnchor,
    required this.leftShoulderAnchor,
    required this.rightShoulderAnchor,
    required this.leftHipAnchor,
    required this.rightHipAnchor,
    required this.axe,
  });

  final _PlayerBoxSpec torso;
  final _PlayerBoxSpec hips;
  final _PlayerBoxSpec head;
  final _PlayerBoxSpec arm;
  final _PlayerBoxSpec leg;
  final _PlayerBoxSpec boot;
  final _PlayerModelVector3 headAnchor;
  final _PlayerModelVector3 leftShoulderAnchor;
  final _PlayerModelVector3 rightShoulderAnchor;
  final _PlayerModelVector3 leftHipAnchor;
  final _PlayerModelVector3 rightHipAnchor;
  final _PlayerToolMountSpec axe;
}

class _PlayerToolMountSpec {
  const _PlayerToolMountSpec({
    required this.gripTransform,
    required this.handle,
    required this.head,
  });

  final _PlayerModelTransform gripTransform;
  final _PlayerBoxSpec handle;
  final _PlayerBoxSpec head;
}

class _PlayerBoxSpec {
  const _PlayerBoxSpec({
    required this.center,
    required this.size,
    required this.color,
  });

  final _PlayerModelVector3 center;
  final _PlayerModelVector3 size;
  final Color color;

  _PlayerModelVector3 get min => _PlayerModelVector3(
    center.x - size.x * 0.5,
    center.y - size.y * 0.5,
    center.z - size.z * 0.5,
  );

  _PlayerModelVector3 get max => _PlayerModelVector3(
    center.x + size.x * 0.5,
    center.y + size.y * 0.5,
    center.z + size.z * 0.5,
  );
}

class _PlayerAnimationPose {
  const _PlayerAnimationPose({
    required this.bodyLift,
    required this.body,
    required this.head,
    required this.leftArm,
    required this.rightArm,
    required this.leftLeg,
    required this.rightLeg,
    required this.shadow,
  });

  final double bodyLift;
  final _PlayerJointPose body;
  final _PlayerJointPose head;
  final _PlayerJointPose leftArm;
  final _PlayerJointPose rightArm;
  final _PlayerJointPose leftLeg;
  final _PlayerJointPose rightLeg;
  final _PlayerShadowSpec shadow;
}

class _PlayerRigPose {
  const _PlayerRigPose({
    required this.root,
    required this.head,
    required this.leftArm,
    required this.rightArm,
    required this.leftLeg,
    required this.rightLeg,
    required this.shadow,
  });

  final _PlayerModelTransform root;
  final _PlayerModelTransform head;
  final _PlayerModelTransform leftArm;
  final _PlayerModelTransform rightArm;
  final _PlayerModelTransform leftLeg;
  final _PlayerModelTransform rightLeg;
  final _PlayerShadowSpec shadow;
}

class _PlayerJointPose {
  const _PlayerJointPose({this.pitch = 0, this.yaw = 0, this.roll = 0});

  final double pitch;
  final double yaw;
  final double roll;

  _PlayerJointPose copyWith({double? pitch, double? yaw, double? roll}) {
    return _PlayerJointPose(
      pitch: pitch ?? this.pitch,
      yaw: yaw ?? this.yaw,
      roll: roll ?? this.roll,
    );
  }
}

class _PlayerShadowSpec {
  const _PlayerShadowSpec({
    required this.opacity,
    required this.widthTiles,
    required this.heightTiles,
  });

  final double opacity;
  final double widthTiles;
  final double heightTiles;

  _PlayerShadowSpec copyWith({
    double? opacity,
    double? widthTiles,
    double? heightTiles,
  }) {
    return _PlayerShadowSpec(
      opacity: opacity ?? this.opacity,
      widthTiles: widthTiles ?? this.widthTiles,
      heightTiles: heightTiles ?? this.heightTiles,
    );
  }
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
