import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../entities/data/entity_repository.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../map/application/map_controller.dart';
import '../../player/application/player_controller.dart';
import '../../../core/realtime/game_socket.dart';
import 'registration_popup.dart';

part 'game_loading_overlay_parts/game_loading_overlay_widget.dart';
part 'game_loading_overlay_parts/loading_status_row.dart';
part 'game_loading_overlay_parts/game_connection_banner.dart';

void retryGameLoad(WidgetRef ref) {
  ref.invalidate(mapControllerProvider);
  ref.invalidate(worldEntitiesProvider);
  ref.invalidate(playerControllerProvider);
  ref.invalidate(inventoryProvider);
}
