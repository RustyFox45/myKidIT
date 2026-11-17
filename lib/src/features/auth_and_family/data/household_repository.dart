import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/invite_code_generator.dart';
import '../domain/app_user.dart';
import '../domain/household.dart';

/// Result returned when pairing via a Child or Co-Parent invite code.
class PairingResult {
  const PairingResult({
    required this.household,
    required this.joinedAsRole,
  });

  final Household household;
  final AccountRole joinedAsRole;
}

/// Repository contract for Family Household setup, Parent-Child pairing,
/// Multi-Parent linking, and 1-vs-2 Parent approval rule settings.
abstract class HouseholdRepository {
  Stream<Household?> watchHousehold(String householdId);
  Household? getHouseholdById(String householdId);

  /// Creates a new household with unique Child & Co-Parent pairing codes.
  Future<Household> createHousehold({
    required String name,
    required String creatorParentId,
    ApprovalRule defaultApprovalRule = ApprovalRule.twoParents,
  });

  /// Pairs a user into a household using either a `childInviteCode` (Feature 1.2)
  /// or a `parentInviteCode` (Feature 1.3).
  Future<PairingResult> joinHouseholdByCode({
    required String inviteCode,
    required AppUser user,
  });

  /// Updates the household's default approval rule (1 Parent vs 2 Parents - Feature 3.3).
  Future<Household> updateApprovalRule({
    required String householdId,
    required ApprovalRule approvalRule,
  });

  /// Regenerates either the child invite code or co-parent invite code.
  Future<Household> regenerateInviteCode({
    required String householdId,
    required bool forParent,
  });

  /// Adds a managed child or co-parent directly to the household.
  Future<Household> addMemberToHousehold({
    required String householdId,
    required AppUser member,
  });
}

/// Reactive in-memory household repository pre-seeded with "The Lawson Household".
class MockHouseholdRepository implements HouseholdRepository {
  MockHouseholdRepository() {
    _households = {
      'household-1': const Household(
        id: 'household-1',
        name: 'The Lawson Family',
        childInviteCode: 'KID405',
        parentInviteCode: 'COP405',
        parentIds: ['parent-1', 'parent-2'],
        childIds: ['child-1', 'child-2'],
        defaultApprovalRule: ApprovalRule.twoParents,
      ),
    };
  }

  final _uuid = const Uuid();
  late Map<String, Household> _households;
  final _controller = StreamController<Map<String, Household>>.broadcast();

  void _emit() {
    _controller.add(Map<String, Household>.unmodifiable(_households));
  }

  @override
  Household? getHouseholdById(String householdId) => _households[householdId];

  @override
  Stream<Household?> watchHousehold(String householdId) {
    return Stream<Household?>.multi((controller) {
      controller.add(_households[householdId]);
      final sub = _controller.stream
          .map((map) => map[householdId])
          .listen(controller.add, onError: controller.addError);
      controller.onCancel = sub.cancel;
    });
  }

  @override
  Future<Household> createHousehold({
    required String name,
    required String creatorParentId,
    ApprovalRule defaultApprovalRule = ApprovalRule.twoParents,
  }) async {
    final id = 'household-${_uuid.v4().substring(0, 8)}';
    final household = Household(
      id: id,
      name: name.trim().isEmpty ? 'My Family Household' : name.trim(),
      childInviteCode: AppFormatters.generateInviteCode(),
      parentInviteCode: AppFormatters.generateInviteCode(),
      parentIds: [creatorParentId],
      childIds: const [],
      defaultApprovalRule: defaultApprovalRule,
    );
    _households = {..._households, id: household};
    _emit();
    return household;
  }

  @override
  Future<PairingResult> joinHouseholdByCode({
    required String inviteCode,
    required AppUser user,
  }) async {
    final normalized = inviteCode.trim().toUpperCase();
    for (final entry in _households.entries) {
      final household = entry.value;

      // Feature 1.2: Household Pairing (Parent to Child)
      if (household.childInviteCode.toUpperCase() == normalized) {
        if (user.role != AccountRole.child) {
          throw StateError(
            'Code "$normalized" is a Child Pairing Code. Switch to a Child account or use the Co-Parent Invite Code (${household.parentInviteCode}).',
          );
        }
        final updatedChildren = household.childIds.contains(user.id)
            ? household.childIds
            : [...household.childIds, user.id];
        final updated = household.copyWith(childIds: updatedChildren);
        _households = {..._households, household.id: updated};
        _emit();
        return PairingResult(
          household: updated,
          joinedAsRole: AccountRole.child,
        );
      }

      // Feature 1.3: Multi-Parent Link (Parent to Parent)
      if (household.parentInviteCode.toUpperCase() == normalized) {
        if (user.role != AccountRole.parent) {
          throw StateError(
            'Code "$normalized" is a Co-Parent Invite Code. Only Parent accounts can link with this code.',
          );
        }
        final updatedParents = household.parentIds.contains(user.id)
            ? household.parentIds
            : [...household.parentIds, user.id];
        final updated = household.copyWith(parentIds: updatedParents);
        _households = {..._households, household.id: updated};
        _emit();
        return PairingResult(
          household: updated,
          joinedAsRole: AccountRole.parent,
        );
      }
    }

    throw StateError(
      'Invalid invite code "$normalized". Try KID405 (Child Pairing) or COP405 (Co-Parent Link).',
    );
  }

