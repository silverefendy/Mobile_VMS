class AuthSession {
  const AuthSession({required this.userId, required this.fullName, required this.authHeader, required this.roles});

  final String userId;
  final String fullName;
  final String authHeader;
  final List<String> roles;

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'fullName': fullName,
        'authHeader': authHeader,
        'roles': roles,
      };

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        userId: json['userId'] as String,
        fullName: json['fullName'] as String,
        authHeader: json['authHeader'] as String,
        roles: (json['roles'] as List<dynamic>).cast<String>(),
      );
}
