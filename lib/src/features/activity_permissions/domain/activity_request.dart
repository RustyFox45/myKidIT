import 'package:flutter/foundation.dart';
import '../../auth_and_family/domain/household.dart';
import '../../chores/domain/chore_task.dart';

/// Decision status recorded by an individual parent on an [ActivityRequest].
enum ParentDecisionStatus {
  approved,
  denied,
  changesRequested;

  String get label => switch (this) {
        ParentDecisionStatus.approved => 'Approved',
        ParentDecisionStatus.denied => 'Denied',
        ParentDecisionStatus.changesRequested => 'Changes Requested',
      };
}

/// Immutable record of a single parent's decision and comment on an [ActivityRequest].
class ParentDecision {
  const ParentDecision({
    required this.parentId,
    required this.parentName,
    required this.status,
    required this.timestamp,
    this.comment,
  });

  final String parentId;
  final String parentName;
  final ParentDecisionStatus status;
  final String? comment;
  final DateTime timestamp;

  Map<String, dynamic> toJson() {
    return {
      'parent_id': parentId,
      'parent_name': parentName,
      'status': status.name,
      'comment': comment,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ParentDecision.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] as String? ?? 'approved';
    return ParentDecision(
      parentId: json['parent_id'] as String? ?? '',
      parentName: json['parent_name'] as String? ?? 'Parent',
      status: ParentDecisionStatus.values.firstWhere(
        (s) => s.name == statusStr,
        orElse: () => ParentDecisionStatus.approved,
      ),
      comment: json['comment'] as String?,
      timestamp: json['timestamp'] != null
          ? (DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ParentDecision &&
        other.parentId == parentId &&
        other.parentName == parentName &&
        other.status == status &&
        other.comment == comment &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode => Object.hash(
        parentId,
        parentName,
        status,
        comment,
        timestamp,
      );
}

/// Overall lifecycle status of an [ActivityRequest] (Features 3.2, 3.3, & 4.2).
enum ActivityRequestStatus {
  blockedByPrerequisites,
  pending,
  awaitingSecondParent,
  approved,
  denied,
  changesRequested;

  String get badgeLabel => switch (this) {
        ActivityRequestStatus.blockedByPrerequisites =>
          'Blocked by Prerequisites',
        ActivityRequestStatus.pending => 'Pending Parent Review',
        ActivityRequestStatus.awaitingSecondParent =>
          'Pending — 1 Parent Hasn\'t Approved Yet',
        ActivityRequestStatus.approved => 'Approved',
        ActivityRequestStatus.denied => 'Denied',
        ActivityRequestStatus.changesRequested => 'Changes Requested',
      };
}

/// Result of the Automated Chore Audit (Feature 3.2).
class ChoreAuditResult {
  const ChoreAuditResult({
    required this.childId,
    required this.prerequisiteChores,
    required this.incompletePrerequisiteChores,
  });

  final String childId;
  final List<ChoreTask> prerequisiteChores;
  final List<ChoreTask> incompletePrerequisiteChores;

  bool get passed => incompletePrerequisiteChores.isEmpty;
  int get totalPrerequisites => prerequisiteChores.length;
  int get completedPrerequisites =>
      prerequisiteChores.length - incompletePrerequisiteChores.length;

  String get summaryBannerText {
    if (passed) {
      return totalPrerequisites == 0
          ? 'No Prerequisite Chores Assigned — Ready to Request Activities!'
          : 'All $totalPrerequisites Prerequisite Chores Approved — Activity Requests Unlocked!';
    }
    final remaining = incompletePrerequisiteChores.length;
    return '$remaining Prerequisite Chore${remaining == 1 ? '' : 's'} Remaining Before Activity Unlock';
  }
}

/// Immutable domain model representing a Child's Activity Permission Request
/// (Section 4.4 of AGENTS.md).
class ActivityRequest {
  const ActivityRequest({
    required this.id,
    required this.householdId,
    required this.childId,
    required this.activityDestination,
    required this.startTime,
    required this.endTime,
    required this.hostParentName,
    required this.hostParentContact,
    required this.transportation,
    required this.prerequisiteAuditPassed,
    required this.incompletePrerequisiteChoreIds,
    required this.approvalRule,
    required this.parentDecisions,
    required this.overallStatus,
  });

  final String id;
  final String householdId;
  final String childId;

  // 3.1.1 Activity / Destination
  final String activityDestination;

  // 3.1.2 Time Window
  final DateTime startTime;
  final DateTime endTime;

  // 3.1.3 Host Parent / Contact
  final String hostParentName;
  final String hostParentContact;

  // 3.1.4 Transportation
  final String transportation;

  // 3.2 Automated Chore Audit
  final bool prerequisiteAuditPassed;
  final List<String> incompletePrerequisiteChoreIds;

  // 3.3 Approval Rule (1 Parent vs 2 Parents)
  final ApprovalRule approvalRule;
  final Map<String, ParentDecision> parentDecisions;
  final ActivityRequestStatus overallStatus;

  int get approvedParentCount => parentDecisions.values
      .where((d) => d.status == ParentDecisionStatus.approved)
      .length;

  /// Latest feedback note from any parent who denied or requested changes.
  String? get latestParentFeedback {
    final relevant = parentDecisions.values
        .where((d) => d.comment != null && d.comment!.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (relevant.isEmpty) return null;
    return '${relevant.first.parentName}: "${relevant.first.comment}"';
  }

  ActivityRequest copyWith({
    String? id,
    String? householdId,
    String? childId,
    String? activityDestination,
    DateTime? startTime,
    DateTime? endTime,
    String? hostParentName,
    String? hostParentContact,
    String? transportation,
    bool? prerequisiteAuditPassed,
    List<String>? incompletePrerequisiteChoreIds,
    ApprovalRule? approvalRule,
    Map<String, ParentDecision>? parentDecisions,
    ActivityRequestStatus? overallStatus,
  }) {
    return ActivityRequest(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      childId: childId ?? this.childId,
      activityDestination: activityDestination ?? this.activityDestination,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      hostParentName: hostParentName ?? this.hostParentName,
      hostParentContact: hostParentContact ?? this.hostParentContact,
      transportation: transportation ?? this.transportation,
      prerequisiteAuditPassed:
          prerequisiteAuditPassed ?? this.prerequisiteAuditPassed,
      incompletePrerequisiteChoreIds: incompletePrerequisiteChoreIds ??
          List<String>.unmodifiable(this.incompletePrerequisiteChoreIds),
      approvalRule: approvalRule ?? this.approvalRule,
      parentDecisions: parentDecisions ??
          Map<String, ParentDecision>.unmodifiable(this.parentDecisions),
      overallStatus: overallStatus ?? this.overallStatus,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'household_id': householdId,
      'child_id': childId,
      'activity_destination': activityDestination,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'host_parent_name': hostParentName,
      'host_parent_contact': hostParentContact,
      'transportation': transportation,
      'prerequisite_audit_passed': prerequisiteAuditPassed,
      'incomplete_prerequisite_chore_ids': incompletePrerequisiteChoreIds,
      'approval_rule': approvalRule.name,
      'parent_decisions': parentDecisions.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'overall_status': overallStatus.name,
    };
  }

  factory ActivityRequest.fromJson(Map<String, dynamic> json) {
    final ruleStr = json['approval_rule'] as String? ?? 'twoParents';
    final statusStr = json['overall_status'] as String? ?? 'pending';
    final rawDecisions =
        json['parent_decisions'] as Map<String, dynamic>? ?? const {};

    return ActivityRequest(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      childId: json['child_id'] as String,
      activityDestination: json['activity_destination'] as String? ?? '',
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      hostParentName: json['host_parent_name'] as String? ?? '',
      hostParentContact: json['host_parent_contact'] as String? ?? '',
      transportation: json['transportation'] as String? ?? '',
      prerequisiteAuditPassed:
          json['prerequisite_audit_passed'] as bool? ?? true,
      incompletePrerequisiteChoreIds:
          (json['incomplete_prerequisite_chore_ids'] as List<dynamic>? ??
                  const [])
              .map((e) => e.toString())
              .toList(growable: false),
      approvalRule: ApprovalRule.values.firstWhere(
        (r) => r.name == ruleStr,
        orElse: () => ApprovalRule.twoParents,
      ),
      parentDecisions: rawDecisions.map(
        (key, value) => MapEntry(
          key,
          ParentDecision.fromJson(value as Map<String, dynamic>),
        ),
      ),
      overallStatus: ActivityRequestStatus.values.firstWhere(
        (s) => s.name == statusStr,
        orElse: () => ActivityRequestStatus.pending,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ActivityRequest &&
        other.id == id &&
        other.householdId == householdId &&
        other.childId == childId &&
        other.activityDestination == activityDestination &&
        other.startTime == startTime &&
        other.endTime == endTime &&
        other.hostParentName == hostParentName &&
        other.hostParentContact == hostParentContact &&
        other.transportation == transportation &&
        other.prerequisiteAuditPassed == prerequisiteAuditPassed &&
        listEquals(
          other.incompletePrerequisiteChoreIds,
          incompletePrerequisiteChoreIds,
        ) &&
        other.approvalRule == approvalRule &&
        mapEquals(other.parentDecisions, parentDecisions) &&
        other.overallStatus == overallStatus;
  }

  @override
  int get hashCode => Object.hash(
        id,
        householdId,
        childId,
        activityDestination,
        startTime,
        endTime,
        hostParentName,
        hostParentContact,
        transportation,
        prerequisiteAuditPassed,
        Object.hashAll(incompletePrerequisiteChoreIds),
        approvalRule,
        overallStatus,
      );
}

