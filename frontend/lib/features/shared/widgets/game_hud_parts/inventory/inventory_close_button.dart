part of '../../game_hud.dart';

class InventoryCloseButton extends StatelessWidget {
  const InventoryCloseButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(20, 20),
          side: const BorderSide(color: Color(0xAA7C6B48), width: 0.8),
          backgroundColor: const Color(0x33150F08),
          foregroundColor: const Color(0xFFE3D8C3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        ),
        child: const Text(
          '×',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
  }
}
