class Recipe {
  final String title;
  final List<String> ingredients;
  final List<String> steps;
  final String? preparationTime;
  final String? nutritionalInfo;

  Recipe({
    required this.title,
    required this.ingredients,
    required this.steps,
    this.preparationTime,
    this.nutritionalInfo,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      title: json['title'],
      ingredients: List<String>.from(json['ingredients']),
      steps: List<String>.from(json['steps']),
      preparationTime: json['preparationTime'],
      nutritionalInfo: json['nutritionalInfo'],
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'ingredients': ingredients,
    'steps': steps,
    'preparationTime': preparationTime,
    'nutritionalInfo': nutritionalInfo,
  };
}
