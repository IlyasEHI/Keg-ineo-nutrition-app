import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import '../models/recipe.dart';
import '../models/weight_history.dart';

class ExportService {
  static Future<void> exportRecipesToCsv(List<Recipe> recipes) async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/recipes_export.csv';

    final csv = const ListToCsvConverter().convert(
      recipes.map((r) => r.toJson()).toList(),
    );

    final file = File(path);
    await file.writeAsString(csv);
    
    print('✅ Recipes exported to: $path');
  }

  static Future<void> exportWeightHistoryToCsv(List<WeightHistory> history) async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/weight_history_export.csv';

    final csv = const ListToCsvConverter().convert(
      history.map((w) => w.toMap()).toList(),
    );

    final file = File(path);
    await file.writeAsString(csv);
    
    print('✅ Weight history exported to: $path');
  }
}