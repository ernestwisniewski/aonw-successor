part of 'map_test_fixture.dart';

CombatPreviewView testCombatPreviewView({
  String attackerUnitId = 'preview-commander',
  MapHexCoordinate defender = const (col: 1, row: 0),
}) => CombatPreviewView(
  stamp: testSessionStamp(),
  attackerUnitId: attackerUnitId,
  defenderCoordinate: defender,
  target: const CombatTargetView(
    kind: CombatTargetKindView.unit,
    id: 'defender',
  ),
  distance: 1,
  attacker: CombatStatsView(
    attack: 7,
    defense: 4,
    hitPoints: 10,
    range: 1,
    mobility: 4,
    modifiers: const [],
  ),
  defender: CombatStatsView(
    attack: 3,
    defense: 5,
    hitPoints: 4,
    range: 1,
    mobility: 4,
    modifiers: const [],
  ),
  outgoingDamageMin: 2,
  outgoingDamageMax: 5,
  retaliationDamageMin: 1,
  retaliationDamageMax: 3,
);

CombatExecutionView testCombatExecutionView({int revision = 1}) =>
    CombatExecutionView(
      defenderRetaliated: true,
      revision: revision,
      preview: testCombatPreviewView(),
      outcome: const CombatOutcomeView(
        attackerHitPoints: 9,
        defenderHitPoints: 0,
        attackerKilled: false,
        defenderKilled: true,
        defenderRetreat: null,
        outgoingDamage: 4,
        retaliationDamage: 1,
      ),
      events: const [
        CombatEventKindView.unitAttacked,
        CombatEventKindView.combatResolved,
        CombatEventKindView.unitKilled,
      ],
    );
