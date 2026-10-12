import 'package:shared_preferences/shared_preferences.dart';

class CompanionSettings {
  static const key = 'companion_handoff_enabled';
  static Future<bool> enabled() async =>
      (await SharedPreferences.getInstance()).getBool(key) ?? false;
  static Future<void> provision(Map<String, dynamic> input) async {
    if (!input.containsKey(key)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, input[key] == true);
  }

  static Future<void> clear() async =>
      (await SharedPreferences.getInstance()).remove(key);
}
