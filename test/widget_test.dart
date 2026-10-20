import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todolist/data/session_store.dart';
import 'package:todolist/data/task_database.dart';
import 'package:todolist/main.dart';
import 'package:todolist/models/task.dart';

class MemoryTasks extends TaskDatabase {
  final Map<String, List<Task>> rows = {};
  int nextId = 1;
  bool failWrites = false;
  @override
  Future<List<Task>> readTasks(String owner) async =>
      List.of(rows[owner] ?? []);
  @override
  Future<Task> insertTask(String owner, Task task) async {
    if (failWrites) throw StateError('disk full');
    final saved = task.copyWith(id: nextId++);
    (rows[owner] ??= []).add(saved);
    return saved;
  }

  @override
  Future<void> updateTask(String owner, Task task) async {
    if (failWrites) throw StateError('disk full');
    final list = rows[owner]!;
    list[list.indexWhere((t) => t.id == task.id)] = task;
  }

  @override
  Future<void> deleteTask(String owner, int id) async {
    if (failWrites) throw StateError('disk full');
    rows[owner]!.removeWhere((t) => t.id == id);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('Login validation, restored session and logout', (tester) async {
    final database = MemoryTasks();
    final sessions = SessionStore();
    await tester.pumpWidget(TodoApp(database: database, sessions: sessions));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Login'));
    await tester.pump();
    expect(find.text('Vui lòng nhập email hoặc tên đăng nhập'), findsOneWidget);
    expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('username')), ' Alice ');
    await tester.enterText(find.byKey(const Key('password')), 'demo');
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();
    expect(find.text('TODOLIST'), findsOneWidget);
    expect(await SessionStore().restore(), 'alice');
    expect((await SharedPreferences.getInstance()).getKeys(), {
      SessionStore.sessionKey,
    });
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      TodoApp(database: database, sessions: SessionStore()),
    );
    await tester.pumpAndSettle();
    expect(find.text('TODOLIST'), findsOneWidget);
    await tester.tap(find.byTooltip('Logout'));
    await tester.pumpAndSettle();
    expect(find.text('Login'), findsOneWidget);
    expect(await SessionStore().restore(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      TodoApp(database: database, sessions: SessionStore()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Login'), findsOneWidget);
  });
  testWidgets('Task validation, CRUD, filters and failed write', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1236, 3300);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final database = MemoryTasks();
    final sessions = SessionStore();
    await sessions.login('alice');
    await tester.pumpWidget(TodoApp(database: database, sessions: sessions));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Task'));
    await tester.pump();
    expect(find.text('Title không được để trống'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Học Flutter');
    await tester.tap(find.text('Add Task'));
    await tester.pumpAndSettle();
    expect(find.text('Học Flutter'), findsOneWidget);
    await tester.tap(find.byTooltip('Mark as completed'));
    await tester.pumpAndSettle();
    expect(database.rows['alice']!.single.isCompleted, isTrue);
    expect(
      tester.widget<Text>(find.text('Học Flutter')).style!.decoration,
      TextDecoration.lineThrough,
    );
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Updated');
    await tester.tap(find.text('Update Task'));
    await tester.pumpAndSettle();
    expect(database.rows['alice']!.single.title, 'Updated');
    expect(database.rows['alice']!.single.isCompleted, isTrue);
    await tester.tap(find.text('All').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Incomplete').last);
    await tester.pumpAndSettle();
    expect(find.text('Updated'), findsNothing);
    await tester.tap(find.text('Incomplete').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('All').last);
    await tester.pumpAndSettle();
    database.failWrites = true;
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Updated'), findsOneWidget);
    expect(
      find.text('Không thể lưu thay đổi. Vui lòng thử lại.'),
      findsOneWidget,
    );
    database.failWrites = false;
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Updated'), findsNothing);
    expect(database.rows['alice'], isEmpty);
  });
}
