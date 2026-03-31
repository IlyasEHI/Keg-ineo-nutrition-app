class Recipe {
 final String id;
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
 String? id,
 }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString() + title.hashCode.toString();

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
 )..id = json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString() + json['title'].hashCode.toString();
 }

 Map<String, dynamic> toJson() => {
 'id': id,
 'title': title,
 'ingredients': ingredients,
 'steps': steps,
 'preparationTime': preparationTime,
 'nutritionalInfo': nutritionalInfo,
 };
}
