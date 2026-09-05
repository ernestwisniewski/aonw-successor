import '../../features/artifacts/read_model/artifact_view.dart';
import '../../features/cities/read_model/city_view.dart';
import '../../features/combat/read_model/combat_view.dart';
import '../../features/map/presentation/map_render_snapshot.dart';
import '../../features/map/read_model/map_view.dart';
import '../../features/map/read_model/player_map_view.dart';
import '../../features/workers/read_model/worker_view.dart';
import 'flame_city_equality.dart';
import 'flame_command_transition.dart';
import 'flame_observed_command.dart';

export 'flame_command_transition.dart';

/// The presentation-only delta between two validated map snapshots.
///
/// Observed commands carry executed paths. A route preview is never promoted to
/// an animation path here.
final class FlameScenePatch {
  FlameScenePatch._({
    required this.snapshot,
    required List<VisibleUnitView> unitUpserts,
    required List<String> removedUnitIds,
    required List<CityView> cityUpserts,
    required List<String> removedCityIds,
    required List<WorldArtifactView> artifactUpserts,
    required List<String> removedArtifactIds,
    required List<FieldImprovementView> fieldImprovementUpserts,
    required List<MapHexCoordinate> removedFieldImprovementCoordinates,
    required List<RoadView> roadUpserts,
    required List<MapHexCoordinate> removedRoadCoordinates,
    required List<FlameUnitMovementTransition> movements,
    required List<FlameCombatTransition> combats,
    this.hasObservedCommand = false,
  }) : unitUpserts = List.unmodifiable(unitUpserts),
       removedUnitIds = List.unmodifiable(removedUnitIds),
       cityUpserts = List.unmodifiable(cityUpserts),
       removedCityIds = List.unmodifiable(removedCityIds),
       artifactUpserts = List.unmodifiable(artifactUpserts),
       removedArtifactIds = List.unmodifiable(removedArtifactIds),
       fieldImprovementUpserts = List.unmodifiable(fieldImprovementUpserts),
       removedFieldImprovementCoordinates = List.unmodifiable(
         removedFieldImprovementCoordinates,
       ),
       roadUpserts = List.unmodifiable(roadUpserts),
       removedRoadCoordinates = List.unmodifiable(removedRoadCoordinates),
       movements = List.unmodifiable(movements),
       combats = List.unmodifiable(combats);

  factory FlameScenePatch.between(
    MapRenderSnapshot? previous,
    MapRenderSnapshot next,
  ) {
    if (previous == null || !_sameMap(previous, next)) {
      return _replacement(previous, next);
    }
    final previousUnits = _unitsById(previous);
    final nextUnits = _unitsById(next);
    final previousCities = _citiesById(previous);
    final nextCities = _citiesById(next);
    final previousArtifacts = _artifactsById(previous);
    final nextArtifacts = _artifactsById(next);
    final previousImprovements = _improvementsByCoordinate(previous);
    final nextImprovements = _improvementsByCoordinate(next);
    final previousRoads = _roadsByCoordinate(previous);
    final nextRoads = _roadsByCoordinate(next);

    return FlameScenePatch._(
      snapshot: next,
      unitUpserts: _unitUpserts(previous, next, previousUnits),
      removedUnitIds: _removedUnitIds(previous, nextUnits),
      cityUpserts: _cityUpserts(previous, next, previousCities),
      removedCityIds: _removedCityIds(previous, nextCities),
      artifactUpserts: [
        for (final artifact in next.player.artifacts)
          if (!_sameArtifact(previousArtifacts[artifact.id], artifact))
            artifact,
      ],
      removedArtifactIds: [
        for (final artifact in previous.player.artifacts)
          if (!nextArtifacts.containsKey(artifact.id)) artifact.id,
      ],
      fieldImprovementUpserts: [
        for (final improvement in next.player.fieldImprovements)
          if (!_sameFlameImprovement(
            previousImprovements[improvement.coordinate],
            improvement,
          ))
            improvement,
      ],
      removedFieldImprovementCoordinates: [
        for (final improvement in previous.player.fieldImprovements)
          if (!nextImprovements.containsKey(improvement.coordinate))
            improvement.coordinate,
      ],
      roadUpserts: [
        for (final road in next.player.roads)
          if (!_sameRoad(previousRoads[road.coordinate], road)) road,
      ],
      removedRoadCoordinates: [
        for (final road in previous.player.roads)
          if (!nextRoads.containsKey(road.coordinate)) road.coordinate,
      ],
      movements: _movementBetween(previous, next, previousUnits, nextUnits),
      combats: _combatBetween(previous, next, previousUnits, nextUnits),
      hasObservedCommand: isFlameObservedAdvance(previous, next),
    );
  }

