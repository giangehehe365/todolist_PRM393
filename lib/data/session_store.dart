import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'task_database.dart';

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
}

// Run password derivation away from the UI isolate.
Future<String> _derivePassword(Map<String, Object> input) async {
  final key =
      await Pbkdf2.hmacSha256(
        iterations: input['iterations'] as int,
        bits: 256,
      ).deriveKeyFromPassword(
        password: input['password'] as String,
        nonce: base64Decode(input['salt'] as String),
      );
  return base64Encode(await key.extractBytes());
}

class SessionStore {
  SessionStore({required this.database});
  final TaskDatabase database;
  // A new key deliberately invalidates sessions from the old simulated login.
  static const sessionKey = 'todo_session_token_v2';
  static const _iterations = 600000;

  String _random(int length) {
    final random = Random.secure();
    return base64UrlEncode(List.generate(length, (_) => random.nextInt(256)));
  }

  Future<String> _hash(String password, String salt, int iterations) => compute(
    _derivePassword,
    {'password': password, 'salt': salt, 'iterations': iterations},
  );

  Future<void> register(String username, String password) async {
    final user = username.trim().toLowerCase();
    if (user.isEmpty) throw const AuthException('Vui lòng nhập tên đăng nhập');
    if (password.length < 8 || password.trim().isEmpty) {
      throw const AuthException('Mật khẩu phải có ít nhất 8 ký tự');
    }
    final db = await database.database;
    final salt = _random(16);
    final hash = await _hash(password, salt, _iterations);
    // A unique primary key also handles simultaneous registration attempts.
    final created = await db.transaction((txn) async {
      await txn.rawInsert(
        'INSERT OR IGNORE INTO users(username, password_hash, salt, iterations) VALUES (?, ?, ?, ?)',
        [user, hash, salt, _iterations],
      );
      return (await txn.rawQuery('SELECT changes() AS count'))
              .single['count'] ==
          1;
    });
    if (!created) {
      throw const AuthException('Tên đăng nhập đã tồn tại');
    }
  }

  Future<String?> restore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('todo_session_user');
    final token = prefs.getString(sessionKey);
    if (token == null) return null;
    final rows = await (await database.database).rawQuery(
      'SELECT sessions.username FROM sessions INNER JOIN users ON users.username = sessions.username '
      'WHERE token = ? AND expires_at > ?',
      [token, DateTime.now().millisecondsSinceEpoch],
    );
    if (rows.isEmpty) {
      await prefs.remove(sessionKey);
      return null;
    }
    return rows.single['username'] as String;
  }

  Future<void> login(String username, String password) async {
    final user = username.trim().toLowerCase();
    final db = await database.database;
    final rows = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [user],
    );
    if (rows.isEmpty) {
      throw const AuthException('Tên đăng nhập hoặc mật khẩu không đúng');
    }
    final row = rows.single;
    final hash = await _hash(
      password,
      row['salt'] as String,
      row['iterations'] as int,
    );
    final expected = base64Decode(row['password_hash'] as String);
    final actual = base64Decode(hash);
    var difference = expected.length ^ actual.length;
    for (var i = 0; i < expected.length && i < actual.length; i++) {
      difference |= expected[i] ^ actual[i];
    }
    if (difference != 0) {
      throw const AuthException('Tên đăng nhập hoặc mật khẩu không đúng');
    }
    final prefs = await SharedPreferences.getInstance();
    final oldToken = prefs.getString(sessionKey);
    final token = _random(32);
    await db.insert('sessions', {
      'token': token,
      'username': user,
      'expires_at': DateTime.now()
          .add(const Duration(days: 30))
          .millisecondsSinceEpoch,
    });
    try {
      if (!await prefs.setString(sessionKey, token)) {
        throw StateError('Cannot save session');
      }
    } catch (_) {
      await db.delete('sessions', where: 'token = ?', whereArgs: [token]);
      rethrow;
    }
    if (oldToken != null) {
      await db.delete('sessions', where: 'token = ?', whereArgs: [oldToken]);
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(sessionKey);
    if (token != null) {
      await (await database.database).delete(
        'sessions',
        where: 'token = ?',
        whereArgs: [token],
      );
    }
    if (!await prefs.remove(sessionKey)) {
      throw StateError('Cannot clear session');
    }
  }
}
