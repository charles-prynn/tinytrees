import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../bootstrap/data/bootstrap_repository.dart';
import 'widgets/registration_popup.dart';

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
      backgroundColor: const Color(0xFF120D08),
      body: PopupPanel(
        title: 'Loading',
        overlayColor: Colors.transparent,
        maxWidth: 360,
        maxHeightFactor: 0.7,
        child: bootstrap.when(
          data:
              (_) => const Text(
                'Starting...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFE3D8C3),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
          loading:
              () => const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
          error:
              (error, _) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Unable to start the app.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFE3D8C3),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$error',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFD2C4AC),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: PopupButton(
                      label: 'Retry',
                      highlighted: true,
                      onPressed: () => ref.invalidate(appBootstrapProvider),
                    ),
                  ),
                ],
              ),
        ),
      ),
    );
  }
}
