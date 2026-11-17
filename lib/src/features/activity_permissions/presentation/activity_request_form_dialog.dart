import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/invite_code_generator.dart';
import '../../auth_and_family/presentation/auth_family_providers.dart';
import '../domain/activity_request.dart';
import 'activity_request_providers.dart';

/// Feature 3.1 & 3.2: Activity Permission Request Form Dialog.
///
/// Includes:
/// 1. Activity / Destination
/// 2. Time Window (Start & End pickers)
/// 3. Host Parent / Contact
/// 4. Transportation
/// Plus real-time Automated Chore Audit gate check (`choreAuditProvider`).
class ActivityRequestFormDialog extends ConsumerStatefulWidget {
  const ActivityRequestFormDialog({
    required this.childId,
    this.existingRequest,
    super.key,
  });

  final String childId;
  final ActivityRequest? existingRequest;

  @override
  ConsumerState<ActivityRequestFormDialog> createState() =>
      _ActivityRequestFormDialogState();
}

class _ActivityRequestFormDialogState
    extends ConsumerState<ActivityRequestFormDialog> {
  late final TextEditingController _destinationController;
  late final TextEditingController _hostNameController;
  late final TextEditingController _hostContactController;
  late final TextEditingController _transportationController;
  late DateTime _startTime;
  late DateTime _endTime;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingRequest;
    final now = DateTime.now();
    _destinationController = TextEditingController(
      text: existing?.activityDestination ?? '',
    );
    _hostNameController = TextEditingController(
      text: existing?.hostParentName ?? '',
    );
    _hostContactController = TextEditingController(
      text: existing?.hostParentContact ?? '',
    );
    _transportationController = TextEditingController(
      text: existing?.transportation ?? '',
    );
    _startTime = existing?.startTime ??
        DateTime(now.year, now.month, now.day, now.hour + 1, 0);
    _endTime = existing?.endTime ??
        DateTime(now.year, now.month, now.day, now.hour + 3, 30);
  }

  @override
  void dispose() {
    _destinationController.dispose();
    _hostNameController.dispose();
    _hostContactController.dispose();
    _transportationController.dispose();
    super.dispose();
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = TimeOfDay.fromDateTime(isStart ? _startTime : _endTime);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() {
      final base = isStart ? _startTime : _endTime;
      final updated = DateTime(
        base.year,
        base.month,
        base.day,
        picked.hour,
        picked.minute,
      );
      if (isStart) {
        _startTime = updated;
        if (_endTime.isBefore(_startTime)) {
          _endTime = _startTime.add(const Duration(hours: 2));
        }
      } else {
        _endTime = updated;
      }
    });
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);
    if (_destinationController.text.trim().isEmpty ||
        _hostNameController.text.trim().isEmpty ||
        _hostContactController.text.trim().isEmpty ||
        _transportationController.text.trim().isEmpty) {
      setState(
        () => _errorMessage =
            'Please fill in all 4 mandatory activity permission fields.',
      );
      return;
    }

    try {
      await ref
          .read(activityRequestControllerProvider.notifier)
          .submitOrResubmitRequest(
            existingRequestId: widget.existingRequest?.id,
            childId: widget.childId,
            activityDestination: _destinationController.text,
            startTime: _startTime,
            endTime: _endTime,
            hostParentName: _hostNameController.text,
            hostParentContact: _hostContactController.text,
            transportation: _transportationController.text,
          );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll('Bad state: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final audit = ref.watch(choreAuditProvider(widget.childId));
    final household = ref.watch(currentHouseholdProvider).asData?.value;
    final isEditing = widget.existingRequest != null;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isEditing
                ? Icons.edit_calendar_rounded
                : Icons.send_time_extension_rounded,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isEditing
                  ? 'Update & Resubmit Activity Request'
                  : 'New Activity Permission Request',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Feature 3.2: Automated Chore Audit Banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: audit.passed
                      ? AppTheme.approvedGreen.withValues(alpha: 0.1)
                      : AppTheme.deniedRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: audit.passed
                        ? AppTheme.approvedGreen
                        : AppTheme.deniedRed,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          audit.passed
                              ? Icons.verified_rounded
                              : Icons.lock_clock_rounded,
                          color: audit.passed
                              ? AppTheme.approvedGreen
                              : AppTheme.deniedRed,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            audit.passed
                                ? 'Automated Chore Audit Passed (${audit.completedPrerequisites}/${audit.totalPrerequisites} Prerequisites Approved)'
                                : 'Automated Chore Audit Gate: ${audit.incompletePrerequisiteChores.length} Prerequisite Chore(s) Unfinished',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: audit.passed
                                  ? AppTheme.approvedGreen
                                  : AppTheme.deniedRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!audit.passed) ...[
                      const SizedBox(height: 8),
                      for (final chore in audit.incompletePrerequisiteChores)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '• ${chore.title} (${chore.status.label})',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF7F1D1D),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (widget.existingRequest?.latestParentFeedback != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.changesOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.changesOrange),
                  ),
                  child: Text(
                    'Parent Feedback: ${widget.existingRequest!.latestParentFeedback}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF9A3412),
                    ),
                  ),
                ),
              ],

              // 3.1.1 Activity / Destination
              TextField(
                controller: _destinationController,
                decoration: const InputDecoration(
                  labelText: '1. Activity / Destination',
                  hintText: 'e.g., Soccer practice or Hangout at Jake\'s house',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
              ),
              const SizedBox(height: 12),

              // 3.1.2 Time Window
              const Text(
                '2. Time Window',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppFormatters.formatTimeWindow(_startTime, _endTime),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _pickTime(isStart: true),
                          icon: const Icon(Icons.schedule_rounded, size: 16),
                          label: const Text('Start Time'),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: () => _pickTime(isStart: false),
                          icon: const Icon(Icons.update_rounded, size: 16),
                          label: const Text('End Time'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 3.1.3 Host Parent / Contact
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _hostNameController,
                      decoration: const InputDecoration(
                        labelText: '3a. Host Parent / Adult',
                        hintText: 'e.g., Mrs. Miller',
                        prefixIcon: Icon(Icons.person_pin_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _hostContactController,
                      decoration: const InputDecoration(
                        labelText: '3b. Host Phone / Contact',
                        hintText: '(801) 555-0188',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 3.1.4 Transportation
              TextField(
                controller: _transportationController,
                decoration: const InputDecoration(
                  labelText: '4. Transportation (There & Back)',
                  hintText: 'Who is driving there and who is picking up?',
                  prefixIcon: Icon(Icons.directions_car_outlined),
                ),
              ),
              const SizedBox(height: 12),

              if (household != null)
                Text(
                  'Household Rule: ${household.defaultApprovalRule.label}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: AppTheme.deniedRed,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: audit.passed ? _submit : null,
          icon: Icon(
            audit.passed ? Icons.send_rounded : Icons.lock_outline_rounded,
          ),
          label: Text(
            audit.passed
                ? (isEditing ? 'Resubmit Request' : 'Submit Activity Request')
                : 'Complete Prerequisites First',
          ),
        ),
      ],
    );
  }
}
