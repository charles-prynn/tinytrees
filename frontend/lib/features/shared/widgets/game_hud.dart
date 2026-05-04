import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_controller.dart';
import '../../bank/data/bank_repository.dart';
import '../../entities/data/entity_repository.dart';
import '../../entities/domain/world_entity.dart';
import '../../auth/domain/auth_session.dart';
import '../../events/application/event_inbox_controller.dart';
import '../../events/domain/player_inbox_item.dart';
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
part 'game_hud_parts/top_bar/inbox_top_bar_section.dart';
part 'game_hud_parts/bank/bank_panel.dart';
part 'game_hud_parts/inbox/inbox_panel.dart';
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

class _HudLayout {
  const _HudLayout._({
    required this.horizontalPadding,
    required this.topOverlayPadding,
    required this.bankPanelPadding,
    required this.minimapPanelSize,
    required this.inventoryHeight,
    required this.inventoryColumns,
    required this.compactInventory,
    required this.renderButtonBottomPadding,
    required this.topBarDesignWidths,
  });

  final double horizontalPadding;
  final double topOverlayPadding;
  final EdgeInsets bankPanelPadding;
  final double minimapPanelSize;
  final double inventoryHeight;
  final int inventoryColumns;
  final bool compactInventory;
  final double renderButtonBottomPadding;
  final List<double> topBarDesignWidths;

  static _HudLayout fromSize(Size size, {required bool inventoryOpen}) {
    final width = size.width;
    final isCompact = width < 760;
    final isNarrow = width < 480;
    final inventoryHeight =
        isCompact ? (width < 420 ? 112.0 : 98.0) : TopBar.barHeight;
    final minimapBase =
        width >= 1100
            ? 156.0
            : width >= 760
            ? 140.0
            : width >= 480
            ? 124.0
            : 108.0;
    final minimapPanelSize = math.max(
      96.0,
      math.min(minimapBase, size.height * 0.28),
    );

    return _HudLayout._(
      horizontalPadding: isNarrow ? 8.0 : 12.0,
      topOverlayPadding: TopBar.barHeight + 16,
      bankPanelPadding: EdgeInsets.fromLTRB(
        isNarrow ? 12 : 20,
        TopBar.barHeight + (isCompact ? 20 : 36),
        isNarrow ? 12 : 20,
        inventoryOpen
            ? (isCompact ? inventoryHeight + 18 : inventoryHeight + 46)
            : 24,
      ),
      minimapPanelSize: minimapPanelSize,
      inventoryHeight: inventoryHeight,
      inventoryColumns: width < 420 ? 3 : (isCompact ? 4 : 8),
      compactInventory: isCompact,
      renderButtonBottomPadding: inventoryOpen ? inventoryHeight + 18 : 14,
      topBarDesignWidths:
          isCompact
              ? const [188, 116, 124, 142, 196]
              : const [220, 140, 146, 172, 232],
    );
  }
}

class GameHud extends ConsumerWidget {
  const GameHud({
    super.key,
    required this.inventoryOpen,
    required this.bankOpen,
    required this.inboxOpen,
    required this.loginOpen,
    required this.registrationOpen,
    required this.minimapVisible,
    required this.useLowPolyPlayer,
    required this.showCoordinateDebug,
    required this.selectedMinimapTile,
    required this.onMinimapTileSelected,
    required this.onInventoryPressed,
    required this.onInventoryClosed,
    required this.onBankClosed,
    required this.onInboxPressed,
    required this.onInboxClosed,
    this.onInventoryItemTap,
    required this.onPlayerRenderModeToggle,
    required this.onLoginPressed,
    required this.onLoginClosed,
    required this.onRegistrationPressed,
    required this.onRegistrationClosed,
  });

