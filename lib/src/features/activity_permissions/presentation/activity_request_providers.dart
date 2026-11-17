import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/app_config.dart';
import '../../auth_and_family/domain/app_user.dart';
import '../../auth_and_family/domain/household.dart';
import '../../auth_and_family/presentation/auth_family_providers.dart';
import '../../chores/domain/chore_task.dart';
import '../../chores/presentation/chore_providers.dart';
import '../../dashboard_and_notifications/domain/app_notification.dart';
import '../../dashboard_and_notifications/presentation/notification_providers.dart';
import '../data/activity_request_repository.dart';
import '../domain/activity_request.dart';

final activityRequestRepositoryProvider =
    Provider<ActivityRequestRepository>((ref) {
  if (AppConfig.isSupabaseConfigured) {
    return SupabaseActivityRequestRepository(Supabase.instance.client);
  }
  return MockActivityRequestRepository();
});

/// Feature 3.2: Automated Chore Audit provider.
///
/// Watches all active chores for [childId] where `isPrerequisite == true` and
/// checks whether any prerequisite flags were not completed (`status != ChoreStatus.approved`).
final choreAuditProvider =
    Provider.family<ChoreAuditResult, String>((ref, childId) {
  final childChores = ref.watch(childChoresProvider(childId));
  final prerequisites =
      childChores.where((c) => c.isPrerequisite).toList(growable: false);
  final incomplete = prerequisites
      .where((c) => c.status != ChoreStatus.approved)
      .toList(growable: false);

  return ChoreAuditResult(
    childId: childId,
    prerequisiteChores: prerequisites,
    incompletePrerequisiteChores: incomplete,
  );
});

/// Watches all activity permission requests for the current household.
final householdActivityRequestsProvider =
    StreamProvider<List<ActivityRequest>>((ref) {
  final user = ref.watch(currentUserProvider).asData?.value ??
      ref.watch(authRepositoryProvider).currentUser;
  final householdId = user?.householdId;
  if (householdId == null || householdId.isEmpty) {
    return Stream<List<ActivityRequest>>.value(const []);
  }
  return ref
      .watch(activityRequestRepositoryProvider)
      .watchHouseholdRequests(householdId);
});

/// Returns activity permission requests for a specific child.
final childActivityRequestsProvider =
    Provider.family<List<ActivityRequest>, String>((ref, childId) {
  final user = ref.watch(currentUserProvider).asData?.value ??
      ref.watch(authRepositoryProvider).currentUser;
  final all = ref.watch(householdActivityRequestsProvider).asData?.value ??
      (user?.householdId != null
          ? ref
              .watch(activityRequestRepositoryProvider)
              .getHouseholdRequestsSnapshot(user!.householdId!)
          : const []);
  return all.where((r) => r.childId == childId).toList(growable: false);
});

