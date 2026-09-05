import '../../features/map/presentation/map_render_snapshot.dart';
import '../../features/map/read_model/map_command_animation_view.dart';
import 'flame_command_transition.dart';

bool isFlameObservedAdvance(
  MapRenderSnapshot previous,
  MapRenderSnapshot next,
) =>
    next.commandFrame != null &&
    identical(next.commandFrame!.player, next.player) &&
    next.effectEpoch == previous.effectEpoch &&
    next.player.actorPlayerId == previous.player.actorPlayerId &&
    next.player.stamp.revision == previous.player.stamp.revision + 1 &&
    next.player.stamp.stateDigest != previous.player.stamp.stateDigest &&
    next.player.stamp.mapHash == previous.player.stamp.mapHash &&
    next.player.stamp.rulesetHash == previous.player.stamp.rulesetHash;

List<FlameUnitMovementTransition> observedFlameMovements(
  MapRenderSnapshot previous,
  MapRenderSnapshot next,
) => [
  if (isFlameObservedAdvance(previous, next))
    for (final movement
        in next.commandFrame!.animations.whereType<MapCommandMovementView>())
      if (movement.path.length >= 2)
        FlameUnitMovementTransition(
          unitId: movement.unitId,
          from: movement.path.first,
          to: movement.path.last,
          fromRevision: previous.player.stamp.revision,
          toRevision: next.player.stamp.revision,
          path: movement.path,
          eventIndex: movement.eventIndex,
        ),
];

List<FlameCombatTransition> observedFlameCombats(
  MapRenderSnapshot previous,
  MapRenderSnapshot next,
) => [
  if (isFlameObservedAdvance(previous, next))
    for (final combat
        in next.commandFrame!.animations.whereType<MapCommandCombatView>())
      FlameCombatTransition(
        attacker: combat.attacker,
        defender: combat.defender,
        revision: next.player.stamp.revision,
        eventCount: 1,
        outgoingDamage: combat.outgoingDamage,
        retaliationDamage: combat.retaliationDamage,
        attackerKilled: combat.attackerKilled,
        defenderKilled: combat.defenderKilled,
        attackerUnitId: combat.attackerUnitId,
        defenderUnitId: combat.defenderUnitId,
        defenderRetaliated: combat.defenderRetaliated,
        eventIndex: combat.eventIndex,
      ),
];
