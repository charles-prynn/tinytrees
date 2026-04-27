part of '../../game_hud.dart';

class UserTopBarSection extends StatelessWidget {
  const UserTopBarSection({
    super.key,
    required this.showDivider,
    required this.auth,
    required this.player,
    required this.showCoordinateDebug,
    required this.onLoginPressed,
    required this.onRegisterPressed,
    required this.onLogout,
  });

  final bool showDivider;
  final AsyncValue<AuthSession?> auth;
  final AsyncValue<PlayerState> player;
  final bool showCoordinateDebug;
  final VoidCallback onLoginPressed;
  final VoidCallback onRegisterPressed;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (showDivider)
          const Positioned(
            left: -9,
            top: -6,
            bottom: -6,
            child: TopBarDivider(),
          ),
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.only(left: showDivider ? 14 : 0, right: 10),
            child: auth.when(
              data:
                  (value) => player.when(
                    data:
                        (playerValue) => _buildUserSection(
                          username: value?.user.displayName ?? 'Guest',
                          dbPositionLabel:
                              showCoordinateDebug
                                  ? dbPositionLabel(playerValue)
                                  : null,
                          showRegister: value?.user.provider == 'guest',
                          showLogout: value?.user.provider != 'guest',
                        ),
                    loading:
                        () => _buildUserSection(
                          username: value?.user.displayName ?? 'Guest',
                          showRegister: value?.user.provider == 'guest',
                          showLogout: value?.user.provider != 'guest',
                        ),
                    error:
                        (_, _) => _buildUserSection(
                          username: value?.user.displayName ?? 'Guest',
                          showRegister: value?.user.provider == 'guest',
                          showLogout: value?.user.provider != 'guest',
                        ),
                  ),
              loading:
                  () => const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TopBarPlaceholderLine(widthFactor: 0.54, bright: true),
                      SizedBox(height: 4),
                      TopBarPlaceholderLine(widthFactor: 0.3),
                    ],
                  ),
              error:
                  (_, _) =>
                      _buildUserSection(username: 'Offline', showLogout: true),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserSection({
    required String username,
    String? dbPositionLabel,
    bool showRegister = false,
    bool showLogout = true,
  }) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          const TopBarIconWell(
            child: Padding(
              padding: EdgeInsets.all(4),
              child: Image(
                image: AssetImage('assets/images/ui/bar/icons/user-icon.png'),
                fit: BoxFit.contain,
                filterQuality: FilterQuality.none,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: UserDetails(
              username: username,
              dbPositionLabel: dbPositionLabel,
              showRegister: showRegister,
              showLogout: showLogout,
              onLogin: onLoginPressed,
              onRegister: onRegisterPressed,
              onLogout: onLogout,
            ),
          ),
        ],
      ),
    );
  }
}
