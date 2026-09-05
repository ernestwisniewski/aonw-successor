part of 'flame_scene_patch.dart';

List<FlameUnitMovementTransition> _combatRetreatBetween(
  MapRenderSnapshot previous,
  MapRenderSnapshot next,
  List<FlameCombatTransition> combats,
) {
  if (next.commandFrame != null || combats.isEmpty) return const [];
  final execution = next.interaction.combat!.lastExecution!;
  final destination = execution.outcome.defenderRetreat;
  final defenderId = combats.single.defenderUnitId;
  final index = execution.events.indexOf(CombatEventKindView.unitRetreated);
  if (destination == null || defenderId == null || index < 0) return const [];
  final origin = combats.single.defender;
  return [
    FlameUnitMovementTransition(
      unitId: defenderId,
      from: origin,
      to: destination,
      path: [origin, destination],
      fromRevision: previous.player.stamp.revision,
      toRevision: next.player.stamp.revision,
      eventIndex: index,
    ),
  ];
}
