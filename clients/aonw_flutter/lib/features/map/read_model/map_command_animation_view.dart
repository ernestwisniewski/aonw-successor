import 'map_view.dart';

sealed class MapCommandAnimationView {
  const MapCommandAnimationView({required this.eventIndex});

  final int eventIndex;
}

final class MapCommandMovementView extends MapCommandAnimationView {
  MapCommandMovementView({
    required super.eventIndex,
    required this.unitId,
    required List<MapHexCoordinate> path,
  }) : path = List.unmodifiable(path);

  final String unitId;

  /// Executed coordinates, including the origin; never a queued route.
  final List<MapHexCoordinate> path;
}

final class MapCommandCombatView extends MapCommandAnimationView {
  const MapCommandCombatView({
    required super.eventIndex,
    required this.attacker,
    required this.defender,
    required this.outgoingDamage,
    required this.retaliationDamage,
    required this.attackerKilled,
    required this.defenderKilled,
    required this.attackerUnitId,
    required this.defenderUnitId,
    required this.defenderRetaliated,
  });

  final MapHexCoordinate attacker;
  final MapHexCoordinate defender;
  final int outgoingDamage;
  final int retaliationDamage;
  final bool attackerKilled;
  final bool defenderKilled;
  final String attackerUnitId;
  final String? defenderUnitId;
  final bool defenderRetaliated;
  bool get defenderIsCity => defenderUnitId == null;
}
