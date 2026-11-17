import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/app_config.dart';
import '../../auth_and_family/domain/app_user.dart';
import '../../auth_and_family/presentation/auth_family_providers.dart';
import '../../dashboard_and_notifications/domain/app_notification.dart';
import '../../dashboard_and_notifications/presentation/notification_providers.dart';
import '../data/ai_verification_service.dart';
import '../data/chore_repository.dart';
import '../domain/chore_task.dart';

final choreRepositoryProvider = Provider<ChoreRepository>((ref) {
  if (AppConfig.isSupabaseConfigured) {
    return SupabaseChoreRepository(Supabase.instance.client);
  }
  return MockChoreRepository();
});

final aiVerificationServiceProvider = Provider<AiVerificationService>((ref) {
  return AiVerificationService(
    supabaseClient:
        AppConfig.isSupabaseConfigured ? Supabase.instance.client : null,
  );
});

/// Watches all chores in the active household.
final householdChoresProvider = StreamProvider<List<ChoreTask>>((ref) {
  final user = ref.watch(currentUserProvider).asData?.value ??
      ref.watch(authRepositoryProvider).currentUser;
  final householdId = user?.householdId;
  if (householdId == null || householdId.isEmpty) {
    return Stream<List<ChoreTask>>.value(const []);
  }
  return ref.watch(choreRepositoryProvider).watchHouseholdChores(householdId);
});

/// Returns chores assigned to a specific `childId`, sorted with Prerequisite chores first.
final childChoresProvider =
    Provider.family<List<ChoreTask>, String>((ref, childId) {
  final user = ref.watch(currentUserProvider).asData?.value ??
      ref.watch(authRepositoryProvider).currentUser;
  final all = ref.watch(householdChoresProvider).asData?.value ??
      (user?.householdId != null
          ? ref
              .watch(choreRepositoryProvider)
              .getHouseholdChoresSnapshot(user!.householdId!)
          : const []);
  final filtered = all.where((c) => c.assignedChildId == childId).toList();
  filtered.sort((a, b) {
    if (a.isPrerequisite != b.isPrerequisite) {
      return a.isPrerequisite ? -1 : 1;
    }
    return a.title.compareTo(b.title);
  });
  return filtered;
});

