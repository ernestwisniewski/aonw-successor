import 'package:aonw_flutter/game/aonw_flame_game.dart';
import 'package:aonw_flutter/game/map/map_unit_sprite_animation.dart';
import 'package:aonw_flutter/game/map/unit_map_layer.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/map_unit_combat_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final mode in ['reduced', 'disabled', 'skip', 'clear']) {
    testWithGame<AonwFlameGame>(
      '$mode releases markers during death playback',
      AonwFlameGame.new,
      (game) async {
        await _load(game);
        final layer = game.world.unitLayer;
        final defender = layer.componentForUnit('defender')!;
        game.replaceScene(
          unitCombatSnapshot(after: true, defenderKilled: true),
        );
        game.world.effectHost.update(0.4);
        expect(defender.debugSpriteAction, MapUnitSpriteAction.die);
        expect(layer.debugRetainedUnitCount, 1);
        switch (mode) {
          case 'reduced':
            game.setReducedMotion(true);
          case 'disabled':
            game.setCombatAnimations(false);
          case 'skip':
            game.skipEffects();
          case 'clear':
            game.clearScene();
        }
        expect(layer.debugRetainedUnitCount, 0);
        expect(layer.componentForUnit('defender'), isNull);
        if (mode != 'clear') {
          expect(
            layer.componentForUnit('attacker')!.debugSpriteAction,
            MapUnitSpriteAction.idle,
          );
        }
      },
    );
  }

  for (final mode in ['reduced', 'disabled']) {
    testWithGame<AonwFlameGame>(
      '$mode before combat removes fallen units without reserving clips',
      AonwFlameGame.new,
      (game) async {
        await _load(game);
        if (mode == 'reduced') {
          game.setReducedMotion(true);
        } else {
          game.setCombatAnimations(false);
        }
        game.replaceScene(
          unitCombatSnapshot(after: true, defenderKilled: true),
        );
        expect(game.world.unitLayer.debugRetainedUnitCount, 0);
        expect(game.world.unitLayer.componentForUnit('defender'), isNull);
        expect(
          game.world.unitLayer.componentForUnit('attacker')!.debugSpriteAction,
          MapUnitSpriteAction.idle,
        );
        game.setReducedMotion(false);
        game.setCombatAnimations(true);
        game.world.effectHost.update(0.4);
        expect(game.world.unitLayer.componentForUnit('defender'), isNull);
      },
    );
  }

  testWithGame<AonwFlameGame>(
    'a newer battle owns the pose while earlier feedback completes',
    AonwFlameGame.new,
    (game) async {
      await _load(game);
      final attacker = game.world.unitLayer.componentForUnit('attacker')!;
      final host = game.world.effectHost;
      game.replaceScene(unitCombatSnapshot(after: true, observed: false));
      host.update(0.65);
      expect(attacker.debugSpriteFrame!.id.value, endsWith('.attack.5'));
      game.replaceScene(
        unitCombatSnapshot(after: true, observed: false, revision: 2),
      );
      expect(attacker.debugSpriteFrame!.id.value, endsWith('.attack.0'));
      expect(host.debugActiveCombatEffectCount, 2);
      host.update(0.26);
      expect(attacker.debugSpriteFrame!.id.value, endsWith('.attack.2'));
      host.update(0.4);
      expect(host.debugActiveCombatEffectCount, 1);
      expect(attacker.debugSpriteFrame!.id.value, endsWith('.attack.5'));
      host.update(0.06);
      expect(attacker.debugSpriteAction, MapUnitSpriteAction.idle);
    },
  );

  testWithGame<AonwFlameGame>(
    'a newly disclosed defender stays at combat until its queued retreat',
    AonwFlameGame.new,
    (game) async {
      addTearDown(game.clearScene);
      game.setUnitIdleAnimations(false);
      game.replaceScene(unitCombatSnapshot(absentUnits: {'defender'}));
      await game.ready();
      game.replaceScene(
        unitCombatSnapshot(after: true, retreat: true, retaliated: false),
      );
      final layer = game.world.unitLayer;
      final defender = layer.componentForUnit('defender')!;
      final battleCenter = layer.centerFor(
        game.world.debugStaticRenderCache!,
        combatTarget,
      );
      expect(
        (defender.visualCenter - battleCenter).distance,
        lessThan(0.00001),
      );
      game.world.effectHost.update(0.72);
      expect(
        (defender.visualCenter - battleCenter).distance,
        lessThan(0.00001),
      );
      game.world.effectHost.update(0.56);
      game.skipEffects();
      final target = layer.centerFor(
        game.world.debugStaticRenderCache!,
        combatRetreat,
      );
      expect((defender.visualCenter - target).distance, lessThan(0.00001));
      expect(layer.debugRetainedUnitCount, 0);
      expect(game.paused, isTrue);
    },
  );

  testWithGame<AonwFlameGame>(
    'a full feedback pool releases unstarted fallen participants',
    AonwFlameGame.new,
    (game) async {
      await _load(game);
      for (var revision = 1; revision <= 5; revision++) {
        game.replaceScene(
          unitCombatSnapshot(
            after: true,
            observed: false,
            revision: revision,
            defenderKilled: revision == 5,
          ),
        );
      }
      expect(game.world.effectHost.debugActiveCombatEffectCount, 4);
      expect(game.world.unitLayer.debugRetainedUnitCount, 0);
      expect(game.world.unitLayer.componentForUnit('defender'), isNull);
      expect(
        game.world.unitLayer.componentForUnit('attacker')!.debugSpriteAction,
        MapUnitSpriteAction.idle,
      );
      game.skipEffects();
      expect(game.paused, isTrue);
    },
  );
}

Future<void> _load(AonwFlameGame game) async {
  addTearDown(game.clearScene);
  game.setUnitIdleAnimations(false);
  game.replaceScene(unitCombatSnapshot());
  await game.ready();
  for (final id in ['attacker', 'defender', 'decoy']) {
    await game.world.unitLayer.componentForUnit(id)!.debugLoadSprite();
  }
}
