import 'package:flutter/material.dart';

import '../data/session_store.dart';
import '../data/task_database.dart';
import '../main.dart';

class SessionGate extends StatefulWidget {
  const SessionGate({
    super.key,
    required this.sessions,
    required this.database,
  });
  final SessionStore sessions;
  final TaskDatabase database;

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  bool _loading = true;
  String? _user;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await widget.sessions.restore();
      if (mounted) {
        setState(() {
          _user = user;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Không thể đọc phiên đăng nhập. Vui lòng thử lại.';
        });
      }
    }
  }

  Future<void> _login(String username, String password, bool register) async {
    if (register) await widget.sessions.register(username, password);
    await widget.sessions.login(username, password);
    if (mounted) setState(() => _user = username.trim().toLowerCase());
  }

  Future<void> _logout() async {
    await widget.sessions.logout();
    if (mounted) setState(() => _user = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!),
              ElevatedButton(onPressed: _restore, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
    }
    if (_user == null) return LoginScreen(onLogin: _login);
    return TodoListScreen(
      key: ValueKey(_user),
      username: _user!,
      database: widget.database,
      onLogout: _logout,
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onLogin});
  final Future<void> Function(String, String, bool) onLogin;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _register = false;
  bool _busy = false;
  bool _hidePassword = true;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onLogin(_username.text, _password.text, _register);
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không thể xử lý tài khoản. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_register ? 'TodoList • Đăng ký' : 'TodoList • Login'),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.task_alt, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              'Chào mừng bạn!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Đăng nhập để quản lý công việc của bạn.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: const Key('username'),
                    controller: _username,
                    enabled: !_busy,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Email / Username',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Vui lòng nhập email hoặc tên đăng nhập'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('password'),
                    controller: _password,
                    enabled: !_busy,
                    obscureText: _hidePassword,
                    enableSuggestions: false,
                    autocorrect: false,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: _hidePassword
                            ? 'Hiện mật khẩu'
                            : 'Ẩn mật khẩu',
                        onPressed: () =>
                            setState(() => _hidePassword = !_hidePassword),
                        icon: Icon(
                          _hidePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Vui lòng nhập mật khẩu';
                      }
                      if (_register && value.length < 8) {
                        return 'Mật khẩu phải có ít nhất 8 ký tự';
                      }
                      return null;
                    },
                  ),
                  if (_register) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('confirmPassword'),
                      controller: _confirmation,
                      enabled: !_busy,
                      obscureText: _hidePassword,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'Nhập lại mật khẩu',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value != _password.text
                          ? 'Mật khẩu nhập lại không khớp'
                          : null,
                    ),
                  ],
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(
                      _busy
                          ? 'Đang xử lý...'
                          : (_register ? 'Đăng ký' : 'Login'),
                    ),
                  ),
                  TextButton(
                    key: const Key('switchAuth'),
                    onPressed: _busy
                        ? null
                        : () {
                            setState(() {
                              _register = !_register;
                              _error = null;
                              _password.clear();
                              _confirmation.clear();
                              _formKey.currentState?.reset();
                            });
                          },
                    child: Text(
                      _register
                          ? 'Đã có tài khoản? Đăng nhập'
                          : 'Chưa có tài khoản? Đăng ký',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
