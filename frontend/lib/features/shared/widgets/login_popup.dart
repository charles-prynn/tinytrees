import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../auth/data/auth_controller.dart';
import 'registration_popup.dart';

class LoginPopup extends ConsumerStatefulWidget {
  const LoginPopup({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  ConsumerState<LoginPopup> createState() => _LoginPopupState();
}

class _LoginPopupState extends ConsumerState<LoginPopup> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;
  bool _submitting = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0x99000000),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF2A2419),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xAA7C6B48), width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x99000000),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const PopupBar(title: 'Login'),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Sign in with your username and password.',
                          style: TextStyle(
                            color: Color(0xFFE3D8C3),
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 14),
                        PopupField(
                          controller: _usernameController,
                          label: 'Username',
                          enabled: !_submitting,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                        PopupField(
                          controller: _passwordController,
                          label: 'Password',
                          enabled: !_submitting,
                          obscureText: true,
                          onSubmitted: (_) => _submit(),
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Color(0xFFF28F7A),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            PopupButton(
                              label: 'Cancel',
                              onPressed: _submitting ? null : widget.onClose,
                            ),
                            const SizedBox(width: 8),
                            PopupButton(
                              label: _submitting ? 'Logging in...' : 'Login',
                              highlighted: true,
                              onPressed: _submitting ? null : _submit,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const PopupBar(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Username and password are required.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(authControllerProvider.notifier)
          .login(username: username, password: password);
      if (!mounted) {
        return;
      }
      widget.onClose();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = _messageForError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  String _messageForError(Object error) {
    if (error is AppError) {
      return error.message;
    }
    return 'Login failed. Please try again.';
  }
}
