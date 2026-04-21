import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../bootstrap/data/bootstrap_repository.dart';

class LoadingScreen extends ConsumerWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(appBootstrapProvider);

    ref.listen(appBootstrapProvider, (previous, next) {
      if (next.hasValue) {
        context.go('/');
      }
    });

    return Scaffold(
      body: Center(
        child: bootstrap.when(
          data: (_) => const Text('Starting...'),
          loading: () => const CircularProgressIndicator(),
          error:
              (error, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Unable to start the app.'),
                    const SizedBox(height: 8),
                    Text(
                      '$error',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: () => ref.invalidate(appBootstrapProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
        ),
      ),
    );
  }
}
