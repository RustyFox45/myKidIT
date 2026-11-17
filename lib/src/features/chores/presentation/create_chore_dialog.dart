import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth_and_family/presentation/auth_family_providers.dart';
import '../domain/chore_task.dart';
import 'chore_providers.dart';

/// Feature 2.1 & 2.4: Parent Task Creation Dialog.
class CreateChoreDialog extends ConsumerStatefulWidget {
  const CreateChoreDialog({super.key});

  @override
  ConsumerState<CreateChoreDialog> createState() => _CreateChoreDialogState();
}

class _CreateChoreDialogState extends ConsumerState<CreateChoreDialog> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String? _selectedChildId;
  ChoreRepetition _repetition = ChoreRepetition.daily;
  bool _isPrerequisite = true;
  bool _requiresPhotoProof = true;
  bool _aiSignOffEnabled = true;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || _selectedChildId == null) return;

    await ref.read(choreControllerProvider.notifier).createChore(
          assignedChildId: _selectedChildId!,
          title: title,
          description: _descController.text.trim().isEmpty
              ? 'Complete task thoroughly before requesting sign-off.'
              : _descController.text.trim(),
          repetition: _repetition,
          isPrerequisite: _isPrerequisite,
          requiresPhotoProof: _requiresPhotoProof,
          aiSignOffEnabled: _requiresPhotoProof && _aiSignOffEnabled,
          dueDate: DateTime.now().add(const Duration(hours: 4)),
        );

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final children = ref.watch(householdChildrenProvider);
    _selectedChildId ??= children.firstOrNull?.id;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.add_task_rounded, color: AppTheme.primaryColor),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Create New Chore / Task',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedChildId,
                decoration: const InputDecoration(
                  labelText: 'Assign to Child',
                  prefixIcon: Icon(Icons.face_retouching_natural),
                ),
                items: children
                    .map(
                      (c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.displayName),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _selectedChildId = val),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Chore Title',
                  hintText: 'e.g., Vacuum living room rug & put away shoes',
                  prefixIcon: Icon(Icons.checklist_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Instructions / Description (Used by AI Sign-Off)',
                  hintText: 'What does "done" look like?',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ChoreRepetition>(
                initialValue: _repetition,
                decoration: const InputDecoration(
                  labelText: 'Repetition Schedule',
                  prefixIcon: Icon(Icons.repeat_rounded),
                ),
                items: ChoreRepetition.values
                    .map(
                      (r) => DropdownMenuItem(
                        value: r,
                        child: Text(r.label),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _repetition = val);
                },
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.prerequisiteGold.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.prerequisiteGold.withValues(alpha: 0.4),
                  ),
                ),
                child: SwitchListTile(
                  value: _isPrerequisite,
                  activeThumbColor: AppTheme.prerequisiteGold,
                  title: const Text(
                    'Prerequisite Flag (Task-Gate)',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Child must complete & get sign-off on this chore before requesting any activity permissions.',
                    style: TextStyle(fontSize: 12),
                  ),
                  onChanged: (val) => setState(() => _isPrerequisite = val),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _requiresPhotoProof,
                title: const Text(
                  'Require Photo Proof',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: const Text(
                  'Child attaches a photo when asking for sign-off',
                  style: TextStyle(fontSize: 12),
                ),
                onChanged: (val) => setState(() {
                  _requiresPhotoProof = val;
                  if (!val) _aiSignOffEnabled = false;
                }),
              ),
              if (_requiresPhotoProof)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _aiSignOffEnabled,
                  title: const Text(
                    'Enable Gemini Vision AI Sign-Off',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'AI evaluates uploaded photo against chore instructions',
                    style: TextStyle(fontSize: 12),
                  ),
                  onChanged: (val) => setState(() => _aiSignOffEnabled = val),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.check_rounded),
          label: const Text('Assign Chore'),
        ),
      ],
    );
  }
}

