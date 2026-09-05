import 'package:aonw_engine_client/aonw_engine_client.dart';

import '../../map/read_model/map_view.dart';
import '../../map/read_model/player_map_view.dart';
import '../read_model/combat_view.dart';

final class CombatViewMapper {
  const CombatViewMapper();

  CombatPreviewView preview(
    AonwCombatPreviewResult wire, {
    required MapView map,
    required String attackerUnitId,
    required MapHexCoordinate defender,
    required int expectedRevision,
  }) {
    _validateStamp(wire.stamp, map: map, revision: expectedRevision);
    if (wire.preview.attackerUnitId != attackerUnitId ||
        !map.contains(defender)) {
      throw const FormatException('Combat preview mismatches its request.');
    }
    return _preview(wire.preview, _stamp(wire.stamp), defender);
  }

  ({CombatExecutionView? execution, CombatRejectionCodeView? rejection})
  command(
    AonwCommandResult wire, {
    required MapView map,
    required CombatAttackView attack,
    required int expectedRevision,
    required int currentRevision,
  }) {
    _validateStamp(
      wire.stamp,
      map: map,
      revision: wire.accepted ? expectedRevision + 1 : currentRevision,
    );
    if (!wire.accepted) return _rejected(wire);
    final evidence = wire.evidence;
    if (wire.rejection != null || evidence is! AonwCombatEvidence) {
      throw const FormatException('Accepted combat result is incomplete.');
    }
    final executionPreview = _preview(
      evidence.execution.preview,
      _stamp(wire.stamp),
      attack.preview.defenderCoordinate,
    );
    if (!_samePreview(attack.preview, executionPreview)) {
      throw const FormatException('Combat evidence mismatches its preview.');
    }
    final events = _events(wire.events);
    if (!events.contains(CombatEventKindView.combatResolved)) {
      throw const FormatException('Combat result has no resolution event.');
    }
    return (
      execution: CombatExecutionView(
        defenderRetaliated: evidence.execution.defenderRetaliated,
        revision: wire.stamp.revision,
        preview: executionPreview,
        outcome: _outcome(evidence.execution.outcome, map),
        events: events,
      ),
      rejection: null,
    );
  }

  static ({CombatExecutionView? execution, CombatRejectionCodeView? rejection})
  _rejected(AonwCommandResult wire) {
    if (wire.rejection == null ||
        wire.events.isNotEmpty ||
        wire.evidence != null) {
      throw const FormatException('Rejected combat result has residue.');
    }
    final rejection = _rejections[wire.rejection!];
    if (rejection == null) {
      throw const FormatException('Unrelated combat rejection code.');
    }
    return (execution: null, rejection: rejection);
  }
}

CombatPreviewView _preview(
  AonwCombatPreview value,
  SessionStampView stamp,
  MapHexCoordinate defender,
) => CombatPreviewView(
  stamp: stamp,
  attackerUnitId: value.attackerUnitId,
  defenderCoordinate: defender,
  target: switch (value.target) {
    AonwUnitCombatTarget(:final unitId) => CombatTargetView(
      kind: CombatTargetKindView.unit,
      id: unitId,
    ),
    AonwCityCombatTarget(:final cityId) => CombatTargetView(
      kind: CombatTargetKindView.city,
      id: cityId,
    ),
  },
  distance: value.distance,
  attacker: _stats(value.attacker),
  defender: _stats(value.defender),
  outgoingDamageMin: value.outgoingDamageMin,
  outgoingDamageMax: value.outgoingDamageMax,
  retaliationDamageMin: value.retaliationDamageMin,
  retaliationDamageMax: value.retaliationDamageMax,
);

CombatStatsView _stats(AonwCombatStats value) => CombatStatsView(
  attack: value.attack,
  defense: value.defense,
  hitPoints: value.hitPoints,
  range: value.range,
  mobility: value.mobility,
  modifiers: [
    for (final modifier in value.modifiers)
      CombatModifierView(
        kind: CombatModifierKindView.values.byName(modifier.kind.name),
        label: modifier.label,
        target: CombatStatTargetView.values.byName(modifier.target.name),
        delta: modifier.delta,
      ),
  ],
);

CombatOutcomeView _outcome(AonwCombatOutcome value, MapView map) =>
    CombatOutcomeView(
      attackerHitPoints: value.attackerHitPoints,
      defenderHitPoints: value.defenderHitPoints,
      attackerKilled: value.attackerKilled,
      defenderKilled: value.defenderKilled,
      defenderRetreat: value.defenderRetreat == null
          ? null
          : _coordinate(value.defenderRetreat!, map),
      outgoingDamage: value.outgoingDamage,
      retaliationDamage: value.retaliationDamage,
    );

