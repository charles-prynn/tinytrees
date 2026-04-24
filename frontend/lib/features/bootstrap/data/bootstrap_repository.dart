import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_response.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/realtime/game_socket.dart';
import '../../auth/data/auth_controller.dart';
import '../domain/bootstrap_config.dart';

final bootstrapRepositoryProvider = Provider<BootstrapRepository>((ref) {
  return BootstrapRepository(
    ref.watch(dioProvider),
    ref.watch(gameSocketProvider),
  );
});

final appBootstrapProvider = FutureProvider<AppBootstrap>((ref) async {
  final auth = await ref.watch(authControllerProvider.future);
  if (auth == null) {
    throw StateError('Authentication is required before bootstrap.');
  }
  final repository = ref.watch(bootstrapRepositoryProvider);
  await repository.ensureRealtimeAvailable();
  final bootstrap = await repository.fetch();
  return AppBootstrap(config: bootstrap);
});

class BootstrapRepository {
  const BootstrapRepository(this._dio, this._socket);

  final Dio _dio;
  final GameSocket _socket;

  Future<void> ensureRealtimeAvailable() async {
    await _socket.ensureConnected();
  }

  Future<BootstrapConfig> fetch() async {
    final response = await _dio.get<Map<String, dynamic>>('/v1/bootstrap');
    return BootstrapConfig.fromJson(unwrapData(response.data));
  }
}

class AppBootstrap {
  const AppBootstrap({required this.config});

  final BootstrapConfig config;
}
