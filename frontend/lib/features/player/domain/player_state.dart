part 'player_state_parts/map_point.dart';
part 'player_state_parts/player_movement.dart';
part 'player_state_parts/player_state_model.dart';
part 'player_state_parts/player_action.dart';
part 'player_state_parts/player_skill.dart';

int xpRequiredForLevel(int level) {
  if (level <= 1) {
    return 0;
  }
  return level * level * 100 - 100;
}
