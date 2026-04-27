part of '../../game_hud.dart';

class _UserActionButton extends StatelessWidget {
  const _UserActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 14,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
          minimumSize: const Size(0, 14),
          side: const BorderSide(color: Color(0xAA7C6B48), width: 0.8),
          backgroundColor: const Color(0x33150F08),
          foregroundColor: const Color(0xFFE6D9C2),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 6.7,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
  }
}
