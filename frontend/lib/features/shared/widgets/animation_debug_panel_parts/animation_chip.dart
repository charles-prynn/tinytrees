part of '../animation_debug_panel.dart';

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
