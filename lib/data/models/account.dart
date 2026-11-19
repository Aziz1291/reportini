enum AccountRole { citizen, agent, admin }

class Account {
  const Account({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.createdAt,
    this.municipalityId,
  });

  factory Account.fromJson(String id, Map<String, dynamic> json) => Account(
    id: id,
    name: json['name'] as String,
    email: json['email'] as String,
    role: AccountRole.values.byName(json['role'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
    municipalityId: json['municipalityId'] as String?,
  );

  final String id;
  final String name;
  final String email;
  final AccountRole role;
  final DateTime createdAt;
  final String? municipalityId;

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
    'role': role.name,
    'municipalityId': municipalityId,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };
}
