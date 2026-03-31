// lib/state/pads_config_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pad.dart';
import '../models/pad_config.dart';
import '../utils/storage.dart';

final padsConfigProvider =
    StateNotifierProvider<PadsConfigNotifier, Map<Pad, PadConfig>>((ref) {
      return PadsConfigNotifier();
    });

class PadsConfigNotifier extends StateNotifier<Map<Pad, PadConfig>> {
  PadsConfigNotifier() : super({for (final p in Pad.values) p: PadConfig()}) {
    _load();
  }

  Future<void> _load() async {
    final loaded = await PadStorage.load();
    state = loaded;
  }

  Future<void> save() async => PadStorage.save(state);

  void updatePad(Pad pad, PadConfig config) {
    final next = Map<Pad, PadConfig>.from(state);
    next[pad] = config;
    state = next;
    save();
  }

  void updateConfig(Map<Pad, PadConfig> next) {
    state = next;
    save();
  }

  Map<Pad, PadConfig> getConfig() => state;
}
