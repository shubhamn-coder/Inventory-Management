class AccessCode {
  final String id;
  final String code;
  final String permission; // 'view' or 'edit'
  final String createdBy;
  final DateTime createdAt;

  AccessCode({
    required this.id,
    required this.code,
    required this.permission,
    required this.createdBy,
    required this.createdAt,
  });

  bool get isViewOnly => permission == 'view';
  bool get isEdit => permission == 'edit';

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'permission': permission,
        'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AccessCode.fromJson(Map<String, dynamic> json) => AccessCode(
        id: json['id'] as String,
        code: json['code'] as String,
        permission: (json['permission'] as String?) ?? 'view',
        createdBy: (json['createdBy'] as String?) ?? 'Admin',
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