/// Controller for Feature 2: Task Creation, Child Sign-Off Toggle, Photo & AI Sign-Off.
class ChoreController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Feature 2.1: Parent creates a new chore task.
  Future<void> createChore({
    required String assignedChildId,
    required String title,
    required String description,
    required ChoreRepetition repetition,
    required bool isPrerequisite,
    required bool requiresPhotoProof,
    required bool aiSignOffEnabled,
    DateTime? dueDate,
  }) async {
    final user = ref.read(authRepositoryProvider).currentUser ??
        ref.read(currentUserProvider).asData?.value;
    if (user == null || user.householdId == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final newChore = ChoreTask(
        id: '',
        householdId: user.householdId!,
        assignedChildId: assignedChildId,
        createdByParentId: user.id,
        title: title.trim(),
        description: description.trim(),
        repetition: repetition,
        dueDate: dueDate,
        isPrerequisite: isPrerequisite,
        requiresPhotoProof: requiresPhotoProof,
        aiSignOffEnabled: aiSignOffEnabled,
        status: ChoreStatus.todo,
      );
      await ref.read(choreRepositoryProvider).createChore(newChore);
    });
  }

  /// Feature 2.2 & 2.3: Child toggles status to ask parents for sign-off,
  /// optionally attaching a photo and triggering Gemini Flash Vision AI verification.
  Future<ChoreTask?> requestSignOff({
    required ChoreTask chore,
    String? proofPhotoUrl,
    bool autoApproveWhenAiConfident = false,
  }) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(choreRepositoryProvider);
      final aiService = ref.read(aiVerificationServiceProvider);
      final notifService = ref.read(notificationServiceProvider);
      final users = ref.read(allUsersProvider).asData?.value ?? const [];
      final childName = users
          .where((u) => u.id == chore.assignedChildId)
          .map((u) => u.displayName)
          .firstOrNull ??
          'Your child';

      double? aiConfidence;
      String? aiFeedback;
      var nextStatus = ChoreStatus.pendingSignOff;

      if (chore.aiSignOffEnabled &&
          proofPhotoUrl != null &&
          proofPhotoUrl.trim().isNotEmpty) {
        final aiResult = await aiService.evaluateChorePhoto(
          choreTitle: chore.title,
          choreDescription: chore.description,
          photoUrlOrLabel: proofPhotoUrl,
          autoApproveHighConfidence: true,
        );
        aiConfidence = aiResult.confidence;
        aiFeedback = aiResult.feedback;

        if (autoApproveWhenAiConfident &&
            aiResult.approved &&
            aiResult.confidence >=
                AiVerificationService.autoApprovalConfidenceThreshold) {
          nextStatus = ChoreStatus.approved;
        }
      }

      final updated = chore.copyWith(
        status: nextStatus,
        proofPhotoUrl: proofPhotoUrl ?? chore.proofPhotoUrl,
        aiVerificationConfidence: aiConfidence,
        aiVerificationFeedback: aiFeedback,
        clearParentFeedback: true,
      );

      final saved = await repo.updateChore(updated);

      if (nextStatus == ChoreStatus.approved) {
        notifService.pushNotification(
          householdId: chore.householdId,
          title: 'AI Sign-Off Auto-Approved Chore',
          body:
              '$childName completed "${chore.title}" — Gemini Vision verified photo (${((aiConfidence ?? 0.94) * 100).round()}%).',
          type: NotificationType.choreApproved,
          targetRole: AccountRole.parent,
        );
      } else {
        final aiNote = aiConfidence != null
            ? ' (Gemini AI Score: ${(aiConfidence * 100).round()}%)'
            : '';
        notifService.pushNotification(
          householdId: chore.householdId,
          title: 'Chore Sign-Off Requested',
          body: '$childName asked for sign-off on "${chore.title}"$aiNote.',
          type: NotificationType.choreSignOffRequested,
          targetRole: AccountRole.parent,
        );
      }

      state = const AsyncData(null);
      return saved;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }

  /// Feature 2.3: Parent approves a chore or requests a redo with feedback.
  Future<void> reviewChoreAsParent({
    required ChoreTask chore,
    required bool approved,
    String? feedback,
  }) async {
    final parent = ref.read(authRepositoryProvider).currentUser ??
        ref.read(currentUserProvider).asData?.value;
    if (parent == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final updated = chore.copyWith(
        status: approved ? ChoreStatus.approved : ChoreStatus.changesRequested,
        parentReviewerId: parent.id,
        parentFeedback: feedback?.trim().isEmpty == true
            ? (approved ? 'Approved by ${parent.displayName}' : 'Please redo')
            : feedback?.trim(),
      );
      await ref.read(choreRepositoryProvider).updateChore(updated);

      ref.read(notificationServiceProvider).pushNotification(
            householdId: chore.householdId,
            title: approved
                ? 'Chore Approved: ${chore.title}'
                : 'Redo Requested: ${chore.title}',
            body: approved
                ? '${parent.displayName} signed off on "${chore.title}".'
                : '${parent.displayName} requested changes: "${updated.parentFeedback}"',
            type: approved
                ? NotificationType.choreApproved
                : NotificationType.choreChangesRequested,
            targetRole: AccountRole.child,
            targetUserId: chore.assignedChildId,
          );
    });
  }

  Future<void> togglePrerequisiteFlag(ChoreTask chore, bool value) async {
    await ref
        .read(choreRepositoryProvider)
        .updateChore(chore.copyWith(isPrerequisite: value));
  }

  Future<void> deleteChore(String choreId) async {
    await ref.read(choreRepositoryProvider).deleteChore(choreId);
  }
}

final choreControllerProvider =
    AsyncNotifierProvider<ChoreController, void>(ChoreController.new);
