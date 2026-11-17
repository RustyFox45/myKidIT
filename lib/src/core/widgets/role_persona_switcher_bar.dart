import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth_and_family/domain/app_user.dart';
import '../../features/auth_and_family/presentation/auth_family_providers.dart';
import '../../features/dashboard_and_notifications/domain/app_notification.dart';
import '../../features/dashboard_and_notifications/presentation/notification_providers.dart';
import '../theme/app_theme.dart';
import '../utils/invite_code_generator.dart';

/// Top bar allowing instant switching between Parent 1, Co-Parent 2, Child 1,
/// Child 2, and the Onboarding/Pairing screen for live multi-user testing.
class RolePersonaSwitcherBar extends ConsumerWidget {
  const RolePersonaSwitcherBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider).asData?.value;
    final allUsers = ref.watch(allUsersProvider).asData?.value ?? const [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(
          bottom: BorderSide(color: Color(0xFF1E293B)),
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.swap_horiz_rounded,
                color: Color(0xFF38BDF8),
                size: 18,
              ),
              const SizedBox(width: 6),
              const Text(
                'Live Role Switcher:',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final user in allUsers)
                      _PersonaChip(
                        user: user,
                        isSelected: currentUser?.id == user.id,
                        onTap: () => ref
                            .read(authFamilyControllerProvider.notifier)
                            .switchPersona(user.id),
                      ),
                  ],
                ),
              ),
            ],
          ),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFF8FAFC),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () =>
                ref.read(authFamilyControllerProvider.notifier).signOut(),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 15),
            label: const Text(
              'Role Setup / Code Pairing',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonaChip extends StatelessWidget {
  const _PersonaChip({
    required this.user,
    required this.isSelected,
    required this.onTap,
  });

  final AppUser user;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor =
        user.isParent ? AppTheme.primaryColor : AppTheme.secondaryColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.white54 : const Color(0xFF334155),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              user.isParent ? Icons.shield_outlined : Icons.face_retouching_natural,
              size: 13,
              color: Colors.white,
            ),
            const SizedBox(width: 5),
            Text(
              user.displayName,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Notification bell icon button that opens the real-time Notification Feed sheet.
class NotificationBellButton extends ConsumerWidget {
  const NotificationBellButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    final user = ref.watch(currentUserProvider).asData?.value;

    return IconButton(
      tooltip: 'Real-Time Notifications',
      onPressed: () {
        if (user != null) {
          ref.read(notificationServiceProvider).markAllReadForUser(user);
        }
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const _NotificationsBottomSheet(),
        );
      },
      icon: Badge(
        isLabelVisible: unreadCount > 0,
        label: Text('$unreadCount'),
        child: const Icon(Icons.notifications_active_outlined),
      ),
    );
  }
}

class _NotificationsBottomSheet extends ConsumerWidget {
  const _NotificationsBottomSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications =
        ref.watch(userNotificationsProvider).asData?.value ?? const [];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.72,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.notifications_active_rounded,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Real-Time Push Notifications & Sync Log',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: notifications.isEmpty
                ? const Center(
                    child: Text(
                      'No notifications yet for this account.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  )
                : ListView.separated(
                    itemCount: notifications.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = notifications[index];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _iconForType(item.type),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.body,
                                    style: const TextStyle(
                                      color: Color(0xFF334155),
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    AppFormatters.formatShortDateTime(
                                      item.createdAt,
                                    ),
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _iconForType(NotificationType type) {
    final (icon, color) = switch (type) {
      NotificationType.choreSignOffRequested => (
          Icons.camera_enhance_rounded,
          AppTheme.prerequisiteGold
        ),
      NotificationType.choreApproved => (
          Icons.verified_rounded,
          AppTheme.approvedGreen
        ),
      NotificationType.choreChangesRequested => (
          Icons.refresh_rounded,
          AppTheme.changesOrange
        ),
      NotificationType.activityRequested => (
          Icons.directions_run_rounded,
          AppTheme.primaryColor
        ),
      NotificationType.activityAwaitingSecondParent => (
          Icons.hourglass_top_rounded,
          AppTheme.pendingAmber
        ),
      NotificationType.activityApproved => (
          Icons.check_circle_rounded,
          AppTheme.approvedGreen
        ),
      NotificationType.activityDenied => (
          Icons.cancel_rounded,
          AppTheme.deniedRed
        ),
      NotificationType.activityChangesRequested => (
          Icons.edit_note_rounded,
          AppTheme.changesOrange
        ),
      NotificationType.familyMemberJoined => (
          Icons.group_add_rounded,
          AppTheme.secondaryColor
        ),
    };

    return CircleAvatar(
      radius: 18,
      backgroundColor: color.withValues(alpha: 0.14),
      child: Icon(icon, color: color, size: 19),
    );
  }
}

