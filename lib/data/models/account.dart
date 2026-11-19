enum AccountRole { citizen, agent, admin }

class Account {
  const Account({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.createdAt,
    this.municipalityId,
    this.enabled = true,
  });

  factory Account.fromJson(String id, Map<String, dynamic> json) => Account(
    id: id,
    name: json['name'] as String,
    email: json['email'] as String,
    role: AccountRole.values.byName(json['role'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
    municipalityId: json['municipalityId'] as String?,
    enabled: json['enabled'] as bool? ?? true,
  );

  final String id;
  final String name;
  final String email;
  final AccountRole role;
  final DateTime createdAt;
  final String? municipalityId;
  final bool enabled;

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
    'role': role.name,
    'municipalityId': municipalityId,
    'enabled': enabled,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };
}
