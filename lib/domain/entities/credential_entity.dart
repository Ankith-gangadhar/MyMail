class CredentialEntity {
  final String id;
  final String categoryId;
  final String email;
  final String password;
  final String? label;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  const CredentialEntity({
    required this.id,
    required this.categoryId,
    required this.email,
    required this.password,
    this.label,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  CredentialEntity copyWith({
    String? id,
    String? categoryId,
    String? email,
    String? password,
    String? label,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return CredentialEntity(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      email: email ?? this.email,
      password: password ?? this.password,
      label: label ?? this.label,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'categoryId': categoryId,
      'email': email,
      'password': password,
      'label': label,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isDeleted': isDeleted,
    };
  }

  factory CredentialEntity.fromJson(Map<String, dynamic> json) {
    return CredentialEntity(
      id: json['id'] as String,
      categoryId: json['categoryId'] as String,
      email: json['email'] as String,
      password: json['password'] as String,
      label: json['label'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isDeleted: json['isDeleted'] as bool? ?? false,
    );
  }
}
