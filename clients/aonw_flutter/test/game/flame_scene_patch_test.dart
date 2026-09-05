import 'package:aonw_flutter/features/cities/read_model/city_view.dart';
import 'package:aonw_flutter/features/combat/application/combat_state.dart';
import 'package:aonw_flutter/features/map/application/map_interaction_state.dart';
import 'package:aonw_flutter/features/map/presentation/map_render_snapshot.dart';
import 'package:aonw_flutter/features/map/read_model/map_scene.dart';
import 'package:aonw_flutter/features/map/read_model/pending_action_view.dart';
import 'package:aonw_flutter/features/map/read_model/player_map_view.dart';
import 'package:aonw_flutter/features/workers/read_model/worker_view.dart';
import 'package:aonw_flutter/game/presentation/flame_scene_patch.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/map_test_fixture.dart';

void main() {
  test(
    'derives one endpoint-only move from authoritative accepted snapshots',
    () {
      final unit = testVisibleUnit();
      final scene = testMapScene(units: [unit]);
      final before = _snapshot(
        scene,
        player: scene.player,
        interaction: const MapInteractionState(
          selectedUnitId: 'preview-commander',
          movementPending: true,
        ),
      );
      final moved = testVisibleUnit(coordinate: (col: 1, row: 0));
      final after = _snapshot(
        scene,
        player: _player(revision: 1, digest: 'd' * 64, units: [moved]),
      );

      final patch = FlameScenePatch.between(before, after);

      expect(patch.unitUpserts, [same(moved)]);
      expect(patch.removedUnitIds, isEmpty);
      expect(patch.movements, hasLength(1));
      expect(patch.movements.single.unitId, 'preview-commander');
      expect(patch.movements.single.from, (col: 0, row: 0));
      expect(patch.movements.single.to, (col: 1, row: 0));
      expect(patch.movements.single.fromRevision, 0);
      expect(patch.movements.single.toRevision, 1);
    },
  );

  test(
    'does not turn route preview or an unvalidated update into movement',
    () {
      final unit = testVisibleUnit();
      final scene = testMapScene(units: [unit]);
      final moved = testVisibleUnit(coordinate: (col: 1, row: 0));
      final previewOnly = FlameScenePatch.between(
        _snapshot(scene, player: scene.player),
        _snapshot(
          scene,
          player: _player(revision: 1, digest: 'd' * 64, units: [moved]),
        ),
      );
      final staleResult = FlameScenePatch.between(
        _snapshot(
          scene,
          player: scene.player,
          interaction: const MapInteractionState(
            selectedUnitId: 'preview-commander',
            movementPending: true,
          ),
        ),
        _snapshot(scene, player: _player(revision: 0, units: [moved])),
      );

      expect(previewOnly.movements, isEmpty);
      expect(staleResult.movements, isEmpty);
    },
  );

  test('upserts only changed stable IDs and reports removals', () {
    final stable = testVisibleUnit(id: 'stable');
    final removed = testVisibleUnit(
      id: 'removed',
      coordinate: (col: 1, row: 0),
    );
    final added = testVisibleUnit(id: 'added', coordinate: (col: 2, row: 0));
    final scene = testMapScene(units: [stable, removed]);

    final patch = FlameScenePatch.between(
      _snapshot(scene, player: scene.player),
      _snapshot(scene, player: _player(units: [stable, added])),
    );

    expect(patch.unitUpserts, [same(added)]);
    expect(patch.removedUnitIds, ['removed']);
  });

  test('upserts a stable unit when authoritative health changes', () {
    final healthy = testVisibleUnit(hitPoints: 8, maximumHitPoints: 8);
    final damaged = testVisibleUnit(hitPoints: 3, maximumHitPoints: 8);
    final scene = testMapScene(units: [healthy]);

    final patch = FlameScenePatch.between(
      _snapshot(scene, player: scene.player),
      _snapshot(scene, player: _player(units: [damaged])),
    );

    expect(patch.unitUpserts, [same(damaged)]);
  });

  test('derives one bounded combat cue only from accepted exact evidence', () {
    final unit = testVisibleUnit();
    final scene = testMapScene(units: [unit]);
    final before = _snapshot(
      scene,
      player: scene.player,
      interaction: CombatState(
        attackerUnitId: unit.id,
        defenderCoordinate: const (col: 1, row: 0),
        preview: testCombatPreviewView(),
        commandPending: true,
      ).asInteraction(unit.coordinate),
    );
    final after = _snapshot(
      scene,
      player: _player(revision: 1, digest: 'd' * 64, units: [unit]),
      interaction: CombatState(
        attackerUnitId: unit.id,
        defenderCoordinate: const (col: 1, row: 0),
        lastExecution: testCombatExecutionView(),
      ).asInteraction(const (col: 1, row: 0)),
    );

    final patch = FlameScenePatch.between(before, after);

    expect(patch.combats, hasLength(1));
    expect(patch.combats.single.attacker, unit.coordinate);
    expect(patch.combats.single.defender, (col: 1, row: 0));
    expect(patch.combats.single.attackerUnitId, unit.id);
    expect(patch.combats.single.defenderUnitId, 'defender');
    expect(patch.combats.single.defenderRetaliated, isTrue);
    expect(patch.combats.single.revision, 1);
    expect(patch.combats.single.eventCount, 3);
    expect(patch.combats.single.outgoingDamage, 4);
    expect(patch.combats.single.retaliationDamage, 1);
    expect(patch.combats.single.defenderKilled, isTrue);
    expect(patch.combats.single.attackerKilled, isFalse);
    expect(patch.combats.single.defenderIsCity, isFalse);
    expect(FlameScenePatch.between(null, after).combats, isEmpty);
    expect(FlameScenePatch.between(before, before).combats, isEmpty);
    expect(FlameScenePatch.between(after, after).combats, isEmpty);
    expect(FlameScenePatch.between(after, before).combats, isEmpty);
  });

  test('reconciles city markers by stable engine identity', () {
    final stable = testCityView(id: 'stable-city');
    final removed = testCityView(id: 'removed-city', center: (col: 2, row: 1));
    final added = testCityView(id: 'added-city', center: (col: 0, row: 1));
    final scene = testMapScene(cities: [stable, removed]);

    final patch = FlameScenePatch.between(
      _snapshot(scene, player: scene.player),
      _snapshot(
        scene,
        player: _player(units: const [], cities: [stable, added]),
      ),
    );

    expect(patch.cityUpserts, [same(added)]);
    expect(patch.removedCityIds, ['removed-city']);
  });

  test('upserts a stable improvement when its public era band changes', () {
    const early = FieldImprovementView(
      coordinate: (col: 1, row: 0),
      improvement: FieldImprovementKind.mine,
    );
    const industrial = FieldImprovementView(
      coordinate: (col: 1, row: 0),
      improvement: FieldImprovementKind.mine,
      eraColumn: 2,
    );
    final scene = testMapScene(fieldImprovements: const [early]);

    final patch = FlameScenePatch.between(
      _snapshot(scene, player: scene.player),
      _snapshot(
        scene,
        player: _player(units: const [], fieldImprovements: const [industrial]),
      ),
    );

    expect(patch.fieldImprovementUpserts, [same(industrial)]);
    expect(patch.removedFieldImprovementCoordinates, isEmpty);
  });
}

extension on CombatState {
  MapInteractionState asInteraction(({int col, int row}) selected) =>
      MapInteractionState(
        selected: selected,
        selectedUnitId: attackerUnitId,
        combat: this,
      );
}

MapRenderSnapshot _snapshot(
  MapScene scene, {
  required PlayerMapView player,
  MapInteractionState interaction = const MapInteractionState(),
}) => MapRenderSnapshot(
  map: scene.map,
  interaction: interaction,
  reference: scene.reference,
  player: player,
);

PlayerMapView _player({
  int revision = 0,
  String? digest,
  required List<VisibleUnitView> units,
  List<CityView> cities = const [],
  List<FieldImprovementView> fieldImprovements = const [],
}) => PlayerMapView.preview(
  actorPlayerId: 'preview-player',
  stamp: SessionStampView(
    revision: revision,
    stateDigest: digest ?? 'b' * 64,
    mapHash: 'a' * 64,
    rulesetHash: 'c' * 64,
  ),
  turn: 1,
  pendingAction: null,
  units: units,
  cities: cities,
  fieldImprovements: fieldImprovements,
);
