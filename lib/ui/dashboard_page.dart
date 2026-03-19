import 'dart:async';
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
import '../services/led_control_service.dart';
import '../state/led_control_provider.dart';

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
                            child: Text(
                              '${e.key + 1}. ${e.value.replaceFirst(RegExp(r'^\s*\d+\s*[\.)\-:]\s*'), '')}',
                            ),
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
  static const String _serviceUuidStr = '6b8a2b7c-52ce-4c4b-9f3a-7d4c6c8f9a12';
  static const String _notifyUuidStr = 'f2c4a1de-0c9a-4e2b-9d6f-6a8b1c3d5e78';
  static const String _writeUuidStr = 'b3f1d7a6-4c2e-4bb1-8b0b-2a6c7d9e1f34';

  final _injectCtrl = TextEditingController();
  final _favoritesSearchCtrl = TextEditingController();
  String _favoritesSearch = '';
  List<Recipe>? _lastRecipes;
  final BleDeviceConnector _bleConnector = BleDeviceConnector();
  bool _isGattConnected = false;
  bool _isNotifySubscribed = false;
  String _lastBleMessage = '';
  DateTime? _lastNotifyAt;
  int? _batteryPercent;
  int _bleDeltaMs = 0;
  String? _connectedDeviceId;
  Uuid? _connectedServiceId;
  Uuid? _connectedCharId;
  final Map<Pad, int> _tareOffsets = {for (final p in Pad.values) p: 0};
  final Map<Pad, bool> _tareActive = {for (final p in Pad.values) p: false};
  int _recipeServings = 4;
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
                                                  '${e.key + 1}. ${e.value.replaceFirst(RegExp(r'^\s*\d+\s*[\.)\-:]\s*'), '')}',
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
    _isGattConnected = false;
    _isNotifySubscribed = false;
    _lastBleMessage = '';
    _injectCtrl.dispose();
    _favoritesSearchCtrl.dispose();
    for (final c in _nameCtrls.values) {
      c.dispose();
    }
    _bleConnector.dispose();
    super.dispose();
  }

  Future<void> _scanAndConnectBle(BuildContext context) async {
    final ok = await ensureBlePermissions();
    if (!ok || !mounted) return;

    final devices = await BleScanner().quickScan();
    if (!mounted) return;

    final filteredDevices = _preferredBleDevices(devices);

    if (filteredDevices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun périphérique BLE trouvé.')),
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
            itemCount: filteredDevices.length,
            itemBuilder: (_, i) {
              final d = filteredDevices[i];
              final name = d.name.isEmpty ? '(sans nom)' : d.name;

              return ListTile(
                title: Text(name),
                subtitle: Text(d.id),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _connectBleDevice(context, d);
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
  }

  List<DiscoveredDevice> _preferredBleDevices(List<DiscoveredDevice> devices) {
    final kebIneoNamed = devices
        .where((d) => d.name.toUpperCase().startsWith('KEGINEO-'))
        .toList();
    if (kebIneoNamed.isNotEmpty) {
      return kebIneoNamed;
    }

    // Fallback: remove unnamed devices when we have at least one named device.
    final named = devices.where((d) => d.name.trim().isNotEmpty).toList();
    if (named.isNotEmpty) {
      return named;
    }

    return devices;
  }

  Future<void> _connectBleDevice(
    BuildContext context,
    DiscoveredDevice device,
  ) async {
    final name = device.name.isEmpty ? '(sans nom)' : device.name;
    final serviceUuid = Uuid.parse(_serviceUuidStr);
    final txNotifyUuid = Uuid.parse(_notifyUuidStr);
    final rxWriteUuid = Uuid.parse(_writeUuidStr);

    setState(() {
      _connectedDeviceId = device.id;
      _connectedServiceId = serviceUuid;
      _connectedCharId = txNotifyUuid;
      _isGattConnected = false;
      _isNotifySubscribed = false;
      _lastBleMessage = '';
      _lastNotifyAt = null;
      _bleDeltaMs = 0;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Connexion à $name...')));
    debugPrint('🔍 BLE UI: trying device name=$name id=${device.id}');

    await _bleConnector.connectAndListen(
      deviceId: device.id,
      serviceId: serviceUuid,
      txNotifyCharId: txNotifyUuid,
      rxWriteCharId: rxWriteUuid,
      onLine: (raw) {
        if (!mounted) return;

        final now = DateTime.now();
        final delta = _lastNotifyAt == null
            ? 0
            : now.difference(_lastNotifyAt!).inMilliseconds;

        setState(() {
          _isNotifySubscribed = true;
          _lastBleMessage = raw;
          _lastNotifyAt = now;
          _bleDeltaMs = delta;
        });

        debugPrint('📲 BLE UI notify received (Δ ${_bleDeltaMs} ms)');

        _handleBleJson(raw);
      },
      onConnection: (connected) {
        if (!mounted) return;
        setState(() {
          _isGattConnected = connected;
          if (!connected) {
            _isNotifySubscribed = false;
          }
        });
        debugPrint('🔗 BLE UI gatt state => $connected');
      },
      onError: (e) {
        debugPrint(
          '❌ BLE UI error: $e | gatt=$_isGattConnected notify=$_isNotifySubscribed',
        );
      },
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Connecté à $name. En attente des données...')),
    );
  }

  Future<void> _disconnectBle(BuildContext context) async {
    await _bleConnector.disconnect();
    if (!mounted) return;

    setState(() {
      _isGattConnected = false;
      _isNotifySubscribed = false;
      _lastBleMessage = '';
      _lastNotifyAt = null;
      _bleDeltaMs = 0;
      _connectedDeviceId = null;
      _connectedServiceId = null;
      _connectedCharId = null;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Déconnexion BLE effectuée.')));
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

  void _syncZeroTare(
    WidgetRef ref,
    Map<Pad, int> weights,
    Map<Pad, PadConfig> cfgs,
  ) {
    bool changed = false;
    final next = Map<Pad, PadConfig>.from(cfgs);
    for (final pad in Pad.values) {
      final c = next[pad] ?? const PadConfig();
      final shouldBeTared = _tareActive[pad] ?? false;
      if (c.tared != shouldBeTared) {
        next[pad] = c.copyWith(tared: shouldBeTared);
        changed = true;
      }
    }
    if (changed) {
      ref.read(padsConfigProvider.notifier).state = next;
    }
  }

  void _clearShoppingList(WidgetRef ref) {
    ref
        .read(padsProvider.notifier)
        .update((_) => {for (final p in Pad.values) p: 0});
    final current = ref.read(padsConfigProvider.notifier).state;
    final next = <Pad, PadConfig>{};
    for (final p in Pad.values) {
      _tareOffsets[p] = 0;
      _tareActive[p] = true;
      final cfg = current[p] ?? const PadConfig();
      next[p] = cfg.copyWith(name: '', tared: true);
    }
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
                              // Mettre à jour les LEDs avec les nouveaux seuils
                              _sendLedColors();
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
  // et met à jour les 4 tapis + la batterie.
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

      if (decoded.containsKey('battery')) {
        final nextBattery = _num(decoded['battery']).clamp(0, 100);
        if (_batteryPercent != nextBattery) {
          setState(() {
            _batteryPercent = nextBattery;
          });
        }
      }

      if (map.isEmpty) {
        debugPrint(
          'ℹ️ BLE: packet without zone update (battery only or metadata)',
        );
        return;
      }

      // Applique l'offset de tare par tapis avant affichage.
      ref.read(padsProvider.notifier).update((current) {
        final next = Map<Pad, int>.from(current);
        map.forEach((pad, rawValue) {
          final offset = _tareOffsets[pad] ?? 0;
          next[pad] = rawValue + offset;
        });
        return next;
      });

      // Le flag tared reflète désormais l'existence d'un offset actif.
      final cfgCurrent = ref.read(padsConfigProvider.notifier).state;
      final cfgNext = Map<Pad, PadConfig>.from(cfgCurrent);
      bool cfgChanged = false;
      for (final pad in map.keys) {
        final conf = cfgNext[pad] ?? const PadConfig();
        final shouldBeTared = _tareActive[pad] ?? false;
        if (conf.tared != shouldBeTared) {
          cfgNext[pad] = conf.copyWith(tared: shouldBeTared);
          cfgChanged = true;
        }
      }
      if (cfgChanged) {
        ref.read(padsConfigProvider.notifier).state = cfgNext;
      }

      debugPrint('✅ BLE parsed OK: ${map.length} values updated');
      debugPrint(
        '✅ BLE OK => A:${map[Pad.A]} B:${map[Pad.B]} C:${map[Pad.C]} D:${map[Pad.D]} battery:${_batteryPercent ?? "?"}',
      );

      // Envoyer les couleurs LED vers l'ESP32
      _sendLedColors();
    } catch (e) {
      debugPrint('❌ BLE JSON ERROR: $e | raw=$raw');
    }
  }

  // Extrait R,G,B d'une couleur Material et les envoie à l'ESP32
  void _sendLedColors() {
    if (!_isGattConnected) return;

    final weights = ref.read(padsProvider);
    final cfgs = ref.read(padsConfigProvider);

    for (final pad in Pad.values) {
      final grams = weights[pad] ?? 0;
      final c = cfgs[pad] ?? const PadConfig();
      final color = _borderColorFor(grams, c);

      // Extraire R, G, B de la couleur (format 0xAARRGGBB)
      final argb = color.value;
      final r = (argb >> 16) & 0xFF;
      final g = (argb >> 8) & 0xFF;
      final b = argb & 0xFF;

      // Format: L,A,255,128,0\n pour envoyer LED du tapis A en orange
      final cmd = 'L,${pad.name},$r,$g,$b\n';
      _bleConnector.sendCommand(cmd);
      debugPrint('💡 LED cmd => $cmd');
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
      // En mode debug W, on repart sur une valeur absolue (offset retiré).
      _tareOffsets[pad] = 0;
      _tareActive[pad] = false;
      final currentConfig = ref.read(padsConfigProvider.notifier).state;
      final nextConfig = Map<Pad, PadConfig>.from(currentConfig);
      nextConfig[pad] = (nextConfig[pad] ?? const PadConfig()).copyWith(
        tared: false,
      );
      ref.read(padsConfigProvider.notifier).state = nextConfig;
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(SnackBar(content: Text('OK: $pad -> $grams g')));
      // Mettre à jour les LEDs
      _sendLedColors();
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
      final currentWeights = ref.read(padsProvider);
      final currentDisplayed = currentWeights[pad] ?? 0;

      // Tare persistante: on ajuste l'offset pour que la valeur courante devienne 0.
      _tareOffsets[pad] = (_tareOffsets[pad] ?? 0) - currentDisplayed;
      _tareActive[pad] = true;

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
      // Mettre à jour les LEDs
      _sendLedColors();
      return;
    }

    ScaffoldMessenger.of(ctx).showSnackBar(
      const SnackBar(content: Text('Type inconnu. Utilise W,... ou T,...')),
    );
  }

  // couleur du contour en fonction des seuils
  Color _borderColorFor(int grams, PadConfig c) {
    if (grams == 0) return const Color(0xFFB0BEC5); // gris clair à 0g
    if (grams < c.seuilBas) return const Color(0xFFC62828); // rouge pro
    if (grams < c.seuilMoyen) return const Color(0xFFEF6C00); // orange soutenu
    if (grams <= c.seuilHaut) return const Color(0xFF43A047); // vert plus clair
    return const Color(0xFF78909C); // gris bleuté sobre
  }

  // LED (taré)
  Color _ledColor(bool tared) =>
      tared ? const Color(0xFF43A047) : const Color(0xFF78909C);

  IconData _batteryIconFor(int? percent) {
    final p = percent ?? 0;
    if (p >= 90) return Icons.battery_full;
    if (p >= 70) return Icons.battery_6_bar;
    if (p >= 50) return Icons.battery_5_bar;
    if (p >= 30) return Icons.battery_3_bar;
    if (p >= 15) return Icons.battery_2_bar;
    return Icons.battery_alert;
  }

  Color _batteryColorFor(int? percent) {
    final p = percent ?? 0;
    if (p >= 50) return const Color(0xFF2E7D32);
    if (p >= 20) return const Color(0xFFEF6C00);
    return const Color(0xFFC62828);
  }

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
        title: const Text('KEG\'INEO – Dashboard'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _batteryIconFor(_batteryPercent),
                  color: _batteryColorFor(_batteryPercent),
                ),
                const SizedBox(width: 4),
                Text(
                  '${_batteryPercent ?? '--'}%',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),

      body: _buildCurrentTabBody(weights, cfgs, theme, cs, isDark, recap),

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF0F141D), const Color(0xFF0B0F16)]
                : [const Color(0xFFF8FAFC), const Color(0xFFF0F2F7)],
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.35)
                  : Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTabIndex,
          onTap: (index) {
            setState(() {
              _currentTabIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: cs.primary,
          unselectedItemColor: isDark ? Colors.grey[600] : Colors.grey[400],
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFF12141A), const Color(0xFF1A1D23)]
              : [const Color(0xFFF5F7FA), const Color(0xFFE8ECF1)],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 Bandeau d'injection (debug) avec design moderne
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          const Color(0xFF7C4DFF).withOpacity(0.2),
                          const Color(0xFF9575FF).withOpacity(0.1),
                        ]
                      : [
                          const Color(0xFF7C4DFF).withOpacity(0.1),
                          const Color(0xFFB39DDB).withOpacity(0.05),
                        ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF7C4DFF).withOpacity(0.3)
                      : const Color(0xFF7C4DFF).withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _injectCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Injecte une ligne (ex: W,A,150,0,92)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _parseAndApply(_injectCtrl.text),
                    icon: const Icon(Icons.send),
                    label: const Text('Inject'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 🔹 Grille des plateaux
            GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: Pad.values.map((pad) {
                final g = weights[pad] ?? 0;
                final c = cfgs[pad] ?? const PadConfig();
                final borderColor = _borderColorFor(g, c);
                final isPadTared = _tareActive[pad] ?? false;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [const Color(0xFF1E2229), const Color(0xFF2A2E35)]
                          : [Colors.white, const Color(0xFFFAFAFA)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: borderColor.withOpacity(isDark ? 0.3 : 0.5),
                        blurRadius: 15,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: borderColor, width: 3),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 8,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Titre et LED
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Tapis ${pad.name}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: borderColor,
                              ),
                            ),
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: _ledColor(isPadTared),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: _ledColor(
                                      isPadTared,
                                    ).withOpacity(0.8),
                                    blurRadius: isPadTared ? 10 : 4,
                                    spreadRadius: isPadTared ? 2 : 0,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 6),

                        // Champ ingrédient
                        TextField(
                          controller: _nameCtrls[pad],
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            hintText: "Nom de l'ingrédient",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            isDense: true,
                          ),
                          onChanged: (txt) {
                            final current = ref.read(padsConfigProvider);
                            final conf = (current[pad] ?? const PadConfig())
                                .copyWith(name: txt);
                            ref
                                .read(padsConfigProvider.notifier)
                                .updatePad(pad, conf);
                          },
                          onSubmitted: (txt) {
                            final current = ref.read(padsConfigProvider);
                            final conf = (current[pad] ?? const PadConfig())
                                .copyWith(name: txt);
                            ref
                                .read(padsConfigProvider.notifier)
                                .updatePad(pad, conf);
                          },
                        ),

                        const SizedBox(height: 8),

                        // Poids affiché avec effet visuel
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                borderColor.withOpacity(0.2),
                                borderColor.withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '$g g',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: borderColor,
                              letterSpacing: 1,
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Bouton Tare avec gradient
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                borderColor.withOpacity(0.8),
                                borderColor.withOpacity(0.6),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: borderColor.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                _parseAndApply('T,${pad.name}');
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 8,
                                ),
                                child: const Center(
                                  child: Text(
                                    'Tare',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 30),

            // 🔹 Récap / liste de courses avec design moderne
            Row(
              children: [
                Icon(Icons.shopping_bag_outlined, color: cs.primary, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Liste de courses',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _clearShoppingList(ref),
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Vider'),
                  style: TextButton.styleFrom(foregroundColor: cs.primary),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [const Color(0xFF0D1826), const Color(0xFF0A121D)]
                      : [const Color(0xFFF2F5F9), const Color(0xFFE7ECF3)],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF2E4053)
                      : const Color(0xFFC5D0DD),
                  width: 1.6,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: (recap.isEmpty)
                  ? Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF26A69A).withOpacity(0.18),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle,
                            color: Color(0xFF26A69A),
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            'Rien pour l\'instant',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: recap
                          .map(
                            (line) => Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: isDark
                                      ? [
                                          const Color(0xFF132233),
                                          const Color(0xFF0F1B2B),
                                        ]
                                      : [
                                          const Color(0xFFE9F2F6),
                                          const Color(0xFFF4F8FB),
                                        ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color:
                                      (isDark
                                              ? const Color(0xFF3AAFA3)
                                              : const Color(0xFF22A295))
                                          .withOpacity(0.5),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(
                                      isDark ? 0.28 : 0.06,
                                    ),
                                    blurRadius: 14,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                dense: true,
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        (isDark
                                                ? const Color(0xFF2E8B83)
                                                : const Color(0xFF2AB3A3))
                                            .withOpacity(0.25),
                                        (isDark
                                                ? const Color(0xFF1B2D3D)
                                                : const Color(0xFFCCD8E6))
                                            .withOpacity(isDark ? 0.35 : 0.3),
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.shopping_cart,
                                    color: isDark
                                        ? const Color(0xFF9DDDD2)
                                        : const Color(0xFF1F8E7E),
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  line,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),

            const SizedBox(height: 24),

            // 🔹 Nombre de personnes (portion cible)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [const Color(0xFF16212E), const Color(0xFF101A25)]
                      : [const Color(0xFFEAF3F7), const Color(0xFFF4F8FB)],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF2E4053)
                      : const Color(0xFFB8C8D6),
                  width: 1.2,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.people_alt_outlined, color: cs.primary),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Nombre de personnes',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Diminuer',
                    onPressed: _recipeServings > 1
                        ? () {
                            setState(() {
                              _recipeServings -= 1;
                            });
                          }
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text(
                    '$_recipeServings',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Augmenter',
                    onPressed: _recipeServings < 20
                        ? () {
                            setState(() {
                              _recipeServings += 1;
                            });
                          }
                        : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 🔹 Boutons de recettes modernes avec gradient
            Container(
              width: double.infinity,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [const Color(0xFF0E7C6B), const Color(0xFF0A5A4F)]
                      : [const Color(0xFF00BFA5), const Color(0xFF00897B)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color:
                        (isDark
                                ? const Color(0xFF0E7C6B)
                                : const Color(0xFF00BFA5))
                            .withOpacity(0.35),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    final weights = ref.read(padsProvider);
                    final cfgs = ref.read(padsConfigProvider);
                    final selectedProfiles = ref.read(selectedProfilesProvider);

                    final stock = _buildStock(weights, cfgs);
                    if (stock.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Aucun ingrédient renseigné ou quantité nulle.',
                          ),
                        ),
                      );
                      return;
                    }

                    // Construire la description combinée de tous les profils sélectionnés
                    String? combinedDescription;
                    if (selectedProfiles.isNotEmpty) {
                      if (selectedProfiles.length == 1) {
                        combinedDescription =
                            selectedProfiles.first.description;
                      } else {
                        // Multi-profils: créer un texte de consensus
                        final profileDescriptions = selectedProfiles
                            .where((p) => p.description.trim().isNotEmpty)
                            .map((p) => '${p.name}: ${p.description}')
                            .join(' | ');
                        if (profileDescriptions.isNotEmpty) {
                          combinedDescription =
                              'RECETTES DE CONSENSUS pour ${selectedProfiles.length} personnes. '
                              'Contraintes à respecter simultanément: $profileDescriptions';
                        }
                      }
                    }

                    // Loader
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) =>
                          const Center(child: CircularProgressIndicator()),
                    );
                    try {
                      const service = RecipeService();
                      final recipes = await service.suggestRecipes(
                        stock,
                        profileDescription: combinedDescription,
                        servings: _recipeServings,
                      );

                      if (!mounted) return;

                      setState(() {
                        _lastRecipes = recipes;
                      });

                      Navigator.of(context).pop(); // ferme le loader

                      if (recipes.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Aucune recette proposée par le modèle.',
                            ),
                          ),
                        );
                        return;
                      }

                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        builder: (_) => RecipesSheet(recipes: recipes),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      Navigator.of(context).pop(); // ferme le loader
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Erreur lors de la génération des recettes: $e',
                          ),
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons.restaurant_menu,
                        color: Colors.white,
                        size: 28,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Proposer des recettes',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Bouton historique avec design moderne
            Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          const Color(0xFF7C4DFF).withOpacity(0.3),
                          const Color(0xFF9575FF).withOpacity(0.2),
                        ]
                      : [
                          const Color(0xFF7C4DFF).withOpacity(0.1),
                          const Color(0xFFB39DDB).withOpacity(0.05),
                        ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFF7C4DFF).withOpacity(0.5),
                  width: 2,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: (_lastRecipes == null || _lastRecipes!.isEmpty)
                      ? null
                      : () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(24),
                              ),
                            ),
                            builder: (_) =>
                                RecipesSheet(recipes: _lastRecipes!),
                          );
                        },
                  borderRadius: BorderRadius.circular(18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        color: (_lastRecipes == null || _lastRecipes!.isEmpty)
                            ? Colors.grey
                            : const Color(0xFF7C4DFF),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Voir la dernière proposition',
                        style: TextStyle(
                          color: (_lastRecipes == null || _lastRecipes!.isEmpty)
                              ? Colors.grey
                              : const Color(0xFF7C4DFF),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
        final selectedIds = ref.watch(selectedProfileIdsProvider);
        final isMultiSelectMode = selectedIds.isNotEmpty;

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
              : Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: FilledButton.icon(
                        onPressed: () => _openProfiles(context, ref),
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text(
                          'Ajouter un profil',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                    ),
                    // Bouton "Sélectionner tous les profils" en vert
                    Container(
                      margin: const EdgeInsets.all(16),
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: selectedIds.length == profiles.length
                              ? Colors.green.shade700
                              : Colors.green,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        onPressed: () {
                          if (selectedIds.length == profiles.length) {
                            // Désélectionner tout
                            ref
                                .read(profilesProvider.notifier)
                                .clearMultiSelection();
                          } else {
                            // Sélectionner tout
                            ref
                                .read(profilesProvider.notifier)
                                .selectAllProfiles();
                          }
                        },
                        icon: Icon(
                          selectedIds.length == profiles.length
                              ? Icons.check_circle
                              : Icons.group,
                        ),
                        label: Text(
                          selectedIds.length == profiles.length
                              ? 'Tous sélectionnés (${profiles.length})'
                              : 'Sélectionner tous les profils',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: selectedIds.length == profiles.length
                                ? Colors.white
                                : null,
                          ),
                        ),
                      ),
                    ),
                    if (isMultiSelectMode)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '${selectedIds.length} profil(s) sélectionné(s) - Recettes de consensus',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: profiles.length,
                        itemBuilder: (context, index) {
                          final isDark =
                              Theme.of(context).brightness == Brightness.dark;
                          final profile = profiles[index];
                          final isActive = currentId == profile.id;
                          final isSelected = selectedIds.contains(profile.id);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: (isActive || isSelected) ? 4 : 1,
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: CircleAvatar(
                                backgroundColor: (isActive || isSelected)
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey[300],
                                child: (isActive || isSelected)
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                      )
                                    : Text(
                                        profile.name[0].toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.black87,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                              title: Text(
                                profile.name,
                                style: TextStyle(
                                  fontWeight: (isActive || isSelected)
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
                                  if (isActive && !isMultiSelectMode)
                                    const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                    ),
                                  if (isSelected)
                                    Icon(
                                      Icons.group,
                                      color: Colors.green.shade700,
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
                                if (isMultiSelectMode) {
                                  // En mode multi-sélection, toggle la sélection
                                  ref
                                      .read(profilesProvider.notifier)
                                      .toggleMultiProfileSelection(profile.id);
                                } else {
                                  // En mode simple, toggle la sélection du profil
                                  if (currentId == profile.id) {
                                    // Si déjà sélectionné, on désélectionne
                                    ref
                                        .read(profilesProvider.notifier)
                                        .selectProfile(null);
                                  } else {
                                    // Sinon, on sélectionne ce profil
                                    ref
                                        .read(profilesProvider.notifier)
                                        .selectProfile(profile.id);
                                  }
                                }
                              },
                              onLongPress: () {
                                // Long press pour entrer en mode multi-sélection
                                ref
                                    .read(profilesProvider.notifier)
                                    .toggleMultiProfileSelection(profile.id);
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildFavoritesTab() {
    return Consumer(
      builder: (context, ref, child) {
        final currentId = ref.watch(currentProfileIdProvider);
        final profiles = ref.watch(profilesProvider);

        Profile? currentProfile;
        for (final p in profiles) {
          if (p.id == currentId) {
            currentProfile = p;
            break;
          }
        }

        final profileName = (currentProfile?.name.trim().isNotEmpty ?? false)
            ? currentProfile!.name
            : 'Profil actif';

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

            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;
            final cs = theme.colorScheme;

            final query = _favoritesSearch.trim().toLowerCase();
            final filteredFavorites = query.isEmpty
                ? favorites
                : favorites.where((recipe) {
                    final title = recipe.title.toLowerCase();
                    final ingredients = recipe.ingredients
                        .map((e) => e.toLowerCase())
                        .join(' ');
                    final steps = recipe.steps
                        .map((e) => e.toLowerCase())
                        .join(' ');
                    return title.contains(query) ||
                        ingredients.contains(query) ||
                        steps.contains(query);
                  }).toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _favoritesSearchCtrl,
                          decoration: InputDecoration(
                            hintText: 'Rechercher une recette...',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: isDark
                                ? cs.surfaceVariant.withOpacity(0.25)
                                : cs.surfaceVariant.withOpacity(0.8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: cs.outlineVariant.withOpacity(0.5),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: cs.primary,
                                width: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: () {
                          setState(() {
                            _favoritesSearch = _favoritesSearchCtrl.text;
                          });
                        },
                        icon: const Icon(Icons.search),
                        tooltip: 'Rechercher',
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Favoris de $profileName',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filteredFavorites.isEmpty
                      ? Center(
                          child: Text(
                            'Aucun favori pour cette recherche',
                            style: TextStyle(
                              color: cs.onSurface.withOpacity(0.7),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: filteredFavorites.length,
                          itemBuilder: (context, index) {
                            final recipe = filteredFavorites[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: const Icon(
                                  Icons.favorite,
                                  color: Colors.red,
                                ),
                                title: Text(
                                  recipe.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  '${recipe.ingredients.length} ingrédients',
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async {
                                    if (currentId == null) return;
                                    await FavoritesStorage.removeForProfile(
                                      currentId,
                                      recipe,
                                    );
                                    if (mounted) setState(() {});
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Recette supprimée des favoris',
                                        ),
                                      ),
                                    );
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
                                    builder: (_) =>
                                        RecipesSheet(recipes: [recipe]),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
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
                    ref.read(themeProvider.notifier).toggleTheme(value);
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
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: FilledButton.icon(
                        icon: const Icon(Icons.radar),
                        label: const Text('Scanner & se connecter'),
                        onPressed: () => _scanAndConnectBle(context),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.link_off),
                        label: const Text('Déconnecter'),
                        onPressed: _isGattConnected
                            ? () => _disconnectBle(context)
                            : null,
                      ),
                    ),
                    const Divider(height: 1),
                    Card(
                      margin: const EdgeInsets.all(12),
                      color: _isGattConnected
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
                                  _isGattConnected
                                      ? Icons.check_circle
                                      : Icons.error,
                                  color: _isGattConnected
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isGattConnected ? 'Connecté' : 'Déconnecté',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _isGattConnected
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Notify: ${_isNotifySubscribed ? 'actif' : 'en attente'}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            if (_lastNotifyAt != null)
                              Text(
                                'Dernière trame: ${_lastNotifyAt!.toIso8601String()} (Δ ${_bleDeltaMs} ms)',
                                style: const TextStyle(fontSize: 12),
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
