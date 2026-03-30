import \'../models/recipe.dart\';
import \'package:shared_preferences/shared_preferences.dart\';
import \'dart:convert\';

class FavoritesStorage {
  static const String _keyPrefix = \'favorites_\';

  static Future<void> saveForProfile(String profileId, List<Recipe> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = favorites.map((r) => json.encode(r.toJson())).toList();
    await prefs.setStringList(\'$_keyPrefix$profileId\', jsonList);
  }

  static Future<List<Recipe>> loadForProfile(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(\'$_keyPrefix$profileId\') ?? [];
    return jsonList.map((jsonStr) => Recipe.fromJson(json.decode(jsonStr))).toList();
  }
}
