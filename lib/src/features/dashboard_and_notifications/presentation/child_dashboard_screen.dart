import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/invite_code_generator.dart';
import '../../../core/widgets/role_persona_switcher_bar.dart';
import '../../activity_permissions/domain/activity_request.dart';
import '../../activity_permissions/presentation/activity_request_form_dialog.dart';
import '../../activity_permissions/presentation/activity_request_providers.dart';
import '../../auth_and_family/domain/app_user.dart';
import '../../auth_and_family/presentation/auth_family_providers.dart';
import '../../chores/domain/chore_task.dart';
import '../../chores/presentation/chore_providers.dart';

/// Feature 4.2: Real-Time Child Status Dashboard.
///
/// Displays:
/// - Automated Chore Audit / Activity Unlock Banner (Features 2.4, 3.2, 4.2.2)
/// - Prerequisite & Standard Chores with "Ask for Sign-Off" + Photo/AI verification (Feature 2.2, 2.3)
/// - Live Activity Permission Requests Status (`Pending — 1 Parent Hasn't Approved Yet`,
///   `Approved`, `Denied`, `Changes Requested` with 1-tap Edit & Resubmit) (Feature 3 & 4.2)
class ChildDashboardScreen extends ConsumerWidget {
  const ChildDashboardScreen({super.key});

