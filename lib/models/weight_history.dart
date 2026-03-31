import 'package:hive/hive.dart';

part 'weight_history.g.dart';

@HiveType(typeId: 0)
class WeightHistory {
  @HiveField(0)
  final double weight;

  @HiveField(1)
  final DateTime timestamp;

  WeightHistory({
    required this.weight,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory WeightHistory.fromMap(Map<String, dynamic> map) => WeightHistory(
    weight: map['weight'],
    timestamp: DateTime.parse(map['timestamp']),
  );

  Map<String, dynamic> toMap() => {
    'weight': weight,
    'timestamp': timestamp.toIso8601String(),
  };
}