class AuditLog {
  final String id;
  final String action;
  final String actor;
  final String details;
  final DateTime timestamp;
  final bool isAlert;

  AuditLog({
    required this.id,
    required this.action,
    required this.actor,
    required this.details,
    required this.timestamp,
    this.isAlert = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'action': action,
        'actor': actor,
        'details': details,
        'timestamp': timestamp.toIso8601String(),
        'isAlert': isAlert,
      };

  factory AuditLog.fromJson(Map<String, dynamic> json) => AuditLog(
        id: json['id'] as String,
        action: json['action'] as String,
        actor: json['actor'] as String,
        details: json['details'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        isAlert: (json['isAlert'] as bool?) ?? false,
      );
}
