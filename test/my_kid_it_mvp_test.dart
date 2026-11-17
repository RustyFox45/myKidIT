import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_kid_it/src/features/activity_permissions/domain/activity_request.dart';
import 'package:my_kid_it/src/features/activity_permissions/presentation/activity_request_providers.dart';
import 'package:my_kid_it/src/features/auth_and_family/domain/app_user.dart';
import 'package:my_kid_it/src/features/auth_and_family/presentation/auth_family_providers.dart';
import 'package:my_kid_it/src/features/chores/presentation/chore_providers.dart';

void main() {
  group('MyKidIT MVP Features (Riverpod State & Task-Gating)', () {
    test(
      'Feature 2 & 3.2: Automated Chore Audit blocks activity requests until all prerequisite chores are approved',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Keep stream listeners active in headless container
        container.listen(currentUserProvider, (_, _) {});
        container.listen(householdChoresProvider, (_, _) {});

        // Child-1 ("Leo") starts with 3 prerequisite chores, only 1 approved
        final initialAudit = container.read(choreAuditProvider('child-1'));
        expect(initialAudit.passed, isFalse);
        expect(initialAudit.totalPrerequisites, equals(3));
        expect(initialAudit.incompletePrerequisiteChores.length, equals(2));

        // Approve the remaining 2 prerequisite chores for child-1
        final choreController = container.read(choreControllerProvider.notifier);
        for (final chore in initialAudit.incompletePrerequisiteChores) {
          await choreController.reviewChoreAsParent(
            chore: chore,
            approved: true,
            feedback: 'Verified!',
          );
        }

        // Wait for stream propagation
        await Future<void>.delayed(const Duration(milliseconds: 20));

        final updatedAudit = container.read(choreAuditProvider('child-1'));
        expect(updatedAudit.passed, isTrue);
        expect(updatedAudit.incompletePrerequisiteChores, isEmpty);
      },
    );

    test(
      'Feature 3.3 & 4.2: 2-Parent approval rule transitions from awaitingSecondParent to approved when 2nd parent approves',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        container.listen(currentUserProvider, (_, _) {});
        container.listen(currentHouseholdProvider, (_, _) {});
        container.listen(householdActivityRequestsProvider, (_, _) {});

        final requests = container
            .read(activityRequestRepositoryProvider)
            .getHouseholdRequestsSnapshot('household-1');

        final basketballReq = requests.firstWhere((r) => r.id == 'req-1');
        expect(
          basketballReq.overallStatus,
          equals(ActivityRequestStatus.awaitingSecondParent),
        );

        // Switch to Parent 2 ("Sarah") and approve
        await container
            .read(authFamilyControllerProvider.notifier)
            .switchPersona('parent-2');

        await container
            .read(activityRequestControllerProvider.notifier)
            .submitParentDecision(
              request: basketballReq,
              decisionStatus: ParentDecisionStatus.approved,
              comment: 'Confirmed pickup!',
            );

        final updatedRequests = container
            .read(activityRequestRepositoryProvider)
            .getHouseholdRequestsSnapshot('household-1');
        final updatedReq = updatedRequests.firstWhere((r) => r.id == 'req-1');

        expect(updatedReq.overallStatus, equals(ActivityRequestStatus.approved));
        expect(updatedReq.approvedParentCount, equals(2));
      },
    );

    test(
      'Feature 1.2: New Child account can pair to household using Child Pairing Code KID405',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final authController =
            container.read(authFamilyControllerProvider.notifier);
        final newChild = await authController.registerOrSignIn(
          displayName: 'Sam (Child, 9)',
          role: AccountRole.child,
        );
        expect(newChild.isPairedToHousehold, isFalse);

        final pairing = await authController.pairWithInviteCode('KID405');
        expect(pairing.household.id, equals('household-1'));
        expect(pairing.household.childIds, contains(newChild.id));
        expect(pairing.joinedAsRole, equals(AccountRole.child));
      },
    );
  });
}
