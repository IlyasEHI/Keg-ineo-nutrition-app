import '../models/recipe.dart';

class SearchService {
  static List<Recipe> filterRecipes({
    required List<Recipe> recipes,
    String? query,
    double? maxCalories,
    double? minProteins,
  }) {
    return recipes.where((recipe) {
      // Search by title/ingredients
      if (query != null && query.isNotEmpty) {
        final searchLower = query.toLowerCase();
        final matchesTitle = recipe.title.toLowerCase().contains(searchLower);
        final matchesIngredients = recipe.ingredients.any(
          (ingredient) => ingredient.toLowerCase().contains(searchLower),
        );
        if (!matchesTitle && !matchesIngredients) return false;
      }
      
      // Filter by macros (mock values - replace with real nutritional data)
      if (maxCalories != null) {
        // if (recipe.calories > maxCalories) return false;
      }
      if (minProteins != null) {
        // if (recipe.proteins < minProteins) return false;
      }
      
      return true;
    }).toList();
  }
}