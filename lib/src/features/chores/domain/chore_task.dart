/// Repetition cadence for a chore (Feature 2.1).
enum ChoreRepetition {
  once,
  daily,
  weekly,
  weekdays,
  custom;

  String get label => switch (this) {
        ChoreRepetition.once => 'One-Time',
        ChoreRepetition.daily => 'Daily',
        ChoreRepetition.weekly => 'Weekly',
        ChoreRepetition.weekdays => 'Weekdays (Mon–Fri)',
        ChoreRepetition.custom => 'Custom',
      };
}

/// Lifecycle status of a chore task (Features 2.2 & 2.3).
enum ChoreStatus {
  todo,
  pendingSignOff,
  approved,
  changesRequested;

  String get label => switch (this) {
        ChoreStatus.todo => 'To Do',
        ChoreStatus.pendingSignOff => 'Awaiting Sign-Off',
        ChoreStatus.approved => 'Approved',
        ChoreStatus.changesRequested => 'Redo Requested',
      };
}

/// Immutable domain model for a Chore / Task (Section 4.3 of AGENTS.md).
class ChoreTask {
  const ChoreTask({
    required this.id,
    required this.householdId,
    required this.assignedChildId,
    required this.createdByParentId,
    required this.title,
    required this.description,
    required this.repetition,
    required this.isPrerequisite,
    required this.requiresPhotoProof,
    required this.aiSignOffEnabled,
    required this.status,
    this.dueDate,
    this.proofPhotoUrl,
    this.aiVerificationConfidence,
    this.aiVerificationFeedback,
    this.parentReviewerId,
    this.parentFeedback,
  });

  final String id;
  final String householdId;
  final String assignedChildId;
  final String createdByParentId;
  final String title;
  final String description;
  final ChoreRepetition repetition;
  final DateTime? dueDate;

  /// Feature 2.4: If `true`, this chore gates new Activity Permission Requests
  /// until its status reaches [ChoreStatus.approved].
  final bool isPrerequisite;
  final bool requiresPhotoProof;
  final bool aiSignOffEnabled;
  final ChoreStatus status;
  final String? proofPhotoUrl;
  final double? aiVerificationConfidence;
  final String? aiVerificationFeedback;
  final String? parentReviewerId;
  final String? parentFeedback;

  bool get isCompleteAndApproved => status == ChoreStatus.approved;

  ChoreTask copyWith({
    String? id,
    String? householdId,
    String? assignedChildId,
    String? createdByParentId,
    String? title,
    String? description,
    ChoreRepetition? repetition,
    DateTime? dueDate,
    bool? isPrerequisite,
    bool? requiresPhotoProof,
    bool? aiSignOffEnabled,
    ChoreStatus? status,
    String? proofPhotoUrl,
    bool clearProofPhoto = false,
    double? aiVerificationConfidence,
    String? aiVerificationFeedback,
    bool clearAiVerification = false,
    String? parentReviewerId,
    String? parentFeedback,
    bool clearParentFeedback = false,
  }) {
    return ChoreTask(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      assignedChildId: assignedChildId ?? this.assignedChildId,
      createdByParentId: createdByParentId ?? this.createdByParentId,
      title: title ?? this.title,
      description: description ?? this.description,
      repetition: repetition ?? this.repetition,
      dueDate: dueDate ?? this.dueDate,
      isPrerequisite: isPrerequisite ?? this.isPrerequisite,
      requiresPhotoProof: requiresPhotoProof ?? this.requiresPhotoProof,
      aiSignOffEnabled: aiSignOffEnabled ?? this.aiSignOffEnabled,
      status: status ?? this.status,
      proofPhotoUrl:
          clearProofPhoto ? null : (proofPhotoUrl ?? this.proofPhotoUrl),
      aiVerificationConfidence: clearAiVerification
          ? null
          : (aiVerificationConfidence ?? this.aiVerificationConfidence),
      aiVerificationFeedback: clearAiVerification
          ? null
          : (aiVerificationFeedback ?? this.aiVerificationFeedback),
      parentReviewerId: parentReviewerId ?? this.parentReviewerId,
      parentFeedback:
          clearParentFeedback ? null : (parentFeedback ?? this.parentFeedback),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'household_id': householdId,
      'assigned_child_id': assignedChildId,
      'created_by_parent_id': createdByParentId,
      'title': title,
      'description': description,
      'repetition': repetition.name,
      'due_date': dueDate?.toIso8601String(),
      'is_prerequisite': isPrerequisite,
      'requires_photo_proof': requiresPhotoProof,
      'ai_sign_off_enabled': aiSignOffEnabled,
      'status': status.name,
      'proof_photo_url': proofPhotoUrl,
      'ai_verification_confidence': aiVerificationConfidence,
      'ai_verification_feedback': aiVerificationFeedback,
      'parent_reviewer_id': parentReviewerId,
      'parent_feedback': parentFeedback,
    };
  }

  factory ChoreTask.fromJson(Map<String, dynamic> json) {
    final repStr = json['repetition'] as String? ?? 'daily';
    final statusStr = json['status'] as String? ?? 'todo';

    return ChoreTask(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      assignedChildId: json['assigned_child_id'] as String,
      createdByParentId: json['created_by_parent_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      repetition: ChoreRepetition.values.firstWhere(
        (e) => e.name == repStr,
        orElse: () => ChoreRepetition.daily,
      ),
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'] as String)
          : null,
      isPrerequisite: json['is_prerequisite'] as bool? ?? false,
      requiresPhotoProof: json['requires_photo_proof'] as bool? ?? false,
      aiSignOffEnabled: json['ai_sign_off_enabled'] as bool? ?? false,
      status: ChoreStatus.values.firstWhere(
        (e) => e.name == statusStr,
        orElse: () => ChoreStatus.todo,
      ),
      proofPhotoUrl: json['proof_photo_url'] as String?,
      aiVerificationConfidence:
          (json['ai_verification_confidence'] as num?)?.toDouble(),
      aiVerificationFeedback: json['ai_verification_feedback'] as String?,
      parentReviewerId: json['parent_reviewer_id'] as String?,
      parentFeedback: json['parent_feedback'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChoreTask &&
        other.id == id &&
        other.householdId == householdId &&
        other.assignedChildId == assignedChildId &&
        other.createdByParentId == createdByParentId &&
        other.title == title &&
        other.description == description &&
        other.repetition == repetition &&
        other.dueDate == dueDate &&
        other.isPrerequisite == isPrerequisite &&
        other.requiresPhotoProof == requiresPhotoProof &&
        other.aiSignOffEnabled == aiSignOffEnabled &&
        other.status == status &&
        other.proofPhotoUrl == proofPhotoUrl &&
        other.aiVerificationConfidence == aiVerificationConfidence &&
        other.aiVerificationFeedback == aiVerificationFeedback &&
        other.parentReviewerId == parentReviewerId &&
        other.parentFeedback == parentFeedback;
  }

  @override
  int get hashCode => Object.hash(
        id,
        householdId,
        assignedChildId,
        createdByParentId,
        title,
        description,
        repetition,
        dueDate,
        isPrerequisite,
        requiresPhotoProof,
        aiSignOffEnabled,
        status,
        proofPhotoUrl,
        aiVerificationConfidence,
        aiVerificationFeedback,
        parentReviewerId,
        parentFeedback,
      );
}

