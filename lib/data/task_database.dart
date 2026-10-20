import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' show databaseFactorySqflitePlugin;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/task.dart';

class TaskDatabase {
  TaskDatabase({this.factory, this.path});

  final DatabaseFactory? factory;
  final String? path;
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    if (kIsWeb) {
      throw UnsupportedError('SQLite hiện hỗ trợ Android và Windows.');
    }
    var factory = this.factory;
    if (factory == null) {
      if (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux) {
        sqfliteFfiInit();
        factory = databaseFactoryFfi;
      } else {
        factory = databaseFactorySqflitePlugin;
      }
    }
    final path =
        this.path ?? p.join(await factory.getDatabasesPath(), 'todo_v2.db');
    _db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''CREATE TABLE tasks (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          owner TEXT NOT NULL,
          title TEXT NOT NULL,
          content TEXT NOT NULL,
          due_date TEXT NOT NULL,
          type TEXT NOT NULL,
          is_completed INTEGER NOT NULL DEFAULT 0 CHECK(is_completed IN (0, 1)),
          created_at TEXT NOT NULL
        )''');
          await db.execute('CREATE INDEX tasks_owner ON tasks(owner)');
        },
      ),
    );
    return _db!;
  }

  Future<List<Task>> readTasks(String owner) async {
    final rows = await (await database).query(
      'tasks',
      where: 'owner = ?',
      whereArgs: [owner],
      orderBy: 'created_at DESC, id DESC',
    );
    return rows.map(Task.fromMap).toList();
  }

  Future<Task> insertTask(String owner, Task task) async {
    final id = await (await database).insert('tasks', {
      ...task.toMap(),
      'owner': owner,
    });
    return task.copyWith(id: id);
  }

  Future<void> updateTask(String owner, Task task) async {
    final count = await (await database).update(
      'tasks',
      task.toMap(),
      where: 'id = ? AND owner = ?',
      whereArgs: [task.id, owner],
    );
    if (count != 1) throw StateError('Task no longer exists');
  }

  Future<void> deleteTask(String owner, int id) async {
    final count = await (await database).delete(
      'tasks',
      where: 'id = ? AND owner = ?',
      whereArgs: [id, owner],
    );
    if (count != 1) throw StateError('Task no longer exists');
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
