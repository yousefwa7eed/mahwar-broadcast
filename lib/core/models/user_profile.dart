enum UserRole { carOwner, provider }

class UserProfile {
  final String id;
  final UserRole role;
  final String fullName;
  final String phoneNumber;
  final String? email;
  final String? nationalId;
  final String? avatarUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserProfile({
    required this.id,
    required this.role,
    required this.fullName,
    required this.phoneNumber,
    this.email,
    this.nationalId,
    this.avatarUrl,
    this.createdAt,
    this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      role: json['role'] == 'car_owner' ? UserRole.carOwner : UserRole.provider,
      fullName: json['full_name'] as String,
      phoneNumber: json['phone_number'] as String,
      email: json['email'] as String?,
      nationalId: json['national_id'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role == UserRole.carOwner ? 'car_owner' : 'provider',
      'full_name': fullName,
      'phone_number': phoneNumber,
      'email': email,
      'national_id': nationalId,
      'avatar_url': avatarUrl,
    };
  }

  UserProfile copyWith({
    String? fullName,
    String? phoneNumber,
    String? email,
    String? nationalId,
    String? avatarUrl,
  }) {
    return UserProfile(
      id: id,
      role: role,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      nationalId: nationalId ?? this.nationalId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
