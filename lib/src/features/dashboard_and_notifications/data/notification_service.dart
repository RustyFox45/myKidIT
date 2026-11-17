import 'dart:async';
import 'package:uuid/uuid.dart';
import '../../auth_and_family/domain/app_user.dart';
import '../domain/app_notification.dart';

/// Real-time notification and status sync service (Feature 4.1).
class NotificationService {
  NotificationService() {
    final now = DateTime.now();
    _notifications = [
      AppNotification(
        id: 'notif-1',
        householdId: 'household-1',
        title: 'Chore Sign-Off Requested',
        body: 'Leo uploaded photo proof for "Clean bedroom floor & make bed" (AI Score: 94%).',
        type: NotificationType.choreSignOffRequested,
        createdAt: now.subtract(const Duration(minutes: 18)),
        targetRole: AccountRole.parent,
      ),
      AppNotification(
        id: 'notif-2',
        householdId: 'household-1',
        title: 'Awaiting 2nd Parent Approval',
        body: 'Logan approved Leo\'s request for "Basketball at Rec Center". Waiting on Sarah.',
        type: NotificationType.activityAwaitingSecondParent,
        createdAt: now.subtract(const Duration(minutes: 9)),
        targetRole: AccountRole.parent,
        targetUserId: 'parent-2',
      ),
      AppNotification(
        id: 'notif-3',
        householdId: 'household-1',
        title: 'Changes Requested on Activity',
        body: 'Logan requested changes on "Movie Night at Jake\'s House": Please add Mrs. Miller\'s phone number.',
        type: NotificationType.activityChangesRequested,
        createdAt: now.subtract(const Duration(minutes: 35)),
        targetRole: AccountRole.child,
        targetUserId: 'child-1',
      ),
    ];
  }

  final _uuid = const Uuid();
  late List<AppNotification> _notifications;
  final _controller = StreamController<List<AppNotification>>.broadcast();
  final _latestBannerController = StreamController<AppNotification>.broadcast();

  Stream<List<AppNotification>> watchNotifications(String householdId) {
    return Stream<List<AppNotification>>.multi((controller) {
      controller.add(
        _notifications
            .where((n) => n.householdId == householdId)
            .toList(growable: false),
      );
      final sub = _controller.stream
          .map(
            (list) => list
                .where((n) => n.householdId == householdId)
                .toList(growable: false),
          )
          .listen(controller.add, onError: controller.addError);
      controller.onCancel = sub.cancel;
    });
  }

  /// Stream of newly pushed notifications to display real-time toast banners.
  Stream<AppNotification> get onPushAlert => _latestBannerController.stream;

  void pushNotification({
    required String householdId,
    required String title,
    required String body,
    required NotificationType type,
    required AccountRole targetRole,
    String? targetUserId,
  }) {
    final notif = AppNotification(
      id: _uuid.v4(),
      householdId: householdId,
      title: title,
      body: body,
      type: type,
      createdAt: DateTime.now(),
      targetRole: targetRole,
      targetUserId: targetUserId,
    );
    _notifications = [notif, ..._notifications];
    _controller.add(List<AppNotification>.unmodifiable(_notifications));
    _latestBannerController.add(notif);
  }

  void markAllReadForUser(AppUser user) {
    _notifications = _notifications.map((n) {
      final matchesUser = n.targetRole == user.role &&
          (n.targetUserId == null || n.targetUserId == user.id);
      return matchesUser ? n.copyWith(isRead: true) : n;
    }).toList(growable: false);
    _controller.add(List<AppNotification>.unmodifiable(_notifications));
  }
}
