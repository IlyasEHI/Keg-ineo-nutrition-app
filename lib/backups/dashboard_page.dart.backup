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
import 'dart:convert';
import '../services/recipe_service.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import '../ble/ble_device_connector.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

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
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.green.withOpacity(0.3),
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

class _DashboardPageState extends ConsumerState<DashboardPage> {
  final _injectCtrl = TextEditingController();
  List<Recipe>? _lastRecipes;
  final BleDeviceConnector _bleConnector = BleDeviceConnector();
  bool _bleConnected = false;
  String _lastBleMessage = '';
  DateTime? _lastBleTs;
  int _bleDeltaMs = 0;
  // contrôleurs texte pour le nom d’ingrédient de chaque plateau
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
    List<IngredientStock> buildStock(
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
  }

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

                      // Search bar and filtered list
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
                            // Search bar
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
                                                    // Remove from favorites
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
                                                    // Refresh the UI
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
                                            if (r.nutritionalInfo != null) ...[
                                              const SizedBox(height: 12),
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  12,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.green
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: Colors.green
                                                        .withOpacity(0.3),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          Icons.restaurant_menu,
                                                          size: 18,
                                                          color:
                                                              Colors.green[700],
                                                        ),
                                                        const SizedBox(
                                                          width: 6,
                                                        ),
                                                        Text(
                                                          'Valeurs nutritionnelles',
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Colors
                                                                .green[700],
                                                            fontSize: 15,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      r.nutritionalInfo!,
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                      ),
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
                                    // Confirmation avant suppression
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
                                              dialogCtx,
                                            ).pop(false),
                                            child: const Text('Annuler'),
                                          ),
                                          FilledButton(
                                            onPressed: () => Navigator.of(
                                              dialogCtx,
                                            ).pop(true),
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

  // met à jour un poids (via +/−) et ajuste l’état "taré" (LED verte si 0 g)
  void _bump(WidgetRef ref, Pad pad, int delta) {
    ref.read(padsProvider.notifier).update((current) {
      final next = Map<Pad, int>.from(current);
      final v = (next[pad] ?? 0) + delta;
      final bounded = v.clamp(0, 2000);
      next[pad] = bounded;
      return next;
    });
    // LED taré = true si poids == 0
    final current = ref.read(padsConfigProvider.notifier).state;
    final next = Map<Pad, PadConfig>.from(current);
    next[pad] = (next[pad] ?? const PadConfig()).copyWith(
      tared: (ref.read(padsProvider)[pad] ?? 0) == 0,
    );
    ref.read(padsConfigProvider.notifier).state = next;
  }

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
                          ref.read(themeProvider.notifier).state = newValue;
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
                              final moy =
                                  int.tryParse(moyCtrl.text) ?? conf.seuilMoyen;
                              final haut =
                                  int.tryParse(hautCtrl.text) ?? conf.seuilHaut;
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

  // Parser robuste pour les valeurs numériques du BLE
  int _num(dynamic v) {
    if (v is num) return v.round();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  // Parse un JSON BLE {"z1":..., "z2":..., "z3":..., "z4":..., "battery":...}
  // et met à jour les 4 tapis en ignorant la batterie.
  void _handleBleJson(String raw) {
    debugPrint('🔹 BLE RAW => $raw');

    try {
      final decoded = jsonDecode(raw);

      if (decoded is! Map<String, dynamic>) {
        debugPrint('❌ BLE JSON: not a Map, got ${decoded.runtimeType}');
        return;
      }

      // mapping zones → pads (robuste)
      final map = <Pad, int>{};

      if (decoded.containsKey('z1')) {
        map[Pad.A] = _num(decoded['z1']);
      }
      if (decoded.containsKey('z2')) {
        map[Pad.B] = _num(decoded['z2']);
      }
      if (decoded.containsKey('z3')) {
        map[Pad.C] = _num(decoded['z3']);
      }
      if (decoded.containsKey('z4')) {
        map[Pad.D] = _num(decoded['z4']);
      }

      if (map.isEmpty) {
        debugPrint('⚠️ BLE: no valid zones detected');
        return;
      }

      // update padsProvider
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

  // parseur des lignes Inject (W,... et T,...)
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
      if (pad == null || grams == null || grams < 0) {
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
      // LED taré = true si 0 g
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
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(SnackBar(content: Text('Tare sur $pad')));
      return;
    }

    ScaffoldMessenger.of(ctx).showSnackBar(
      const SnackBar(content: Text('Type inconnu. Utilise W,... ou T,...')),
    );
  }

  // couleur du contour en fonction des seuils
  Color _borderColorFor(int grams, PadConfig c) {
    if (grams < c.seuilBas) return Colors.red; // < bas  => rouge
    if (grams < c.seuilMoyen) return Colors.orange; // [bas..moyen) => orange
    if (grams <= c.seuilHaut) return Colors.green; // [moyen..haut] => vert
    return Colors.grey; // au-dessus du haut
  }

  // LED (taré)
  Color _ledColor(bool tared) => tared ? Colors.green : Colors.grey;
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

    // liste "récap / liste de courses"
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
                            Navigator.of(ctx).pop(); // ferme la liste

                            // TODO: remplace ces UUID par ceux donnés par Barnabé
                            final serviceUuid = Uuid.parse(
                              '6b8a2b7c-52ce-4c4b-9f3a-7d4c6c8f9a12',
                            ); // EXEMPLE
                            final charUuid = Uuid.parse(
                              'f2c4a1de-0c9a-4e2b-9d6f-6a8b1c3d5e78',
                            ); // EXEMPLE

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Connexion à $name...')),
                            );
                            await _bleConnector.connectAndListen(
                              deviceId: d.id,
                              serviceId: serviceUuid,
                              charId: charUuid,
                              onLine: (raw) {
                                if (!mounted) return;

                                final now = DateTime.now();
                                if (_lastBleTs != null) {
                                  _bleDeltaMs = now
                                      .difference(_lastBleTs!)
                                      .inMilliseconds;
                                }
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
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Paramètres',
          ),
        ],
      ),
    );
  }

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
        return _buildSettingsTab(theme, cs);
      default:
        return _buildDashboardTab(weights, cfgs, theme, cs, isDark, recap);
    }
  }

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
            // Le contenu actuel du dashboard sera ici
            Text('Dashboard Content - Coming soon'),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilesTab() {
    return Consumer(
      builder: (context, ref, child) {
        final profiles = ref.watch(profilesProvider);
        final currentId = ref.watch(currentProfileIdProvider);

        return Container(
          color: Theme.of(context).colorScheme.surface,
          child: profiles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aucun profil',
                        style: TextStyle(fontSize: 20, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => _openProfiles(context, ref),
                        icon: const Icon(Icons.add),
                        label: const Text('Créer un profil'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: profiles.length,
                  itemBuilder: (context, index) {
                    final profile = profiles[index];
                    final isActive = currentId == profile.id;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: isActive ? 4 : 1,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: isActive
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey[300],
                          child: Text(
                            profile.name[0].toUpperCase(),
                            style: TextStyle(
                              color: isActive ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          profile.name,
                          style: TextStyle(
                            fontWeight: isActive
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          profile.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isActive)
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () =>
                                  _editProfile(context, ref, profile),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              onPressed: () {
                                ref
                                    .read(profilesProvider.notifier)
                                    .deleteProfile(profile.id);
                              },
                            ),
                          ],
                        ),
                        onTap: () {
                          ref
                              .read(profilesProvider.notifier)
                              .selectProfile(profile.id);
                        },
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _buildFavoritesTab() {
    return Consumer(
      builder: (context, ref, child) {
        final currentId = ref.watch(currentProfileIdProvider);

        if (currentId == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite_outline, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Sélectionne un profil d\'abord',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return FutureBuilder<List<Recipe>>(
          future: FavoritesStorage.loadForProfile(currentId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final favorites = snapshot.data ?? [];

            if (favorites.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.favorite_border,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Aucune recette favorite',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final recipe = favorites[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: const Icon(Icons.favorite, color: Colors.red),
                    title: Text(
                      recipe.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('${recipe.ingredients.length} ingrédients'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        ref
                            .read(favoritesProvider.notifier)
                            .toggleFavorite(recipe);
                      },
                    ),
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        builder: (_) => RecipesSheet(recipes: [recipe]),
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSettingsTab(ThemeData theme, ColorScheme cs) {
    return Consumer(
      builder: (context, ref, child) {
        final isDarkMode = ref.watch(themeProvider);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Apparence',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Card(
                child: SwitchListTile(
                  title: const Text('Mode sombre'),
                  subtitle: const Text('Activer le thème sombre'),
                  value: isDarkMode,
                  secondary: Icon(
                    isDarkMode ? Icons.dark_mode : Icons.light_mode,
                  ),
                  onChanged: (value) {
                    ref.read(themeProvider.notifier).state = value;
                  },
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Configuration des plateaux',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Seuils des capteurs'),
                  subtitle: const Text('Configurer les seuils de poids'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _openThresholdSettings(context, ref),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Bluetooth',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.bluetooth),
                      title: const Text('Permissions BLE'),
                      subtitle: const Text('Autoriser l\'accès Bluetooth'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () async {
                        final ok = await ensureBlePermissions();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok ? 'Permissions OK' : 'Permissions refusées',
                            ),
                          ),
                        );
                      },
                    ),
                    Card(
                      margin: const EdgeInsets.all(12),
                      color: _bleConnected
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _bleConnected
                                      ? Icons.check_circle
                                      : Icons.error,
                                  color: _bleConnected
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _bleConnected ? 'Connecté' : 'Déconnecté',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _bleConnected
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            if (_lastBleMessage.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Dernier message: $_lastBleMessage',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

