import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth_and_family/presentation/auth_family_providers.dart';
import '../data/notification_service.dart';
import '../domain/app_notification.dart';

/// Singleton notification service for Feature 4.1.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// Watches all notifications for the current household filtered by the active user's role.
final userNotificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final user = ref.watch(currentUserProvider).asData?.value;
  final householdId = user?.householdId;
  if (user == null || householdId == null) {
    return Stream<List<AppNotification>>.value(const []);
  }
  final service = ref.watch(notificationServiceProvider);
  return service.watchNotifications(householdId).map(
        (list) => list
            .where(
              (n) =>
                  n.targetRole == user.role &&
                  (n.targetUserId == null || n.targetUserId == user.id),
            )
            .toList(growable: false),
      );
});

/// Unread notification badge count for the active user.
final unreadNotificationCountProvider = Provider<int>((ref) {
  final list = ref.watch(userNotificationsProvider).asData?.value ?? const [];
  return list.where((n) => !n.isRead).length;
});

