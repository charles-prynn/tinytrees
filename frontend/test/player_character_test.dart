import 'package:flame/cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treescape/features/rendering/player_character.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('player character export loads drawable frames', () async {
    final images = Images();
    final sheet = await PlayerCharacterSheet.load(images);

    expect(sheet.layers, isNotEmpty);
    expect(sheet.axeSlashTool, isNotNull);

    final baseLayer = sheet.layers.firstWhere(
      (layer) => layer.name.startsWith('Body Color'),
    );

    final idleFrame = sheet.frameFor(
      layer: baseLayer,
      animation: PlayerCharacterAnimation.idle,
      direction: PlayerCharacterDirection.down,
      elapsedSeconds: 0,
    );
    final walkFrame = sheet.frameFor(
      layer: baseLayer,
      animation: PlayerCharacterAnimation.walk,
      direction: PlayerCharacterDirection.right,
      elapsedSeconds: 0.2,
    );
    final slashFrame = sheet.frameFor(
      layer: baseLayer,
      animation: PlayerCharacterAnimation.slash,
      direction: PlayerCharacterDirection.left,
      elapsedSeconds: 0.1,
    );

    expect(idleFrame, isNotNull);
    expect(walkFrame, isNotNull);
    expect(slashFrame, isNotNull);
    expect(
      sheet.axeSlashBackgroundFrame(
        direction: PlayerCharacterDirection.left,
        elapsedSeconds: 0.1,
      ),
      isNotNull,
    );
  });
}
