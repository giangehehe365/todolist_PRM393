import 'package:flutter/material.dart';

import 'models/task.dart';
import 'data/task_database.dart';
import 'data/session_store.dart';
import 'screens/session_gate.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(TodoApp(database: TaskDatabase(), sessions: SessionStore()));
}

class TodoApp extends StatelessWidget {
  const TodoApp({super.key, required this.database, required this.sessions});
  final TaskDatabase database;
  final SessionStore sessions;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TodoList',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
      home: SessionGate(database: database, sessions: sessions),
    );
  }
}

enum StatusFilter {
  all('All'),
  completed('Completed'),
  incomplete('Incomplete');

  final String label;
  const StatusFilter(this.label);
}

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({
    super.key,
    required this.username,
    required this.database,
    required this.onLogout,
  });
  final String username;
  final TaskDatabase database;
  final Future<void> Function() onLogout;

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _dateController = TextEditingController();
  final _searchController = TextEditingController();

  final List<Task> _tasks = [];
  bool _loading = true;
  bool _busy = false;
  String? _loadError;
  DateTime _selectedDate = DateTime.now();
  TaskType _selectedType = TaskType.easy;

  Task? _editingTask; // != null when editing an existing task
  StatusFilter _statusFilter = StatusFilter.all;
  TaskType? _typeFilter; // null = All types
  bool _newestFirst = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _dateController.text = _formatDate(_selectedDate);
    _loadTasks();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _dateController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (!mounted) return;
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = _formatDate(picked);
      });
    }
  }

  void _clearForm() {
    _titleController.clear();
    _contentController.clear();
    _selectedType = TaskType.easy;
    _selectedDate = DateTime.now();
    _dateController.text = _formatDate(_selectedDate);
    _editingTask = null;
  }

  Future<void> _loadTasks() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final tasks = await widget.database.readTasks(widget.username);
      if (!mounted) return;
      setState(() {
        _tasks
          ..clear()
          ..addAll(tasks);
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _loadError = 'Không thể tải công việc. Vui lòng thử lại trên Android hoặc Windows.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Commit to SQLite before updating the visible state.
  Future<void> _save(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await operation();
    } catch (_) {
      if (mounted) _showMessage('Không thể lưu thay đổi. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    final editing = _editingTask;
    final task = Task(
      id: editing?.id,
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
      date: _selectedDate,
      type: _selectedType,
      isCompleted: editing?.isCompleted ?? false,
      createdAt: editing?.createdAt ?? DateTime.now(),
    );
    FocusScope.of(context).unfocus();
    await _save(() async {
      if (editing == null) {
        final saved = await widget.database.insertTask(widget.username, task);
        if (!mounted) return;
        setState(() => _tasks.add(saved));
      } else {
        await widget.database.updateTask(widget.username, task);
        if (!mounted) return;
        setState(
          () => _tasks[_tasks.indexWhere((t) => t.id == task.id)] = task,
        );
      }
      setState(() {
        _clearForm();
        // Make the saved item visible even when a filter was active.
        _statusFilter = StatusFilter.all;
        _typeFilter = null;
        _searchQuery = '';
        _searchController.clear();
      });
      _showMessage(
        editing == null
            ? 'Đã thêm task thành công'
            : 'Đã cập nhật task thành công',
      );
    });
  }

  Future<void> _toggleTask(Task task) => _save(() async {
    final updated = task.copyWith(isCompleted: !task.isCompleted);
    await widget.database.updateTask(widget.username, updated);
    if (!mounted) return;
    setState(() {
      _tasks[_tasks.indexWhere((t) => t.id == task.id)] = updated;
      if (_editingTask?.id == task.id) _editingTask = updated;
    });
  });

  Future<void> _deleteTask(Task task) => _save(() async {
    await widget.database.deleteTask(widget.username, task.id!);
    if (!mounted) return;
    setState(() {
      _tasks.removeWhere((t) => t.id == task.id);
      if (_editingTask?.id == task.id) _clearForm();
    });
    _showMessage('Đã xóa task "${task.title}"');
  });

  Future<void> _logout() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onLogout();
    } catch (_) {
      if (mounted) _showMessage('Không thể đăng xuất. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Load the task into the edit form.
  void _startEdit(Task task) {
    setState(() {
      _editingTask = task;
      _titleController.text = task.title;
      _contentController.text = task.content;
      _selectedType = task.type;
      _selectedDate = task.date;
      _dateController.text = _formatDate(task.date);
    });
  }

  List<Task> get _visibleTasks {
    final query = _searchQuery.trim().toLowerCase();
    final list = _tasks.where((t) {
      final statusOk = switch (_statusFilter) {
        StatusFilter.all => true,
        StatusFilter.completed => t.isCompleted,
        StatusFilter.incomplete => !t.isCompleted,
      };
      final typeOk = _typeFilter == null || t.type == _typeFilter;
      final searchOk =
          query.isEmpty ||
          t.title.toLowerCase().contains(query) ||
          t.content.toLowerCase().contains(query);
      return statusOk && typeOk && searchOk;
    }).toList();
    list.sort(
      (a, b) => _newestFirst
          ? b.createdAt.compareTo(a.createdAt)
          : a.createdAt.compareTo(b.createdAt),
    );
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = _tasks.where((t) => t.isCompleted).length;
    final visible = _visibleTasks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TODOLIST'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: _busy ? null : _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: _buildSearchBar(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_loadError!, textAlign: TextAlign.center),
                  ElevatedButton(
                    onPressed: _loadTasks,
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            )
          : AbsorbPointer(
              absorbing: _busy,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Xin chào, ${widget.username}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (_busy) const LinearProgressIndicator(),
                  _buildForm(),
                  const SizedBox(height: 16),
                  Text(
                    'Total: ${_tasks.length}  •  Completed: $completedCount  •  Incomplete: ${_tasks.length - completedCount}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  _buildFilterBar(),
                  const SizedBox(height: 8),
                  if (visible.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No tasks',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ...visible.map(_buildTaskItem),
                ],
              ),
            ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Tìm kiếm task...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                  }),
                ),
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Title:', style: TextStyle(fontSize: 16)),
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(hintText: 'Nhập tiêu đề'),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Title không được để trống'
                : null,
          ),
          const SizedBox(height: 8),
          const Text('Content:', style: TextStyle(fontSize: 16)),
          TextFormField(
            controller: _contentController,
            decoration: const InputDecoration(hintText: 'Nhập nội dung'),
          ),
          const SizedBox(height: 8),
          const Text('Date:', style: TextStyle(fontSize: 16)),
          TextFormField(
            controller: _dateController,
            readOnly: true,
            onTap: _pickDate,
            decoration: const InputDecoration(
              suffixIcon: Icon(Icons.calendar_today),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Type:', style: TextStyle(fontSize: 16)),
          DropdownButton<TaskType>(
            value: _selectedType,
            isExpanded: true,
            items: TaskType.values
                .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                .toList(),
            onChanged: (t) {
              if (t != null) setState(() => _selectedType = t);
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _busy ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Colors.black, width: 2),
              ),
            ),
            child: Text(_editingTask == null ? 'Add Task' : 'Update Task'),
          ),
          if (_editingTask != null)
            TextButton(
              onPressed: () => setState(_clearForm),
              child: const Text('Hủy sửa'),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Row(
      children: [
        // Status filter
        Expanded(
          child: DropdownButton<StatusFilter>(
            value: _statusFilter,
            isExpanded: true,
            items: StatusFilter.values
                .map((f) => DropdownMenuItem(value: f, child: Text(f.label)))
                .toList(),
            onChanged: (f) {
              if (f != null) setState(() => _statusFilter = f);
            },
          ),
        ),
        const SizedBox(width: 12),
        // Type filter (null = All)
        Expanded(
          child: DropdownButton<TaskType?>(
            value: _typeFilter,
            isExpanded: true,
            items: [
              const DropdownMenuItem<TaskType?>(
                value: null,
                child: Text('All types'),
              ),
              ...TaskType.values.map(
                (t) =>
                    DropdownMenuItem<TaskType?>(value: t, child: Text(t.label)),
              ),
            ],
            onChanged: (t) => setState(() => _typeFilter = t),
          ),
        ),
        IconButton(
          tooltip: _newestFirst ? 'Newest first' : 'Oldest first',
          icon: Icon(_newestFirst ? Icons.arrow_downward : Icons.arrow_upward),
          onPressed: () => setState(() => _newestFirst = !_newestFirst),
        ),
      ],
    );
  }

  Widget _buildTaskItem(Task task) {
    final done = task.isCompleted;
    return Card(
      color: const Color(0xFFE8F5C8),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        key: ValueKey(task.id),
        leading: IconButton(
          tooltip: done ? 'Mark as incomplete' : 'Mark as completed',
          icon: Icon(
            done ? Icons.check_box : Icons.check_box_outline_blank,
            color: done ? Colors.black : Colors.grey,
          ),
          onPressed: () => _toggleTask(task),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            fontStyle: FontStyle.italic,
            fontSize: 17,
            decoration: done ? TextDecoration.lineThrough : null,
            color: done ? Colors.grey : Colors.black,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.content.isNotEmpty) Text(task.content),
            Text(
              'Created: ${_formatDate(task.createdAt)} ${task.createdAt.hour.toString().padLeft(2, '0')}:${task.createdAt.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              'Type: ${task.type.label}',
              style: const TextStyle(fontSize: 12),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${task.date.day}/${task.date.month}/${task.date.year}',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
        // Edit and delete are available for every task.
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit),
              color: Colors.green,
              disabledColor: Colors.grey.shade400,
              onPressed: () => _startEdit(task),
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.cancel),
              color: Colors.red,
              disabledColor: Colors.grey.shade400,
              onPressed: () => _deleteTask(task),
            ),
          ],
        ),
      ),
    );
  }
}
