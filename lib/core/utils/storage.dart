import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class StorageService {
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _prefsAsync async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<void> setString(String key, String value) async {
    final prefs = await _prefsAsync;
    await prefs.setString(key, value);
  }

  Future<String?> getString(String key) async {
    final prefs = await _prefsAsync;
    return prefs.getString(key);
  }

  Future<void> setBool(String key, bool value) async {
    final prefs = await _prefsAsync;
    await prefs.setBool(key, value);
  }

  Future<bool?> getBool(String key) async {
    final prefs = await _prefsAsync;
    return prefs.getBool(key);
  }

  Future<void> setInt(String key, int value) async {
    final prefs = await _prefsAsync;
    await prefs.setInt(key, value);
  }

  Future<int?> getInt(String key) async {
    final prefs = await _prefsAsync;
    return prefs.getInt(key);
  }

  Future<void> setJson(String key, Map<String, dynamic> value) async {
    await setString(key, jsonEncode(value));
  }

  Future<Map<String, dynamic>?> getJson(String key) async {
    final str = await getString(key);
    if (str == null) return null;
    try {
      return jsonDecode(str) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  Future<void> remove(String key) async {
    final prefs = await _prefsAsync;
    await prefs.remove(key);
  }

  Future<void> clear() async {
    final prefs = await _prefsAsync;
    await prefs.clear();
  }

  Future<String?> getCookie() async {
    return getString(AppConstants.cookieKey);
  }

  Future<void> setCookie(String cookie) async {
    await setString(AppConstants.cookieKey, cookie);
  }

  Future<void> removeCookie() async {
    await remove(AppConstants.cookieKey);
  }

  Future<String?> getThemeMode() async {
    return getString(AppConstants.themeKey);
  }

  Future<void> setThemeMode(String mode) async {
    await setString(AppConstants.themeKey, mode);
  }
}

final storageProvider = Provider<StorageService>((ref) {
  return StorageService();
});
