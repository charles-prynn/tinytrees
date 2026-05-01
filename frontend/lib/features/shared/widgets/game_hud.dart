import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_controller.dart';
import '../../entities/data/entity_repository.dart';
import '../../entities/domain/world_entity.dart';
import '../../auth/domain/auth_session.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../inventory/domain/inventory_item.dart';
import '../../map/application/map_controller.dart';
import '../../map/domain/tile_map.dart';
import '../../player/application/player_controller.dart';
import '../../player/domain/player_state.dart';
import '../tree_resource_palette.dart';
import 'login_popup.dart';
import 'registration_popup.dart';

part 'game_hud_parts/top_bar/top_bar.dart';
part 'game_hud_parts/top_bar/inventory_top_bar_section.dart';
part 'game_hud_parts/inventory/inventory_drawer.dart';
part 'game_hud_parts/inventory/inventory_close_button.dart';
part 'game_hud_parts/inventory/inventory_grid.dart';
part 'game_hud_parts/inventory/inventory_grid_loading.dart';
part 'game_hud_parts/inventory/inventory_grid_error.dart';
part 'game_hud_parts/inventory/inventory_slot.dart';
part 'game_hud_parts/details/user_top_bar_section.dart';
part 'game_hud_parts/details/activity_top_bar_section.dart';
part 'game_hud_parts/details/woodcutting_top_bar_section.dart';
part 'game_hud_parts/details/activity_details.dart';
part 'game_hud_parts/details/user_details.dart';
part 'game_hud_parts/details/user_action_button.dart';
part 'game_hud_parts/details/woodcutting_details.dart';
part 'game_hud_parts/shared/top_bar_divider.dart';
part 'game_hud_parts/shared/divider_stud.dart';
part 'game_hud_parts/shared/top_bar_icon_well.dart';
part 'game_hud_parts/shared/top_bar_progress_bar.dart';
part 'game_hud_parts/shared/top_bar_placeholder_line.dart';
part 'game_hud_parts/minimap/minimap_overlay.dart';

class GameHud extends ConsumerWidget {
  const GameHud({
    super.key,
    required this.inventoryOpen,
    required this.loginOpen,
    required this.registrationOpen,
    required this.minimapVisible,
    required this.showCoordinateDebug,
    required this.selectedMinimapTile,
    required this.onMinimapTileSelected,
    required this.onInventoryPressed,
    required this.onInventoryClosed,
    required this.onLoginPressed,
    required this.onLoginClosed,
    required this.onRegistrationPressed,
    required this.onRegistrationClosed,
  });

  final bool inventoryOpen;
  final bool loginOpen;
  final bool registrationOpen;
  final bool minimapVisible;
  final bool showCoordinateDebug;
  final math.Point<int>? selectedMinimapTile;
  final ValueChanged<math.Point<int>> onMinimapTileSelected;
  final VoidCallback onInventoryPressed;
  final VoidCallback onInventoryClosed;
  final VoidCallback onLoginPressed;
  final VoidCallback onLoginClosed;
  final VoidCallback onRegistrationPressed;
  final VoidCallback onRegistrationClosed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventory = ref.watch(inventoryProvider);
    return Stack(
      children: [
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TopBar(
              inventoryOpen: inventoryOpen,
              showCoordinateDebug: showCoordinateDebug,
              onInventoryPressed: onInventoryPressed,
              onLoginPressed: onLoginPressed,
              onRegistrationPressed: onRegistrationPressed,
            ),
          ),
        ),
        if (minimapVisible)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 66, 12, 0),
              child: Align(
                alignment: Alignment.topRight,
                child: MinimapOverlay(
                  selectedTile: selectedMinimapTile,
                  onTileSelected: onMinimapTileSelected,
                ),
              ),
            ),
          ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Align(
              alignment: Alignment.bottomCenter,
              child:
                  inventoryOpen
                      ? InventoryDrawer(
                        inventory: inventory,
                        onClose: onInventoryClosed,
                      )
                      : const SizedBox.shrink(),
            ),
          ),
        ),
        IgnorePointer(
          ignoring: !loginOpen,
          child: Offstage(
            offstage: !loginOpen,
            child: LoginPopup(onClose: onLoginClosed),
          ),
        ),
        IgnorePointer(
          ignoring: !registrationOpen,
          child: Offstage(
            offstage: !registrationOpen,
            child: RegistrationPopup(onClose: onRegistrationClosed),
          ),
        ),
      ],
    );
  }
}
