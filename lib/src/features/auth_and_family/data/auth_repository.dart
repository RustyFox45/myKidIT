import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../domain/app_user.dart';

/// Repository contract for authentication and role management (Feature 1.1).
abstract class AuthRepository {
  Stream<AppUser?> watchCurrentUser();
  AppUser? get currentUser;

  /// Lists all known users in the household or demo environment.
  Stream<List<AppUser>> watchAllUsers();
  List<AppUser> get allUsers;

  /// Creates or signs in a user with a chosen [AccountRole].
  Future<AppUser> registerOrSignIn({
    required String displayName,
    required AccountRole role,
    String? email,
    String? password,
  });

  /// Updates a user's linked `householdId`.
  Future<AppUser> updateUserHousehold({
    required String userId,
    required String? householdId,
  });

  /// Switches active persona (for instant multi-parent / child testing).
  Future<void> switchActiveUser(String userId);

  Future<void> signOut();
}

/// Seeded reactive repository for immediate local/demo testing and CS 405 demos.
class MockAuthRepository implements AuthRepository {
  MockAuthRepository() {
    _users = [
      const AppUser(
        id: 'parent-1',
        displayName: 'Logan (Parent 1)',
        email: 'logan@mykidit.app',
        role: AccountRole.parent,
        householdId: 'household-1',
      ),
      const AppUser(
        id: 'parent-2',
        displayName: 'Sarah (Parent 2)',
        email: 'sarah@mykidit.app',
        role: AccountRole.parent,
        householdId: 'household-1',
      ),
      const AppUser(
        id: 'child-1',
        displayName: 'Leo (Child, 13)',
        email: 'leo@mykidit.app',
        role: AccountRole.child,
        householdId: 'household-1',
      ),
      const AppUser(
        id: 'child-2',
        displayName: 'Maya (Child, 10)',
        email: 'maya@mykidit.app',
        role: AccountRole.child,
        householdId: 'household-1',
      ),
    ];
    _activeUserId = 'parent-1';
  }

  final _uuid = const Uuid();
  late List<AppUser> _users;
  String? _activeUserId;

  final _currentUserController = StreamController<AppUser?>.broadcast();
  final _allUsersController = StreamController<List<AppUser>>.broadcast();

  @override
  AppUser? get currentUser {
    if (_activeUserId == null) return null;
    for (final user in _users) {
      if (user.id == _activeUserId) return user;
    }
    return null;
  }

  @override
  List<AppUser> get allUsers => List<AppUser>.unmodifiable(_users);

  @override
  Stream<AppUser?> watchCurrentUser() {
    return Stream<AppUser?>.multi((controller) {
      controller.add(currentUser);
      final sub = _currentUserController.stream.listen(
        controller.add,
        onError: controller.addError,
      );
      controller.onCancel = sub.cancel;
    });
  }

  @override
  Stream<List<AppUser>> watchAllUsers() {
    return Stream<List<AppUser>>.multi((controller) {
      controller.add(allUsers);
      final sub = _allUsersController.stream.listen(
        controller.add,
        onError: controller.addError,
      );
      controller.onCancel = sub.cancel;
    });
  }

  void _emit() {
    _allUsersController.add(allUsers);
    _currentUserController.add(currentUser);
  }

  @override
  Future<AppUser> registerOrSignIn({
    required String displayName,
    required AccountRole role,
    String? email,
    String? password,
  }) async {
    final trimmedName = displayName.trim();
    final normalizedEmail = email?.trim().toLowerCase();

    final existingIndex = _users.indexWhere(
      (u) =>
          (normalizedEmail != null &&
              normalizedEmail.isNotEmpty &&
              u.email?.toLowerCase() == normalizedEmail) ||
          (u.displayName.toLowerCase() == trimmedName.toLowerCase() &&
              u.role == role),
    );

    if (existingIndex != -1) {
      _activeUserId = _users[existingIndex].id;
      _emit();
      return _users[existingIndex];
    }

    final newUser = AppUser(
      id: _uuid.v4(),
      displayName: trimmedName.isEmpty ? 'New ${role.label}' : trimmedName,
      email: normalizedEmail,
      role: role,
      householdId: null,
    );

    _users = [..._users, newUser];
    _activeUserId = newUser.id;
    _emit();
    return newUser;
  }

  @override
  Future<AppUser> updateUserHousehold({
    required String userId,
    required String? householdId,
  }) async {
    final index = _users.indexWhere((u) => u.id == userId);
    if (index == -1) {
      throw StateError('User $userId not found');
    }
    final updated = _users[index].copyWith(
      householdId: householdId,
      clearHouseholdId: householdId == null,
    );
    final next = [..._users];
    next[index] = updated;
    _users = next;
    _emit();
    return updated;
  }

  @override
  Future<void> switchActiveUser(String userId) async {
    _activeUserId = userId;
    _emit();
  }

  @override
  Future<void> signOut() async {
    _activeUserId = null;
    _emit();
  }
}

/// Live Supabase implementation of [AuthRepository].
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;
  AppUser? _cachedUser;
  List<AppUser> _cachedHouseholdUsers = const [];

  @override
  AppUser? get currentUser => _cachedUser;

  @override
  List<AppUser> get allUsers => _cachedHouseholdUsers;

  @override
  Stream<AppUser?> watchCurrentUser() {
    return _client.auth.onAuthStateChange.asyncMap((event) async {
      final sessionUser = event.session?.user;
      if (sessionUser == null) {
        _cachedUser = null;
        return null;
      }
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', sessionUser.id)
          .maybeSingle();
      if (data == null) return null;
      _cachedUser = AppUser.fromJson(data);
      return _cachedUser;
    });
  }

  @override
  Stream<List<AppUser>> watchAllUsers() {
    return _client.from('profiles').stream(primaryKey: ['id']).map((rows) {
      _cachedHouseholdUsers =
          rows.map(AppUser.fromJson).toList(growable: false);
      return _cachedHouseholdUsers;
    });
  }

  @override
  Future<AppUser> registerOrSignIn({
    required String displayName,
    required AccountRole role,
    String? email,
    String? password,
  }) async {
    final response = await _client.auth.signUp(
      email: email ?? '${DateTime.now().millisecondsSinceEpoch}@mykidit.app',
      password: password ?? 'MyKidIT-Demo-Pass-405!',
    );
    final userId = response.user!.id;
    final profileJson = {
      'id': userId,
      'email': email,
      'display_name': displayName,
      'role': role.name,
    };
    await _client.from('profiles').upsert(profileJson);
    final user = AppUser.fromJson(profileJson);
    _cachedUser = user;
    return user;
  }

  @override
  Future<AppUser> updateUserHousehold({
    required String userId,
    required String? householdId,
  }) async {
    final row = await _client
        .from('profiles')
        .update({'household_id': householdId})
        .eq('id', userId)
        .select()
        .single();
    final updated = AppUser.fromJson(row);
    if (_cachedUser?.id == userId) {
      _cachedUser = updated;
    }
    return updated;
  }

  @override
  Future<void> switchActiveUser(String userId) async {
    final row =
        await _client.from('profiles').select().eq('id', userId).maybeSingle();
    if (row != null) {
      _cachedUser = AppUser.fromJson(row);
    }
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
    _cachedUser = null;
  }
}