  final MapRenderSnapshot snapshot;
  final List<VisibleUnitView> unitUpserts;
  final List<String> removedUnitIds;
  final List<CityView> cityUpserts;
  final List<String> removedCityIds;
  final List<WorldArtifactView> artifactUpserts;
  final List<String> removedArtifactIds;
  final List<FieldImprovementView> fieldImprovementUpserts;
  final List<MapHexCoordinate> removedFieldImprovementCoordinates;
  final List<RoadView> roadUpserts;
  final List<MapHexCoordinate> removedRoadCoordinates;
  final List<FlameUnitMovementTransition> movements;
  final List<FlameCombatTransition> combats;
  final bool hasObservedCommand;

  static FlameScenePatch _replacement(
    MapRenderSnapshot? previous,
    MapRenderSnapshot next,
  ) => FlameScenePatch._(
    snapshot: next,
    unitUpserts: next.player.units,
    removedUnitIds:
        previous?.player.units.map((unit) => unit.id).toList() ?? const [],
    movements: const [],
    cityUpserts: next.player.cities,
    removedCityIds:
        previous?.player.cities.map((city) => city.id).toList() ?? const [],
    artifactUpserts: next.player.artifacts,
    removedArtifactIds:
        previous?.player.artifacts.map((artifact) => artifact.id).toList() ??
        const [],
    fieldImprovementUpserts: next.player.fieldImprovements,
    removedFieldImprovementCoordinates:
        previous?.player.fieldImprovements
            .map((value) => value.coordinate)
            .toList() ??
        const [],
    roadUpserts: next.player.roads,
    removedRoadCoordinates:
        previous?.player.roads.map((value) => value.coordinate).toList() ??
        const [],
    combats: const [],
  );

  static Map<String, VisibleUnitView> _unitsById(MapRenderSnapshot snapshot) =>
      {for (final unit in snapshot.player.units) unit.id: unit};

  static Map<String, CityView> _citiesById(MapRenderSnapshot snapshot) => {
    for (final city in snapshot.player.cities) city.id: city,
  };

  static Map<String, WorldArtifactView> _artifactsById(
    MapRenderSnapshot snapshot,
  ) => {
    for (final artifact in snapshot.player.artifacts) artifact.id: artifact,
  };

  static Map<MapHexCoordinate, FieldImprovementView> _improvementsByCoordinate(
    MapRenderSnapshot snapshot,
  ) => {
    for (final value in snapshot.player.fieldImprovements)
      value.coordinate: value,
  };

  static Map<MapHexCoordinate, RoadView> _roadsByCoordinate(
    MapRenderSnapshot snapshot,
  ) => {for (final value in snapshot.player.roads) value.coordinate: value};

  static List<VisibleUnitView> _unitUpserts(
    MapRenderSnapshot previous,
    MapRenderSnapshot next,
    Map<String, VisibleUnitView> previousUnits,
  ) {
    final actorChanged =
        previous.player.actorPlayerId != next.player.actorPlayerId;
    return [
      for (final unit in next.player.units)
        if (actorChanged || _unitChanged(previousUnits[unit.id], unit)) unit,
    ];
  }

  static bool _unitChanged(VisibleUnitView? before, VisibleUnitView next) =>
      before == null || !_sameFlameUnit(before, next);

