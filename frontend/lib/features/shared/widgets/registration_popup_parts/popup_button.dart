part of '../registration_popup.dart';

class PopupButton extends StatelessWidget {
  const PopupButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.highlighted = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: BorderSide(
          color:
              highlighted ? const Color(0xFFE2BF63) : const Color(0xAA7C6B48),
          width: 1,
        ),
        backgroundColor:
            highlighted ? const Color(0x332E2107) : const Color(0x33150F08),
        foregroundColor: const Color(0xFFE6D9C2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}
