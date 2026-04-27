part of '../registration_popup.dart';

class RegistrationPopup extends ConsumerStatefulWidget {
  const RegistrationPopup({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  ConsumerState<RegistrationPopup> createState() => _RegistrationPopupState();
}
