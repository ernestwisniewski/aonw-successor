import '../../map/read_model/map_view.dart';
import '../../map/read_model/player_map_view.dart';

enum CombatTargetKindView { unit, city }

final class CombatTargetView {
  const CombatTargetView({required this.kind, required this.id});

  final CombatTargetKindView kind;
  final String id;
}

enum CombatStatTargetView { attack, defense, hitPoints }

enum CombatModifierKindView {
  terrain,
  fortification,
  technology,
  counter,
  troopComposition,
  veterancy,
}

final class CombatModifierView {
  const CombatModifierView({
    required this.kind,
    required this.label,
    required this.target,
    required this.delta,
  });

  final CombatModifierKindView kind;
  final String label;
  final CombatStatTargetView target;
  final int delta;
}

final class CombatStatsView {
  CombatStatsView({
    required this.attack,
    required this.defense,
    required this.hitPoints,
    required this.range,
    required this.mobility,
    required List<CombatModifierView> modifiers,
  }) : modifiers = List.unmodifiable(modifiers);

  final int attack;
  final int defense;
  final int hitPoints;
  final int range;
  final int mobility;
  final List<CombatModifierView> modifiers;
}

final class CombatPreviewView {
  const CombatPreviewView({
    required this.stamp,
    required this.attackerUnitId,
    required this.defenderCoordinate,
    required this.target,
    required this.distance,
    required this.attacker,
    required this.defender,
    required this.outgoingDamageMin,
    required this.outgoingDamageMax,
    required this.retaliationDamageMin,
    required this.retaliationDamageMax,
  });

  final SessionStampView stamp;
  final String attackerUnitId;
  final MapHexCoordinate defenderCoordinate;
  final CombatTargetView target;
  final int distance;
  final CombatStatsView attacker;
  final CombatStatsView defender;
  final int outgoingDamageMin;
  final int outgoingDamageMax;
  final int? retaliationDamageMin;
  final int? retaliationDamageMax;
}

enum CityConquestActionView { capture, destroy }

final class CombatAttackView {
  const CombatAttackView({
    required this.preview,
    required this.cityConquestAction,
  });

  final CombatPreviewView preview;
  final CityConquestActionView cityConquestAction;
}

enum CombatEventKindView {
  unitAttacked,
  cityAttacked,
  combatResolved,
  unitGainedExperience,
  unitKilled,
  unitRetreated,
  cityCaptured,
  cityDestroyed,
  diplomaticScoreChanged,
}

final class CombatOutcomeView {
  const CombatOutcomeView({
    required this.attackerHitPoints,
    required this.defenderHitPoints,
    required this.attackerKilled,
    required this.defenderKilled,
    required this.defenderRetreat,
    required this.outgoingDamage,
    required this.retaliationDamage,
  });

  final int attackerHitPoints;
  final int defenderHitPoints;
  final bool attackerKilled;
  final bool defenderKilled;
  final MapHexCoordinate? defenderRetreat;
  final int outgoingDamage;
  final int retaliationDamage;
}

final class CombatExecutionView {
  CombatExecutionView({
    required this.defenderRetaliated,
    required this.revision,
    required this.preview,
    required this.outcome,
    required List<CombatEventKindView> events,
  }) : events = List.unmodifiable(events);

  final int revision;
  final CombatPreviewView preview;
  final CombatOutcomeView outcome;
  final List<CombatEventKindView> events;
  final bool defenderRetaliated;
}

enum CombatRejectionCodeView {
  staleRevision,
  matchFinished,
  attackerNotFound,
  attackerNotControlled,
  attackerUnavailable,
  attackerExhausted,
  attackerOutOfBounds,
  attackerCannotAttack,
  attackTargetNotVisible,
  attackTargetOutOfBounds,
  attackTargetNotFound,
  attackTargetNotEnemy,
  attackTargetProtectedByTreaty,
  attackTargetOutOfRange,
  attackCityHasNoHealth,
}

final class CombatCommandResultView {
  const CombatCommandResultView.accepted({
    required this.player,
    required this.execution,
  }) : accepted = true,
       rejectionCode = null;

  const CombatCommandResultView.rejected({required this.rejectionCode})
    : accepted = false,
      player = null,
      execution = null;

  final bool accepted;
  final CombatRejectionCodeView? rejectionCode;
  final PlayerMapView? player;
  final CombatExecutionView? execution;
}
