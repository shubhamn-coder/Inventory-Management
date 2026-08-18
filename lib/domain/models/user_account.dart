class UserAccount {
  final String username;
  final String email;
  final String password;
  final String role; // 'Admin', 'Member', etc.
  final DateTime createdAt;

  UserAccount({
    required this.username,
    required this.email,
    required this.password,
    this.role = 'Member',
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'username': username,
        'email': email,
        'password': password,
        'role': role,
        'createdAt': createdAt.toIso8601String(),
      };

  factory UserAccount.fromJson(Map<String, dynamic> json) => UserAccount(
        username: json['username'] as String,
        email: json['email'] as String,
        password: json['password'] as String,
        role: (json['role'] as String?) ?? 'Member',
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
