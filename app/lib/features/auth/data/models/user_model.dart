class UserModel {
  final int userId;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? roleName;

  const UserModel({
    required this.userId,
    required this.email,
    this.firstName,
    this.lastName,
    this.roleName,
  });

  String get displayName {
    if (firstName != null && firstName!.trim().isNotEmpty) {
      if (lastName != null && lastName!.trim().isNotEmpty) {
        return '$firstName $lastName';
      }
      return firstName!;
    }
    return email;
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['userId'] as int? ?? json['id'] as int? ?? 0,
      email: json['email'] as String? ?? '',
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      roleName: json['role'] as String? ?? json['roleName'] as String?,
    );
  }

  UserModel copyWith({
    int? userId,
    String? email,
    String? firstName,
    String? lastName,
    String? roleName,
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      roleName: roleName ?? this.roleName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'roleName': roleName,
    };
  }
}
