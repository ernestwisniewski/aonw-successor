import 'package:aonw_flutter/features/map/application/map_interaction_state.dart';
import 'package:aonw_flutter/features/map/presentation/map_render_snapshot.dart';
import 'package:aonw_flutter/features/map/read_model/map_command_animation_view.dart';
import 'package:aonw_flutter/features/map/read_model/map_command_frame_view.dart';
import 'package:aonw_flutter/features/map/read_model/player_map_view.dart';
import 'package:aonw_flutter/game/aonw_flame_game.dart';
import 'package:aonw_flutter/game/map/flame_map_camera.dart';
import 'package:aonw_flutter/game/presentation/flame_scene_patch.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/map_feedback_test_fixture.dart';
import '../support/map_test_fixture.dart';

void main() {
  for (final city in [false, true]) {
    test('observed combat carries participant identities (city: $city)', () {
      final patch = FlameScenePatch.between(
        _snapshot(),
        _snapshot(revision: 1, animations: [_combat(3, city: city)]),
      );
      final combat = patch.combats.single;
      expect(combat.attackerUnitId, 'unit');
      expect(combat.defenderUnitId, city ? null : 'defender');
      expect(combat.defenderIsCity, city);
      expect(combat.defenderRetaliated, isTrue);
      expect(combat.eventIndex, 3);
    });
  }

  testWithGame<AonwFlameGame>(
    'plays the executed route, combat and retreat in order',
    AonwFlameGame.new,
    (game) async {
      game.setViewportActive(true);
      game.replaceScene(_snapshot());
      game.replaceScene(_snapshot(revision: 1, animations: _sequence()));
      final host = game.world.effectHost;
      final unit = game.world.unitLayer.componentForUnit('unit')!;
      final cache = game.world.debugStaticRenderCache!;
      final middle = game.world.unitLayer.visualCenterFor(cache, 'unit', (
        col: 1,
        row: 0,
      ));
      final target = game.world.unitLayer.visualCenterFor(cache, 'unit', (
        col: 1,
        row: 1,
      ));
      expect(host.debugPendingCommandEffectCount, 2);
      expect(host.debugActiveCombatEffectCount, 0);
      final completion = game.waitForCommandEffects();
      var completed = false;
      completion.then((_) => completed = true);
      game.mapCamera.update(0.28);
      host.update(0.6);
      expect((unit.visualCenter - middle).distance, closeTo(0, 0.0001));
      expect(host.debugActiveCombatEffectCount, 0);
      host.update(0.6);
      expect(host.debugActiveCombatEffectCount, 1);
      expect(host.debugPendingCommandEffectCount, 1);
      game.replaceScene(_snapshot(revision: 1, animations: _sequence()));
      expect(
        host.debugPendingCommandEffectCount,
        1,
        reason: 'A repeated UI update does not replay effects.',
      );
      host.update(1.28);
      expect(host.debugActiveCombatEffectCount, 0);
      expect(completed, isFalse);
      game.mapCamera.update(0.28);
      host.update(0.6);
      await completion;
      expect((unit.visualCenter - target).distance, closeTo(0, 0.0001));
      expect(host.debugCompletedMovementCount, 2);
      expect(host.debugActiveEffectCount, 0);
      expect(game.paused, isTrue);
    },
  );

  testWithGame<AonwFlameGame>(
    'reduced motion and skipping finish the complete queued path',
    AonwFlameGame.new,
    (game) async {
      game.setReducedMotion(true);
      game.replaceScene(_snapshot());
      game.replaceScene(_snapshot(revision: 1, animations: _sequence()));
      final host = game.world.effectHost;
      expect(host.debugCompletedMovementCount, 1);
      expect(host.debugActiveCombatEffectCount, 1);
      final completion = game.waitForCommandEffects();
      game.skipEffects();
      await completion;
      final expected = game.world.unitLayer.visualCenterFor(
        game.world.debugStaticRenderCache!,
        'unit',
        (col: 1, row: 1),
      );
      expect(
        (game.world.unitLayer.componentForUnit('unit')!.visualCenter - expected)
            .distance,
        closeTo(0, 0.0001),
      );
      expect(host.debugPendingCommandEffectCount, 0);
      expect(host.debugActiveEffectCount, 0);
    },
  );

  testWithGame<AonwFlameGame>(
    'animation choices preserve the observed sequence and deferred feedback',
    AonwFlameGame.new,
    (game) async {
      game.setUnitMovementAnimations(false);
      game.setCombatAnimations(false);
      game.replaceScene(_snapshot());
      game.replaceScene(
        _snapshot(revision: 1, animations: _sequence(), feedback: true),
      );
      final host = game.world.effectHost;
      final feedback = game.world.eventFeedbackLayer;
      expect(host.debugCompletedMovementCount, 1);
      expect(host.debugActiveCombatEffectCount, 1);
      expect(host.debugPendingCommandEffectCount, 1);
      expect(host.debugCombatPulse, 0.55);
      expect(feedback.debugDeferredCueCount, 1);
      final completion = game.waitForCommandEffects();
      host.update(1.28);
      expect(host.debugCompletedMovementCount, 2);
      expect(host.debugActiveEffectCount, 0);
      expect(host.debugPendingCommandEffectCount, 0);
      expect(feedback.debugDeferredCueCount, 0);
      expect(feedback.debugActiveBurstCount, 1);
      final expected = game.world.unitLayer.visualCenterFor(
        game.world.debugStaticRenderCache!,
        'unit',
        (col: 1, row: 1),
      );
      expect(
        (game.world.unitLayer.componentForUnit('unit')!.visualCenter - expected)
            .distance,
        closeTo(0, 0.0001),
      );
      var completed = false;
      completion.then((_) => completed = true);
      await Future<void>.value();
      expect(completed, isFalse);
      feedback.update(10);
      await completion;
      expect(game.paused, isTrue);
    },
  );

  testWithGame<AonwFlameGame>(
    'a replay jump clears active effects and deferred feedback',
    AonwFlameGame.new,
    (game) async {
      game.replaceScene(_snapshot());
      game.replaceScene(
        _snapshot(revision: 1, animations: _sequence(), feedback: true),
      );
      final cache = game.world.debugStaticRenderCache;
      expect(game.world.eventFeedbackLayer.debugDeferredCueCount, 1);
      final completion = game.waitForCommandEffects();
      game.replaceScene(_snapshot(revision: 1, epoch: 1));
      await completion;
      expect(game.world.debugStaticRenderCache, same(cache));
      expect(game.world.effectHost.debugPendingCommandEffectCount, 0);
      expect(game.world.eventFeedbackLayer.debugDeferredCueCount, 0);
      expect(game.world.eventFeedbackLayer.debugActiveBurstCount, 0);
    },
  );

  testWithGame<AonwFlameGame>(
    'feedback waits for its event and participates in completion',
    AonwFlameGame.new,
    (game) async {
      game.replaceScene(_snapshot());
      game.replaceScene(
        _snapshot(revision: 1, animations: _sequence(), feedback: true),
      );
      final completion = game.waitForCommandEffects();
      final layer = game.world.eventFeedbackLayer;
      expect(layer.debugDeferredCueCount, 1);
      expect(layer.debugActiveBurstCount, 0);
      game.world.effectHost.update(1.2);
      expect(layer.debugActiveBurstCount, 0);
      game.world.effectHost.update(1.28);
      expect(layer.debugActiveBurstCount, 0);
      game.world.effectHost.update(0.6);
      expect(layer.debugDeferredCueCount, 0);
      expect(layer.debugActiveBurstCount, 1);
      var completed = false;
      completion.then((_) => completed = true);
      expect(completed, isFalse);
      layer.update(10);
      await completion;
      expect(layer.debugActiveBurstCount, 0);
    },
  );

  testWithGame<AonwFlameGame>(
    'serial combat playback reuses the fixed pool without dropping battles',
    AonwFlameGame.new,
    (game) async {
      game.replaceScene(_snapshot());
      game.replaceScene(
        _snapshot(
          revision: 1,
          animations: [for (var index = 0; index < 6; index++) _combat(index)],
        ),
      );
      final host = game.world.effectHost;
      final completion = game.waitForCommandEffects();
      for (var remaining = 5; remaining >= 0; remaining--) {
        expect(host.debugPendingCommandEffectCount, remaining);
        expect(host.debugActiveCombatEffectCount, 1);
        host.update(1.28);
      }
      await completion;
      expect(host.debugActiveCombatEffectCount, 0);
      expect(host.debugMaximumCombatEffectCount, 4);
    },
  );
}

