import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../domain/chore_task.dart';

/// Repository contract for the Core Chore and Task Engine (Feature 2).
abstract class ChoreRepository {
  Stream<List<ChoreTask>> watchHouseholdChores(String householdId);
  List<ChoreTask> getHouseholdChoresSnapshot(String householdId);

  Future<ChoreTask> createChore(ChoreTask chore);
  Future<ChoreTask> updateChore(ChoreTask chore);
  Future<void> deleteChore(String choreId);
}

/// Seeded reactive in-memory chore repository with Prerequisite & Standard chores.
class MockChoreRepository implements ChoreRepository {
  MockChoreRepository() {
    final now = DateTime.now();
    _chores = [
      ChoreTask(
        id: 'chore-1',
        householdId: 'household-1',
        assignedChildId: 'child-1',
        createdByParentId: 'parent-1',
        title: 'Clean bedroom floor & make bed',
        description:
            'Pick up clothes/shoes off the floor, pull sheets tight, and arrange pillows.',
        repetition: ChoreRepetition.daily,
        dueDate: DateTime(now.year, now.month, now.day, 17, 0),
        isPrerequisite: true,
        requiresPhotoProof: true,
        aiSignOffEnabled: true,
        status: ChoreStatus.pendingSignOff,
        proofPhotoUrl: 'sample://clean_bedroom_verified.jpg',
        aiVerificationConfidence: 0.94,
        aiVerificationFeedback:
            'Gemini Flash Vision (94% confidence): Bed is neatly made and bedroom floor is clear of clothes.',
      ),
      ChoreTask(
        id: 'chore-2',
        householdId: 'household-1',
        assignedChildId: 'child-1',
        createdByParentId: 'parent-2',
        title: 'Unload dishwasher & wipe counters',
        description:
            'Put away all clean plates, glasses, and silverware before asking to go out.',
        repetition: ChoreRepetition.daily,
        dueDate: DateTime(now.year, now.month, now.day, 16, 30),
        isPrerequisite: true,
        requiresPhotoProof: true,
        aiSignOffEnabled: true,
        status: ChoreStatus.todo,
      ),
      ChoreTask(
        id: 'chore-3',
        householdId: 'household-1',
        assignedChildId: 'child-1',
        createdByParentId: 'parent-1',
        title: 'Finish Math & Science homework',
        description: 'Complete module worksheet and pack backpack for tomorrow.',
        repetition: ChoreRepetition.weekdays,
        dueDate: DateTime(now.year, now.month, now.day, 18, 0),
        isPrerequisite: true,
        requiresPhotoProof: false,
        aiSignOffEnabled: false,
        status: ChoreStatus.approved,
        parentReviewerId: 'parent-1',
        parentFeedback: 'Checked worksheet — great job!',
      ),
      ChoreTask(
        id: 'chore-4',
        householdId: 'household-1',
        assignedChildId: 'child-1',
        createdByParentId: 'parent-1',
        title: 'Take recycling bin to curb',
        description: 'Roll blue recycling bin out to the driveway.',
        repetition: ChoreRepetition.weekly,
        dueDate: DateTime(now.year, now.month, now.day, 19, 0),
        isPrerequisite: false,
        requiresPhotoProof: false,
        aiSignOffEnabled: false,
        status: ChoreStatus.todo,
      ),
      ChoreTask(
        id: 'chore-5',
        householdId: 'household-1',
        assignedChildId: 'child-2',
        createdByParentId: 'parent-2',
        title: 'Feed dog & refill water bowl',
        description: '1 scoop of dry food and fresh water in the kitchen bowl.',
        repetition: ChoreRepetition.daily,
        dueDate: DateTime(now.year, now.month, now.day, 17, 0),
        isPrerequisite: true,
        requiresPhotoProof: true,
        aiSignOffEnabled: true,
        status: ChoreStatus.approved,
        proofPhotoUrl: 'sample://dog_bowl_filled.jpg',
        aiVerificationConfidence: 0.96,
        aiVerificationFeedback:
            'Gemini Flash Vision (96% confidence): Food and water bowls are full and clean.',
      ),
    ];
  }

  final _uuid = const Uuid();
  late List<ChoreTask> _chores;
  final _controller = StreamController<List<ChoreTask>>.broadcast();

  void _emit() {
    _controller.add(List<ChoreTask>.unmodifiable(_chores));
  }

  @override
  List<ChoreTask> getHouseholdChoresSnapshot(String householdId) {
    return _chores
        .where((c) => c.householdId == householdId)
        .toList(growable: false);
  }

  @override
  Stream<List<ChoreTask>> watchHouseholdChores(String householdId) {
    return Stream<List<ChoreTask>>.multi((controller) {
      controller.add(getHouseholdChoresSnapshot(householdId));
      final sub = _controller.stream
          .map(
            (list) => list
                .where((c) => c.householdId == householdId)
                .toList(growable: false),
          )
          .listen(controller.add, onError: controller.addError);
      controller.onCancel = sub.cancel;
    });
  }

  @override
  Future<ChoreTask> createChore(ChoreTask chore) async {
    final created = chore.id.trim().isEmpty
        ? chore.copyWith(id: 'chore-${_uuid.v4().substring(0, 8)}')
        : chore;
    _chores = [created, ..._chores];
    _emit();
    return created;
  }

  @override
  Future<ChoreTask> updateChore(ChoreTask chore) async {
    final index = _chores.indexWhere((c) => c.id == chore.id);
    if (index == -1) {
      throw StateError('Chore ${chore.id} not found');
    }
    final next = [..._chores];
    next[index] = chore;
    _chores = next;
    _emit();
    return chore;
  }

  @override
  Future<void> deleteChore(String choreId) async {
    _chores = _chores.where((c) => c.id != choreId).toList(growable: false);
    _emit();
  }
}

/// Live Supabase implementation of [ChoreRepository].
class SupabaseChoreRepository implements ChoreRepository {
  SupabaseChoreRepository(this._client);

  final SupabaseClient _client;
  final Map<String, List<ChoreTask>> _cache = {};

  @override
  List<ChoreTask> getHouseholdChoresSnapshot(String householdId) =>
      _cache[householdId] ?? const [];

  @override
  Stream<List<ChoreTask>> watchHouseholdChores(String householdId) {
    return _client
        .from('chores')
        .stream(primaryKey: ['id'])
        .eq('household_id', householdId)
        .map((rows) {
          final chores = rows.map(ChoreTask.fromJson).toList(growable: false);
          _cache[householdId] = chores;
          return chores;
        });
  }

  @override
  Future<ChoreTask> createChore(ChoreTask chore) async {
    final row = await _client
        .from('chores')
        .insert(chore.toJson())
        .select()
        .single();
    return ChoreTask.fromJson(row);
  }

  @override
  Future<ChoreTask> updateChore(ChoreTask chore) async {
    final row = await _client
        .from('chores')
        .update(chore.toJson())
        .eq('id', chore.id)
        .select()
        .single();
    return ChoreTask.fromJson(row);
  }

  @override
  Future<void> deleteChore(String choreId) async {
    await _client.from('chores').delete().eq('id', choreId);
  }
}
