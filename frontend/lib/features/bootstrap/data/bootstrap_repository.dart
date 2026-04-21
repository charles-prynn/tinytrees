import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_response.dart';
import '../../../core/network/dio_provider.dart';
import '../../auth/data/auth_controller.dart';
import '../domain/bootstrap_config.dart';

final bootstrapRepositoryProvider = Provider<BootstrapRepository>((ref) {
  return BootstrapRepository(ref.watch(dioProvider));
});

final appBootstrapProvider = FutureProvider<AppBootstrap>((ref) async {
  final auth = await ref.watch(authControllerProvider.future);
  if (auth == null) {
    throw StateError('Authentication is required before bootstrap.');
  }
  final bootstrap = await ref.watch(bootstrapRepositoryProvider).fetch();
  return AppBootstrap(config: bootstrap);
});

class BootstrapRepository {
  const BootstrapRepository(this._dio);

  final Dio _dio;

  Future<BootstrapConfig> fetch() async {
    final response = await _dio.get<Map<String, dynamic>>('/v1/bootstrap');
    return BootstrapConfig.fromJson(unwrapData(response.data));
  }
}

class AppBootstrap {
  const AppBootstrap({required this.config});

  final BootstrapConfig config;
}
