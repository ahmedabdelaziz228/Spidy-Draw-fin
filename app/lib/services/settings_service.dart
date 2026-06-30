import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_constants.dart';

class SettingsService {
  const SettingsService();

  Future<String> loadEspUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.savedEspUrlKey) ??
        AppConstants.defaultEspUrl;
  }

  Future<void> saveEspUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.savedEspUrlKey, url);
  }
}
