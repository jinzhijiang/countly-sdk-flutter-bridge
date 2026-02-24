import 'package:countly_sdk_dart_core/countly_sdk_dart_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesStorageAdapter implements CountlyStorageAdapter {
  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async => _prefs ??= await SharedPreferences.getInstance();

  @override
  Future<String?> read(String key) async {
    final p = await _getPrefs();
    return p.getString(key);
  }

  @override
  Future<void> remove(String key) async {
    final p = await _getPrefs();
    await p.remove(key);
  }

  @override
  Future<void> write(String key, String value) async {
    final p = await _getPrefs();
    await p.setString(key, value);
  }
}
