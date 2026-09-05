import 'package:aonw_flutter/features/combat/application/combat_state.dart';
import 'package:aonw_flutter/features/combat/read_model/combat_view.dart';
import 'package:aonw_flutter/features/map/application/map_interaction_state.dart';
import 'package:aonw_flutter/features/map/presentation/map_render_snapshot.dart';
import 'package:aonw_flutter/features/map/read_model/map_command_animation_view.dart';
import 'package:aonw_flutter/features/map/read_model/map_command_frame_view.dart';
import 'package:aonw_flutter/features/map/read_model/player_map_view.dart';

import 'map_test_fixture.dart';

const combatOrigin = (col: 0, row: 0);
const combatApproach = (col: 1, row: 0);
const combatTarget = (col: 2, row: 0);
const combatRetreat = (col: 3, row: 1);

MapRenderSnapshot unitCombatSnapshot({
  bool after = false,
  Set<String> absentUnits = const {},
  bool observed = true,
  bool approach = false,
  bool retreat = false,
  bool attackerKilled = false,
  bool defenderKilled = false,
  bool retaliated = true,
  VisibleUnitKind defenderKind = VisibleUnitKind.warrior,
  bool city = false,
  int epoch = 0,
  int revision = 1,
  String actor = 'preview-player',
}) {
  final source = testMapScene(cols: 8, rows: 6);
  final base = source.player;
  final stamp = testSessionStamp(
    revision: after ? revision : 0,
    stateDigest: (after ? '$revision' : 'b').padLeft(64, 'd'),
  );
  final player = PlayerMapView(
    actorPlayerId: actor,
    stamp: stamp,
    turnMode: base.turnMode,
    participants: base.participants,
    fog: base.fog,
    economy: base.economy,
    research: base.research,
    victory: base.victory,
    turnView: base.turnView,
    diplomacy: base.diplomacy,
    units: _combatUnits(
      after: after,
      absentUnits: absentUnits,
      attackerKilled: attackerKilled,
      defenderKilled: defenderKilled,
      defenderKind: defenderKind,
      approach: approach,
      retreat: retreat,
    ),
  );
  final battle = MapCommandCombatView(
    eventIndex: 1,
    attackerUnitId: 'attacker',
    defenderUnitId: city ? null : 'defender',
    attacker: approach ? combatApproach : combatOrigin,
    defender: combatTarget,
    outgoingDamage: 3,
    retaliationDamage: retaliated ? 1 : 0,
    attackerKilled: attackerKilled,
    defenderKilled: defenderKilled,
    defenderRetaliated: retaliated,
  );
  final animations = <MapCommandAnimationView>[
    if (approach)
      MapCommandMovementView(
        eventIndex: 0,
        unitId: 'attacker',
        path: [combatOrigin, combatApproach],
      ),
    battle,
    if (retreat)
      MapCommandMovementView(
        eventIndex: 2,
        unitId: 'defender',
        path: [combatTarget, combatRetreat],
      ),
  ];
  return MapRenderSnapshot(
    map: source.map,
    reference: source.reference,
    player: player,
    effectEpoch: epoch,
    interaction: MapInteractionState(
      combat: after && !observed
          ? _directCombat(battle, revision: revision, retreat: retreat)
          : null,
    ),
    commandFrame: after && observed
        ? MapCommandFrameView(player: player, animations: animations)
        : null,
  );
}

List<VisibleUnitView> _combatUnits({
  required bool after,
  required Set<String> absentUnits,
  required bool attackerKilled,
  required bool defenderKilled,
  required VisibleUnitKind defenderKind,
  required bool approach,
  required bool retreat,
}) => [
  if ((!after || !attackerKilled) && !absentUnits.contains('attacker'))
    testVisibleUnit(
      id: 'attacker',
      coordinate: after && approach ? combatApproach : combatOrigin,
    ),
  if ((!after || !defenderKilled) && !absentUnits.contains('defender'))
    testVisibleUnit(
      id: 'defender',
      kind: defenderKind,
      ownerPlayerId: 'other',
      coordinate: after && retreat ? combatRetreat : combatTarget,
    ),
  testVisibleUnit(
    id: 'decoy',
    kind: VisibleUnitKind.settler,
    coordinate: combatTarget,
  ),
];

CombatState _directCombat(
  MapCommandCombatView battle, {
  required int revision,
  required bool retreat,
}) => CombatState(
  attackerUnitId: 'attacker',
  defenderCoordinate: combatTarget,
  lastExecution: CombatExecutionView(
    revision: revision,
    preview: testCombatPreviewView(
      attackerUnitId: 'attacker',
      defender: combatTarget,
    ),
    defenderRetaliated: battle.defenderRetaliated,
    outcome: CombatOutcomeView(
      attackerHitPoints: battle.attackerKilled ? 0 : 9,
      defenderHitPoints: battle.defenderKilled ? 0 : 7,
      attackerKilled: battle.attackerKilled,
      defenderKilled: battle.defenderKilled,
      defenderRetreat: retreat ? combatRetreat : null,
      outgoingDamage: 3,
      retaliationDamage: battle.defenderRetaliated ? 1 : 0,
    ),
    events: [
      CombatEventKindView.unitAttacked,
      CombatEventKindView.combatResolved,
      if (retreat) CombatEventKindView.unitRetreated,
    ],
  ),
);
