import 'package:aonw_engine_client/aonw_engine_client.dart';

import '../read_model/map_command_animation_view.dart';
import '../read_model/map_view.dart';
import '../read_model/player_map_view.dart';
import 'map_feedback_positions.dart';
import 'map_movement_evidence_index.dart';

List<MapCommandAnimationView> mapCommandAnimations({
  required AonwCommandResult command,
  required PlayerMapView previous,
  required PlayerMapView next,
  required MapView map,
}) {
  if (!command.accepted || next.stamp.revision == previous.stamp.revision) {
    return const [];
  }
  final positions = MapFeedbackPositions(
    previous,
    command.evidence,
    command.events,
  );
  final movements = MapMovementEvidenceIndex(command.evidence, command.events);
  final cities = {
    for (final city in [...next.cities, ...previous.cities])
      city.id: city.center,
  };
  final animations = <MapCommandAnimationView>[];
  for (var index = 0; index < command.events.length; index++) {
    final animation = _animation(
      command.events[index],
      index,
      positions,
      movements,
      cities,
      map,
    );
    if (animation != null) animations.add(animation);
  }
  return animations;
}

MapCommandAnimationView? _animation(
  AonwClientEvent event,
  int index,
  MapFeedbackPositions positions,
  MapMovementEvidenceIndex movements,
  Map<String, MapHexCoordinate> cities,
  MapView map,
) {
  if (event is AonwUnitRetreatedEvent) {
    final from = positions.coordinateOf(event.subjectUnitId);
    final to = positions.advance(event);
    return from == null || to == null
        ? null
        : _retreat(event, from, to, index, map);
  }
  positions.advance(event);
  return switch (event) {
    AonwUnitMovedEvent() => _movement(movements.take(event), index, map),
    AonwCombatResolvedEvent() => _combat(positions, cities, index, map),
    _ => null,
  };
}

MapCommandMovementView? _movement(
  AonwUnitMovementExecution? execution,
  int index,
  MapView map,
) {
  if (execution == null) return null;
  final path = [
    _coordinate(execution.from, map),
    for (final step in execution.steps) _coordinate(step.coordinate, map),
  ];
  return MapCommandMovementView(
    eventIndex: index,
    unitId: execution.unitId,
    path: path,
  );
}

MapCommandCombatView? _combat(
  MapFeedbackPositions positions,
  Map<String, MapHexCoordinate> cities,
  int index,
  MapView map,
) {
  final execution = positions.combat;
  if (execution == null) return null;
  MapHexCoordinate? unit(String id) => positions.coordinateOf(id);
  final attacker = unit(execution.preview.attackerUnitId);
  final defender = switch (execution.preview.target) {
    AonwUnitCombatTarget(:final unitId) => unit(unitId),
    AonwCityCombatTarget(:final cityId) => cities[cityId],
  };
  if (attacker == null || defender == null) return null;
  if (!map.contains(attacker) || !map.contains(defender)) {
    throw const FormatException('Observed combat is outside the map.');
  }
  return MapCommandCombatView(
    eventIndex: index,
    attacker: attacker,
    defender: defender,
    outgoingDamage: execution.outcome.outgoingDamage,
    retaliationDamage: execution.outcome.retaliationDamage,
    attackerKilled: execution.outcome.attackerKilled,
    defenderKilled: execution.outcome.defenderKilled,
    attackerUnitId: execution.preview.attackerUnitId,
    defenderUnitId: switch (execution.preview.target) {
      AonwUnitCombatTarget(:final unitId) => unitId,
      AonwCityCombatTarget() => null,
    },
    defenderRetaliated: execution.defenderRetaliated,
  );
}

MapCommandMovementView _retreat(
  AonwUnitRetreatedEvent event,
  MapHexCoordinate from,
  MapHexCoordinate to,
  int index,
  MapView map,
) {
  if (!map.contains(from) || !map.contains(to)) {
    throw const FormatException('Observed retreat is outside the map.');
  }
  return MapCommandMovementView(
    eventIndex: index,
    unitId: event.subjectUnitId,
    path: [from, to],
  );
}

MapHexCoordinate _coordinate(AonwCoordinate wire, MapView map) {
  final coordinate = (col: wire.col, row: wire.row);
  if (!map.contains(coordinate)) {
    throw const FormatException('Observed movement is outside the map.');
  }
  return coordinate;
}
