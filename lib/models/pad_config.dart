// lib/models/pad_config.dart
class PadConfig {
  final String name; // Nom de l’ingrédient (ex: Riz, Farine)
  final bool tared; // LED taré
  final int seuilBas; // ex: 50
  final int seuilMoyen; // ex: 100
  final int seuilHaut; // ex: 150

  const PadConfig({
    this.name = '',
    this.tared = false,
    this.seuilBas = 50,
    this.seuilMoyen = 100,
    this.seuilHaut = 150,
  });

  PadConfig copyWith({
    String? name,
    int? seuilBas,
    int? seuilMoyen,
    int? seuilHaut,
    bool? tared,
  }) {
    return PadConfig(
      name: name ?? this.name,
      seuilBas: seuilBas ?? this.seuilBas,
      seuilMoyen: seuilMoyen ?? this.seuilMoyen,
      seuilHaut: seuilHaut ?? this.seuilHaut,
      tared: tared ?? this.tared,
    );
  }
}
