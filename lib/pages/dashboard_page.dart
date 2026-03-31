// Correction finale Mon Mar 30 22:43:04 UTC 2026
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pad.dart';
import '../models/pad_config.dart';
import '../state/pads_provider.dart';
import '../state/pads_config_provider.dart';
import '../state/theme_provider.dart';
import '../state/profile_provider.dart';
import '../state/favorites_provider.dart';
import '../models/profile.dart';
import '../utils/ble_permissions.dart';
import '../ble/ble_scan.dart';
import '../models/ingredient_stock.dart';
import '../models/recipe.dart';
import '../utils/favorites_storage.dart';
import "package:shared_preferences/shared_preferences.dart";
import 'dart:convert';
import '../services/recipe_service.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import '../ble/ble_device_connector.dart';

/// Feuille modale affichant les recettes proposées par l'IA.
/// Permet à l'utilisateur de consulter les détails d'une recette et
/// de l'ajouter/supprimer des favoris.
class RecipesSheet extends ConsumerWidget {
  final List<Recipe> recipes;

  const RecipesSheet({super.key, required this.recipes});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const Text(
            'Recettes proposées',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: recipes.length,
              itemBuilder: (_, i) {
                final r = recipes[i];
                final favs = ref.watch(favoritesProvider);
                final isFav = favs.any((e) => e.title == r.title);
                final currentId = ref.watch(currentProfileIdProvider);
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                r.title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: isFav
                                  ? 'Retirer des favoris'
                                  : 'Ajouter aux favoris',
                              icon: Icon(
                                isFav ? Icons.favorite : Icons.favorite_border,
                                color: isFav ? Colors.red : null,
                              ),
                              onPressed: currentId == null
                                  ? null
                                  : () {
                                      ref
                                          .read(favoritesProvider.notifier)
                                          .toggleFavorite(r);
                                    },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (r.preparationTime != null)
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 16,
                                color: Colors.blue[700],
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  r.preparationTime!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.blue[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        if (r.preparationTime != null)
                          const SizedBox(height: 8),
                        const Text(
                          'Ingrédients :',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        ...r.ingredients.map((ing) => Text('• $ing')),
                        const SizedBox(height: 8),
                        const Text(
                          'Étapes :',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        ...r.steps.asMap().entries.map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('${e.key + 1}. ${e.value}'),
                          ),
                        ),
                        if (r.nutritionalInfo != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.green.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.restaurant_menu,
                                      size: 18,
                                      color: Colors.green[700],
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Valeurs nutritionnelles',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green[700],
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  r.nutritionalInfo!,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Page principale de l'application KEG'INEO.
/// Affiche les données des capteurs BLE, gère les profils utilisateurs,
/// les recettes favorites et la configuration des seuils.
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

/// État de la page Dashboard.
/// Gère :
/// - La connexion BLE et la réception des données.
/// - Les interactions utilisateur (ajout/suppression de profils, seuils, etc.).
/// - La navigation entre les onglets.
class _DashboardPageState extends ConsumerState<DashboardPage> {
  final TextEditingController _injectCtrl = TextEditingController();
 
  final BleDeviceConnector _bleConnector = BleDeviceConnector();
  bool _bleConnected = false;
  String _lastBleMessage = '';
  DateTime? _lastBleTs;

  late final Map<Pad, TextEditingController> _nameCtrls;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    final cfg = ref.read(padsConfigProvider);
    _nameCtrls = {
      for (final p in Pad.values)
        p: TextEditingController(text: cfg[p]?.name ?? ''),
    };
  }

  /// Met à jour un poids (via +/−) et ajuste l’état "taré" (LED verte si 0 g).
  /// Paramètres:
  /// - `ref`: Référence au provider.
  /// - `pad`: Le tapis à mettre à jour.
  /// - `delta`: La variation de poids (positive ou négative).
  void _bump(WidgetRef ref, Pad pad, int delta) {
    ref.read(padsProvider.notifier).update((current) {
      final next = Map<Pad, int>.from(current);
      final v = (next[pad] ?? 0) + delta;
      final bounded = v.clamp(0, 2000);
      next[pad] = bounded;
      return next;
    });
    // LED taré = true si poids == 0
final notifier = ref.read(padsConfigProvider.notifier);
final current = notifier.getConfig();
final next = Map<Pad, PadConfig>.from(current);
next[pad] = (next[pad] ?? const PadConfig()).copyWith(
tared: (ref.read(padsProvider)[pad] ?? 0) == 0,
);
notifier.updateConfig(next);
  }

  /// Ouvre la boîte de dialogue de modification d'un profil utilisateur.
  /// Permet de modifier le nom et la description du profil.
  void _editProfile(BuildContext context, WidgetRef ref, Profile profile) {
    showDialog(
      context: context,
      builder: (ctx) {
        final nameCtrl = TextEditingController(text: profile.name);
        final descCtrl = TextEditingController(text: profile.description);

        return AlertDialog(
          title: const Text('Modifier le profil'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nom du profil'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description / attentes / allergies',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
              },
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final desc = descCtrl.text.trim();
                if (name.isEmpty) return;

                await ref
                    .read(profilesProvider.notifier)
                    .updateProfile(profile.id, name, desc);

                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );
  }

  /// Ouvre la feuille modale pour gérer les profils utilisateurs.
  /// Permet d'ajouter, modifier ou supprimer des profils.
  void _openProfiles(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, child) {
            final profiles = ref.watch(profilesProvider);
            final currentId = ref.watch(currentProfileIdProvider);

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Profils utilisateur',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (profiles.isEmpty)
                      const Text('Aucun profil. Ajoute-en un ci-dessous.'),
                    ...profiles.map(
                      (p) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            title: Text(p.name),
                            subtitle: Text(
                              p.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (currentId == p.id)
                                  const Icon(Icons.check, color: Colors.teal),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  tooltip: 'Modifier ce profil',
                                  onPressed: () {
                                    _editProfile(ctx, ref, p);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                  tooltip: 'Supprimer ce profil',
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: ctx,
                                      builder: (dialogCtx) => AlertDialog(
                                        title: const Text(
                                          'Supprimer le profil ?',
                                        ),
                                        content: Text(
                                          'Voulez-vous vraiment supprimer le profil "${p.name}" ?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(
                                                    dialogCtx)
                                                .pop(false),
                                            child: const Text('Annuler'),
                                          ),
                                          FilledButton(
                                            onPressed: () => Navigator.of(
                                                    dialogCtx)
                                                .pop(true),
                                            style: FilledButton.styleFrom(
                                              backgroundColor: Colors.red,
                                            ),
                                            child: const Text('Supprimer'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true) {
                                      await ref
                                          .read(profilesProvider.notifier)
                                          .deleteProfile(p.id);
                                    }
                                  },
                                ),
                              ],
                            ),
                            onTap: () async {
                              await ref
                                  .read(profilesProvider.notifier)
                                  .selectProfile(p.id);
                              if (ctx.mounted) Navigator.of(ctx).pop();
                            },
                          ),
                          FutureBuilder<List<Recipe>>(
                            future: FavoritesStorage.loadForProfile(p.id),
                            builder: (context, snapshot) {
                              final favs = snapshot.data ?? const <Recipe>[];
                              final hasFavs = favs.isNotEmpty;
                              return Padding(
                                padding: const EdgeInsets.only(
                                  left: 16,
                                  right: 16,
                                  bottom: 8,
                                ),
                                child: Row(
                                  children: [
                                    if (hasFavs)
                                      TextButton.icon(
                                        onPressed: () =>
                                            _showFavoritesForProfile(
                                              ctx,
                                              p.id,
                                              p.name,
                                            ),
                                        icon: const Icon(
                                          Icons.favorite,
                                          color: Colors.red,
                                        ),
                                        label: Text(
                                          'Recettes favorites (${favs.length})',
                                        ),
                                      )
                                    else
                                      Text(
                                        'aucune recette mise en favoris',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 24),
                    const Text(
                      'Nouveau profil',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nom du profil',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description / attentes / allergies',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) return;
                          await ref
                              .read(profilesProvider.notifier)
                              .addProfile(name, descCtrl.text.trim());
                          final list = ref.read(profilesProvider);
                          if (list.isNotEmpty) {
                            await ref
                                .read(profilesProvider.notifier)
                                .selectProfile(list.last.id);
                          }
                          if (ctx.mounted) Navigator.of(ctx).pop();
                        },
                        child: const Text('Enregistrer'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Affiche les recettes favorites pour un profil donné.
  void _showFavoritesForProfile(
    BuildContext context,
    String profileId,
    String profileName,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final searchController = TextEditingController();
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Favoris – $profileName',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<List<Recipe>>(
                    future: FavoritesStorage.loadForProfile(profileId),
                    builder: (context, snapshot) {
                      final allFavs = snapshot.data ?? const <Recipe>[];
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (allFavs.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.favorite_border,
                                  size: 48,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Aucune recette mise en favoris',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      // Barre de recherche et liste filtrée
                      final filteredFavs = allFavs.where((recipe) {
                        if (searchQuery.isEmpty) return true;
                        final query = searchQuery.toLowerCase();
                        final titleMatch = recipe.title.toLowerCase().contains(
                          query,
                        );
                        final ingredientMatch = recipe.ingredients.any(
                          (ing) => ing.toLowerCase().contains(query),
                        );
                        final stepMatch = recipe.steps.any(
                          (step) => step.toLowerCase().contains(query),
                        );
                        return titleMatch || ingredientMatch || stepMatch;
                      }).toList();

                      return Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: searchController,
                                    decoration: InputDecoration(
                                      hintText: 'Rechercher une recette...',
                                      prefixIcon: const Icon(Icons.search),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      searchQuery = searchController.text;
                                    });
                                  },
                                  icon: const Icon(Icons.search),
                                  label: const Text('Chercher'),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                                if (searchQuery.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      searchController.clear();
                                      setState(() {
                                        searchQuery = '';
                                      });
                                    },
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (filteredFavs.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(32),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.search_off,
                                        size: 48,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Aucune recette trouvée',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              Flexible(
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: filteredFavs.length,
                                  itemBuilder: (_, i) {
                                    final r = filteredFavs[i];
                                    return Card(
                                      elevation: 2,
                                      margin: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    r.title,
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                IconButton(
                                                  tooltip:
                                                      'Retirer des favoris',
                                                  icon: const Icon(
                                                    Icons.favorite,
                                                    color: Colors.red,
                                                  ),
                                                  onPressed: () async {
                                                    final updatedFavs = allFavs
                                                        .where(
                                                          (e) =>
                                                              e.title !=
                                                              r.title,
                                                        )
                                                        .toList();
                                                    await FavoritesStorage.saveForProfile(
                                                      profileId,
                                                      updatedFavs,
                                                    );
                                                    setState(() {});
                                                  },
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            if (r.preparationTime != null)
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.access_time,
                                                    size: 16,
                                                    color: Colors.blue[700],
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      r.preparationTime!,
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: Colors.blue[700],
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            if (r.preparationTime != null)
                                              const SizedBox(height: 8),
                                            const Text(
                                              'Ingrédients :',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            ...r.ingredients.map(
                                              (ing) => Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 8,
                                                  top: 2,
                                                ),
                                                child: Text(
                                                  '• $ing',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            const Text(
                                              'Étapes :',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            ...r.steps.asMap().entries.map(
                                              (e) => Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 8,
                                                  top: 4,
                                                ),
                                                child: Text(
                                                  '${e.key + 1}. ${e.value}',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _bleConnected = false;
    _lastBleMessage = '';
    _injectCtrl.dispose();
    for (final c in _nameCtrls.values) {
      c.dispose();
    }
    _bleConnector.dispose();
    super.dispose();
  }

  /// Ouvre la feuille modale pour configurer les seuils des tapis.
  /// Permet de définir les seuils bas, moyen et haut pour chaque tapis.
  void _openThresholdSettings(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final cfgs = ref.watch(padsConfigProvider);
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '⚙️ Configuration des seuils',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 🌙 Section Dark Mode
              Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.dark_mode, size: 20),
                          SizedBox(width: 12),
                          Text(
                            'Mode sombre',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Switch(
                        value: ref.watch(themeProvider),
                        onChanged: (newValue) {
                          ref.read(themeProvider.notifier).theme = newValue;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...Pad.values.map((pad) {
                final conf = cfgs[pad] ?? const PadConfig();
                final basCtrl = TextEditingController(
                  text: conf.seuilBas.toString(),
                );
                final moyCtrl = TextEditingController(
                  text: conf.seuilMoyen.toString(),
                );
                final hautCtrl = TextEditingController(
                  text: conf.seuilHaut.toString(),
                );
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tapis ${pad.name}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Flexible(
                              child: TextField(
                                controller: basCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Seuil bas',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: TextField(
                                controller: moyCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Seuil moyen',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: TextField(
                                controller: hautCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Seuil haut',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(
                            onPressed: () {
                              final bas =
                                  int.tryParse(basCtrl.text) ?? conf.seuilBas;
                              final moy = int.tryParse(moyCtrl.text) ??
                                  conf.seuilMoyen;
                              final haut = int.tryParse(hautCtrl.text) ??
                                  conf.seuilHaut;
                              ref.read(padsConfigProvider.notifier).state = {
                                ...ref.read(padsConfigProvider.notifier).state,
                                pad: conf.copyWith(
                                  seuilBas: bas,
                                  seuilMoyen: moy,
                                  seuilHaut: haut,
                                ),
                              };
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Seuils mis à jour pour Tapis ${pad.name}',
                                  ),
                                ),
                              );
                            },
                            child: const Text('Enregistrer'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  /// Convertit une chaîne (ex: 'A') en enum Pad.
  Pad? _padFromString(String s) {
    switch (s.trim().toUpperCase()) {
      case 'A':
        return Pad.A;
      case 'B':
        return Pad.B;
      case 'C':
        return Pad.C;
      case 'D':
        return Pad.D;
    }
    return null;
  }

  /// Parseur robuste pour les valeurs numériques.
  /// Accepte les types `num` ou `String`.
  int _num(dynamic v) {
    if (v is num) return v.round();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  /// Gère la réception des données BLE au format JSON.
  /// Valide que le poids est dans une plage réaliste (0 < poids < 300).
  /// Met à jour les données des tapis si les valeurs sont valides.
  void _handleBleJson(String raw) {
    debugPrint('🔹 BLE RAW => $raw');

    try {
      final decoded = jsonDecode(raw);

      if (decoded is! Map<String, dynamic>) {
        debugPrint('❌ BLE JSON: not a Map, got ${decoded.runtimeType}');
        return;
      }

      // Mapping zones → pads (robuste)
      final map = <Pad, int>{};

      if (decoded.containsKey('z1')) {
        final weight = _num(decoded['z1']);
        if (weight > 0 && weight < 300) {
          map[Pad.A] = weight;
        }
      }
      if (decoded.containsKey('z2')) {
        final weight = _num(decoded['z2']);
        if (weight > 0 && weight < 300) {
          map[Pad.B] = weight;
        }
      }
      if (decoded.containsKey('z3')) {
        final weight = _num(decoded['z3']);
        if (weight > 0 && weight < 300) {
          map[Pad.C] = weight;
        }
      }
      if (decoded.containsKey('z4')) {
        final weight = _num(decoded['z4']);
        if (weight > 0 && weight < 300) {
          map[Pad.D] = weight;
        }
      }

      if (map.isEmpty) {
        debugPrint('⚠️ BLE: no valid zones detected');
        return;
      }

      // Met à jour les données des tapis
      ref.read(padsProvider.notifier).update((current) {
        final next = Map<Pad, int>.from(current);
        next.addAll(map);
        return next;
      });

      debugPrint('✅ BLE parsed OK: ${map.length} values updated');
      final battery = (decoded['battery'] as num?)?.round();
      debugPrint(
        '✅ BLE OK => A:${map[Pad.A]} B:${map[Pad.B]} C:${map[Pad.C]} D:${map[Pad.D]} battery:${battery ?? "?"}',
      );
    } catch (e) {
      debugPrint('❌ BLE JSON ERROR: $e | raw=$raw');
    }
  }

  /// Parse et applique une ligne de commande Inject (W ou T).
  /// Format attendu:
  /// - W,A,150 : met à jour le poids du tapis A.
  /// - T,C : tare le tapis C.
  void _parseAndApply(String line) {
    final ctx = context;
    final parts = line.trim().split(',');
    if (parts.isEmpty || parts[0].isEmpty) {
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(const SnackBar(content: Text('Ligne vide ')));
      return;
    }

    final kind = parts[0].trim().toUpperCase();

    if (kind == 'W' && parts.length >= 3) {
      final pad = _padFromString(parts[1]);
      final grams = int.tryParse(parts[2].trim());
      if (pad == null || grams == null || grams < 0 || grams >= 300) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text('Format W invalide. Exemple: W,A,150,0,92'),
          ),
        );
        return;
      }
      ref.read(padsProvider.notifier).update((current) {
        final next = Map<Pad, int>.from(current);
        next[pad] = grams.clamp(0, 2000);
        return next;
      });
      final currentConfig = ref.read(padsConfigProvider.notifier).state;
      final nextConfig = Map<Pad, PadConfig>.from(currentConfig);
      nextConfig[pad] = (nextConfig[pad] ?? const PadConfig()).copyWith(
        tared: grams == 0,
      );
      ref.read(padsConfigProvider.notifier).state = nextConfig;
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(SnackBar(content: Text('OK: $pad -> $grams g')));
      return;
    }

    if (kind == 'T' && parts.length >= 2) {
      final pad = _padFromString(parts[1]);
      if (pad == null) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Format T invalide. Exemple: T,C,1')),
        );
        return;
      }
      ref.read(padsProvider.notifier).update((current) {
        final next = Map<Pad, int>.from(current);
        next[pad] = 0;
        return next;
      });
      final current = ref.read(padsConfigProvider.notifier).state;
      final next = Map<Pad, PadConfig>.from(current);
      next[pad] = (next[pad] ?? const PadConfig()).copyWith(tared: true);
      ref.read(padsConfigProvider.notifier).state = next;
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Tare sur $pad')));
      return;
    }

    ScaffoldMessenger.of(ctx).showSnackBar(
      const SnackBar(content: Text('Type inconnu. Utilise W,... ou T,...')),
    );
  }

  /// Détermine la couleur du contour en fonction des seuils.
  Color _borderColorFor(int grams, PadConfig c) {
    if (grams < c.seuilBas) return Colors.red;
    if (grams < c.seuilMoyen) return Colors.orange;
    if (grams <= c.seuilHaut) return Colors.green;
    return Colors.grey;
  }

  /// Détermine la couleur de la LED (taré).
  Color _ledColor(bool tared) => tared ? Colors.green : Colors.grey;

  /// Construit la liste des ingrédients à partir des poids et configurations.
  List<IngredientStock> _buildStock(
    Map<Pad, int> weights,
    Map<Pad, PadConfig> cfgs,
  ) {
    final result = <IngredientStock>[];
    for (final p in Pad.values) {
      final grams = weights[p] ?? 0;
      final c = cfgs[p] ?? const PadConfig();
      final name = c.name.trim();
      if (name.isNotEmpty && grams > 0) {
        result.add(IngredientStock(name: name, grams: grams));
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final weights = ref.watch(padsProvider);
    final cfgs = ref.watch(padsConfigProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Liste récapitulative pour la liste de courses
    final recap = <String>[];
    for (final p in Pad.values) {
      final grams = weights[p] ?? 0;
      final c = cfgs[p] ?? const PadConfig();
      final name = c.name.trim();
      if (name.isNotEmpty && grams < c.seuilHaut) {
        final missing = (c.seuilHaut - grams).clamp(0, 999999);
        if (missing > 0) {
          recap.add('Il manque $missing g de $name (tapis ${p.name})');
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('KEG’INEO – Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Profils',
            icon: const Icon(Icons.person),
            onPressed: () => _openProfiles(context, ref),
          ),
          IconButton(
            tooltip: 'Configurer les seuils',
            icon: const Icon(Icons.settings),
            onPressed: () => _openThresholdSettings(context, ref),
          ),
          IconButton(
            tooltip: 'Autoriser BLE',
            icon: const Icon(Icons.bluetooth_searching),
            onPressed: () async {
              final ok = await ensureBlePermissions();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok ? 'Permissions BLE OK' : 'Permissions refusées',
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Scanner BLE',
            icon: const Icon(Icons.radar),
            onPressed: () async {
              final ok = await ensureBlePermissions();
              if (!ok || !mounted) return;

              final devices = await BleScanner().quickScan();
              if (!mounted) return;

              if (devices.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Aucun périphérique BLE trouvé.'),
                  ),
                );
                return;
              }

              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Périphériques trouvés'),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: devices.length,
                      itemBuilder: (_, i) {
                        final d = devices[i];
                        final name = (d.name.isEmpty) ? '(sans nom)' : d.name;
                        return ListTile(
                          title: Text(name),
                          subtitle: Text(d.id),
                          onTap: () async {
                            Navigator.of(ctx).pop();

                            // UUIDs à remplacer par ceux fournis
                            final serviceUuid = Uuid.parse(
                              '6b8a2b7c-52ce-4c4b-9f3a-7d4c6c8f9a12',
                            );
                            final charUuid = Uuid.parse(
                              'f2c4a1de-0c9a-4e2b-9d6f-6a8b1c3d5e78',
                            );

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Connexion à $name...')),
                            );
await _bleConnector.connectAndListen(
deviceId: d.id,
serviceId: serviceUuid,
txNotifyCharId: charUuid,
onDisconnect: () {
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('Déconnecté de la balance')));
},
onLine: (raw) {
                                if (!mounted) return;

                                final now = DateTime.now();
                                if (_lastBleTs != null) {
                                  _bleDeltaMs = now
                                      .difference(_lastBleTs!)
                                      .inMilliseconds;
_lastBleTs = now;

                                if (!_bleConnected) {
                                  setState(() => _bleConnected = true);
                                }

                                setState(() {
                                  _lastBleMessage = raw;
                                });

                                _handleBleJson(raw);
                              },
                              onDisconnect: () {
                                if (!mounted) return;
                                setState(() {
                                  _bleConnected = false;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Déconnecté du périphérique BLE.',
                                    ),
                                  ),
                                );
                              },
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Connecté à $name. En attente des données...',
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Fermer'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _buildCurrentTabBody(weights, cfgs, theme, cs, isDark, recap),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (index) {
          setState(() {
            _currentTabIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profils',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_outline),
            activeIcon: Icon(Icons.favorite),
            label: 'Favoris',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.track_changes_outlined),
            activeIcon: Icon(Icons.track_changes),
            label: 'Suivi',
          ),
        ],
      ),
    );
  }

  /// Construit le corps de l'onglet actuel.
  Widget _buildCurrentTabBody(
    Map<Pad, int> weights,
    Map<Pad, PadConfig> cfgs,
    ThemeData theme,
    ColorScheme cs,
    bool isDark,
    List<String> recap,
  ) {
    switch (_currentTabIndex) {
      case 0:
        return _buildDashboardTab(weights, cfgs, theme, cs, isDark, recap);
      case 1:
        return _buildProfilesTab();
      case 2:
        return _buildFavoritesTab();
      case 3:
        return const TrackingPage(); // Nouvelle page de suivi
      default:
        return _buildDashboardTab(weights, cfgs, theme, cs, isDark, recap);
    }
  }

  /// Construit l'onglet Dashboard.
  Widget _buildDashboardTab(
    Map<Pad, int> weights,
    Map<Pad, PadConfig> cfgs,
    ThemeData theme,
    ColorScheme cs,
    bool isDark,
    List<String> recap,
  ) {
    return Container(
      color: cs.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Contenu du dashboard actuel
            // ... (inchangé)
            const Text(
              'Suivi des ingrédients',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.2,
              children: Pad.values.map((pad) {
                final grams = weights[pad] ?? 0;
                final cfg = cfgs[pad] ?? const PadConfig();
                return Card(
                  elevation: 2,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      final nameCtrl = _nameCtrls[pad]!;
                      showDialog(
                        context: context,
                        builder: (ctx) {
                          return AlertDialog(
                            title: Text('Configurer Tapis ${pad.name}'),
                            content: TextField(
                              controller: nameCtrl,
                              decoration: InputDecoration(
                                labelText: 'Nom de l’ingrédient',
                                hintText: cfg.name.isNotEmpty
                                    ? '(actuel: ${cfg.name})'
                                    : 'exemple: Farine',
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: const Text('Annuler'),
                              ),
                              FilledButton(
                                onPressed: () {
                                  final name = nameCtrl.text.trim();
                                  ref.read(padsConfigProvider.notifier).state =
                                    {
                                      ...ref.read(padsConfigProvider.notifier).state,
                                      pad: cfg.copyWith(name: name),
                                    };
                                  Navigator.of(ctx).pop();
                                  setState(() {});
                                },
                                child: const Text('Valider'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Tapis ${pad.name}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.refresh, size: 18),
                                color: cs.primary,
                                tooltip: 'Tarer',
                                onPressed: () => _bump(ref, pad, -(weights[pad] ?? 0)),
                              ),
                            ],
                          ),
                          const Divider(),
                          Text(
                            cfg.name.isEmpty ? '(non configuré)' : cfg.name,
                            style: TextStyle(
                              color: cfg.name.isEmpty
                                  ? Colors.grey[500]
                                  : cs.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '$grams g',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: _borderColorFor(grams, cfg),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Icon(
                              Icons.circle,
                              color: _ledColor(cfg.tared),
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            if (recap.isNotEmpty) ...[
              const Text(
                'Liste de courses',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...recap.map((txt) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 10, top: 6),
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(child: Text(txt, style: const TextStyle(fontSize: 15))),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  /// Construit l'onglet Profils.
  Widget _buildProfilesTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _openProfiles(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Gérer les profils'),
          ),
        ],
      ),
    );
  }

  /// Construit l'onglet Favoris.
  Widget _buildFavoritesTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Consumer(
        builder: (_, ref, __) {
          final currentId = ref.watch(currentProfileIdProvider);
          return FutureBuilder<List<Recipe>>(
            future: currentId == null
                ? Future.value([])
                : FavoritesStorage.loadForProfile(currentId),
            builder: (context, snapshot) {
              final favs = snapshot.data ?? [];
              if (favs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        currentId == null
                            ? 'Aucun profil sélectionné'
                            : 'Aucune recette en favoris',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ],
                  ),
                );
              }
return ListView.builder(
itemCount: favs.length,
itemBuilder: (_, i) => Padding(
padding: const EdgeInsets.only(bottom: 12),
child: Hero(
tag: 'recipe_${favs[i].id}',
child: Card(
elevation: 2,
child: Padding(
padding: const EdgeInsets.all(16),
child: ListTile(
onTap: () => Navigator.of(context).push(
MaterialPageRoute(
builder: (ctx) => Scaffold(
appBar: AppBar(title: Text(favs[i].title)),
body: SingleChildScrollView(
child: Hero(
tag: 'recipe_${favs[i].id}',
child: Padding(
padding: const EdgeInsets.all(16),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(favs[i].title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
const SizedBox(height: 12),
Text(favs[i].description),
],
),
),
),
),
),
),
),
title: Text(
favs[i].title,
style: const TextStyle(fontWeight: FontWeight.bold),
),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            Text('• Ingrédients: ${favs[i].ingredients.join(', ')}'),
                            const SizedBox(height: 4),
                            Text('• Étapes: ${favs[i].steps.length}'),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () async {
                            if (currentId == null) return;

                            final shouldRemove = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Supprimer des favoris?'),
                                content: Text(
                                  'Retirer \"${favs[i].title}\" de vos favoris ?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Annuler'),
                                  ),
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.red,
                                    ),
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Supprimer'),
                                  ),
                                ],
                              ),
                            );

                            if (shouldRemove == true) {
                              ref
                                  .read(favoritesProvider.notifier)
                                  .removeFavorite(favs[i]);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Construit l'onglet Paramètres.
  Widget _buildSettingsTab(ThemeData theme, ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Mode sombre',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Switch(
                      value: theme.brightness == Brightness.dark,
                      onChanged: (v) {
                        ref.read(themeProvider.notifier).theme = v;
                      },
                    ),
                  ],
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Configurer les seuils'),
                  onTap: () => _openThresholdSettings(context, ref),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}