  Future<void> _openSignOffModal(
    BuildContext context,
    WidgetRef ref,
    ChoreTask chore,
  ) async {
    String? attachedPhotoPath = chore.proofPhotoUrl;
    var allowAiAutoApprove = chore.aiSignOffEnabled;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.verified_outlined,
                        color: AppTheme.secondaryColor,
                        size: 26,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Ask for Sign-Off: ${chore.title}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    chore.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (chore.requiresPhotoProof) ...[
                    const Text(
                      'Photo Proof (Required for this Chore)',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              final picker = ImagePicker();
                              final picked = await picker.pickImage(
                                source: ImageSource.gallery,
                              );
                              if (picked != null) {
                                setSheetState(
                                  () => attachedPhotoPath = picked.name,
                                );
                              }
                            } catch (_) {
                              setSheetState(
                                () => attachedPhotoPath =
                                    'camera_proof_${chore.id}.jpg',
                              );
                            }
                          },
                          icon: const Icon(Icons.add_a_photo_outlined),
                          label: const Text('Choose / Capture Photo'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () {
                            setSheetState(() {
                              attachedPhotoPath =
                                  'verified_photo_${chore.id}_clean.jpg';
                            });
                          },
                          icon: const Icon(Icons.auto_awesome_rounded),
                          label: const Text('Attach Demo Clean Photo'),
                        ),
                      ],
                    ),
                    if (attachedPhotoPath != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.approvedGreen),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: AppTheme.approvedGreen,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Attached: $attachedPhotoPath',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (chore.aiSignOffEnabled) ...[
                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: allowAiAutoApprove,
                        title: const Text(
                          'Instant Gemini Vision AI Sign-Off',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: const Text(
                          'Auto-approves immediately if Gemini Vision confidence is 88%+ (or turn off to send to parent for manual review).',
                          style: TextStyle(fontSize: 12),
                        ),
                        onChanged: (val) =>
                            setSheetState(() => allowAiAutoApprove = val),
                      ),
                    ],
                  ],

                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: chore.requiresPhotoProof &&
                              (attachedPhotoPath == null ||
                                  attachedPhotoPath!.isEmpty)
                          ? null
                          : () async {
                              Navigator.of(ctx).pop();
                              await ref
                                  .read(choreControllerProvider.notifier)
                                  .requestSignOff(
                                    chore: chore,
                                    proofPhotoUrl: attachedPhotoPath,
                                    autoApproveWhenAiConfident:
                                        allowAiAutoApprove,
                                  );
                            },
                      icon: const Icon(Icons.send_rounded),
                      label: Text(
                        chore.requiresPhotoProof &&
                                (attachedPhotoPath == null ||
                                    attachedPhotoPath!.isEmpty)
                            ? 'Attach Photo Proof First'
                            : (allowAiAutoApprove && chore.aiSignOffEnabled
                                ? 'Verify with Gemini AI & Request Sign-Off'
                                : 'Send Sign-Off Request to Parents'),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(currentUserProvider).asData?.value;
    final household = ref.watch(currentHouseholdProvider).asData?.value;
    final parents = ref.watch(householdParentsProvider);

    if (child == null) {
      return const SizedBox.shrink();
    }

    final chores = ref.watch(childChoresProvider(child.id));
    final audit = ref.watch(choreAuditProvider(child.id));
    final requests = ref.watch(childActivityRequestsProvider(child.id));

    final prerequisiteChores =
        chores.where((c) => c.isPrerequisite).toList(growable: false);
    final standardChores =
        chores.where((c) => !c.isPrerequisite).toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(
              Icons.face_retouching_natural,
              color: AppTheme.secondaryColor,
              size: 24,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                '${child.displayName} • ${household?.name ?? "MyKidIT"}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: const [
          NotificationBellButton(),
          SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor:
            audit.passed ? AppTheme.primaryColor : AppTheme.prerequisiteGold,
        onPressed: () {
          showDialog<bool>(
            context: context,
            builder: (_) => ActivityRequestFormDialog(childId: child.id),
          );
        },
        icon: Icon(
          audit.passed ? Icons.directions_run_rounded : Icons.lock_clock_rounded,
        ),
        label: Text(
          audit.passed
              ? 'Request Activity Permission'
              : 'Request Activity (${audit.incompletePrerequisiteChores.length} Prereq Left)',
        ),
      ),
      body: Column(
        children: [
          const RolePersonaSwitcherBar(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
              children: [
                // Automated Chore Audit & Prerequisite Status Card (Feature 3.2 & 4.2.2)
                _PrerequisiteAuditBanner(
                  audit: audit,
                  onRequestActivity: () {
                    showDialog<bool>(
                      context: context,
                      builder: (_) =>
                          ActivityRequestFormDialog(childId: child.id),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Section 1: My Activity Requests Status (Feature 4.2.1 & 4.2.3)
                Row(
                  children: [
                    const Icon(
                      Icons.event_note_rounded,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'My Activity Permission Requests',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        showDialog<bool>(
                          context: context,
                          builder: (_) =>
                              ActivityRequestFormDialog(childId: child.id),
                        );
                      },
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('New Request'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (requests.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'You haven\'t submitted any activity requests yet.',
                      ),
                    ),
                  )
                else
                  for (final req in requests) ...[
                    _ChildActivityStatusCard(
                      request: req,
                      householdParents: parents,
                      onEditAndResubmit: () {
                        showDialog<bool>(
                          context: context,
                          builder: (_) => ActivityRequestFormDialog(
                            childId: child.id,
                            existingRequest: req,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                const SizedBox(height: 20),

                // Section 2: Prerequisite Chores (Feature 2.2, 2.3, 2.4)
                const Row(
                  children: [
                    Icon(
                      Icons.lock_clock_rounded,
                      color: AppTheme.prerequisiteGold,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Prerequisite Chores (Required to Unlock Activities)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final chore in prerequisiteChores) ...[
                  _ChildChoreCard(
                    chore: chore,
                    onAskForSignOff: () =>
                        _openSignOffModal(context, ref, chore),
                  ),
                  const SizedBox(height: 10),
                ],

                if (standardChores.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Additional Daily / Weekly Chores',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final chore in standardChores) ...[
                    _ChildChoreCard(
                      chore: chore,
                      onAskForSignOff: () =>
                          _openSignOffModal(context, ref, chore),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrerequisiteAuditBanner extends StatelessWidget {
  const _PrerequisiteAuditBanner({
    required this.audit,
    required this.onRequestActivity,
  });

  final ChoreAuditResult audit;
  final VoidCallback onRequestActivity;

  @override
  Widget build(BuildContext context) {
    final progress = audit.totalPrerequisites == 0
        ? 1.0
        : audit.completedPrerequisites / audit.totalPrerequisites;
    final bannerColor =
        audit.passed ? AppTheme.approvedGreen : AppTheme.prerequisiteGold;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: bannerColor.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: bannerColor.withValues(alpha: 0.14),
                child: Icon(
                  audit.passed
                      ? Icons.lock_open_rounded
                      : Icons.lock_clock_rounded,
                  color: bannerColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      audit.summaryBannerText,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: bannerColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      audit.passed
                          ? 'Automated Chore Audit Passed! You can now submit new Activity Permission Requests.'
                          : 'Complete and get sign-off on all prerequisite chores below to unlock activity requests.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: const Color(0xFFE2E8F0),
              color: bannerColor,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${audit.completedPrerequisites} of ${audit.totalPrerequisites} Prerequisite Chores Signed Off',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569),
                ),
              ),
              if (audit.passed)
                TextButton.icon(
                  onPressed: onRequestActivity,
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Request Activity Now'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChildActivityStatusCard extends StatelessWidget {
  const _ChildActivityStatusCard({
    required this.request,
    required this.householdParents,
    required this.onEditAndResubmit,
  });

  final ActivityRequest request;
  final List<AppUser> householdParents;
  final VoidCallback onEditAndResubmit;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (request.overallStatus) {
      ActivityRequestStatus.approved => AppTheme.approvedGreen,
      ActivityRequestStatus.awaitingSecondParent => AppTheme.prerequisiteGold,
      ActivityRequestStatus.pending => AppTheme.primaryColor,
      ActivityRequestStatus.changesRequested => AppTheme.changesOrange,
      ActivityRequestStatus.denied ||
      ActivityRequestStatus.blockedByPrerequisites =>
        AppTheme.deniedRed,
    };

    final waitingOnParents = householdParents
        .where(
          (p) =>
              request.parentDecisions[p.id]?.status !=
              ParentDecisionStatus.approved,
        )
        .map((p) => p.displayName)
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    request.overallStatus ==
                                ActivityRequestStatus.awaitingSecondParent &&
                            waitingOnParents.isNotEmpty
                        ? 'Pending — 1 Parent Hasn\'t Approved Yet (Waiting on ${waitingOnParents.join(", ")})'
                        : request.overallStatus.badgeLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
                Text(
                  request.approvalRule.shortLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              request.activityDestination,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${AppFormatters.formatTimeWindow(request.startTime, request.endTime)}\nHost: ${request.hostParentName} (${request.hostParentContact}) • Ride: ${request.transportation}',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF475569),
                height: 1.4,
              ),
            ),

            // Feature 4.2.3: Denial / Changes Requested Banner + Resubmit
            if (request.overallStatus ==
                    ActivityRequestStatus.changesRequested ||
                request.overallStatus == ActivityRequestStatus.denied) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.latestParentFeedback ??
                          'Parent requested updates before approving.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      onPressed: onEditAndResubmit,
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text('Update Details & Resubmit'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChildChoreCard extends StatelessWidget {
  const _ChildChoreCard({
    required this.chore,
    required this.onAskForSignOff,
  });

  final ChoreTask chore;
  final VoidCallback onAskForSignOff;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (chore.status) {
      ChoreStatus.approved => AppTheme.approvedGreen,
      ChoreStatus.pendingSignOff => AppTheme.prerequisiteGold,
      ChoreStatus.changesRequested => AppTheme.changesOrange,
      ChoreStatus.todo => const Color(0xFF64748B),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (chore.isPrerequisite)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.prerequisiteGold.withValues(
                            alpha: 0.15,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'PREREQUISITE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.prerequisiteGold,
                          ),
                        ),
                      ),
                    Text(
                      chore.repetition.label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    chore.status.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              chore.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                decoration: chore.status == ChoreStatus.approved
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              chore.description,
              style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),

            if (chore.parentFeedback != null &&
                chore.status == ChoreStatus.changesRequested) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.changesOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Parent Note: "${chore.parentFeedback}"',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.changesOrange,
                  ),
                ),
              ),
            ],

            if (chore.aiVerificationFeedback != null) ...[
              const SizedBox(height: 8),
              Text(
                chore.aiVerificationFeedback!,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF1E3A8A),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],

            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Wrap(
                  spacing: 6,
                  children: [
                    if (chore.requiresPhotoProof)
                      const Chip(
                        visualDensity: VisualDensity.compact,
                        avatar: Icon(Icons.camera_alt_outlined, size: 15),
                        label: Text(
                          'Photo Proof',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    if (chore.aiSignOffEnabled)
                      const Chip(
                        visualDensity: VisualDensity.compact,
                        avatar: Icon(Icons.auto_awesome_rounded, size: 15),
                        label: Text(
                          'Gemini AI Sign-Off',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                  ],
                ),
                if (chore.status == ChoreStatus.todo ||
                    chore.status == ChoreStatus.changesRequested)
                  FilledButton.icon(
                    onPressed: onAskForSignOff,
                    icon: const Icon(Icons.check_circle_outline, size: 17),
                    label: Text(
                      chore.status == ChoreStatus.changesRequested
                          ? 'Submit Redo for Sign-Off'
                          : 'Ask for Sign-Off',
                    ),
                  )
                else if (chore.status == ChoreStatus.pendingSignOff)
                  OutlinedButton.icon(
                    onPressed: onAskForSignOff,
                    icon: const Icon(Icons.hourglass_top_rounded, size: 16),
                    label: const Text('Update Photo Proof'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

