import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/app_config.dart';
import '../../dashboard_and_notifications/domain/app_notification.dart';
import '../../dashboard_and_notifications/presentation/notification_providers.dart';
import '../data/auth_repository.dart';
import '../data/household_repository.dart';
import '../domain/app_user.dart';
import '../domain/household.dart';

/// Provides the active [AuthRepository] (Supabase when configured, Mock by default).
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (AppConfig.isSupabaseConfigured) {
    return SupabaseAuthRepository(Supabase.instance.client);
  }
  return MockAuthRepository();
});

/// Provides the active [HouseholdRepository].
final householdRepositoryProvider = Provider<HouseholdRepository>((ref) {
  if (AppConfig.isSupabaseConfigured) {
    return SupabaseHouseholdRepository(Supabase.instance.client);
  }
  return MockHouseholdRepository();
});

/// Feature 1.1: Reactive stream of the currently signed-in [AppUser].
final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.watchCurrentUser();
});

/// Feature 1.1: Exposes the current user's [AccountRole] (`parent` vs. `child`).
final currentAccountRoleProvider = Provider<AccountRole?>((ref) {
  final user = ref.watch(currentUserProvider).asData?.value ??
      ref.watch(authRepositoryProvider).currentUser;
  return user?.role;
});

/// Reactive list of all registered family members.
final allUsersProvider = StreamProvider<List<AppUser>>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.watchAllUsers();
});

/// Reactive stream of the active user's linked [Household].
final currentHouseholdProvider = StreamProvider<Household?>((ref) {
  final user = ref.watch(currentUserProvider).asData?.value ??
      ref.watch(authRepositoryProvider).currentUser;
  final householdId = user?.householdId;
  if (householdId == null || householdId.isEmpty) {
    return Stream<Household?>.value(null);
  }
  final repo = ref.watch(householdRepositoryProvider);
  return repo.watchHousehold(householdId);
});

/// Parents belonging to the current household.
final householdParentsProvider = Provider<List<AppUser>>((ref) {
  final householdRepo = ref.watch(householdRepositoryProvider);
  final authRepo = ref.watch(authRepositoryProvider);
  final user = ref.watch(currentUserProvider).asData?.value ??
      authRepo.currentUser;
  final household = ref.watch(currentHouseholdProvider).asData?.value ??
      (user?.householdId != null
          ? householdRepo.getHouseholdById(user!.householdId!)
          : null);
  final users =
      ref.watch(allUsersProvider).asData?.value ?? authRepo.allUsers;
  if (household == null) return const [];
  return users
      .where((u) => u.isParent && household.parentIds.contains(u.id))
      .toList(growable: false);
});

/// Children belonging to the current household.
final householdChildrenProvider = Provider<List<AppUser>>((ref) {
  final householdRepo = ref.watch(householdRepositoryProvider);
  final authRepo = ref.watch(authRepositoryProvider);
  final user = ref.watch(currentUserProvider).asData?.value ??
      authRepo.currentUser;
  final household = ref.watch(currentHouseholdProvider).asData?.value ??
      (user?.householdId != null
          ? householdRepo.getHouseholdById(user!.householdId!)
          : null);
  final users =
      ref.watch(allUsersProvider).asData?.value ?? authRepo.allUsers;
  if (household == null) return const [];
  return users
      .where((u) => u.isChild && household.childIds.contains(u.id))
      .toList(growable: false);
});

/// Controller for Feature 1: Role-Based Access, Household Pairing, & Multi-Parent Link.
class AuthFamilyController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<AppUser> registerOrSignIn({
    required String displayName,
    required AccountRole role,
    String? email,
  }) async {
    state = const AsyncLoading();
    try {
      final authRepo = ref.read(authRepositoryProvider);
      final user = await authRepo.registerOrSignIn(
        displayName: displayName,
        role: role,
        email: email,
      );
      state = const AsyncData(null);
      return user;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// Creates a new household for a Parent account.
  Future<Household> createHousehold({
    required String householdName,
    ApprovalRule approvalRule = ApprovalRule.twoParents,
  }) async {
    state = const AsyncLoading();
    try {
      final authRepo = ref.read(authRepositoryProvider);
      final householdRepo = ref.read(householdRepositoryProvider);
      final user = authRepo.currentUser;
      if (user == null || !user.isParent) {
        throw StateError('Only a Parent account can create a household.');
      }

      final household = await householdRepo.createHousehold(
        name: householdName,
        creatorParentId: user.id,
        defaultApprovalRule: approvalRule,
      );
      await authRepo.updateUserHousehold(
        userId: user.id,
        householdId: household.id,
      );
      state = const AsyncData(null);
      return household;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// Pairs a Child (Feature 1.2) or Co-Parent (Feature 1.3) via invite code.
  Future<PairingResult> pairWithInviteCode(String inviteCode) async {
    state = const AsyncLoading();
    try {
      final authRepo = ref.read(authRepositoryProvider);
      final householdRepo = ref.read(householdRepositoryProvider);
      final notifService = ref.read(notificationServiceProvider);
      final user = authRepo.currentUser;
      if (user == null) {
        throw StateError('Please sign in or select a role first.');
      }

      final result = await householdRepo.joinHouseholdByCode(
        inviteCode: inviteCode,
        user: user,
      );

      await authRepo.updateUserHousehold(
        userId: user.id,
        householdId: result.household.id,
      );

      notifService.pushNotification(
        householdId: result.household.id,
        title: result.joinedAsRole == AccountRole.parent
            ? 'Co-Parent Linked!'
            : 'Child Device Paired!',
        body:
            '${user.displayName} joined ${result.household.name} as a ${result.joinedAsRole.label}.',
        type: NotificationType.familyMemberJoined,
        targetRole: AccountRole.parent,
      );

      state = const AsyncData(null);
      return result;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// Feature 3.3: Configures 1-Parent vs 2-Parent approval rule on the household.
  Future<void> updateDefaultApprovalRule(ApprovalRule rule) async {
    final household = ref.read(currentHouseholdProvider).asData?.value;
    if (household == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(householdRepositoryProvider).updateApprovalRule(
            householdId: household.id,
            approvalRule: rule,
          );
    });
  }

  Future<void> regenerateInviteCode({required bool forParent}) async {
    final household = ref.read(currentHouseholdProvider).asData?.value;
    if (household == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(householdRepositoryProvider).regenerateInviteCode(
            householdId: household.id,
            forParent: forParent,
          );
    });
  }

  /// Creates and pairs a new Child or Co-Parent profile directly into the household.
  Future<AppUser> addFamilyMemberDirect({
    required String displayName,
    required AccountRole role,
  }) async {
    final household = ref.read(currentHouseholdProvider).asData?.value;
    if (household == null) {
      throw StateError('No active household');
    }
    final authRepo = ref.read(authRepositoryProvider);
    final householdRepo = ref.read(householdRepositoryProvider);
    final previousUserId = authRepo.currentUser?.id;

    final created = await authRepo.registerOrSignIn(
      displayName: displayName,
      role: role,
    );
    final linked = await authRepo.updateUserHousehold(
      userId: created.id,
      householdId: household.id,
    );
    await householdRepo.addMemberToHousehold(
      householdId: household.id,
      member: linked,
    );
    if (previousUserId != null) {
      await authRepo.switchActiveUser(previousUserId);
    }
    return linked;
  }

  Future<void> switchPersona(String userId) async {
    await ref.read(authRepositoryProvider).switchActiveUser(userId);
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
  }
}

final authFamilyControllerProvider =
    AsyncNotifierProvider<AuthFamilyController, void>(
  AuthFamilyController.new,
);
