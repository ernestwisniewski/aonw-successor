part of 'map_feedback_mapper_test.dart';

void animationMapperTests() {
  test('keeps a city target separate from units stacked on its hex', () {
    final previous = testMapScene(
      units: [
        testVisibleUnit(id: 'attacker'),
        testVisibleUnit(id: 'garrison', coordinate: (col: 1, row: 0)),
      ],
    );
    final snapshot = _snapshot();
    const target = AonwCityCombatTarget(cityId: 'city');
    final command = _command(
      snapshot,
      [
        const AonwCombatResolvedEvent(
          attackerUnitId: 'attacker',
          target: target,
        ),
      ],
      evidence: AonwCombatEvidence(
        execution: _statusCombat('attacker', target: target, retaliated: true),
      ),
    );
    final next = const PlayerMapViewMapper().fromWire(
      snapshot,
      map: previous.map,
      actorPlayerId: previous.player.actorPlayerId,
    );
    final combat =
        mapCommandAnimations(
              command: command,
              previous: previous.player,
              next: next,
              map: previous.map,
            ).single
            as MapCommandCombatView;
    expect(combat.attackerUnitId, 'attacker');
    expect(combat.defenderUnitId, isNull);
    expect(combat.defenderIsCity, isTrue);
    expect(combat.defender, (col: 1, row: 0));
    expect(combat.retaliationDamage, 0);
    expect(combat.defenderRetaliated, isTrue);
  });

  test(
    'orders executed routes, combat and retreat at their event coordinates',
    () {
      final previous = testMapScene(
        units: [
          testVisibleUnit(id: 'first'),
          testVisibleUnit(id: 'stacked', coordinate: (col: 1, row: 1)),
          testVisibleUnit(id: 'unit', coordinate: (col: 2, row: 1)),
        ],
      );
      final snapshot = _snapshot(
        unitCoordinate: const AonwCoordinate(col: 2, row: 0),
      );
      final command = _command(
        snapshot,
        [_moved, _resolved('first'), _retreated('first')],
        evidence: _turnEvidence(
          combats: [
            _statusCombat(
              'first',
              retreat: const AonwCoordinate(col: 2, row: 0),
            ),
          ],
          movements: [_executedMovement],
        ),
      );
      final next = const PlayerMapViewMapper().fromWire(
        snapshot,
        map: previous.map,
        actorPlayerId: previous.player.actorPlayerId,
      );
      final animations = mapCommandAnimations(
        command: command,
        previous: previous.player,
        next: next,
        map: previous.map,
      );
      expect(animations.map((animation) => animation.eventIndex), [0, 1, 2]);
      final movement = animations.first as MapCommandMovementView;
      expect(movement.path, [
        (col: 2, row: 1),
        (col: 2, row: 0),
        (col: 1, row: 1),
      ]);
      expect(() => movement.path.clear(), throwsUnsupportedError);
      final combat = animations[1] as MapCommandCombatView;
      expect(combat.attacker, (col: 0, row: 0));
      expect(combat.defender, (col: 1, row: 1));
      expect(combat.attackerUnitId, 'first');
      expect(combat.defenderUnitId, 'unit');
      expect(combat.defenderRetaliated, isFalse);
      expect(combat.outgoingDamage, 1);
      expect(combat.retaliationDamage, 0);
      expect(combat.defenderKilled, isFalse);
      expect(combat.defenderIsCity, isFalse);
      expect((animations.last as MapCommandMovementView).path, [
        (col: 1, row: 1),
        (col: 2, row: 0),
      ]);
    },
  );

  test('withheld combat evidence does not consume the next visible battle', () {
    final previous = testMapScene(
      units: [
        testVisibleUnit(id: 'second'),
        testVisibleUnit(id: 'unit', coordinate: (col: 2, row: 1)),
      ],
    );
    final snapshot = _snapshot(
      unitCoordinate: const AonwCoordinate(col: 0, row: 1),
    );
    final command = _command(
      snapshot,
      [
        _resolved('first'),
        _retreated('first'),
        _moved,
        _resolved('second'),
        _retreated('second'),
      ],
      evidence: _turnEvidence(
        combats: [
          _statusCombat(
            'second',
            retreat: const AonwCoordinate(col: 0, row: 1),
          ),
        ],
      ),
    );
    final next = const PlayerMapViewMapper().fromWire(
      snapshot,
      map: previous.map,
      actorPlayerId: previous.player.actorPlayerId,
    );
    final animations = mapCommandAnimations(
      command: command,
      previous: previous.player,
      next: next,
      map: previous.map,
    );
    expect(animations.map((animation) => animation.eventIndex), [3, 4]);
    expect((animations.first as MapCommandCombatView).defender, (
      col: 1,
      row: 1,
    ));
    final cues = mapCommandFeedback(
      command: command,
      snapshot: snapshot,
      previous: previous.player,
      map: previous.map,
    );
    expect(cues.single.identity, (revision: 1, eventIndex: 4));
    expect(cues.single.coordinate, (col: 0, row: 1));
  });

  test(
    'ambiguous repeated battles invalidate undisclosed retreat positions',
    () {
      final previous = feedbackSnapshot();
      final snapshot = _snapshot(hasUnit: false);
      final command = _command(
        snapshot,
        [
          _resolved('first'),
          _retreated('first'),
          _resolved('first'),
          _retreated('first'),
          const AonwUnitKilledEvent(
            attackerUnitId: 'first',
            target: AonwUnitCombatTarget(unitId: 'unit'),
            subjectUnitId: 'unit',
          ),
        ],
        evidence: _turnEvidence(
          combats: [
            _statusCombat(
              'first',
              retreat: const AonwCoordinate(col: 0, row: 1),
            ),
          ],
        ),
      );
      final initial = const PlayerMapViewMapper().fromWire(
        _snapshot(revision: 0),
        map: previous.map,
        actorPlayerId: 'preview-player',
      );
      expect(
        mapCommandFeedback(
          command: command,
          snapshot: snapshot,
          previous: initial,
          map: previous.map,
        ),
        isEmpty,
      );
    },
  );

  test(
    'animates executed automation while ignoring queued merchant routes',
    () {
      final previous = testMapScene(
        units: [testVisibleUnit(id: 'unit', coordinate: (col: 2, row: 1))],
      );
      final snapshot = _snapshot(
        unitCoordinate: const AonwCoordinate(col: 1, row: 1),
      );
      final next = const PlayerMapViewMapper().fromWire(
        snapshot,
        map: previous.map,
        actorPlayerId: previous.player.actorPlayerId,
      );
      for (final evidence in <AonwClientEvidence>[
        AonwUnitMovementEvidence(
          unitId: 'unit',
          from: _executedMovement.from,
          steps: _executedMovement.steps,
        ),
        _turnEvidence(movements: [_executedMovement]),
        AonwLogisticsEvidence(
          execution: AonwAutoExploreExecution(
            unitId: 'unit',
            target: const AonwCoordinate(col: 0, row: 0),
            movement: _executedMovement,
          ),
        ),
        AonwWorkerAutomationEvidence(
          unitId: 'unit',
          option: const AonwWorkerAutomationOption(
            target: AonwCoordinate(col: 0, row: 0),
            action: AonwWorkerAssignAction(),
            movementCostUnits: 3,
            metrics: AonwWorkerAutomationMetrics(
              tilesExamined: 1,
              legalityEvaluations: 1,
              routesPlanned: 1,
            ),
          ),
          movement: _executedMovement,
        ),
      ]) {
        final animations = mapCommandAnimations(
          command: _command(snapshot, [_moved], evidence: evidence),
          previous: previous.player,
          next: next,
          map: previous.map,
        );
        expect((animations.single as MapCommandMovementView).path.last, (
          col: 1,
          row: 1,
        ));
      }
      for (final evidence in <AonwClientEvidence?>[
        null,
        AonwLogisticsEvidence(
          execution: AonwMerchantTravelExecution(
            unitId: 'unit',
            destinationCityId: 'city',
            steps: _executedMovement.steps,
          ),
        ),
      ]) {
        expect(
          mapCommandAnimations(
            command: _command(snapshot, [_moved], evidence: evidence),
            previous: previous.player,
            next: next,
            map: previous.map,
          ),
          isEmpty,
        );
      }
    },
  );

  test('rejects a disclosed movement path outside the map', () {
    final previous = feedbackSnapshot();
    final snapshot = _snapshot();
    final evidence = AonwUnitMovementEvidence(
      unitId: 'unit',
      from: _executedMovement.from,
      steps: [
        const AonwMovementStep(
          coordinate: AonwCoordinate(col: 7, row: 0),
          enterCostUnits: 1,
          cumulativeCostUnits: 1,
        ),
        _executedMovement.steps.last,
      ],
    );
    final next = const PlayerMapViewMapper().fromWire(
      snapshot,
      map: previous.map,
      actorPlayerId: previous.player.actorPlayerId,
    );
    expect(
      () => mapCommandAnimations(
        command: _command(snapshot, [_moved], evidence: evidence),
        previous: previous.player,
        next: next,
        map: previous.map,
      ),
      throwsFormatException,
    );
  });
}

