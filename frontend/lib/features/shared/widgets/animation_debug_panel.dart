import 'package:flutter/material.dart';

import '../../rendering/player_character.dart';

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
                              onPressed:
                                  () => onSelectedAnimation(animation),
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

class _PanelFrame extends StatelessWidget {
  const _PanelFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(
                width: 40,
                child: Image(
                  image: AssetImage('assets/images/ui/bar/left-bar.png'),
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.none,
                ),
              ),
              const Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/ui/bar/middle-bar.png'),
                      repeat: ImageRepeat.repeat,
                      fit: BoxFit.fill,
                      alignment: Alignment.centerLeft,
                      filterQuality: FilterQuality.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(
                width: 40,
                child: Image(
                  image: AssetImage('assets/images/ui/bar/right-bar.png'),
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.none,
                ),
              ),
            ],
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _AnimationChip extends StatelessWidget {
  const _AnimationChip({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color:
                selected ? const Color(0xFF405B2E) : const Color(0x3F000000),
            border: Border.all(
              color:
                  selected
                      ? const Color(0xFF93C85F)
                      : const Color(0x665A4C30),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color:
                  selected ? const Color(0xFFF0F6D8) : const Color(0xFFE6DCC0),
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Ink(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0x33000000),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0x665A4C30)),
          ),
          child: const Icon(Icons.close, color: Color(0xFFE6DCC0), size: 20),
        ),
      ),
    );
  }
}
