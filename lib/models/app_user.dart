class AppUser {
  AppUser(this.raw)
      : id = (raw['_id'] ?? raw['id'] ?? '').toString(),
        name = (raw['name'] ?? '').toString(),
        email = (raw['email'] ?? '').toString(),
        role = (raw['role'] ?? 'staff').toString(),
        avatar = (raw['avatar'] is String && (raw['avatar'] as String).isNotEmpty)
            ? raw['avatar'] as String
            : null;

  final Map<String, dynamic> raw;
  final String id;
  final String name;
  final String email;
  final String role;
  final String? avatar;

  bool get isAdmin => role == 'admin';

  String get firstName => name.trim().isEmpty ? '' : name.trim().split(RegExp(r'\s+')).first;

  String get initials {
    final parts = (name.trim().isEmpty ? '?' : name.trim()).split(RegExp(r'\s+'));
    return parts.take(2).map((p) => p.isEmpty ? '' : p[0]).join().toUpperCase();
  }

  AppUser merge(Map<String, dynamic> changes) => AppUser({...raw, ...changes});
}
