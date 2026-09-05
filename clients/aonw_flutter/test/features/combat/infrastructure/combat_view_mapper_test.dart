import 'package:aonw_engine_client/aonw_engine_client.dart';
import 'package:aonw_flutter/features/combat/infrastructure/combat_view_mapper.dart';
import 'package:aonw_flutter/features/combat/read_model/combat_view.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/map_test_fixture.dart';

void main() {
  const mapper = CombatViewMapper();

  test('maps engine preview without exposing RNG or deriving legality', () {
    final preview = mapper.preview(
      AonwCombatPreviewResult(stamp: _stamp(), preview: _wirePreview()),
      map: testMapScene().map,
      attackerUnitId: 'preview-commander',
      defender: (col: 1, row: 0),
      expectedRevision: 0,
    );

    expect(preview.target.id, 'defender');
    expect(preview.target.kind, CombatTargetKindView.unit);
    expect(preview.outgoingDamageMin, 2);
    expect(preview.retaliationDamageMax, 3);
    expect(preview.attacker.modifiers.single.delta, 1);
  });

  test('requires exact preview, ordered combat events and combat evidence', () {
    final preview = _mappedPreview();
    final mapped = mapper.command(
      _accepted(_wirePreview()),
      map: testMapScene().map,
      attack: CombatAttackView(
        preview: preview,
        cityConquestAction: CityConquestActionView.capture,
      ),
      expectedRevision: 0,
      currentRevision: 0,
    );

    expect(mapped.execution?.events, [
      CombatEventKindView.unitAttacked,
      CombatEventKindView.combatResolved,
      CombatEventKindView.unitKilled,
    ]);
    expect(mapped.execution?.outcome.defenderKilled, isTrue);
    expect(mapped.execution?.defenderRetaliated, isFalse);

    expect(
      () => mapper.command(
        _accepted(_wirePreview(outgoingDamageMax: 6)),
        map: testMapScene().map,
        attack: CombatAttackView(
          preview: preview,
          cityConquestAction: CityConquestActionView.capture,
        ),
        expectedRevision: 0,
        currentRevision: 0,
      ),
      throwsFormatException,
    );
  });

  test('maps the executed retaliation even when it deals no damage', () {
    final mapped = mapper.command(
      _accepted(_wirePreview(), retaliated: true),
      map: testMapScene().map,
      attack: CombatAttackView(
        preview: _mappedPreview(),
        cityConquestAction: CityConquestActionView.capture,
      ),
      expectedRevision: 0,
      currentRevision: 0,
    );
    expect(mapped.execution!.outcome.retaliationDamage, 0);
    expect(mapped.execution!.defenderRetaliated, isTrue);
  });

  test('fails closed for stale identity and unrelated rejection', () {
    expect(
      () => mapper.preview(
        AonwCombatPreviewResult(
          stamp: _stamp(revision: 1),
          preview: _wirePreview(),
        ),
        map: testMapScene().map,
        attackerUnitId: 'preview-commander',
        defender: (col: 1, row: 0),
        expectedRevision: 0,
      ),
      throwsFormatException,
    );
    expect(
      () => mapper.command(
        _rejected(AonwCommandRejectionCode.cityNotFound),
        map: testMapScene().map,
        attack: CombatAttackView(
          preview: _mappedPreview(),
          cityConquestAction: CityConquestActionView.capture,
        ),
        expectedRevision: 0,
        currentRevision: 0,
      ),
      throwsFormatException,
    );
  });
}

CombatPreviewView _mappedPreview() => const CombatViewMapper().preview(
  AonwCombatPreviewResult(stamp: _stamp(), preview: _wirePreview()),
  map: testMapScene().map,
  attackerUnitId: 'preview-commander',
  defender: (col: 1, row: 0),
  expectedRevision: 0,
);

AonwCombatPreview _wirePreview({int outgoingDamageMax = 5}) =>
    AonwCombatPreview(
      attackerUnitId: 'preview-commander',
      target: const AonwUnitCombatTarget(unitId: 'defender'),
      distance: 1,
      attacker: const AonwCombatStats(
        attack: 7,
        defense: 4,
        hitPoints: 10,
        range: 1,
        mobility: 4,
        modifiers: [
          AonwCombatModifier(
            kind: AonwCombatModifierKind.terrain,
            label: 'plains',
            target: AonwCombatStatTarget.attack,
            delta: 1,
          ),
        ],
      ),
      defender: const AonwCombatStats(
        attack: 3,
        defense: 5,
        hitPoints: 4,
        range: 1,
        mobility: 4,
        modifiers: [],
      ),
      outgoingDamageMin: 2,
      outgoingDamageMax: outgoingDamageMax,
      retaliationDamageMin: 1,
      retaliationDamageMax: 3,
    );

AonwCommandResult _accepted(
  AonwCombatPreview preview, {
  bool retaliated = false,
}) => AonwCommandResult(
  stamp: _stamp(revision: 1),
  outcome: const AonwCommandAccepted(),
  events: const [
    AonwPresentationEvent(AonwClientEventKind.unitAttacked),
    AonwPresentationEvent(AonwClientEventKind.combatResolved),
    AonwPresentationEvent(AonwClientEventKind.unitKilled),
  ],
  evidence: AonwCombatEvidence(
    execution: AonwCombatExecution(
      seed: 7,
      rolls: [
        const AonwCombatRoll(value: 3),
        if (retaliated) const AonwCombatRoll(value: 0),
      ],
      preview: preview,
      outcome: AonwCombatOutcome(
        attackerHitPoints: 10,
        defenderHitPoints: retaliated ? 2 : 0,
        attackerKilled: false,
        defenderKilled: !retaliated,
        defenderRetreat: null,
        outgoingDamage: 4,
        retaliationDamage: 0,
      ),
    ),
  ),
  viewPatch: _patch(toRevision: 1),
);

AonwCommandResult _rejected(AonwCommandRejectionCode code) => AonwCommandResult(
  stamp: _stamp(),
  outcome: AonwCommandRejected(code),
  events: const [],
  evidence: null,
  viewPatch: _patch(),
);

AonwSessionStamp _stamp({int revision = 0}) => AonwSessionStamp(
  revision: revision,
  stateDigest: 'b' * 64,
  mapHash: 'a' * 64,
  rulesetHash: 'c' * 64,
);

AonwPlayerViewPatch _patch({int toRevision = 0}) => AonwPlayerViewPatch(
  fromRevision: 0,
  toRevision: toRevision,
  turn: 1,
  turnMode: AonwTurnMode.sequential,
  turnLifecycle: null,
  outcome: null,
  upsertedUnits: const [],
  removedUnitIds: const [],
  upsertedCities: const [],
  removedCityIds: const [],
  upsertedArtifacts: const [],
  removedArtifactIds: const [],
  upsertedFieldImprovements: const [],
  removedFieldImprovementCoordinates: const [],
  upsertedRoads: const [],
  removedRoadCoordinates: const [],
  pendingAction: null,
  cityFoundingDraft: null,
  diplomacy: null,
);
