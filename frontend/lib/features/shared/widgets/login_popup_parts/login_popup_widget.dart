part of '../login_popup.dart';

class LoginPopup extends ConsumerStatefulWidget {
  const LoginPopup({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  ConsumerState<LoginPopup> createState() => _LoginPopupState();
}
