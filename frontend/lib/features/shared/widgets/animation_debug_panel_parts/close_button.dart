part of '../animation_debug_panel.dart';

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
