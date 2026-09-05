part of 'map_feedback_mapper_test.dart';

void textMapperTests() {
  test('evicts complete artifact pairs at the journal boundary', () {
    final snapshot = _snapshot();
    final cues = mapCommandFeedback(
      command: _command(snapshot, [
        for (var i = 0; i < 33; i++)
          AonwArtifactCarriedEvent(
            artifactId: 'artifact-$i',
            ownerPlayerId: 'preview-player',
            unitId: 'carrier',
            coordinate: const AonwCoordinate(col: 1, row: 0),
          ),
        _events.last,
      ]),
      snapshot: snapshot,
      previous: feedbackSnapshot().player,
      map: feedbackSnapshot().map,
    );
    expect(cues, hasLength(63));
    expect(cues.first.identity, (revision: 1, eventIndex: 2));
    expect(cues.whereType<MapFloatingTextCueView>(), hasLength(31));
    expect(cues.whereType<MapParticleCueView>(), hasLength(32));
    expect(cues.last.identity, (revision: 1, eventIndex: 33));
  });

  test('maps authoritative worker yields even after consumption', () {
    final snapshot = _snapshot();
    final cues = mapCommandFeedback(
      command: _command(snapshot, [
        const AonwWorkerCompletedJobEvent(
          unitId: 'consumed',
          target: AonwCoordinate(col: 2, row: 1),
          completion: AonwFieldImprovementCompletion(
            AonwFieldImprovementKind.riverFarm,
          ),
          yieldDelta: AonwYieldValue(
            food: 7,
            production: 3,
            gold: 2,
            defense: 1,
          ),
        ),
        const AonwWorkerCompletedJobEvent(
          unitId: 'builder',
          target: AonwCoordinate(col: 1, row: 0),
          completion: AonwRoadCompletion(),
          yieldDelta: AonwYieldValue(
            food: 0,
            production: 0,
            gold: 0,
            defense: 0,
          ),
        ),
      ]),
      snapshot: snapshot,
      previous: feedbackSnapshot().player,
      map: feedbackSnapshot().map,
    );
    final improvement = cues.first as MapFloatingTextCueView;
    final content = improvement.content as MapImprovementYieldTextView;
    expect(improvement.coordinate, (col: 2, row: 1));
    expect(
      (
        content.yieldDelta.food,
        content.yieldDelta.production,
        content.yieldDelta.gold,
        content.yieldDelta.defense,
      ),
      (7, 3, 2, 1),
    );
    expect(content.improvement.name, 'riverFarm');
    expect(improvement.anchor, isA<MapTileTextAnchorView>());
    expect(improvement.colorValue, 0xff86efac);
    final road = cues.last as MapFloatingTextCueView;
    expect(
      (road.content as MapMessageTextView).message,
      MapFeedbackMessageView.roadCompleted,
    );
  });

  test('anchors artifact bubbles and particles to private visible events', () {
    final snapshot = _snapshot();
    final events = <AonwClientEvent>[
      const AonwArtifactExcavationStartedEvent(
        artifactId: 'a',
        ownerPlayerId: 'preview-player',
        unitId: 'excavator',
        coordinate: AonwCoordinate(col: 2, row: 1),
      ),
      const AonwArtifactCarriedEvent(
        artifactId: 'a',
        ownerPlayerId: 'preview-player',
        unitId: 'carrier',
        coordinate: AonwCoordinate(col: 2, row: 1),
      ),
      const AonwArtifactStoredEvent(
        artifactId: 'a',
        ownerPlayerId: 'preview-player',
        sourceUnitId: null,
        cityId: 'storehouse',
        coordinate: AonwCoordinate(col: 1, row: 0),
      ),
      const AonwArtifactCarriedEvent(
        artifactId: 'foreign',
        ownerPlayerId: 'other',
        unitId: 'other-unit',
        coordinate: AonwCoordinate(col: 1, row: 0),
      ),
    ];
    List<MapFeedbackCueView> mapped(AonwPlayerViewSnapshot snapshot) =>
        mapCommandFeedback(
          command: _command(snapshot, events),
          snapshot: snapshot,
          previous: feedbackSnapshot().player,
          map: feedbackSnapshot().map,
        );
    final cues = mapped(snapshot);
    expect(cues, hasLength(6));
    expect(cues.map((cue) => cue.identity.eventIndex), [0, 0, 1, 1, 2, 2]);
    final labels = cues.whereType<MapFloatingTextCueView>().toList();
    expect((labels[0].anchor as MapUnitTextAnchorView).unitId, 'excavator');
    expect((labels[1].anchor as MapUnitTextAnchorView).unitId, 'carrier');
    expect((labels[2].anchor as MapCityTextAnchorView).cityId, 'storehouse');
    expect(
      labels.every(
        (cue) =>
            cue.delay.inMilliseconds == 120 &&
            cue.style == MapFloatingTextStyleView.bubble &&
            cue.colorValue == 0xffffd166,
      ),
      isTrue,
    );
    expect(mapped(_snapshot(visible: const [])), isEmpty);
    expect(
      mapped(_snapshot(visible: const [AonwCoordinate(col: 1, row: 0)])),
      hasLength(2),
    );
  });

  test(
    'follows movement and exact retreat evidence before later destruction',
    () {
      final previous = const PlayerMapViewMapper().fromWire(
        _snapshot(
          revision: 0,
          unitCoordinate: const AonwCoordinate(col: 2, row: 1),
        ),
        map: feedbackSnapshot().map,
        actorPlayerId: 'preview-player',
      );
      final snapshot = _snapshot(hasUnit: false);
      final events = <AonwClientEvent>[
        const AonwUnitMovedEvent(
          unitId: 'unit',
          from: AonwCoordinate(col: 2, row: 1),
          to: AonwCoordinate(col: 1, row: 1),
        ),
        const AonwCombatResolvedEvent(
          attackerUnitId: 'first',
          target: AonwUnitCombatTarget(unitId: 'unit'),
        ),
        const AonwUnitRetreatedEvent(
          attackerUnitId: 'first',
          target: AonwUnitCombatTarget(unitId: 'unit'),
          subjectUnitId: 'unit',
        ),
        const AonwUnitMovedEvent(
          unitId: 'unit',
          from: AonwCoordinate(col: 2, row: 0),
          to: AonwCoordinate(col: 1, row: 0),
        ),
        const AonwCombatResolvedEvent(
          attackerUnitId: 'second',
          target: AonwUnitCombatTarget(unitId: 'unit'),
        ),
        const AonwUnitKilledEvent(
          attackerUnitId: 'second',
          target: AonwUnitCombatTarget(unitId: 'unit'),
          subjectUnitId: 'unit',
        ),
        const AonwUnitKilledEvent(
          attackerUnitId: 'second',
          target: AonwUnitCombatTarget(unitId: 'hidden'),
          subjectUnitId: 'hidden',
        ),
      ];
      final evidence = AonwTurnKernelEvidence(
        processors: const [],
        foundedCityIds: const [],
        combatExecutions: [
          _statusCombat('first', retreat: const AonwCoordinate(col: 2, row: 0)),
          _statusCombat('second'),
        ],
        resetUnitIds: const [],
        movementExecutions: const [],
        invalidatedOrderUnitIds: const [],
        finishedAutoExploreUnitIds: const [],
      );
      final cues = mapCommandFeedback(
        command: _command(snapshot, events, evidence: evidence),
        snapshot: snapshot,
        previous: previous,
        map: feedbackSnapshot().map,
      ).cast<MapFloatingTextCueView>();
      expect(cues.map((cue) => cue.coordinate), [
        (col: 2, row: 0),
        (col: 1, row: 0),
      ]);
      expect(cues.map((cue) => (cue.content as MapMessageTextView).message), [
        MapFeedbackMessageView.unitRetreated,
        MapFeedbackMessageView.unitKilled,
      ]);
      expect(cues.every((cue) => cue.delay.inMilliseconds == 180), isTrue);
      expect(
        mapCommandFeedback(
          command: _command(
            snapshot,
            [events[1], events[2]],
            evidence: AonwCombatEvidence(
              execution: _statusCombat(
                'unrelated',
                retreat: const AonwCoordinate(col: 1, row: 1),
              ),
            ),
          ),
          snapshot: snapshot,
          previous: previous,
          map: feedbackSnapshot().map,
        ),
        isEmpty,
      );
    },
  );
}

AonwCombatExecution _statusCombat(
  String attacker, {
  AonwCoordinate? retreat,
  AonwCombatTarget target = const AonwUnitCombatTarget(unitId: 'unit'),
  bool retaliated = false,
}) => AonwCombatExecution(
  seed: 0,
  rolls: [
    const AonwCombatRoll(value: 0),
    if (retaliated) const AonwCombatRoll(value: 0),
  ],
  preview: AonwCombatPreview(
    attackerUnitId: attacker,
    target: target,
    distance: 1,
    attacker: _statusStats,
    defender: _statusStats,
    outgoingDamageMin: 1,
    outgoingDamageMax: 1,
    retaliationDamageMin: 0,
    retaliationDamageMax: 0,
  ),
  outcome: AonwCombatOutcome(
    attackerHitPoints: 10,
    defenderHitPoints: retaliated || retreat != null ? 1 : 0,
    attackerKilled: false,
    defenderKilled: !retaliated && retreat == null,
    defenderRetreat: retreat,
    outgoingDamage: 1,
    retaliationDamage: 0,
  ),
);

const _statusStats = AonwCombatStats(
  attack: 1,
  defense: 1,
  hitPoints: 10,
  range: 1,
  mobility: 1,
  modifiers: [],
);
