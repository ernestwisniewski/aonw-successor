import 'dart:async';

import 'package:aonw_flutter/features/combat/application/combat_session_port.dart';
import 'package:aonw_flutter/features/combat/application/combat_workflow.dart';
import 'package:aonw_flutter/features/combat/read_model/combat_view.dart';
import 'package:aonw_flutter/features/map/application/game_session_state.dart';
import 'package:aonw_flutter/features/map/application/map_interaction_state.dart';
import 'package:aonw_flutter/features/map/read_model/player_map_view.dart';
import 'package:aonw_flutter/features/unit_actions/application/action_deck_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/map_test_fixture.dart';

void main() {
  test('correlates preview and dispatches only one accepted attack', () async {
    final preview = _preview();
    final session = _CombatSession(preview: preview);
    final workflow = CombatWorkflow(
      session: session,
      diagnosticReporter: (_, _, _) {},
    );
    var state = _ready();

    workflow.preview(
      attackerUnitId: 'attacker',
      defender: (col: 1, row: 0),
      readState: () => state,
      publish: (value) => state = value,
      isDisposed: () => false,
    );
    await pumpEventQueue();
    expect(state.interaction.combat?.preview, same(preview));

    final pending = Completer<CombatCommandResultView>();
    session.pendingAttack = pending;
    workflow.attack(
      readState: () => state,
      publish: (value) => state = value,
      isDisposed: () => false,
    );
    workflow.attack(
      readState: () => state,
      publish: (value) => state = value,
      isDisposed: () => false,
    );
    expect(session.attackCalls, 1);

    pending.complete(
      CombatCommandResultView.accepted(
        player: _player(revision: 1),
        execution: _execution(preview),
      ),
    );
    await pumpEventQueue();
    expect(state.recipient.stamp.revision, 1);
    expect(state.interaction.combat?.lastExecution, isNotNull);
    expect(state.interaction.actionDeck, isNull);
  });

  test(
    'ignores a late preview after a newer target wins correlation',
    () async {
      final first = Completer<CombatPreviewView>();
      final second = Completer<CombatPreviewView>();
      final session = _CombatSession(previewQueue: [first, second]);
      final workflow = CombatWorkflow(
        session: session,
        diagnosticReporter: (_, _, _) {},
      );
      var state = _ready();

      for (final target in [(col: 1, row: 0), (col: 2, row: 0)]) {
        workflow.preview(
          attackerUnitId: 'attacker',
          defender: target,
          readState: () => state,
          publish: (value) => state = value,
          isDisposed: () => false,
        );
      }
      second.complete(_preview(defender: (col: 2, row: 0)));
      await pumpEventQueue();
      first.complete(_preview());
      await pumpEventQueue();

      expect(state.interaction.combat?.defenderCoordinate, (col: 2, row: 0));
      expect(state.interaction.combat?.preview?.defenderCoordinate, (
        col: 2,
        row: 0,
      ));
    },
  );
}

final class _CombatSession implements CombatSessionPort {
  _CombatSession({
    this.preview,
    List<Completer<CombatPreviewView>> previewQueue = const [],
  }) : previewQueue = [...previewQueue];

  final CombatPreviewView? preview;
  final List<Completer<CombatPreviewView>> previewQueue;
  Completer<CombatCommandResultView>? pendingAttack;
  var attackCalls = 0;

  @override
  Future<CombatPreviewView> combatPreview({
    required int expectedRevision,
    required String attackerUnitId,
    required ({int col, int row}) defender,
  }) => previewQueue.isEmpty
      ? Future.value(preview!)
      : previewQueue.removeAt(0).future;

  @override
  Future<CombatCommandResultView> attack({
    required int expectedRevision,
    required CombatAttackView attack,
  }) {
    attackCalls += 1;
    return pendingAttack!.future;
  }
}

GameSessionReady _ready() {
  final scene = testMapScene(
    units: [
      testVisibleUnit(id: 'attacker', coordinate: (col: 0, row: 0)),
      testVisibleUnit(
        id: 'defender',
        ownerPlayerId: 'enemy',
        coordinate: (col: 1, row: 0),
      ),
    ],
  );
  return GameSessionReady.initial(scene).withInteraction(
    const MapInteractionState(
      selected: (col: 0, row: 0),
      selectedUnitId: 'attacker',
      actionDeck: ActionDeckViewState(unitId: 'attacker'),
    ),
  );
}

PlayerMapView _player({required int revision}) => PlayerMapView.preview(
  actorPlayerId: 'preview-player',
  stamp: testSessionStamp(revision: revision),
  turn: 1,
  pendingAction: null,
  units: [testVisibleUnit(id: 'attacker')],
);

CombatPreviewView _preview({
  ({int col, int row}) defender = const (col: 1, row: 0),
}) => CombatPreviewView(
  stamp: testSessionStamp(),
  attackerUnitId: 'attacker',
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

CombatExecutionView _execution(CombatPreviewView preview) =>
    CombatExecutionView(
      defenderRetaliated: true,
      revision: 1,
      preview: preview,
      outcome: const CombatOutcomeView(
        attackerHitPoints: 9,
        defenderHitPoints: 0,
        attackerKilled: false,
        defenderKilled: true,
        defenderRetreat: null,
        outgoingDamage: 4,
        retaliationDamage: 1,
      ),
      events: const [CombatEventKindView.combatResolved],
    );
