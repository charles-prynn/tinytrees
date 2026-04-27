import 'package:flutter/material.dart';

import '../../rendering/player_character.dart';

part 'animation_debug_panel_parts/panel_frame.dart';
part 'animation_debug_panel_parts/animation_chip.dart';
part 'animation_debug_panel_parts/close_button.dart';

class AnimationDebugPanel extends StatelessWidget {
  const AnimationDebugPanel({
    super.key,
    required this.selectedAnimation,
    required this.onSelectedAnimation,
    required this.onClose,
  });

  final PlayerCharacterAnimation? selectedAnimation;
  final ValueChanged<PlayerCharacterAnimation?> onSelectedAnimation;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0x7F000000),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 460),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _PanelFrame(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Animation Debug',
                              style: TextStyle(
                                color: Color(0xFFE6DCC0),
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          _CloseButton(onPressed: onClose),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Press 3 three times quickly to show or hide this panel.',
                        style: TextStyle(
                          color: Color(0xFFBFAF8C),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _AnimationChip(
                            label: 'Game Driven',
                            selected: selectedAnimation == null,
                            onPressed: () => onSelectedAnimation(null),
                          ),
                          for (final animation in PlayerCharacterAnimation.values)
                            _AnimationChip(
                              label: animation.label,
                              selected: selectedAnimation == animation,
                              onPressed: () => onSelectedAnimation(animation),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
