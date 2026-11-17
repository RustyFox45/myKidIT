import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/role_persona_switcher_bar.dart';
import '../domain/app_user.dart';
import '../domain/household.dart';
import 'auth_family_providers.dart';

/// Feature 1: Role-Based Access and Family Setup Screen.
///
/// Covers:
/// 1.1 Account roles (`Parent` vs. `Child`)
/// 1.2 Household Pairing (Parent to Child via 6-character code, e.g., `KID405`)
/// 1.3 Multi-Parent Link (Parent to Parent via Co-Parent code, e.g., `COP405`)
class OnboardingAndRoleScreen extends ConsumerStatefulWidget {
  const OnboardingAndRoleScreen({super.key});

  @override
  ConsumerState<OnboardingAndRoleScreen> createState() =>
      _OnboardingAndRoleScreenState();
}

class _OnboardingAndRoleScreenState
    extends ConsumerState<OnboardingAndRoleScreen> {
  AccountRole _selectedRole = AccountRole.parent;
  bool _parentCreateNewHousehold = true;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _householdNameController =
      TextEditingController(text: 'The Lawson Family');
  final _inviteCodeController = TextEditingController();
  ApprovalRule _approvalRule = ApprovalRule.twoParents;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _householdNameController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleCompleteSetup() async {
    setState(() => _errorMessage = null);
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please enter your display name.');
      return;
    }

    try {
      final controller = ref.read(authFamilyControllerProvider.notifier);
      await controller.registerOrSignIn(
        displayName: name,
        role: _selectedRole,
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
      );

      if (_selectedRole == AccountRole.parent && _parentCreateNewHousehold) {
        await controller.createHousehold(
          householdName: _householdNameController.text.trim(),
          approvalRule: _approvalRule,
        );
      } else {
        final code = _inviteCodeController.text.trim();
        if (code.isEmpty) {
          setState(
            () => _errorMessage = _selectedRole == AccountRole.child
                ? 'Please enter your Parent\'s Child Pairing Code (try KID405).'
                : 'Please enter the Co-Parent Invite Code (try COP405).',
          );
          return;
        }
        await controller.pairWithInviteCode(code);
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll('Bad state: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).asData?.value;
    final isLoading = ref.watch(authFamilyControllerProvider).isLoading;

    if (user != null && _nameController.text.isEmpty) {
      _nameController.text = user.displayName;
      _selectedRole = user.role;
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const RolePersonaSwitcherBar(),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.verified_user_rounded,
                                    color: AppTheme.primaryColor,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'MyKidIT Family Setup',
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Automated Task-Gating & Activity Permissions',
                                        style: TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // 1.1 Account Role Selection
                            const Text(
                              '1. Select Account Role',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _RoleOptionCard(
                                    title: 'Parent Account',
                                    subtitle:
                                        'Assign chores, review photo proof, & approve activities',
                                    icon: Icons.admin_panel_settings_rounded,
                                    isSelected:
                                        _selectedRole == AccountRole.parent,
                                    onTap: () => setState(() {
                                      _selectedRole = AccountRole.parent;
                                      _errorMessage = null;
                                    }),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _RoleOptionCard(
                                    title: 'Child Account',
                                    subtitle:
                                        'Complete prerequisite chores & request activities',
                                    icon: Icons.emoji_people_rounded,
                                    isSelected:
                                        _selectedRole == AccountRole.child,
                                    onTap: () => setState(() {
                                      _selectedRole = AccountRole.child;
                                      _errorMessage = null;
                                    }),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            TextField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: _selectedRole == AccountRole.parent
                                    ? 'Parent Display Name (e.g., Logan)'
                                    : 'Child Display Name (e.g., Leo)',
                                prefixIcon: const Icon(Icons.person_outline),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'Email (Optional for Child Devices)',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                            ),
                            const SizedBox(height: 22),

                            // 1.2 & 1.3 Household Pairing / Multi-Parent Link
                            Text(
                              _selectedRole == AccountRole.parent
                                  ? '2. Household Setup or Co-Parent Link'
                                  : '2. Pair to Parent\'s Household',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 10),

                            if (_selectedRole == AccountRole.parent) ...[
                              SegmentedButton<bool>(
                                segments: const [
                                  ButtonSegment<bool>(
                                    value: true,
                                    icon: Icon(Icons.add_home_work_outlined),
                                    label: Text('Create New Household'),
                                  ),
                                  ButtonSegment<bool>(
                                    value: false,
                                    icon: Icon(Icons.group_add_outlined),
                                    label: Text('Link as Co-Parent (Code)'),
                                  ),
                                ],
                                selected: {_parentCreateNewHousehold},
                                onSelectionChanged: (selection) {
                                  setState(() {
                                    _parentCreateNewHousehold = selection.first;
                                    if (!_parentCreateNewHousehold &&
                                        _inviteCodeController.text.isEmpty) {
                                      _inviteCodeController.text = 'COP405';
                                    }
                                  });
                                },
                              ),
                              const SizedBox(height: 14),
                              if (_parentCreateNewHousehold) ...[
                                TextField(
                                  controller: _householdNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Household Name',
                                    prefixIcon: Icon(Icons.home_outlined),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<ApprovalRule>(
                                  initialValue: _approvalRule,
                                  decoration: const InputDecoration(
                                    labelText:
                                        'Default Activity Approval Rule (Feature 3.3)',
                                    prefixIcon: Icon(Icons.rule_rounded),
                                  ),
                                  items: ApprovalRule.values
                                      .map(
                                        (rule) => DropdownMenuItem(
                                          value: rule,
                                          child: Text(rule.label),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _approvalRule = val);
                                    }
                                  },
                                ),
                              ] else ...[
                                TextField(
                                  controller: _inviteCodeController,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  decoration: const InputDecoration(
                                    labelText: 'Co-Parent Invite Code',
                                    hintText:
                                        'Enter 6-character code (Demo: COP405)',
                                    prefixIcon: Icon(Icons.vpn_key_outlined),
                                  ),
                                ),
                              ],
                            ] else ...[
                              TextField(
                                controller: _inviteCodeController,
                                textCapitalization:
                                    TextCapitalization.characters,
                                decoration: InputDecoration(
                                  labelText: 'Child Household Pairing Code',
                                  hintText:
                                      'Enter code from Parent app (Demo: KID405)',
                                  prefixIcon: const Icon(Icons.qr_code_rounded),
                                  suffixIcon: TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _inviteCodeController.text = 'KID405';
                                      });
                                    },
                                    child: const Text('Use Demo KID405'),
                                  ),
                                ),
                              ),
                            ],

                            if (_errorMessage != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color:
                                      AppTheme.deniedRed.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppTheme.deniedRed),
                                ),
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: AppTheme.deniedRed,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed:
                                    isLoading ? null : _handleCompleteSetup,
                                icon: isLoading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.arrow_forward_rounded),
                                label: Text(
                                  _selectedRole == AccountRole.parent
                                      ? (_parentCreateNewHousehold
                                          ? 'Create Household & Enter Parent Dashboard'
                                          : 'Link Co-Parent Account')
                                      : 'Pair Child Device & Enter Child Dashboard',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleOptionCard extends StatelessWidget {
  const _RoleOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.08)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                isSelected ? AppTheme.primaryColor : const Color(0xFFCBD5E1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color:
                  isSelected ? AppTheme.primaryColor : const Color(0xFF64748B),
              size: 26,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: isSelected
                    ? AppTheme.primaryColor
                    : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

