part of '../../game_hud.dart';

class UserDetails extends StatelessWidget {
  const UserDetails({
    super.key,
    required this.username,
    this.dbPositionLabel,
    this.showRegister = false,
    this.showLogout = true,
    this.onLogin,
    this.onRegister,
    required this.onLogout,
  });

  final String username;
  final String? dbPositionLabel;
  final bool showRegister;
  final bool showLogout;
  final VoidCallback? onLogin;
  final VoidCallback? onRegister;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'User',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Color(0xFFE3D8C3),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          dbPositionLabel == null ? username : '$username  $dbPositionLabel',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFDBCDB4),
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (showRegister) ...[
              _UserActionButton(label: 'Register', onPressed: onRegister),
              const SizedBox(width: 4),
              _UserActionButton(label: 'Login', onPressed: onLogin),
            ],
            if (showLogout) ...[
              if (showRegister) const SizedBox(width: 4),
              _UserActionButton(label: 'Logout', onPressed: onLogout),
            ],
          ],
        ),
      ],
    );
  }
}

String dbPositionLabel(PlayerState player) {
  final dbX = player.movement?.fromX ?? player.x;
  final dbY = player.movement?.fromY ?? player.y;
  return 'DB $dbX,$dbY';
}