List<CombatEventKindView> _events(List<AonwClientEvent> source) {
  final result = <CombatEventKindView>[];
  for (final event in source) {
    final mapped = _combatEvents[event.kind];
    if (mapped == null) {
      throw const FormatException('Unrelated event in combat result.');
    }
    result.add(mapped);
  }
  return result;
}

const _combatEvents = <AonwClientEventKind, CombatEventKindView>{
  AonwClientEventKind.unitAttacked: CombatEventKindView.unitAttacked,
  AonwClientEventKind.cityAttacked: CombatEventKindView.cityAttacked,
  AonwClientEventKind.combatResolved: CombatEventKindView.combatResolved,
  AonwClientEventKind.unitGainedExperience:
      CombatEventKindView.unitGainedExperience,
  AonwClientEventKind.unitKilled: CombatEventKindView.unitKilled,
  AonwClientEventKind.unitRetreated: CombatEventKindView.unitRetreated,
  AonwClientEventKind.cityCaptured: CombatEventKindView.cityCaptured,
  AonwClientEventKind.cityDestroyed: CombatEventKindView.cityDestroyed,
  AonwClientEventKind.diplomaticScoreChanged:
      CombatEventKindView.diplomaticScoreChanged,
};

bool _samePreview(CombatPreviewView left, CombatPreviewView right) =>
    left.attackerUnitId == right.attackerUnitId &&
    left.defenderCoordinate == right.defenderCoordinate &&
    left.target.kind == right.target.kind &&
    left.target.id == right.target.id &&
    left.distance == right.distance &&
    left.outgoingDamageMin == right.outgoingDamageMin &&
    left.outgoingDamageMax == right.outgoingDamageMax &&
    left.retaliationDamageMin == right.retaliationDamageMin &&
    left.retaliationDamageMax == right.retaliationDamageMax;

SessionStampView _stamp(AonwSessionStamp value) => SessionStampView(
  revision: value.revision,
  stateDigest: value.stateDigest,
  mapHash: value.mapHash,
  rulesetHash: value.rulesetHash,
);

MapHexCoordinate _coordinate(AonwCoordinate value, MapView map) {
  final coordinate = (col: value.col, row: value.row);
  if (!map.contains(coordinate)) {
    throw const FormatException('Combat coordinate is outside the map.');
  }
  return coordinate;
}

void _validateStamp(
  AonwSessionStamp value, {
  required MapView map,
  required int revision,
}) {
  final digest = RegExp(r'^[0-9a-f]{64}$');
  if (value.revision != revision ||
      value.mapHash != map.contentHash ||
      !digest.hasMatch(value.stateDigest) ||
      !digest.hasMatch(value.mapHash) ||
      !digest.hasMatch(value.rulesetHash)) {
    throw const FormatException('Combat session identity is stale.');
  }
}

const _rejections = <AonwCommandRejectionCode, CombatRejectionCodeView>{
  AonwCommandRejectionCode.staleRevision: CombatRejectionCodeView.staleRevision,
  AonwCommandRejectionCode.matchFinished: CombatRejectionCodeView.matchFinished,
  AonwCommandRejectionCode.attackerNotFound:
      CombatRejectionCodeView.attackerNotFound,
  AonwCommandRejectionCode.attackerNotControlled:
      CombatRejectionCodeView.attackerNotControlled,
  AonwCommandRejectionCode.attackerUnavailable:
      CombatRejectionCodeView.attackerUnavailable,
  AonwCommandRejectionCode.attackerExhausted:
      CombatRejectionCodeView.attackerExhausted,
  AonwCommandRejectionCode.attackerOutOfBounds:
      CombatRejectionCodeView.attackerOutOfBounds,
  AonwCommandRejectionCode.attackerCannotAttack:
      CombatRejectionCodeView.attackerCannotAttack,
  AonwCommandRejectionCode.attackTargetNotVisible:
      CombatRejectionCodeView.attackTargetNotVisible,
  AonwCommandRejectionCode.attackTargetOutOfBounds:
      CombatRejectionCodeView.attackTargetOutOfBounds,
  AonwCommandRejectionCode.attackTargetNotFound:
      CombatRejectionCodeView.attackTargetNotFound,
  AonwCommandRejectionCode.attackTargetNotEnemy:
      CombatRejectionCodeView.attackTargetNotEnemy,
  AonwCommandRejectionCode.attackTargetProtectedByTreaty:
      CombatRejectionCodeView.attackTargetProtectedByTreaty,
  AonwCommandRejectionCode.attackTargetOutOfRange:
      CombatRejectionCodeView.attackTargetOutOfRange,
  AonwCommandRejectionCode.attackCityHasNoHealth:
      CombatRejectionCodeView.attackCityHasNoHealth,
};
