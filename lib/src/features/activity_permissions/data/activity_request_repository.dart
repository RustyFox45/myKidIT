import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../auth_and_family/domain/household.dart';
import '../domain/activity_request.dart';

/// Repository contract for the Activity Permission Workflow (Feature 3).
abstract class ActivityRequestRepository {
  Stream<List<ActivityRequest>> watchHouseholdRequests(String householdId);
  List<ActivityRequest> getHouseholdRequestsSnapshot(String householdId);

  Future<ActivityRequest> createRequest(ActivityRequest request);
  Future<ActivityRequest> updateRequest(ActivityRequest request);
}

/// Seeded reactive in-memory repository demonstrating:
/// 1) `awaitingSecondParent` ("1 of 2 parents approved — waiting on Sarah")
/// 2) `changesRequested` ("Please add Mrs. Miller's contact number")
/// 3) `approved` request
class MockActivityRequestRepository implements ActivityRequestRepository {
  MockActivityRequestRepository() {
    final now = DateTime.now();
    final tonightStart = DateTime(now.year, now.month, now.day, 18, 30);
    final tonightEnd = DateTime(now.year, now.month, now.day, 21, 0);
    final tomorrowStart =
        DateTime(now.year, now.month, now.day + 1, 15, 30);
    final tomorrowEnd = DateTime(now.year, now.month, now.day + 1, 18, 0);

    _requests = [
      ActivityRequest(
        id: 'req-1',
        householdId: 'household-1',
        childId: 'child-1',
        activityDestination: 'Basketball Open Gym at Riverside Rec Center',
        startTime: tonightStart,
        endTime: tonightEnd,
        hostParentName: 'Coach Marcus Vance',
        hostParentContact: '(801) 555-0194',
        transportation: 'Coach Vance driving there; Logan picking up at 9:00 PM',
        prerequisiteAuditPassed: true,
        incompletePrerequisiteChoreIds: const [],
        approvalRule: ApprovalRule.twoParents,
        parentDecisions: {
          'parent-1': ParentDecision(
            parentId: 'parent-1',
            parentName: 'Logan (Parent 1)',
            status: ParentDecisionStatus.approved,
            comment: 'Looks good to me once Sarah confirms pickup!',
            timestamp: now.subtract(const Duration(minutes: 12)),
          ),
        },
        overallStatus: ActivityRequestStatus.awaitingSecondParent,
      ),
      ActivityRequest(
        id: 'req-2',
        householdId: 'household-1',
        childId: 'child-1',
        activityDestination: 'Movie Night & Pizza at Jake\'s House',
        startTime: tomorrowStart,
        endTime: tomorrowEnd,
        hostParentName: 'Mrs. Miller',
        hostParentContact: 'Not sure yet',
        transportation: 'Riding bikes with Jake',
        prerequisiteAuditPassed: true,
        incompletePrerequisiteChoreIds: const [],
        approvalRule: ApprovalRule.twoParents,
        parentDecisions: {
          'parent-1': ParentDecision(
            parentId: 'parent-1',
            parentName: 'Logan (Parent 1)',
            status: ParentDecisionStatus.changesRequested,
            comment:
                'Please get Mrs. Miller\'s cell phone number and plan for a parent ride home before dark.',
            timestamp: now.subtract(const Duration(minutes: 35)),
          ),
        },
        overallStatus: ActivityRequestStatus.changesRequested,
      ),
      ActivityRequest(
        id: 'req-3',
        householdId: 'household-1',
        childId: 'child-2',
        activityDestination: 'Art Club Practice at Elementary Library',
        startTime: tomorrowStart,
        endTime: tomorrowEnd,
        hostParentName: 'Ms. Henderson',
        hostParentContact: '(801) 555-0142',
        transportation: 'Sarah dropping off and picking up',
        prerequisiteAuditPassed: true,
        incompletePrerequisiteChoreIds: const [],
        approvalRule: ApprovalRule.oneParent,
        parentDecisions: {
          'parent-2': ParentDecision(
            parentId: 'parent-2',
            parentName: 'Sarah (Parent 2)',
            status: ParentDecisionStatus.approved,
            comment: 'Approved! Have fun at Art Club.',
            timestamp: now.subtract(const Duration(hours: 1)),
          ),
        },
        overallStatus: ActivityRequestStatus.approved,
      ),
    ];
  }

  final _uuid = const Uuid();
  late List<ActivityRequest> _requests;
  final _controller = StreamController<List<ActivityRequest>>.broadcast();

  void _emit() {
    _controller.add(List<ActivityRequest>.unmodifiable(_requests));
  }

  @override
  List<ActivityRequest> getHouseholdRequestsSnapshot(String householdId) {
    return _requests
        .where((r) => r.householdId == householdId)
        .toList(growable: false);
  }

  @override
  Stream<List<ActivityRequest>> watchHouseholdRequests(String householdId) {
    return Stream<List<ActivityRequest>>.multi((controller) {
      controller.add(getHouseholdRequestsSnapshot(householdId));
      final sub = _controller.stream
          .map(
            (list) => list
                .where((r) => r.householdId == householdId)
                .toList(growable: false),
          )
          .listen(controller.add, onError: controller.addError);
      controller.onCancel = sub.cancel;
    });
  }

  @override
  Future<ActivityRequest> createRequest(ActivityRequest request) async {
    final created = request.id.trim().isEmpty
        ? request.copyWith(id: 'req-${_uuid.v4().substring(0, 8)}')
        : request;
    _requests = [created, ..._requests];
    _emit();
    return created;
  }

  @override
  Future<ActivityRequest> updateRequest(ActivityRequest request) async {
    final index = _requests.indexWhere((r) => r.id == request.id);
    if (index == -1) {
      throw StateError('ActivityRequest ${request.id} not found');
    }
    final next = [..._requests];
    next[index] = request;
    _requests = next;
    _emit();
    return request;
  }
}

/// Live Supabase implementation of [ActivityRequestRepository].
class SupabaseActivityRequestRepository implements ActivityRequestRepository {
  SupabaseActivityRequestRepository(this._client);

  final SupabaseClient _client;
  final Map<String, List<ActivityRequest>> _cache = {};

  @override
  List<ActivityRequest> getHouseholdRequestsSnapshot(String householdId) =>
      _cache[householdId] ?? const [];

  @override
  Stream<List<ActivityRequest>> watchHouseholdRequests(String householdId) {
    return _client
        .from('activity_requests')
        .stream(primaryKey: ['id'])
        .eq('household_id', householdId)
        .map((rows) {
          final requests =
              rows.map(ActivityRequest.fromJson).toList(growable: false);
          _cache[householdId] = requests;
          return requests;
        });
  }

  @override
  Future<ActivityRequest> createRequest(ActivityRequest request) async {
    final row = await _client
        .from('activity_requests')
        .insert(request.toJson())
        .select()
        .single();
    return ActivityRequest.fromJson(row);
  }

  @override
  Future<ActivityRequest> updateRequest(ActivityRequest request) async {
    final row = await _client
        .from('activity_requests')
        .update(request.toJson())
        .eq('id', request.id)
        .select()
        .single();
    return ActivityRequest.fromJson(row);
  }
}