  @override
  Future<Household> updateApprovalRule({
    required String householdId,
    required ApprovalRule approvalRule,
  }) async {
    final existing = _households[householdId];
    if (existing == null) {
      throw StateError('Household not found');
    }
    final updated = existing.copyWith(defaultApprovalRule: approvalRule);
    _households = {..._households, householdId: updated};
    _emit();
    return updated;
  }

  @override
  Future<Household> regenerateInviteCode({
    required String householdId,
    required bool forParent,
  }) async {
    final existing = _households[householdId];
    if (existing == null) {
      throw StateError('Household not found');
    }
    final newCode = AppFormatters.generateInviteCode();
    final updated = forParent
        ? existing.copyWith(parentInviteCode: newCode)
        : existing.copyWith(childInviteCode: newCode);
    _households = {..._households, householdId: updated};
    _emit();
    return updated;
  }

  @override
  Future<Household> addMemberToHousehold({
    required String householdId,
    required AppUser member,
  }) async {
    final existing = _households[householdId];
    if (existing == null) {
      throw StateError('Household not found');
    }
    final updated = member.isParent
        ? existing.copyWith(
            parentIds: existing.parentIds.contains(member.id)
                ? existing.parentIds
                : [...existing.parentIds, member.id],
          )
        : existing.copyWith(
            childIds: existing.childIds.contains(member.id)
                ? existing.childIds
                : [...existing.childIds, member.id],
          );
    _households = {..._households, householdId: updated};
    _emit();
    return updated;
  }
}

/// Live Supabase implementation of [HouseholdRepository].
class SupabaseHouseholdRepository implements HouseholdRepository {
  SupabaseHouseholdRepository(this._client);

  final SupabaseClient _client;
  final Map<String, Household> _cache = {};

  @override
  Household? getHouseholdById(String householdId) => _cache[householdId];

  @override
  Stream<Household?> watchHousehold(String householdId) {
    return _client
        .from('households')
        .stream(primaryKey: ['id'])
        .eq('id', householdId)
        .map((rows) {
          if (rows.isEmpty) return null;
          final household = Household.fromJson(rows.first);
          _cache[householdId] = household;
          return household;
        });
  }

  @override
  Future<Household> createHousehold({
    required String name,
    required String creatorParentId,
    ApprovalRule defaultApprovalRule = ApprovalRule.twoParents,
  }) async {
    final payload = {
      'name': name.trim(),
      'child_invite_code': AppFormatters.generateInviteCode(),
      'parent_invite_code': AppFormatters.generateInviteCode(),
      'parent_ids': [creatorParentId],
      'child_ids': <String>[],
      'default_approval_rule': defaultApprovalRule.name,
    };
    final row =
        await _client.from('households').insert(payload).select().single();
    final household = Household.fromJson(row);
    _cache[household.id] = household;
    return household;
  }

  @override
  Future<PairingResult> joinHouseholdByCode({
    required String inviteCode,
    required AppUser user,
  }) async {
    final normalized = inviteCode.trim().toUpperCase();
    final childMatch = await _client
        .from('households')
        .select()
        .eq('child_invite_code', normalized)
        .maybeSingle();

    if (childMatch != null) {
      final household = Household.fromJson(childMatch);
      final updatedIds = {...household.childIds, user.id}.toList();
      final row = await _client
          .from('households')
          .update({'child_ids': updatedIds})
          .eq('id', household.id)
          .select()
          .single();
      final updated = Household.fromJson(row);
      _cache[updated.id] = updated;
      return PairingResult(household: updated, joinedAsRole: AccountRole.child);
    }

    final parentMatch = await _client
        .from('households')
        .select()
        .eq('parent_invite_code', normalized)
        .maybeSingle();

    if (parentMatch != null) {
      final household = Household.fromJson(parentMatch);
      final updatedIds = {...household.parentIds, user.id}.toList();
      final row = await _client
          .from('households')
          .update({'parent_ids': updatedIds})
          .eq('id', household.id)
          .select()
          .single();
      final updated = Household.fromJson(row);
      _cache[updated.id] = updated;
      return PairingResult(
        household: updated,
        joinedAsRole: AccountRole.parent,
      );
    }

    throw StateError('No household found matching invite code "$normalized".');
  }

  @override
  Future<Household> updateApprovalRule({
    required String householdId,
    required ApprovalRule approvalRule,
  }) async {
    final row = await _client
        .from('households')
        .update({'default_approval_rule': approvalRule.name})
        .eq('id', householdId)
        .select()
        .single();
    final updated = Household.fromJson(row);
    _cache[householdId] = updated;
    return updated;
  }

  @override
  Future<Household> regenerateInviteCode({
    required String householdId,
    required bool forParent,
  }) async {
    final newCode = AppFormatters.generateInviteCode();
    final column = forParent ? 'parent_invite_code' : 'child_invite_code';
    final row = await _client
        .from('households')
        .update({column: newCode})
        .eq('id', householdId)
        .select()
        .single();
    final updated = Household.fromJson(row);
    _cache[householdId] = updated;
    return updated;
  }

  @override
  Future<Household> addMemberToHousehold({
    required String householdId,
    required AppUser member,
  }) async {
    final existing = _cache[householdId];
    if (existing == null) {
      throw StateError('Household not loaded');
    }
    final column = member.isParent ? 'parent_ids' : 'child_ids';
    final updatedIds = member.isParent
        ? {...existing.parentIds, member.id}.toList()
        : {...existing.childIds, member.id}.toList();
    final row = await _client
        .from('households')
        .update({column: updatedIds})
        .eq('id', householdId)
        .select()
        .single();
    final updated = Household.fromJson(row);
    _cache[householdId] = updated;
    return updated;
  }
}
