import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:todolist/data/session_store.dart';
import 'package:todolist/data/task_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  late TaskDatabase database;
  late SessionStore sessions;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('todo_auth_');
    database = TaskDatabase(
      factory: databaseFactoryFfi,
      path: p.join(directory.path, 'todo.db'),
    );
    sessions = SessionStore(database: database);
  });
  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test(
    'Accounts persist, reject wrong credentials and store salted hashes',
    () async {
      await expectLater(
        sessions.login('unknown', 'anything'),
        throwsA(isA<AuthException>()),
      );
      await expectLater(
        sessions.register('alice', 'short'),
        throwsA(isA<AuthException>()),
      );
      await sessions.register(' Alice ', 'Password123!');
      await sessions.register('bob', 'Password123!');
      await expectLater(
        sessions.register('ALICE', 'replacement123'),
        throwsA(isA<AuthException>()),
      );
      final rows = await (await database.database).query(
        'users',
        orderBy: 'username',
      );
      expect(rows.first['password_hash'], isNot('Password123!'));
      expect(rows.first['password_hash'], isNot(rows.last['password_hash']));
      expect(rows.first['salt'], isNot(rows.last['salt']));
      await expectLater(
        sessions.login('alice', 'wrong'),
        throwsA(isA<AuthException>()),
      );
      expect(await sessions.restore(), isNull);
      await sessions.login('ALICE', 'Password123!');
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(SessionStore.sessionKey)!;
      expect(token, isNot('alice'));
      await database.close();
      database = TaskDatabase(
        factory: databaseFactoryFfi,
        path: p.join(directory.path, 'todo.db'),
      );
      sessions = SessionStore(database: database);
      expect(await sessions.restore(), 'alice');
      await sessions.logout();
      expect(await sessions.restore(), isNull);
      // A copied token must no longer restore a logged-out session.
      await prefs.setString(SessionStore.sessionKey, token);
      expect(await sessions.restore(), isNull);
      await sessions.login('alice', 'Password123!');
      await (await database.database).update('sessions', {'expires_at': 0});
      expect(await sessions.restore(), isNull);
    },
  );

  test(
    'Old username-only sessions and forged tokens cannot bypass login',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('todo_session_user', 'alice');
      expect(await sessions.restore(), isNull);
      expect(prefs.getString('todo_session_user'), isNull);
      await prefs.setString(SessionStore.sessionKey, 'alice');
      expect(await sessions.restore(), isNull);
    },
  );

  test('Schema v1 upgrades without losing existing tasks', () async {
    final legacy = await databaseFactoryFfi.openDatabase(
      database.path!,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''CREATE TABLE tasks (
          id INTEGER PRIMARY KEY AUTOINCREMENT, owner TEXT NOT NULL,
          title TEXT NOT NULL, content TEXT NOT NULL, due_date TEXT NOT NULL,
          type TEXT NOT NULL, is_completed INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL)''');
          await db.insert('tasks', {
            'owner': 'alice',
            'title': 'Existing task',
            'content': '',
            'due_date': '2026-10-22',
            'type': 'easy',
            'created_at': '2026-10-22',
          });
        },
      ),
    );
    await legacy.close();
    final db = await database.database;
    expect((await db.query('tasks')).single['title'], 'Existing task');
    expect(await db.query('users'), isEmpty);
    expect(await db.query('sessions'), isEmpty);
  });
}
