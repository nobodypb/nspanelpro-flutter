import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Private persistence owned by this extension, never by HA settings or cards.
class DoorBirdProfiles {
  static const key = 'intercom_profiles'; // keep the deployed storage contract
  static Future<Map<String, dynamic>> read(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      final profile = decoded is Map ? decoded[name] : null;
      return profile is Map ? Map<String, dynamic>.from(profile) : {};
    } catch (_) {
      return {}; // invalid private data is reported by the media controller
    }
  }

  static Future<void> provision(Map<String, dynamic> input) async {
    if (!input.containsKey(key)) return;
    final prefs = await SharedPreferences.getInstance();
    final profiles = input[key];
    if (profiles is Map) {
      await prefs.setString(key, jsonEncode(profiles));
    } else {
      await prefs.remove(key);
    }
  }

  static Future<void> clear() async {
    await (await SharedPreferences.getInstance()).remove(key);
  }
}
