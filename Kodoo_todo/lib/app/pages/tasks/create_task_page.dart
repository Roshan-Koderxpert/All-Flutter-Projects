import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:odoo_rpc/odoo_rpc.dart';

import '../../controllers/login_controller.dart';

class CreateTaskPage extends StatefulWidget {
  const CreateTaskPage({super.key});

  @override
  State<CreateTaskPage> createState() => _CreateTaskPageState();
}

class _CreateTaskPageState extends State<CreateTaskPage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final _isLoading = false.obs;
  final _isSubmitting = false.obs;

  final _assigneeOptions = <_SelectOption>[].obs;
  final _tagOptions = <_SelectOption>[].obs;

  final _selectedAssigneeIds = <int>[].obs;
  final _selectedTagIds = <int>[].obs;

  int _priorityStars = 0; // 0 = low, >0 = high

  AuthController get _auth => Get.find<AuthController>();

  @override
  void initState() {
    super.initState();
    _loadFormOptions();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadFormOptions() async {
    final client = _auth.odooClient;
    if (client == null) return;

    _isLoading.value = true;
    try {
      final usersResult = await client.callKw({
        'model': 'res.users',
        'method': 'search_read',
        'args': [
          [
            ['share', '=', false],
            ['active', '=', true],
          ],
          ['id', 'name'],
        ],
        'kwargs': {
          'order': 'name asc',
          'limit': 200,
        },
      });

      final tagsResult = await client.callKw({
        'model': 'project.tags',
        'method': 'search_read',
        'args': [
          [],
          ['id', 'name'],
        ],
        'kwargs': {
          'order': 'name asc',
          'limit': 300,
        },
      });

      _assigneeOptions.assignAll(_toOptions(usersResult));
      _tagOptions.assignAll(_toOptions(tagsResult));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load form data: $e')),
        );
      }
    } finally {
      _isLoading.value = false;
    }
  }

  List<_SelectOption> _toOptions(dynamic result) {
    final rows = (result is List) ? result : const [];
    return rows.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return _SelectOption(
        id: (m['id'] as num?)?.toInt() ?? 0,
        name: (m['name'] as String?) ?? '',
      );
    }).where((e) => e.id > 0 && e.name.isNotEmpty).toList();
  }

  Future<void> _openMultiSelect({
    required String title,
    required List<_SelectOption> options,
    required RxList<int> selectedIds,
  }) async {
    final temp = {...selectedIds};
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 380),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (_, i) {
                          final item = options[i];
                          final checked = temp.contains(item.id);
                          return CheckboxListTile(
                            dense: true,
                            value: checked,
                            onChanged: (v) {
                              setSheetState(() {
                                if (v == true) {
                                  temp.add(item.id);
                                } else {
                                  temp.remove(item.id);
                                }
                              });
                            },
                            title: Text(item.name),
                            controlAffinity: ListTileControlAffinity.leading,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              selectedIds.assignAll(temp.toList());
                              Navigator.pop(ctx);
                            },
                            child: const Text('Apply'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _selectedNames(List<_SelectOption> options, List<int> selected) {
    if (selected.isEmpty) return 'None selected';
    final names = options.where((o) => selected.contains(o.id)).map((o) => o.name).toList();
    if (names.isEmpty) return 'None selected';
    return names.join(', ');
  }

  Future<void> _createTask() async {
    if (!_formKey.currentState!.validate()) return;
    final client = _auth.odooClient;
    if (client == null) return;

    _isSubmitting.value = true;
    try {
      await client.callKw({
        'model': 'project.task',
        'method': 'create',
        'args': [
          {
            'name': _titleController.text.trim(),
            'description': _descriptionController.text.trim(),
            'project_id': false,
            'priority': _priorityStars > 0 ? '1' : '0',
            if (_selectedAssigneeIds.isNotEmpty) 'user_ids': [
              [6, 0, _selectedAssigneeIds.toList()]
            ],
            if (_selectedTagIds.isNotEmpty) 'tag_ids': [
              [6, 0, _selectedTagIds.toList()]
            ],
          }
        ],
        'kwargs': {},
      });

      if (mounted) Navigator.pop(context, true);
    } on OdooException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create task: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create task: $e')),
        );
      }
    } finally {
      _isSubmitting.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Create task'),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
      ),
      body: Obx(() {
        if (_isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        return Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            children: [
              TextFormField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Task title',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Task title is required' : null,
              ),
              const SizedBox(height: 12),
              Obx(() => _pickerTile(
                    title: 'Assignees',
                    value: _selectedNames(_assigneeOptions, _selectedAssigneeIds),
                    onTap: () => _openMultiSelect(
                      title: 'Select assignees',
                      options: _assigneeOptions,
                      selectedIds: _selectedAssigneeIds,
                    ),
                  )),
              const SizedBox(height: 12),
              Obx(() => _pickerTile(
                    title: 'Tags',
                    value: _selectedNames(_tagOptions, _selectedTagIds),
                    onTap: () => _openMultiSelect(
                      title: 'Select tags',
                      options: _tagOptions,
                      selectedIds: _selectedTagIds,
                    ),
                  )),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                minLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Task description',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Priority',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Row(
                children: List.generate(3, (i) {
                  final filled = i < _priorityStars;
                  return IconButton(
                    onPressed: () => setState(() => _priorityStars = i + 1),
                    icon: Icon(
                      filled ? Icons.star_rounded : Icons.star_border_rounded,
                      color: const Color(0xFFFFB300),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Discard'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Obx(() => FilledButton(
                          onPressed: _isSubmitting.value ? null : _createTask,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1E4A6B),
                          ),
                          child: Text(_isSubmitting.value ? 'Adding...' : 'Add task'),
                        )),
                  ),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _pickerTile({
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: title,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
        ),
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _SelectOption {
  final int id;
  final String name;

  _SelectOption({required this.id, required this.name});
}

