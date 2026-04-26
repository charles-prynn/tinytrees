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
    return PopupPanel(
      title: 'Login',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Sign in with your username and password.',
            style: TextStyle(
              color: Color(0xFFE3D8C3),
              fontSize: 13,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          PopupField(
            controller: _usernameController,
            label: 'Username',
            enabled: !_submitting,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 10),
          PopupField(
            controller: _passwordController,
            label: 'Password',
            enabled: !_submitting,
            obscureText: true,
            onSubmitted: (_) => _submit(),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
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
          const SizedBox(height: 14),
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
