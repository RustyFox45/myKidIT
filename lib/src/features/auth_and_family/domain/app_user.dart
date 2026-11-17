/// Role of an account within MyKidIT (Feature 1.1).
enum AccountRole {
  parent,
  child;

  String get label => switch (this) {
        AccountRole.parent => 'Parent',
        AccountRole.child => 'Child',
      };
}

/// Immutable domain model representing a Parent or Child user (Section 4.1 of AGENTS.md).
class AppUser {
  const AppUser({
    required this.id,
    required this.displayName,
    required this.role,
    this.email,
    this.householdId,
    this.avatarUrl,
  });

  final String id;
  final String? email;
  final String displayName;
  final AccountRole role;
  final String? householdId;
  final String? avatarUrl;

  bool get isParent => role == AccountRole.parent;
  bool get isChild => role == AccountRole.child;
  bool get isPairedToHousehold =>
      householdId != null && householdId!.trim().isNotEmpty;

  AppUser copyWith({
    String? id,
    String? email,
    String? displayName,
    AccountRole? role,
    String? householdId,
    bool clearHouseholdId = false,
    String? avatarUrl,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      householdId: clearHouseholdId ? null : (householdId ?? this.householdId),
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'role': role.name,
      'household_id': householdId,
      'avatar_url': avatarUrl,
    };
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final roleStr = json['role'] as String? ?? 'child';
    final parsedRole = AccountRole.values.firstWhere(
      (r) => r.name == roleStr,
      orElse: () => AccountRole.child,
    );

    return AppUser(
      id: json['id'] as String,
      email: json['email'] as String?,
      displayName: json['display_name'] as String? ?? 'Family Member',
      role: parsedRole,
      householdId: json['household_id'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppUser &&
        other.id == id &&
        other.email == email &&
        other.displayName == displayName &&
        other.role == role &&
        other.householdId == householdId &&
        other.avatarUrl == avatarUrl;
  }

  @override
  int get hashCode => Object.hash(
        id,
        email,
        displayName,
        role,
        householdId,
        avatarUrl,
      );
}

