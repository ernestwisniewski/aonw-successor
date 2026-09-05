import 'package:aonw_flutter/features/combat/application/combat_state.dart';
import 'package:aonw_flutter/features/combat/presentation/combat_panel.dart';
import 'package:aonw_flutter/features/combat/read_model/combat_view.dart';
import 'package:aonw_flutter/features/map/read_model/player_map_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/localized_test_app.dart';

void main() {
  testWidgets(
    'shows authoritative preview and dispatches one accessible attack',
    (tester) async {
      var confirms = 0;
      await tester.pumpWidget(
        LocalizedTestApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MediaQuery(
                data: const MediaQueryData(
                  textScaler: TextScaler.linear(2),
                  disableAnimations: true,
                ),
                child: CombatPanel(
                  state: CombatState(
                    attackerUnitId: 'attacker',
                    defenderCoordinate: const (col: 1, row: 0),
                    preview: _preview(),
                  ),
                  onConfirm: () => confirms += 1,
                  onCityConquestAction: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Combat'), findsOneWidget);
      expect(find.text('Target: defender'), findsOneWidget);
      expect(find.text('Outgoing damage: 2–5'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('confirm-combat')));
      expect(confirms, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('keeps ordered result text when animations are disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      LocalizedTestApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: CombatPanel(
              state: CombatState(
                attackerUnitId: 'attacker',
                defenderCoordinate: const (col: 1, row: 0),
                lastExecution: CombatExecutionView(
                  defenderRetaliated: true,
                  revision: 1,
                  preview: _preview(),
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
                ),
              ),
              onConfirm: () {},
              onCityConquestAction: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Unit attacked'), findsOneWidget);
    expect(find.text('Combat resolved'), findsNWidgets(2));
    expect(find.text('Unit defeated'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('combat-result-semantics')))
          .label,
      contains('Combat resolved'),
    );
  });
}

CombatPreviewView _preview() => CombatPreviewView(
  stamp: const SessionStampView(
    revision: 0,
    stateDigest:
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    mapHash: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    rulesetHash:
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
  ),
  attackerUnitId: 'attacker',
  defenderCoordinate: const (col: 1, row: 0),
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
