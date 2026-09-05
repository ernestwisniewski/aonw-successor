import '../../features/map/read_model/map_view.dart';

sealed class FlameCommandTransition {
  const FlameCommandTransition({this.eventIndex = -1});
  final int eventIndex;
}

final class FlameCombatTransition extends FlameCommandTransition {
  const FlameCombatTransition({
    required this.attacker,
    required this.defender,
    required this.revision,
    required this.eventCount,
    required this.outgoingDamage,
    required this.retaliationDamage,
    required this.attackerKilled,
    required this.defenderKilled,
    required this.attackerUnitId,
    required this.defenderUnitId,
    required this.defenderRetaliated,
    super.eventIndex,
  });

  final MapHexCoordinate attacker;
  final MapHexCoordinate defender;
  final int revision;
  final int eventCount;
  final int outgoingDamage;
  final int retaliationDamage;
  final bool attackerKilled;
  final bool defenderKilled;
  final String attackerUnitId;
  final String? defenderUnitId;
  final bool defenderRetaliated;
  bool get defenderIsCity => defenderUnitId == null;
}

final class FlameUnitMovementTransition extends FlameCommandTransition {
  const FlameUnitMovementTransition({
    required this.unitId,
    required this.from,
    required this.to,
    required this.fromRevision,
    required this.toRevision,
    this.path = const [],
    super.eventIndex,
  });

  final String unitId;
  final MapHexCoordinate from;
  final MapHexCoordinate to;
  final int fromRevision;
  final int toRevision;
  final List<MapHexCoordinate> path;
}
