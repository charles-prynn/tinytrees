part of '../auth_api.dart';

class GuestLoginResponse {
  const GuestLoginResponse({required this.user, required this.tokens});

  final AppUser user;
  final TokenPair tokens;
}