  static List<String> _removedUnitIds(
    MapRenderSnapshot previous,
    Map<String, VisibleUnitView> nextUnits,
  ) => [
    for (final unit in previous.player.units)
      if (!nextUnits.containsKey(unit.id)) unit.id,
  ];

  static List<CityView> _cityUpserts(
    MapRenderSnapshot previous,
    MapRenderSnapshot next,
    Map<String, CityView> previousCities,
  ) {
    final actorChanged =
        previous.player.actorPlayerId != next.player.actorPlayerId;
    return [
      for (final city in next.player.cities)
        if (actorChanged || !_sameCity(previousCities[city.id], city)) city,
    ];
  }

  static List<String> _removedCityIds(
    MapRenderSnapshot previous,
    Map<String, CityView> nextCities,
  ) => [
    for (final city in previous.player.cities)
      if (!nextCities.containsKey(city.id)) city.id,
  ];

  static List<FlameUnitMovementTransition> _movementBetween(
    MapRenderSnapshot previous,
    MapRenderSnapshot next,
    Map<String, VisibleUnitView> previousUnits,
    Map<String, VisibleUnitView> nextUnits,
  ) {
    if (next.commandFrame != null) {
      return observedFlameMovements(previous, next);
    }
    final unitId = previous.interaction.movementPending
        ? previous.interaction.selectedUnitId
        : null;
    if (unitId == null || !_isAuthoritativeAdvance(previous, next)) {
      return const [];
    }
    final before = previousUnits[unitId];
    final after = nextUnits[unitId];
    if (before == null ||
        after == null ||
        before.coordinate == after.coordinate) {
      return const [];
    }
    return [
      FlameUnitMovementTransition(
        unitId: unitId,
        from: before.coordinate,
        to: after.coordinate,
        fromRevision: previous.player.stamp.revision,
        toRevision: next.player.stamp.revision,
      ),
    ];
  }

  static bool _isAuthoritativeAdvance(
    MapRenderSnapshot previous,
    MapRenderSnapshot next,
  ) =>
      next.player.actorPlayerId == previous.player.actorPlayerId &&
      next.player.stamp.revision > previous.player.stamp.revision &&
      next.player.stamp.stateDigest != previous.player.stamp.stateDigest &&
      next.player.stamp.mapHash == previous.player.stamp.mapHash &&
      next.player.stamp.rulesetHash == previous.player.stamp.rulesetHash;

  static List<FlameCombatTransition> _combatBetween(
    MapRenderSnapshot previous,
    MapRenderSnapshot next,
    Map<String, VisibleUnitView> previousUnits,
    Map<String, VisibleUnitView> nextUnits,
  ) {
    if (next.commandFrame != null) return observedFlameCombats(previous, next);
    final execution = next.interaction.combat?.lastExecution;
    if (execution == null ||
        execution.revision ==
            previous.interaction.combat?.lastExecution?.revision ||
        execution.revision != next.player.stamp.revision ||
        !_isAuthoritativeAdvance(previous, next)) {
      return const [];
    }
    final attackerId = execution.preview.attackerUnitId;
    final attacker = previousUnits[attackerId] ?? nextUnits[attackerId];
    if (attacker == null) return const [];
    return [
      FlameCombatTransition(
        attacker: attacker.coordinate,
        defender: execution.preview.defenderCoordinate,
        revision: execution.revision,
        eventCount: execution.events.length,
        outgoingDamage: execution.outcome.outgoingDamage,
        retaliationDamage: execution.outcome.retaliationDamage,
        attackerKilled: execution.outcome.attackerKilled,
        defenderKilled: execution.outcome.defenderKilled,
        attackerUnitId: attackerId,
        defenderUnitId:
            execution.preview.target.kind == CombatTargetKindView.unit
            ? execution.preview.target.id
            : null,
        defenderRetaliated: execution.defenderRetaliated,
      ),
    ];
  }

  static bool _sameMap(MapRenderSnapshot previous, MapRenderSnapshot next) =>
      previous.map.mapId == next.map.mapId &&
      previous.map.contentHash == next.map.contentHash &&
      previous.map.cols == next.map.cols &&
      previous.map.rows == next.map.rows;

