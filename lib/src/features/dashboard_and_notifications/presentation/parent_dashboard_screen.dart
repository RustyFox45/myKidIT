import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/invite_code_generator.dart';
import '../../../core/widgets/role_persona_switcher_bar.dart';
import '../../activity_permissions/domain/activity_request.dart';
import '../../activity_permissions/presentation/activity_request_providers.dart';
import '../../auth_and_family/domain/app_user.dart';
import '../../auth_and_family/presentation/auth_family_providers.dart';
import '../../auth_and_family/presentation/family_setup_sheet.dart';
import '../../chores/domain/chore_task.dart';
import '../../chores/presentation/chore_providers.dart';
import '../../chores/presentation/create_chore_dialog.dart';

/// Feature 4.2: Real-Time Parent Status Dashboard.
class ParentDashboardScreen extends ConsumerStatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  ConsumerState<ParentDashboardScreen> createState() =>
      _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends ConsumerState<ParentDashboardScreen> {
  String? _selectedChildFilterId;

  Future<void> _promptParentDecision({
    required ActivityRequest request,
    required ParentDecisionStatus status,
  }) async {
    final commentController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${status.label}: ${request.activityDestination}'),
        content: TextField(
          controller: commentController,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: status == ParentDecisionStatus.approved
                ? 'Optional Note for Child / Co-Parent'
                : 'Reason / Changes Needed (Shown to Child)',
            hintText: status == ParentDecisionStatus.changesRequested
                ? 'e.g., Please add host parent phone number or return by 8:30 PM'
                : 'Add a quick note...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Confirm ${status.label}'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(activityRequestControllerProvider.notifier)
          .submitParentDecision(
            request: request,
            decisionStatus: status,
            comment: commentController.text,
          );
    }
    commentController.dispose();
  }

  Future<void> _promptChoreRedo(ChoreTask chore) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Request Redo: ${chore.title}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Feedback for Child',
            hintText: 'e.g., Please also put away the shoes under the desk',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Send Redo Request'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(choreControllerProvider.notifier).reviewChoreAsParent(
            chore: chore,
            approved: false,
            feedback: controller.text,
          );
    }
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).asData?.value;
    final household = ref.watch(currentHouseholdProvider).asData?.value;
    final parents = ref.watch(householdParentsProvider);
    final children = ref.watch(householdChildrenProvider);
    final allChores =
        ref.watch(householdChoresProvider).asData?.value ?? const [];
    final allRequests =
        ref.watch(householdActivityRequestsProvider).asData?.value ?? const [];

    final filteredChores = _selectedChildFilterId == null
        ? allChores
        : allChores
            .where((c) => c.assignedChildId == _selectedChildFilterId)
            .toList();

    final pendingSignOffChores = allChores
        .where((c) => c.status == ChoreStatus.pendingSignOff)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(
              Icons.shield_rounded,
              color: AppTheme.primaryColor,
              size: 24,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                '${household?.name ?? "MyKidIT"} • Parent Hub',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (household != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ActionChip(
                avatar: const Icon(Icons.vpn_key_rounded, size: 16),
                label: Text(
                  'Codes & ${household.defaultApprovalRule.shortLabel}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const FamilySetupSheet(),
                  );
                },
              ),
            ),
          const SizedBox(width: 6),
          const NotificationBellButton(),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog<void>(
            context: context,
            builder: (_) => const CreateChoreDialog(),
          );
        },
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('Assign Chore'),
      ),
      body: Column(
        children: [
          const RolePersonaSwitcherBar(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
              children: [
                // Top Summary Metrics Bar
                _ParentSummaryRow(
                  children: children,
                  pendingSignOffCount: pendingSignOffChores.length,
                  requests: allRequests,
                  onOpenFamilySheet: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const FamilySetupSheet(),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Section 1: Status of Activity Requests (Feature 4.2.1)
                const Row(
                  children: [
                    Icon(
                      Icons.event_available_rounded,
                      color: AppTheme.primaryColor,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Activity Permission Requests (1-Parent vs 2-Parent Sync)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (allRequests.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No activity permission requests yet.'),
                    ),
                  )
                else
                  for (final req in allRequests) ...[
                    _ParentActivityRequestCard(
                      request: req,
                      currentParent: currentUser,
                      householdParents: parents,
                      childUser: children
                          .where((c) => c.id == req.childId)
                          .firstOrNull,
                      onApprove: () => ref
                          .read(activityRequestControllerProvider.notifier)
                          .submitParentDecision(
                            request: req,
                            decisionStatus: ParentDecisionStatus.approved,
                            comment: 'Approved by ${currentUser?.displayName}',
                          ),
                      onRequestChanges: () => _promptParentDecision(
                        request: req,
                        status: ParentDecisionStatus.changesRequested,
                      ),
                      onDeny: () => _promptParentDecision(
                        request: req,
                        status: ParentDecisionStatus.denied,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                const SizedBox(height: 20),

                // Section 2: Chores & Prerequisite Sign-Offs (Feature 2 & 4.2.2)
                Row(
                  children: [
                    const Icon(
                      Icons.task_alt_rounded,
                      color: AppTheme.secondaryColor,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Chores, Prerequisite Flags, & Photo/AI Sign-Offs',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        showDialog<void>(
                          context: context,
                          builder: (_) => const CreateChoreDialog(),
                        );
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('New Chore'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Child Filter Chips + Prerequisite Audit Status per Child
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('All Children'),
                      selected: _selectedChildFilterId == null,
                      onSelected: (_) =>
                          setState(() => _selectedChildFilterId = null),
                    ),
                    for (final child in children)
                      FilterChip(
                        label: Consumer(
                          builder: (context, ref, _) {
                            final audit =
                                ref.watch(choreAuditProvider(child.id));
                            return Text(
                              '${child.displayName} (${audit.completedPrerequisites}/${audit.totalPrerequisites} Prereqs)',
                            );
                          },
                        ),
                        selected: _selectedChildFilterId == child.id,
                        onSelected: (_) =>
                            setState(() => _selectedChildFilterId = child.id),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                for (final chore in filteredChores) ...[
                  _ParentChoreCard(
                    chore: chore,
                    childName: children
                            .where((c) => c.id == chore.assignedChildId)
                            .map((c) => c.displayName)
                            .firstOrNull ??
                        'Child',
                    onApprove: () => ref
                        .read(choreControllerProvider.notifier)
                        .reviewChoreAsParent(
                          chore: chore,
                          approved: true,
                          feedback:
                              'Signed off by ${currentUser?.displayName ?? "Parent"}',
                        ),
                    onRequestRedo: () => _promptChoreRedo(chore),
                    onTogglePrerequisite: (val) => ref
                        .read(choreControllerProvider.notifier)
                        .togglePrerequisiteFlag(chore, val),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ParentSummaryRow extends ConsumerWidget {
  const _ParentSummaryRow({
    required this.children,
    required this.pendingSignOffCount,
    required this.requests,
    required this.onOpenFamilySheet,
  });

  final List<AppUser> children;
  final int pendingSignOffCount;
  final List<ActivityRequest> requests;
  final VoidCallback onOpenFamilySheet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final awaitingApprovalCount = requests
        .where(
          (r) =>
              r.overallStatus == ActivityRequestStatus.pending ||
              r.overallStatus == ActivityRequestStatus.awaitingSecondParent,
        )
        .length;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _StatTile(
          title: 'Chore Sign-Offs Waiting',
          value: '$pendingSignOffCount',
          subtitle: 'Photo & AI-verified requests',
          color: AppTheme.prerequisiteGold,
          icon: Icons.camera_alt_outlined,
        ),
        _StatTile(
          title: 'Activity Requests Pending',
          value: '$awaitingApprovalCount',
          subtitle: '1-of-2 or pending parent review',
          color: AppTheme.primaryColor,
          icon: Icons.pending_actions_rounded,
        ),
        for (final child in children)
          Builder(
            builder: (context) {
              final audit = ref.watch(choreAuditProvider(child.id));
              return _StatTile(
                title: '${child.displayName} Gate Status',
                value: audit.passed ? 'Unlocked' : 'Locked',
                subtitle:
                    '${audit.completedPrerequisites}/${audit.totalPrerequisites} prerequisite chores approved',
                color: audit.passed
                    ? AppTheme.approvedGreen
                    : AppTheme.deniedRed,
                icon: audit.passed
                    ? Icons.lock_open_rounded
                    : Icons.lock_outline_rounded,
              );
            },
          ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 245,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ParentActivityRequestCard extends StatelessWidget {
  const _ParentActivityRequestCard({
    required this.request,
    required this.currentParent,
    required this.householdParents,
    required this.childUser,
    required this.onApprove,
    required this.onRequestChanges,
    required this.onDeny,
  });

  final ActivityRequest request;
  final AppUser? currentParent;
  final List<AppUser> householdParents;
  final AppUser? childUser;
  final VoidCallback onApprove;
  final VoidCallback onRequestChanges;
  final VoidCallback onDeny;

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

    final myDecision = currentParent != null
        ? request.parentDecisions[currentParent!.id]
        : null;

    // Identify any parent who hasn't approved yet when rule == twoParents
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
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor:
                          AppTheme.secondaryColor.withValues(alpha: 0.14),
                      child: const Icon(
                        Icons.face_retouching_natural,
                        size: 18,
                        color: AppTheme.secondaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      childUser?.displayName ?? 'Child',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        request.approvalRule.shortLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    request.overallStatus ==
                                ActivityRequestStatus.awaitingSecondParent &&
                            waitingOnParents.isNotEmpty
                        ? '1 of 2 Approved • Waiting on ${waitingOnParents.join(", ")}'
                        : request.overallStatus.badgeLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              request.activityDestination,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                _DetailItem(
                  icon: Icons.schedule_rounded,
                  label: 'Time Window',
                  value: AppFormatters.formatTimeWindow(
                    request.startTime,
                    request.endTime,
                  ),
                ),
                _DetailItem(
                  icon: Icons.person_pin_rounded,
                  label: 'Host Parent / Contact',
                  value:
                      '${request.hostParentName} • ${request.hostParentContact}',
                ),
                _DetailItem(
                  icon: Icons.directions_car_rounded,
                  label: 'Transportation',
                  value: request.transportation,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Per-Parent Approval Breakdown
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final parent in householdParents)
                  Builder(
                    builder: (context) {
                      final decision = request.parentDecisions[parent.id];
                      final label = decision == null
                          ? '${parent.displayName}: Pending'
                          : '${parent.displayName}: ${decision.status.label}';
                      final chipColor = switch (decision?.status) {
                        ParentDecisionStatus.approved => AppTheme.approvedGreen,
                        ParentDecisionStatus.changesRequested =>
                          AppTheme.changesOrange,
                        ParentDecisionStatus.denied => AppTheme.deniedRed,
                        null => const Color(0xFF64748B),
                      };
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: chipColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: chipColor.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: chipColor,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),

            if (request.latestParentFeedback != null) ...[
              const SizedBox(height: 10),
              Text(
                'Note: ${request.latestParentFeedback}',
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF475569),
                ),
              ),
            ],

            const Divider(height: 24),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.approvedGreen,
                  ),
                  onPressed:
                      myDecision?.status == ParentDecisionStatus.approved
                          ? null
                          : onApprove,
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(
                    myDecision?.status == ParentDecisionStatus.approved
                        ? 'You Approved'
                        : 'Approve as ${currentParent?.displayName ?? "Parent"}',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onRequestChanges,
                  icon: const Icon(
                    Icons.edit_note_rounded,
                    color: AppTheme.changesOrange,
                  ),
                  label: const Text(
                    'Request Changes',
                    style: TextStyle(color: AppTheme.changesOrange),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onDeny,
                  icon: const Icon(
                    Icons.cancel_outlined,
                    color: AppTheme.deniedRed,
                  ),
                  label: const Text(
                    'Deny Request',
                    style: TextStyle(color: AppTheme.deniedRed),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            '$label: $value',
            style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
          ),
        ),
      ],
    );
  }
}

class _ParentChoreCard extends StatelessWidget {
  const _ParentChoreCard({
    required this.chore,
    required this.childName,
    required this.onApprove,
    required this.onRequestRedo,
    required this.onTogglePrerequisite,
  });

  final ChoreTask chore;
  final String childName;
  final VoidCallback onApprove;
  final VoidCallback onRequestRedo;
  final ValueChanged<bool> onTogglePrerequisite;

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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
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
                            alpha: 0.14,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lock_clock_rounded,
                              size: 13,
                              color: AppTheme.prerequisiteGold,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'PREREQUISITE GATE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.prerequisiteGold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Text(
                      '$childName • ${chore.repetition.label}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
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
                    borderRadius: BorderRadius.circular(16),
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
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              chore.description,
              style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),

            if (chore.proofPhotoUrl != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.approvedGreen.withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.photo_camera_back_rounded,
                          size: 18,
                          color: AppTheme.approvedGreen,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Photo Proof Attached: ${chore.proofPhotoUrl}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (chore.aiVerificationFeedback != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.auto_awesome_rounded,
                            size: 16,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              chore.aiVerificationFeedback!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF1E3A8A),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (chore.status != ChoreStatus.approved)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.approvedGreen,
                    ),
                    onPressed: onApprove,
                    icon: const Icon(Icons.verified_rounded, size: 17),
                    label: Text(
                      chore.status == ChoreStatus.pendingSignOff
                          ? 'Approve Sign-Off'
                          : 'Mark Approved',
                    ),
                  ),
                if (chore.status == ChoreStatus.pendingSignOff ||
                    chore.status == ChoreStatus.approved)
                  OutlinedButton.icon(
                    onPressed: onRequestRedo,
                    icon: const Icon(Icons.replay_rounded, size: 17),
                    label: const Text('Request Redo'),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: chore.isPrerequisite,
                      onChanged: (val) {
                        if (val != null) onTogglePrerequisite(val);
                      },
                    ),
                    const Text(
                      'Prerequisite for Activity',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

