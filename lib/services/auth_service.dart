import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local-only mock authentication. There is no backend: accounts are
/// registered and verified entirely on-device (SharedPreferences), salted
/// and hashed with SHA-256. This exists to drive the login/signup/guest UI
/// flow, not to secure anything — do not treat it as real auth.
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  static const _usersKey = 'auth_users_v1';
  static const _sessionEmailKey = 'auth_session_email';
  static const _sessionGuestKey = 'auth_session_guest';
  static const _sessionNameKey = 'auth_session_name';

  String? _currentEmail;
  String? _currentName;
  bool _isGuest = false;

  String? get currentEmail => _currentEmail;
  String? get currentName => _currentName;
  bool get isGuest => _isGuest;
  bool get isLoggedIn => _currentEmail != null || _isGuest;

  /// Restores the persisted session. Must be awaited before the first
  /// frame is built so the app can decide between the login screen and
  /// the dashboard.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentEmail = prefs.getString(_sessionEmailKey);
    _currentName = prefs.getString(_sessionNameKey);
    _isGuest = prefs.getBool(_sessionGuestKey) ?? false;
  }

  Future<Map<String, dynamic>> _loadUsers(SharedPreferences prefs) async {
    final raw = prefs.getString(_usersKey);
    if (raw == null) return {};
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> _saveUsers(SharedPreferences prefs, Map<String, dynamic> users) async {
    await prefs.setString(_usersKey, jsonEncode(users));
  }

  String _hashPassword(String password, String salt) {
    return sha256.convert(utf8.encode('$salt:$password')).toString();
  }

  String _generateSalt() {
    final rand = Random.secure();
    return base64Url.encode(List<int>.generate(16, (_) => rand.nextInt(256)));
  }

  /// Returns an error message on failure, or null on success.
  Future<String?> signUp({required String email, required String password, required String name}) async {
    final normalizedEmail = email.trim().toLowerCase();
    final prefs = await SharedPreferences.getInstance();
    final users = await _loadUsers(prefs);
    if (users.containsKey(normalizedEmail)) {
      return 'Bu e-posta adresi zaten kayıtlı.';
    }
    final salt = _generateSalt();
    users[normalizedEmail] = {
      'salt': salt,
      'hash': _hashPassword(password, salt),
      'name': name.trim(),
    };
    await _saveUsers(prefs, users);
    await _startSession(prefs, email: normalizedEmail, name: name.trim(), guest: false);
    return null;
  }

  /// Returns an error message on failure, or null on success.
  Future<String?> login({required String email, required String password}) async {
    final normalizedEmail = email.trim().toLowerCase();
    final prefs = await SharedPreferences.getInstance();
    final users = await _loadUsers(prefs);
    final record = users[normalizedEmail] as Map<String, dynamic>?;
    if (record == null) {
      return 'Bu e-posta ile kayıtlı bir hesap bulunamadı.';
    }
    final hash = _hashPassword(password, record['salt'] as String);
    if (hash != record['hash']) {
      return 'E-posta veya şifre hatalı.';
    }
    await _startSession(prefs, email: normalizedEmail, name: record['name'] as String?, guest: false);
    return null;
  }

  Future<void> continueAsGuest() async {
    final prefs = await SharedPreferences.getInstance();
    await _startSession(prefs, email: null, name: null, guest: true);
  }

  /// Returns an error message on failure, or null on success. Not available
  /// for guest sessions.
  Future<String?> changePassword({required String currentPassword, required String newPassword}) async {
    final email = _currentEmail;
    if (email == null) {
      return 'Misafir kullanıcılar şifre değiştiremez.';
    }
    final prefs = await SharedPreferences.getInstance();
    final users = await _loadUsers(prefs);
    final record = users[email] as Map<String, dynamic>?;
    if (record == null) {
      return 'Hesap bulunamadı.';
    }
    final currentHash = _hashPassword(currentPassword, record['salt'] as String);
    if (currentHash != record['hash']) {
      return 'Mevcut şifre hatalı.';
    }
    final salt = _generateSalt();
    users[email] = {
      ...record,
      'salt': salt,
      'hash': _hashPassword(newPassword, salt),
    };
    await _saveUsers(prefs, users);
    return null;
  }

  Future<void> _startSession(SharedPreferences prefs, {required String? email, required String? name, required bool guest}) async {
    _currentEmail = email;
    _currentName = name;
    _isGuest = guest;
    if (email != null) {
      await prefs.setString(_sessionEmailKey, email);
    } else {
      await prefs.remove(_sessionEmailKey);
    }
    if (name != null) {
      await prefs.setString(_sessionNameKey, name);
    } else {
      await prefs.remove(_sessionNameKey);
    }
    await prefs.setBool(_sessionGuestKey, guest);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    _currentEmail = null;
    _currentName = null;
    _isGuest = false;
    await prefs.remove(_sessionEmailKey);
    await prefs.remove(_sessionNameKey);
    await prefs.remove(_sessionGuestKey);
  }
}
