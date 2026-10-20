import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:todolist/data/task_database.dart';
import 'package:todolist/models/task.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  test('SQLite CRUD survives reopen and isolates usernames', () async {
    final dir = await Directory.systemTemp.createTemp('todo_test_');
    final path = p.join(dir.path, 'tasks.db');
    var store = TaskDatabase(factory: databaseFactoryFfi, path: path);
    try {
      final created = DateTime(2026, 10, 20, 9, 30);
      final saved = await store.insertTask(
        'alice',
        Task(
          title: 'Học Flutter',
          content: 'SQLite',
          date: created,
          type: TaskType.hard,
          createdAt: created,
        ),
      );
      expect(saved.id, isNotNull);
      await store.updateTask(
        'alice',
        saved.copyWith(title: 'Updated', isCompleted: true),
      );
      await store.close();
      store = TaskDatabase(factory: databaseFactoryFfi, path: path);
      final restored = (await store.readTasks('alice')).single;
      expect(restored.id, saved.id);
      expect(restored.title, 'Updated');
      expect(restored.isCompleted, isTrue);
      expect(restored.createdAt, created);
      expect(restored.content, 'SQLite');
      expect(restored.type, TaskType.hard);
      expect(restored.date, created);
      expect(await store.readTasks('bob'), isEmpty);
      await expectLater(store.deleteTask('bob', saved.id!), throwsStateError);
      await expectLater(store.updateTask('bob', restored), throwsStateError);
      await store.updateTask('alice', restored.copyWith(isCompleted: false));
      expect((await store.readTasks('alice')).single.isCompleted, isFalse);
      await store.deleteTask('alice', saved.id!);
      await store.close();
      store = TaskDatabase(factory: databaseFactoryFfi, path: path);
      expect(await store.readTasks('alice'), isEmpty);
    } finally {
      await store.close();
      await dir.delete(recursive: true);
    }
  });
}
