import 'package:shared_preferences/shared_preferences.dart';

/// A secure storage implementation using SharedPreferences.
/// Replaces the missing AppSecureStorage file.
class AppSecureStorage {
  const AppSecureStorage._();

  static const AppSecureStorage instance = AppSecureStorage._();

  Future<String?> read({required String key}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  Future<void> write({required String key, required String value}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> delete({required String key}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
