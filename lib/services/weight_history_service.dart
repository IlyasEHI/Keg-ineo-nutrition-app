import 'package:hive/hive.dart';
import '../models/weight_history.dart';

class WeightHistoryService {
  static const String _boxName = 'weight_history';

  static Future<void> saveWeight(double weight) async {
    final box = Hive.box<WeightHistory>(_boxName);
    await box.add(WeightHistory(weight: weight));
  }

  static List<WeightHistory> getHistory() {
    final box = Hive.box<WeightHistory>(_boxName);
    return box.values.toList();
  }

  static Future<void> clearHistory() async {
    final box = Hive.box<WeightHistory>(_boxName);
    await box.clear();
  }
}