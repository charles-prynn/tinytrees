class AppUser {
  const AppUser({
    required this.id,
    required this.provider,
    required this.displayName,
  });

  final String id;
  final String provider;
  final String displayName;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      provider: json['provider'] as String,
      displayName: json['display_name'] as String? ?? 'User',
    );
  }
}
