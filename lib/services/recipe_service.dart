// lib/services/recipe_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/ingredient_stock.dart';
import '../models/recipe.dart';

class RecipeService {
  const RecipeService();

  static String get openAIApiKey {
    final key = dotenv.env['OPENAI_API_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('Clé API OpenAI non trouvée dans le fichier .env');
    }
    return key;
  }

  Future<List<Recipe>> suggestRecipes(
    List<IngredientStock> stock, {
    String? profileDescription,
    int servings = 4,
  }) async {
    if (stock.isEmpty) return [];

    final stockText = stock.map((s) => '${s.grams} g de ${s.name}').join(', ');

    // Détection du mode multi-profils
    final isMultiProfile =
        profileDescription != null &&
        profileDescription.contains('RECETTES DE CONSENSUS');

    final profileText =
        (profileDescription == null || profileDescription.trim().isEmpty)
        ? 'Aucune contrainte particulière.'
        : profileDescription.trim();

    final prompt =
        '''
Tu es un chef cuisinier professionnel et expert en nutrition.

${isMultiProfile ? '🌟 MODE CONSENSUS MULTI-PROFILS 🌟\n$profileText\n\n⚠️ IMPÉRATIF : Les recettes doivent satisfaire TOUTES les contraintes listées ci-dessus simultanément. Trouve des recettes qui mettent TOUT LE MONDE d\'accord. Pense à des plats universels, adaptables, et qui respectent toutes les restrictions alimentaires mentionnées.' : 'Profil utilisateur : $profileText'}

L'utilisateur possède les ingrédients suivants dans son stock :
$stockText

🎯 OBJECTIF PRINCIPAL : Utilise le MAXIMUM de quantité possible de chaque ingrédient disponible pour minimiser le gaspillage.

👥 NOMBRE DE PERSONNES CIBLE : $servings
Les recettes doivent être dimensionnées pour exactement $servings personne(s). Ajuste les portions et les quantités en conséquence.

📋 INSTRUCTIONS DÉTAILLÉES :
1. Propose exactement 3 recettes complètes et détaillées
2. Pour CHAQUE recette, utilise autant d'ingrédients que possible EN GRANDE QUANTITÉ
3. Spécifie les QUANTITÉS EXACTES utilisées pour chaque ingrédient (en grammes)
4. Écris des étapes TRÈS DÉTAILLÉES et précises (minimum 8-12 étapes par recette)
5. Inclus des conseils de chef, astuces, temps de cuisson précis
6. Ajoute une ESTIMATION DU TEMPS DE PRÉPARATION total (préparation + cuisson)
7. Ajoute une section complète de valeurs nutritionnelles à la fin
8. Le nombre de portions final doit correspondre à $servings personne(s)

📊 VALEURS NUTRITIONNELLES OBLIGATOIRES (pour la portion totale) :
- Calories (kcal)
- Protéines (g)
- Glucides (g)
- Lipides (g)
- Fibres (g)
- Sucres (g)
- Sel (mg)
- Nombre de portions

✨ STYLE DE RÉDACTION :
- Sois extrêmement détaillé et descriptif
- Explique les techniques de cuisson
- Donne des repères visuels ("jusqu'à ce que doré", "texture crémeuse")
- Mentionne les temps précis de préparation et cuisson
- Sois généreux dans les explications

Répond STRICTEMENT en JSON, sans texte autour, du type :
{
  "recipes": [
    {
      "title": "Titre appétissant de la recette",
      "preparation_time": "Préparation: 20 min | Cuisson: 35 min | Total: 55 min",
      "ingredients": [
        "250g de tomate (du stock disponible)",
        "150g d'oignon (du stock disponible)",
        "3 cuillères à soupe d'huile d'olive"
      ],
      "steps": [
        "1. Première étape très détaillée avec temps et technique précise...",
        "2. Deuxième étape très détaillée avec conseils de chef...",
        "[...] minimum 8-12 étapes détaillées NUMÉROTÉES (format: 1. , 2. , 3. , etc.)"
      ],
      "nutritional_info": "Valeurs nutritionnelles (pour $servings portions) : Calories: 450 kcal | Protéines: 25g | Glucides: 58g | Lipides: 12g | Fibres: 8g | Sucres: 6g | Sel: 850mg"
    }
  ]
}
''';
    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer ${RecipeService.openAIApiKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-4o',
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.8,
        'max_tokens': 4000,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur API ${response.statusCode}: ${response.body}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final content = body['choices'][0]['message']['content'] as String? ?? '';

    // Nettoyer la réponse pour extraire uniquement le JSON
    String cleanedContent = content.trim();

    // Supprimer les balises markdown si présentes
    if (cleanedContent.startsWith('```json')) {
      cleanedContent = cleanedContent.substring(7);
    }
    if (cleanedContent.startsWith('```')) {
      cleanedContent = cleanedContent.substring(3);
    }
    if (cleanedContent.endsWith('```')) {
      cleanedContent = cleanedContent.substring(0, cleanedContent.length - 3);
    }

    // Trouver le début et la fin du JSON
    final jsonStart = cleanedContent.indexOf('{');
    final jsonEnd = cleanedContent.lastIndexOf('}');

    if (jsonStart == -1 || jsonEnd == -1) {
      throw Exception(
        'Impossible de trouver le JSON dans la réponse: $content',
      );
    }

    cleanedContent = cleanedContent.substring(jsonStart, jsonEnd + 1).trim();

    // Parser le JSON nettoyé
    final decoded = jsonDecode(cleanedContent) as Map<String, dynamic>;
    final recipesJson = decoded['recipes'] as List<dynamic>;
    return recipesJson
        .map((r) => Recipe.fromJson(r as Map<String, dynamic>))
        .toList();
  }
}
