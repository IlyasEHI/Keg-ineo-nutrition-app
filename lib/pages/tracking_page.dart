import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Page de suivi des macronutriments basée sur un apport calorique.
/// Permet à l'utilisateur de saisir des calories et calcule automatiquement
/// la répartition en protéines, glucides et lipides.
/// Les données sont sauvegardées localement via `shared_preferences`.
class TrackingPage extends ConsumerStatefulWidget {
  const TrackingPage({super.key});

  @override
  ConsumerState<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends ConsumerState<TrackingPage> {
  final TextEditingController _caloriesController = TextEditingController();
  double _protein = 0;
  double _carbs = 0;
  double _fat = 0;
  bool _isSaving = false;

  // Ratios par défaut pour les macronutriments (40% protéines, 30% glucides, 30% lipides)
  static const double _proteinRatio = 0.4;
  static const double _carbsRatio = 0.3;
  static const double _fatRatio = 0.3;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  @override
  void dispose() {
    _caloriesController.dispose();
    super.dispose();
  }

  /// Charge les données sauvegardées depuis `shared_preferences`.
  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCalories = prefs.getDouble('calories') ?? 0;
    if (savedCalories > 0) {
      _caloriesController.text = savedCalories.toStringAsFixed(0);
      _calculateMacros(savedCalories);
    }
  }

  /// Calcule les macronutriments en fonction des calories saisies.
  /// Formule :
  /// - Protéines = (calories * ratio_protéines) / 4
  /// - Glucides = (calories * ratio_glucides) / 4
  /// - Lipides = (calories * ratio_lipides) / 9
  void _calculateMacros(double calories) {
    setState(() {
      _protein = (calories * _proteinRatio) / 4;
      _carbs = (calories * _carbsRatio) / 4;
      _fat = (calories * _fatRatio) / 9;
    });
  }

  /// Sauvegarde les données dans `shared_preferences`.
  Future<void> _saveData() async {
    if (_caloriesController.text.isEmpty) return;

    setState(() => _isSaving = true);
    final prefs = await SharedPreferences.getInstance();
    final calories = double.tryParse(_caloriesController.text) ?? 0;
    await prefs.setDouble('calories', calories);

    // Simulation d'un délai pour l'UX
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Données sauvegardées'))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suivi des macronutriments'),
        actions: [
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.chartBar),
            onPressed: () {},
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Champ de saisie pour les calories
            Card(
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Calories totales (kcal)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _caloriesController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Ex: 2000',
                        suffixText: 'kcal',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        final calories = double.tryParse(value) ?? 0;
                        if (calories > 0) _calculateMacros(calories);
                      },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveData,
                      icon: _isSaving
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: const Text('Sauvegarder'),
                    ),
                  ],
                ),
              ),
            ),

            // Affichage des macronutriments
            const SizedBox(height: 16),
            const Text(
              'Répartition des macronutriments',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            
            // Protéines
            _MacroCard(
              title: 'Protéines',
              value: _protein,
              unit: 'g',
              icon: FontAwesomeIcons.drumstickBite,
              color: Colors.blue,
            ),
            
            // Glucides
            _MacroCard(
              title: 'Glucides',
              value: _carbs,
              unit: 'g',
              icon: FontAwesomeIcons.breadSlice,
              color: Colors.green,
            ),
            
            // Lipides
            _MacroCard(
              title: 'Lipides',
              value: _fat,
              unit: 'g',
              icon: FontAwesomeIcons.cheese,
              color: Colors.orange,
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget personnalisé pour afficher un macronutriment sous forme de carte.
class _MacroCard extends StatelessWidget {
  final String title;
  final double value;
  final String unit;
  final IconData icon;
  final Color color;

  const _MacroCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: FaIcon(icon, color: color, size: 30),
        title: Text(title, style: const TextStyle(fontSize: 16)),
        trailing: Text(
          '${value.toStringAsFixed(1)} $unit',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}