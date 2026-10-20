import 'package:shared_preferences/shared_preferences.dart';

/// Local assignment login: only the username is saved, never the password.
class SessionStore {
  static const sessionKey = 'todo_session_user';
  Future<String?> restore() async {
    final user = (await SharedPreferences.getInstance()).getString(sessionKey);
    return user == null || user.trim().isEmpty ? null : user;
  }

  Future<void> login(String username) async {
    final saved = await (await SharedPreferences.getInstance()).setString(
      sessionKey,
      username.trim().toLowerCase(),
    );
    if (!saved) throw StateError('Cannot save session');
  }

  Future<void> logout() async {
    final removed = await (await SharedPreferences.getInstance()).remove(
      sessionKey,
    );
    if (!removed) throw StateError('Cannot clear session');
  }
}
