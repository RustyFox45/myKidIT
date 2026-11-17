import '../../auth_and_family/domain/app_user.dart';

/// Categories of real-time notifications in MyKidIT (Feature 4.1).
enum NotificationType {
  choreSignOffRequested,
  choreApproved,
  choreChangesRequested,
  activityRequested,
  activityAwaitingSecondParent,
  activityApproved,
  activityDenied,
  activityChangesRequested,
  familyMemberJoined,
}

/// Immutable domain model representing a Push / In-App Notification.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.householdId,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    required this.targetRole,
    this.targetUserId,
    this.isRead = false,
  });

  final String id;
  final String householdId;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime createdAt;
  final AccountRole targetRole;
  final String? targetUserId;
  final bool isRead;

  AppNotification copyWith({
    bool? isRead,
  }) {
    return AppNotification(
      id: id,
      householdId: householdId,
      title: title,
      body: body,
      type: type,
      createdAt: createdAt,
      targetRole: targetRole,
      targetUserId: targetUserId,
      isRead: isRead ?? this.isRead,
    );
  }
}