/// Controller for Feature 3: Activity Permission Request Form, Automated Chore Audit,
/// and 1-Parent vs 2-Parent Approval Rules.
class ActivityRequestController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Submits a new Activity Request (or updates an existing one after Changes Requested)
  /// after running the Automated Chore Audit (Feature 3.2).
  Future<ActivityRequest> submitOrResubmitRequest({
    String? existingRequestId,
    required String childId,
    required String activityDestination,
    required DateTime startTime,
    required DateTime endTime,
    required String hostParentName,
    required String hostParentContact,
    required String transportation,
  }) async {
    state = const AsyncLoading();
    try {
      final household = ref.read(currentHouseholdProvider).asData?.value;
      if (household == null) {
        throw StateError('User is not paired to a household.');
      }

      // Run Automated Chore Audit (Feature 3.2)
      final audit = ref.read(choreAuditProvider(childId));
      if (!audit.passed) {
        final missingTitles =
            audit.incompletePrerequisiteChores.map((c) => c.title).join(', ');
        throw StateError(
          'Automated Chore Audit Blocked Request: Complete & get sign-off on prerequisite chores first ($missingTitles).',
        );
      }

      final repo = ref.read(activityRequestRepositoryProvider);
      final notifService = ref.read(notificationServiceProvider);
      final users = ref.read(allUsersProvider).asData?.value ?? const [];
      final childName = users
              .where((u) => u.id == childId)
              .map((u) => u.displayName)
              .firstOrNull ??
          'Child';

      final request = ActivityRequest(
        id: existingRequestId ?? '',
        householdId: household.id,
        childId: childId,
        activityDestination: activityDestination.trim(),
        startTime: startTime,
        endTime: endTime,
        hostParentName: hostParentName.trim(),
        hostParentContact: hostParentContact.trim(),
        transportation: transportation.trim(),
        prerequisiteAuditPassed: true,
        incompletePrerequisiteChoreIds: const [],
        approvalRule: household.defaultApprovalRule,
        parentDecisions: const {},
        overallStatus: ActivityRequestStatus.pending,
      );

      final saved = existingRequestId != null
          ? await repo.updateRequest(request)
          : await repo.createRequest(request);

      notifService.pushNotification(
        householdId: household.id,
        title: existingRequestId != null
            ? 'Updated Activity Request Resubmitted'
            : 'New Activity Permission Request',
        body:
            '$childName requested permission for "${saved.activityDestination}" (All prerequisite chores verified!).',
        type: NotificationType.activityRequested,
        targetRole: AccountRole.parent,
      );

      state = const AsyncData(null);
      return saved;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// Feature 3.3 & 4.2: Records a Parent's decision (`approved`, `denied`, or `changesRequested`)
  /// and computes the live 1-Parent vs 2-Parent status.
  Future<void> submitParentDecision({
    required ActivityRequest request,
    required ParentDecisionStatus decisionStatus,
    String? comment,
  }) async {
    final parent = ref.read(authRepositoryProvider).currentUser ??
        ref.read(currentUserProvider).asData?.value;
    final household = (parent?.householdId != null
            ? ref
                .read(householdRepositoryProvider)
                .getHouseholdById(parent!.householdId!)
            : null) ??
        ref.read(currentHouseholdProvider).asData?.value;
    if (parent == null || !parent.isParent || household == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final updatedDecisions = {
        ...request.parentDecisions,
        parent.id: ParentDecision(
          parentId: parent.id,
          parentName: parent.displayName,
          status: decisionStatus,
          comment: comment?.trim(),
          timestamp: DateTime.now(),
        ),
      };

      final totalHouseholdParents = household.parentIds.length;
      final requiredApprovals =
          request.approvalRule == ApprovalRule.twoParents &&
                  totalHouseholdParents >= 2
              ? 2
              : 1;

      ActivityRequestStatus nextOverallStatus;
      if (updatedDecisions.values
          .any((d) => d.status == ParentDecisionStatus.denied)) {
        nextOverallStatus = ActivityRequestStatus.denied;
      } else if (updatedDecisions.values
          .any((d) => d.status == ParentDecisionStatus.changesRequested)) {
        nextOverallStatus = ActivityRequestStatus.changesRequested;
      } else {
        final approvedCount = updatedDecisions.values
            .where((d) => d.status == ParentDecisionStatus.approved)
            .length;
        if (approvedCount >= requiredApprovals) {
          nextOverallStatus = ActivityRequestStatus.approved;
        } else {
          nextOverallStatus = ActivityRequestStatus.awaitingSecondParent;
        }
      }

      final updated = request.copyWith(
        parentDecisions: updatedDecisions,
        overallStatus: nextOverallStatus,
      );

      await ref.read(activityRequestRepositoryProvider).updateRequest(updated);

      final notifService = ref.read(notificationServiceProvider);
      switch (nextOverallStatus) {
        case ActivityRequestStatus.awaitingSecondParent:
          notifService.pushNotification(
            householdId: request.householdId,
            title: 'Co-Parent Approval Needed (1 of 2 Approved)',
            body:
                '${parent.displayName} approved "${request.activityDestination}". Waiting on 2nd parent sign-off.',
            type: NotificationType.activityAwaitingSecondParent,
            targetRole: AccountRole.parent,
          );
          notifService.pushNotification(
            householdId: request.householdId,
            title: '1 of 2 Parents Approved!',
            body:
                '${parent.displayName} approved "${request.activityDestination}". Waiting for your other parent to approve.',
            type: NotificationType.activityAwaitingSecondParent,
            targetRole: AccountRole.child,
            targetUserId: request.childId,
          );
        case ActivityRequestStatus.approved:
          notifService.pushNotification(
            householdId: request.householdId,
            title: 'Activity Permission Approved!',
            body:
                '"${request.activityDestination}" is officially approved! Have fun and stay safe.',
            type: NotificationType.activityApproved,
            targetRole: AccountRole.child,
            targetUserId: request.childId,
          );
        case ActivityRequestStatus.changesRequested:
          notifService.pushNotification(
            householdId: request.householdId,
            title: 'Changes Requested on Activity Request',
            body:
                '${parent.displayName} requested changes on "${request.activityDestination}": ${comment ?? "Please review details."}',
            type: NotificationType.activityChangesRequested,
            targetRole: AccountRole.child,
            targetUserId: request.childId,
          );
        case ActivityRequestStatus.denied:
          notifService.pushNotification(
            householdId: request.householdId,
            title: 'Activity Request Denied',
            body:
                '${parent.displayName} denied "${request.activityDestination}": ${comment ?? "Not approved for this time."}',
            type: NotificationType.activityDenied,
            targetRole: AccountRole.child,
            targetUserId: request.childId,
          );
        case ActivityRequestStatus.pending:
        case ActivityRequestStatus.blockedByPrerequisites:
          break;
      }
    });
  }
}

final activityRequestControllerProvider =
    AsyncNotifierProvider<ActivityRequestController, void>(
  ActivityRequestController.new,
);
