import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/errors/app_error.dart';
import '../../core/realtime/game_socket.dart';
import '../auth/data/auth_controller.dart';
import '../bank/data/bank_repository.dart';
import '../entities/data/entity_repository.dart';
import '../entities/domain/world_entity.dart';
import '../inventory/data/inventory_repository.dart';
import '../inventory/domain/inventory_item.dart';
import '../map/application/map_controller.dart';
import '../map/domain/tile_map.dart';
import '../player/application/player_controller.dart';
import '../player/domain/player_state.dart';
import '../rendering/player_character.dart';
import '../rendering/tile_map_game.dart';
import 'widgets/animation_debug_panel.dart';
import 'widgets/game_loading_overlay.dart';
import 'widgets/game_hud.dart';

part 'main_screen_parts/main_screen_state.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key, this.waitForGameAssetsDuringLoad = true});

  final bool waitForGameAssetsDuringLoad;

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}