  static bool _sameCity(CityView? left, CityView right) =>
      sameFlameCity(left, right);

  static bool _sameRoad(RoadView? left, RoadView right) =>
      left != null && left.condition == right.condition;

  static bool _sameArtifact(WorldArtifactView? left, WorldArtifactView right) =>
      left != null &&
      left.id == right.id &&
      left.kind == right.kind &&
      _sameArtifactLocation(left.location, right.location);

  static bool _sameArtifactLocation(
    ArtifactLocationView left,
    ArtifactLocationView right,
  ) => switch ((left, right)) {
    (
      MapArtifactLocationView(coordinate: final leftCoordinate),
      MapArtifactLocationView(coordinate: final rightCoordinate),
    ) =>
      leftCoordinate == rightCoordinate,
    (
      CarriedArtifactLocationView(unitId: final leftUnitId),
      CarriedArtifactLocationView(unitId: final rightUnitId),
    ) =>
      leftUnitId == rightUnitId,
    (
      StoredArtifactLocationView(cityId: final leftCityId),
      StoredArtifactLocationView(cityId: final rightCityId),
    ) =>
      leftCityId == rightCityId,
    (
      ExcavationArtifactLocationView(
        unitId: final leftUnitId,
        coordinate: final leftCoordinate,
        remainingTurns: final leftRemainingTurns,
      ),
      ExcavationArtifactLocationView(
        unitId: final rightUnitId,
        coordinate: final rightCoordinate,
        remainingTurns: final rightRemainingTurns,
      ),
    ) =>
      leftUnitId == rightUnitId &&
          leftCoordinate == rightCoordinate &&
          leftRemainingTurns == rightRemainingTurns,
    _ => false,
  };
}

bool _sameFlameUnit(VisibleUnitView left, VisibleUnitView right) =>
    (
          left.id,
          left.ownerPlayerId,
          left.kind,
          left.name,
          left.coordinate,
          left.movementUnits,
          left.posture,
          left.hitPoints,
          left.maximumHitPoints,
          left.queuedTarget,
          left.merchantRouteDestinationCityId,
          left.carriedArtifactId,
          left.excavatingArtifactId,
          left.workerBuildCharges,
          left.workerAssignment,
          left.cityFoundingRemainingTurns,
        ) ==
        (
          right.id,
          right.ownerPlayerId,
          right.kind,
          right.name,
          right.coordinate,
          right.movementUnits,
          right.posture,
          right.hitPoints,
          right.maximumHitPoints,
          right.queuedTarget,
          right.merchantRouteDestinationCityId,
          right.carriedArtifactId,
          right.excavatingArtifactId,
          right.workerBuildCharges,
          right.workerAssignment,
          right.cityFoundingRemainingTurns,
        ) &&
    _sameFlameArmy(left.army, right.army) &&
    _sameFlameWorkerJob(left.workerJob, right.workerJob);

bool _sameFlameArmy(
  List<VisibleArmyTroopView> left,
  List<VisibleArmyTroopView> right,
) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index].kind != right[index].kind ||
        left[index].count != right[index].count) {
      return false;
    }
  }
  return true;
}

bool _sameFlameImprovement(
  FieldImprovementView? left,
  FieldImprovementView right,
) =>
    left != null &&
    (left.improvement, left.eraColumn) == (right.improvement, right.eraColumn);

bool _sameFlameWorkerJob(WorkerJobView? left, WorkerJobView? right) {
  if (left == null || right == null) return left == right;
  if (left.target != right.target ||
      left.remainingTurns != right.remainingTurns ||
      left.totalTurns != right.totalTurns) {
    return false;
  }
  return switch ((left, right)) {
    (
      FieldImprovementJobView(improvement: final leftImprovement),
      FieldImprovementJobView(improvement: final rightImprovement),
    ) =>
      leftImprovement == rightImprovement,
    (RoadConstructionJobView(), RoadConstructionJobView()) => true,
    _ => false,
  };
}