List<MapCommandAnimationView> _sequence() => [
  MapCommandMovementView(
    eventIndex: 0,
    unitId: 'unit',
    path: [(col: 0, row: 0), (col: 1, row: 0), (col: 2, row: 0)],
  ),
  _combat(1),
  MapCommandMovementView(
    eventIndex: 2,
    unitId: 'unit',
    path: [(col: 2, row: 0), (col: 1, row: 1)],
  ),
];

MapCommandCombatView _combat(int index, {bool city = false}) =>
    MapCommandCombatView(
      eventIndex: index,
      attacker: (col: 2, row: 0),
      defender: (col: 2, row: 1),
      outgoingDamage: 3,
      retaliationDamage: 1,
      attackerKilled: false,
      defenderKilled: false,
      attackerUnitId: 'unit',
      defenderUnitId: city ? null : 'defender',
      defenderRetaliated: true,
    );

MapRenderSnapshot _snapshot({
  int revision = 0,
  int epoch = 0,
  List<MapCommandAnimationView>? animations,
  bool feedback = false,
}) {
  final scene = testMapScene();
  final source = scene.player;
  final player = PlayerMapView(
    actorPlayerId: source.actorPlayerId,
    stamp: testSessionStamp(
      revision: revision,
      stateDigest: (revision == 0 ? 'b' : 'c') * 64,
    ),
    turnMode: source.turnMode,
    participants: source.participants,
    fog: source.fog,
    economy: source.economy,
    research: source.research,
    victory: source.victory,
    turnView: source.turnView,
    diplomacy: source.diplomacy,
    units: [
      testVisibleUnit(
        id: 'unit',
        coordinate: revision == 0 ? (col: 0, row: 0) : (col: 1, row: 1),
      ),
    ],
    recentFeedback: [if (feedback) particleCue(eventIndex: 3)],
  );
  return MapRenderSnapshot(
    map: scene.map,
    interaction: const MapInteractionState(),
    reference: scene.reference,
    player: player,
    commandFrame: animations == null
        ? null
        : MapCommandFrameView(player: player, animations: animations),
    effectEpoch: epoch,
  );
}