  final bool inventoryOpen;
  final bool bankOpen;
  final bool inboxOpen;
  final bool loginOpen;
  final bool registrationOpen;
  final bool minimapVisible;
  final bool useLowPolyPlayer;
  final bool showCoordinateDebug;
  final math.Point<int>? selectedMinimapTile;
  final ValueChanged<math.Point<int>> onMinimapTileSelected;
  final VoidCallback onInventoryPressed;
  final VoidCallback onInventoryClosed;
  final VoidCallback onBankClosed;
  final VoidCallback onInboxPressed;
  final VoidCallback onInboxClosed;
  final ValueChanged<InventoryItem>? onInventoryItemTap;
  final VoidCallback onPlayerRenderModeToggle;
  final VoidCallback onLoginPressed;
  final VoidCallback onLoginClosed;
  final VoidCallback onRegistrationPressed;
  final VoidCallback onRegistrationClosed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventory = ref.watch(inventoryProvider);
    final bank = ref.watch(bankProvider);
    final inbox = ref.watch(eventInboxControllerProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _HudLayout.fromSize(
          constraints.biggest,
          inventoryOpen: inventoryOpen,
        );
        return Stack(
          children: [
            SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  layout.horizontalPadding,
                  8,
                  layout.horizontalPadding,
                  0,
                ),
                child: TopBar(
                  layout: layout,
                  inventoryOpen: inventoryOpen,
                  inboxOpen: inboxOpen,
                  showCoordinateDebug: showCoordinateDebug,
                  onInventoryPressed: onInventoryPressed,
                  onInboxPressed: onInboxPressed,
                  onLoginPressed: onLoginPressed,
                  onRegistrationPressed: onRegistrationPressed,
                ),
              ),
            ),
            if (inboxOpen)
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    layout.horizontalPadding,
                    layout.topOverlayPadding,
                    layout.horizontalPadding,
                    0,
                  ),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: InboxPanel(
                      inbox: inbox,
                      onClose: onInboxClosed,
                      onMarkAllRead:
                          () =>
                              ref
                                  .read(eventInboxControllerProvider.notifier)
                                  .ackUnread(),
                    ),
                  ),
                ),
              ),
            if (minimapVisible)
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    layout.horizontalPadding,
                    layout.topOverlayPadding,
                    layout.horizontalPadding,
                    0,
                  ),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: MinimapOverlay(
                      panelSize: layout.minimapPanelSize,
                      selectedTile: selectedMinimapTile,
                      onTileSelected: onMinimapTileSelected,
                    ),
                  ),
                ),
              ),
            if (bankOpen)
              SafeArea(
                child: Padding(
                  padding: layout.bankPanelPadding,
                  child: Align(
                    alignment: Alignment.center,
                    child: BankPanel(bank: bank, onClose: onBankClosed),
                  ),
                ),
              ),
            SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  layout.horizontalPadding,
                  0,
                  layout.horizontalPadding,
                  layout.compactInventory ? 8 : 10,
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child:
                      inventoryOpen
                          ? InventoryDrawer(
                            layout: layout,
                            inventory: inventory,
                            onClose: onInventoryClosed,
                            title: 'Inventory',
                            onItemTap: onInventoryItemTap,
                          )
                          : const SizedBox.shrink(),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  layout.horizontalPadding,
                  0,
                  layout.horizontalPadding,
                  layout.renderButtonBottomPadding,
                ),
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: _PlayerRenderModeButton(
                    useLowPolyPlayer: useLowPolyPlayer,
                    onPressed: onPlayerRenderModeToggle,
                  ),
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
      },
    );
  }
}

class _PlayerRenderModeButton extends StatelessWidget {
  const _PlayerRenderModeButton({
    required this.useLowPolyPlayer,
    required this.onPressed,
  });

  final bool useLowPolyPlayer;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final active = useLowPolyPlayer;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors:
                  active
                      ? const [Color(0xFF345A43), Color(0xFF223A2C)]
                      : const [Color(0xFF5E4630), Color(0xFF3A2A1B)],
            ),
            border: Border.all(
              color: active ? const Color(0xFF8BD3A3) : const Color(0xFFC9A06B),
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Player',
                  style: TextStyle(
                    color:
                        active
                            ? const Color(0xFFD9F3E2)
                            : const Color(0xFFF1DEC4),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Render',
                  style: TextStyle(
                    color: Color(0xCFFFFFFF),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                Text(
                  active ? '3D' : '2D',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
