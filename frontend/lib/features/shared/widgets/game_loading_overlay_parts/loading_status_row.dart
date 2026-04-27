part of '../game_loading_overlay.dart';

class _LoadingStatusRow extends StatelessWidget {
  const _LoadingStatusRow({
    required this.label,
    required this.ready,
    required this.failed,
  });

  final String label;
  final bool ready;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final status = failed ? 'Failed' : ready ? 'Ready' : 'Loading';
    final color =
        failed
            ? const Color(0xFFF28F7A)
            : ready
            ? const Color(0xFF6FCF38)
            : const Color(0xFFE2BF63);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x33150F08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0x665B503A), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFFE3D8C3),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
