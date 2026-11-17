import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/app_user.dart';
import '../domain/household.dart';
import 'auth_family_providers.dart';

/// Modal sheet for managing Feature 1.2 (Child Pairing Code),
/// Feature 1.3 (Multi-Parent Co-Parent Invite Code), and
/// Feature 3.3 (1-Parent vs 2-Parent Approval Rule Setting).
class FamilySetupSheet extends ConsumerStatefulWidget {
  const FamilySetupSheet({super.key});

  @override
  ConsumerState<FamilySetupSheet> createState() => _FamilySetupSheetState();
}

class _FamilySetupSheetState extends ConsumerState<FamilySetupSheet> {
  final _newMemberNameController = TextEditingController();
  AccountRole _newMemberRole = AccountRole.child;

  @override
  void dispose() {
    _newMemberNameController.dispose();
    super.dispose();
  }

  Future<void> _addMember() async {
    final name = _newMemberNameController.text.trim();
    if (name.isEmpty) return;
    await ref.read(authFamilyControllerProvider.notifier).addFamilyMemberDirect(
          displayName: name,
          role: _newMemberRole,
        );
    _newMemberNameController.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added $name (${_newMemberRole.label}) to household!'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final household = ref.watch(currentHouseholdProvider).asData?.value;
    final parents = ref.watch(householdParentsProvider);
    final children = ref.watch(householdChildrenProvider);

    if (household == null) {
      return const SizedBox.shrink();
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.family_restroom_rounded,
                  color: AppTheme.primaryColor,
                  size: 26,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${household.name} — Pairing & Approval Rules',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(height: 24),

            // Feature 1.2 & 1.3 Pairing Codes
            const Text(
              'Household Pairing & Multi-Parent Codes (Features 1.2 & 1.3)',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _InviteCodeCard(
                    title: 'Child Pairing Code',
                    subtitle: 'Pairs a child\'s device to this household',
                    code: household.childInviteCode,
                    color: AppTheme.secondaryColor,
                    onRegenerate: () => ref
                        .read(authFamilyControllerProvider.notifier)
                        .regenerateInviteCode(forParent: false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InviteCodeCard(
                    title: 'Co-Parent Link Code',
                    subtitle: 'Links a spouse or co-parent account',
                    code: household.parentInviteCode,
                    color: AppTheme.primaryColor,
                    onRegenerate: () => ref
                        .read(authFamilyControllerProvider.notifier)
                        .regenerateInviteCode(forParent: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // Feature 3.3 Approval Rule Setting (1 Parent vs 2 Parents)
            const Text(
              'Activity Permission Approval Rule (Feature 3.3)',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose whether child activity requests require 1 parent or both linked parents to approve.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 10),
            SegmentedButton<ApprovalRule>(
              segments: const [
                ButtonSegment(
                  value: ApprovalRule.oneParent,
                  icon: Icon(Icons.person_outline),
                  label: Text('1-Parent Approval'),
                ),
                ButtonSegment(
                  value: ApprovalRule.twoParents,
                  icon: Icon(Icons.people_alt_outlined),
                  label: Text('2-Parent Approval (Both)'),
                ),
              ],
              selected: {household.defaultApprovalRule},
              onSelectionChanged: (sel) {
                ref
                    .read(authFamilyControllerProvider.notifier)
                    .updateDefaultApprovalRule(sel.first);
              },
            ),
            const SizedBox(height: 22),

            // Linked Family Members
            Text(
              'Linked Parents (${parents.length}) & Children (${children.length})',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in parents)
                  Chip(
                    avatar: const Icon(
                      Icons.shield_rounded,
                      size: 16,
                      color: AppTheme.primaryColor,
                    ),
                    label: Text('${p.displayName} (Parent)'),
                  ),
                for (final c in children)
                  Chip(
                    avatar: const Icon(
                      Icons.face_retouching_natural,
                      size: 16,
                      color: AppTheme.secondaryColor,
                    ),
                    label: Text('${c.displayName} (Child)'),
                  ),
              ],
            ),
            const SizedBox(height: 18),

            // Quick Add Child or Co-Parent
            const Text(
              'Quick-Add Family Member to Household',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _newMemberNameController,
                    decoration: const InputDecoration(
                      labelText: 'Name (e.g., Chloe, Age 8)',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<AccountRole>(
                    initialValue: _newMemberRole,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: AccountRole.values
                        .map(
                          (r) => DropdownMenuItem(
                            value: r,
                            child: Text(r.label),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _newMemberRole = val);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _addMember,
                  child: const Text('Add'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteCodeCard extends StatelessWidget {
  const _InviteCodeCard({
    required this.title,
    required this.subtitle,
    required this.code,
    required this.color,
    required this.onRegenerate,
  });

  final String title;
  final String subtitle;
  final String code;
  final Color color;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  code,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Copy Code',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Copied code $code to clipboard')),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
              ),
              IconButton(
                tooltip: 'Regenerate Code',
                onPressed: onRegenerate,
                icon: const Icon(Icons.refresh_rounded, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

