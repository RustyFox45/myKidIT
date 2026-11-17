import 'package:flutter/foundation.dart';

/// Configurable household approval rule for Activity Permission Requests (Feature 3.3).
enum ApprovalRule {
  oneParent,
  twoParents;

  String get label => switch (this) {
        ApprovalRule.oneParent => '1-Parent Approval',
        ApprovalRule.twoParents => '2-Parent Approval (Both Required)',
      };

  String get shortLabel => switch (this) {
        ApprovalRule.oneParent => '1 Parent Required',
        ApprovalRule.twoParents => '2 Parents Required',
      };

  int get requiredCount => switch (this) {
        ApprovalRule.oneParent => 1,
        ApprovalRule.twoParents => 2,
      };
}

/// Immutable domain model representing a Family Household (Section 4.2 of AGENTS.md).
///
/// Supports:
/// - Feature 1.2: Household Pairing (Parent -> Child via `childInviteCode`)
/// - Feature 1.3: Multi-Parent Link (Parent -> Parent via `parentInviteCode`)
/// - Feature 3.3: Approval Rule Setting (`defaultApprovalRule`)
class Household {
  const Household({
    required this.id,
    required this.name,
    required this.childInviteCode,
    required this.parentInviteCode,
    required this.parentIds,
    required this.childIds,
    this.defaultApprovalRule = ApprovalRule.twoParents,
  });

  final String id;
  final String name;
  final String childInviteCode;
  final String parentInviteCode;
  final List<String> parentIds;
  final List<String> childIds;
  final ApprovalRule defaultApprovalRule;

  Household copyWith({
    String? id,
    String? name,
    String? childInviteCode,
    String? parentInviteCode,
    List<String>? parentIds,
    List<String>? childIds,
    ApprovalRule? defaultApprovalRule,
  }) {
    return Household(
      id: id ?? this.id,
      name: name ?? this.name,
      childInviteCode: childInviteCode ?? this.childInviteCode,
      parentInviteCode: parentInviteCode ?? this.parentInviteCode,
      parentIds: parentIds ?? List<String>.unmodifiable(this.parentIds),
      childIds: childIds ?? List<String>.unmodifiable(this.childIds),
      defaultApprovalRule: defaultApprovalRule ?? this.defaultApprovalRule,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'child_invite_code': childInviteCode,
      'parent_invite_code': parentInviteCode,
      'parent_ids': parentIds,
      'child_ids': childIds,
      'default_approval_rule': defaultApprovalRule.name,
    };
  }

  factory Household.fromJson(Map<String, dynamic> json) {
    final ruleStr = json['default_approval_rule'] as String? ?? 'twoParents';
    final rule = ApprovalRule.values.firstWhere(
      (r) => r.name == ruleStr,
      orElse: () => ApprovalRule.twoParents,
    );

    return Household(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'My Family',
      childInviteCode: json['child_invite_code'] as String? ?? 'KID405',
      parentInviteCode: json['parent_invite_code'] as String? ?? 'PAR405',
      parentIds: (json['parent_ids'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      childIds: (json['child_ids'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      defaultApprovalRule: rule,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Household &&
        other.id == id &&
        other.name == name &&
        other.childInviteCode == childInviteCode &&
        other.parentInviteCode == parentInviteCode &&
        listEquals(other.parentIds, parentIds) &&
        listEquals(other.childIds, childIds) &&
        other.defaultApprovalRule == defaultApprovalRule;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        childInviteCode,
        parentInviteCode,
        Object.hashAll(parentIds),
        Object.hashAll(childIds),
        defaultApprovalRule,
      );
}