const _moved = AonwUnitMovedEvent(
  unitId: 'unit',
  from: AonwCoordinate(col: 2, row: 1),
  to: AonwCoordinate(col: 1, row: 1),
);

const _executedMovement = AonwUnitMovementExecution(
  unitId: 'unit',
  from: AonwCoordinate(col: 2, row: 1),
  steps: [
    AonwMovementStep(
      coordinate: AonwCoordinate(col: 2, row: 0),
      enterCostUnits: 1,
      cumulativeCostUnits: 1,
    ),
    AonwMovementStep(
      coordinate: AonwCoordinate(col: 1, row: 1),
      enterCostUnits: 1,
      cumulativeCostUnits: 2,
    ),
  ],
);

AonwCombatResolvedEvent _resolved(String attacker) => AonwCombatResolvedEvent(
  attackerUnitId: attacker,
  target: const AonwUnitCombatTarget(unitId: 'unit'),
);
AonwUnitRetreatedEvent _retreated(String attacker) => AonwUnitRetreatedEvent(
  attackerUnitId: attacker,
  target: const AonwUnitCombatTarget(unitId: 'unit'),
  subjectUnitId: 'unit',
);

AonwTurnKernelEvidence _turnEvidence({
  List<AonwCombatExecution> combats = const [],
  List<AonwUnitMovementExecution> movements = const [],
}) => AonwTurnKernelEvidence(
  processors: const [],
  foundedCityIds: const [],
  combatExecutions: combats,
  resetUnitIds: const [],
  movementExecutions: movements,
  invalidatedOrderUnitIds: const [],
  finishedAutoExploreUnitIds: const [],
);
