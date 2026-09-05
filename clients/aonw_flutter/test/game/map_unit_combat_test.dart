import 'package:aonw_flutter/features/map/read_model/player_map_view.dart';
import 'package:aonw_flutter/game/aonw_flame_game.dart';
import 'package:aonw_flutter/game/map/flame_map_camera.dart';
import 'package:aonw_flutter/game/map/map_unit_sprite_animation.dart';
import 'package:aonw_flutter/game/map/unit_map_layer.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/map_unit_combat_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWithGame<AonwFlameGame>(
    'attacks face each other while unrelated stacked units remain idle',
    AonwFlameGame.new,
    (game) async {
      await _load(game);
      final layer = game.world.unitLayer;
      final attacker = layer.componentForUnit('attacker')!;
      final defender = layer.componentForUnit('defender')!;
      final decoy = layer.componentForUnit('decoy')!;
      game.replaceScene(unitCombatSnapshot(after: true));
      expect(attacker.debugSpriteAction, MapUnitSpriteAction.attack);
      expect(defender.debugSpriteAction, MapUnitSpriteAction.attack);
      expect(attacker.debugSpriteMirrored, isFalse);
      expect(defender.debugSpriteMirrored, isTrue);
      expect(decoy.debugSpriteAction, MapUnitSpriteAction.idle);
      _advance(game, 0.26);
      expect(attacker.debugSpriteFrame!.id.value, endsWith('.attack.2'));
      expect(defender.debugSpriteFrame!.id.value, endsWith('.attack.2'));
      game.replaceScene(unitCombatSnapshot(after: true));
      expect(attacker.debugSpriteFrame!.id.value, endsWith('.attack.2'));
      _advance(game, 0.46);
      expect(attacker.debugSpriteAction, MapUnitSpriteAction.idle);
      expect(defender.debugSpriteAction, MapUnitSpriteAction.idle);
      expect(game.world.effectHost.debugActiveCombatEffectCount, 1);
      _advance(game, 0.56);
      expect(game.world.effectHost.debugActiveEffectCount, 0);
      expect(game.paused, isTrue);
    },
  );

  testWithGame<AonwFlameGame>(
    'retains both fallen markers and starts death at the authored offsets',
    AonwFlameGame.new,
    (game) async {
      await _load(game);
      final layer = game.world.unitLayer;
      final attacker = layer.componentForUnit('attacker')!;
      final defender = layer.componentForUnit('defender')!;
      final attackerImage = attacker.debugSpriteFrame!.image;
      game.replaceScene(
        unitCombatSnapshot(
          after: true,
          attackerKilled: true,
          defenderKilled: true,
        ),
      );
      expect(layer.debugUnitCount, 1);
      expect(layer.debugRetainedUnitCount, 2);
      expect(layer.componentForUnit('attacker'), same(attacker));
      _advance(game, 0.34);
      expect(defender.debugSpriteAction, MapUnitSpriteAction.attack);
      _advance(game, 0.06);
      expect(defender.debugSpriteFrame!.id.value, endsWith('.die.0'));
      expect(attacker.debugSpriteAction, MapUnitSpriteAction.attack);
      _advance(game, 0.12);
      expect(attacker.debugSpriteFrame!.id.value, endsWith('.die.0'));
      _advance(game, 0.19);
      expect(defender.debugSpriteFrame!.id.value, endsWith('.die.2'));
      expect(attacker.debugSpriteFrame!.id.value, endsWith('.die.1'));
      _advance(game, 0.01);
      expect(layer.debugRetainedUnitCount, 0);
      expect(layer.componentForUnit('attacker'), isNull);
      expect(layer.componentForUnit('defender'), isNull);
      expect(attackerImage.debugDisposed, isTrue);
      expect(game.world.effectHost.debugActiveCombatEffectCount, 1);
      game.skipEffects();
    },
  );

  for (final observed in [false, true]) {
    testWithGame<AonwFlameGame>(
      'keeps the defender at battle until its retreat starts (observed: $observed)',
      AonwFlameGame.new,
      (game) async {
        await _load(game);
        final defender = game.world.unitLayer.componentForUnit('defender')!;
        final start = defender.visualCenter;
        game.replaceScene(
          unitCombatSnapshot(
            after: true,
            observed: observed,
            retreat: true,
            retaliated: false,
          ),
        );
        final host = game.world.effectHost;
        final completion = game.waitForCommandEffects();
        expect(host.debugPendingCommandEffectCount, 1);
        expect(defender.visualCenter, start);
        expect(defender.debugSpriteAction, MapUnitSpriteAction.idle);
        _advance(game, 0.72);
        expect(defender.visualCenter, start);
        _advance(game, 0.56);
        expect(defender.visualCenter, start);
        expect(host.debugPendingCommandEffectCount, 0);
        _advance(game, 0.3);
        expect(defender.visualCenter, isNot(start));
        expect(defender.debugSpriteAction, MapUnitSpriteAction.walk);
        _advance(game, 0.3);
        await completion;
        expect(defender.debugSpriteAction, MapUnitSpriteAction.idle);
        final target = game.world.unitLayer.centerFor(
          game.world.debugStaticRenderCache!,
          combatRetreat,
        );
        expect((defender.visualCenter - target).distance, lessThan(0.00001));
        expect(game.paused, isTrue);
      },
    );
  }

  testWithGame<AonwFlameGame>(
    'keeps a fallen attacker through its preceding movement and combat',
    AonwFlameGame.new,
    (game) async {
      await _load(game);
      final layer = game.world.unitLayer;
      final attacker = layer.componentForUnit('attacker')!;
      game.replaceScene(
        unitCombatSnapshot(after: true, approach: true, attackerKilled: true),
      );
      expect(layer.debugRetainedUnitCount, 1);
      _advance(game, 0.3);
      expect(attacker.debugSpriteAction, MapUnitSpriteAction.walk);
      _advance(game, 0.3);
      expect(attacker.debugSpriteAction, MapUnitSpriteAction.attack);
      expect(layer.debugRetainedUnitCount, 1);
      _advance(game, 0.72);
      expect(layer.debugRetainedUnitCount, 0);
      game.skipEffects();
    },
  );

  for (final mode in [
    'skip',
    'reduced',
    'disabled',
    'epoch',
    'actor',
    'clear',
  ]) {
    testWithGame<AonwFlameGame>(
      '$mode releases active and queued combat markers',
      AonwFlameGame.new,
      (game) async {
        await _load(game);
        final layer = game.world.unitLayer;
        game.replaceScene(
          unitCombatSnapshot(
            after: true,
            approach: true,
            attackerKilled: true,
            defenderKilled: true,
          ),
        );
        _advance(game, 0.2);
        expect(layer.debugRetainedUnitCount, 2);
        switch (mode) {
          case 'skip':
            game.skipEffects();
          case 'reduced':
            game.setReducedMotion(true);
          case 'disabled':
            game.setCombatAnimations(false);
          case 'epoch':
            game.replaceScene(
              unitCombatSnapshot(
                after: true,
                attackerKilled: true,
                defenderKilled: true,
                epoch: 1,
              ),
            );
          case 'actor':
            game.replaceScene(
              unitCombatSnapshot(
                after: true,
                attackerKilled: true,
                defenderKilled: true,
                actor: 'other',
              ),
            );
          case 'clear':
            game.clearScene();
        }
        if (mode == 'disabled') _advance(game, 0.6);
        expect(layer.debugRetainedUnitCount, 0);
        expect(layer.componentForUnit('attacker'), isNull);
        expect(layer.componentForUnit('defender'), isNull);
        game.skipEffects();
      },
    );
  }

  testWithGame<AonwFlameGame>(
    'city targets do not animate their garrison as the defender',
    AonwFlameGame.new,
    (game) async {
      await _load(game);
      game.replaceScene(unitCombatSnapshot(after: true, city: true));
      expect(
        game.world.unitLayer.componentForUnit('attacker')!.debugSpriteAction,
        MapUnitSpriteAction.attack,
      );
      expect(
        game.world.unitLayer.componentForUnit('defender')!.debugSpriteAction,
        MapUnitSpriteAction.idle,
      );
      game.skipEffects();
    },
  );

  testWithGame<AonwFlameGame>(
    'civilian death uses its authored clip without inventing an attack',
    AonwFlameGame.new,
    (game) async {
      await _load(game, defenderKind: VisibleUnitKind.worker);
      final defender = game.world.unitLayer.componentForUnit('defender')!;
      game.replaceScene(
        unitCombatSnapshot(
          after: true,
          defenderKind: VisibleUnitKind.worker,
          defenderKilled: true,
          retaliated: false,
        ),
      );
      expect(defender.debugSpriteAction, MapUnitSpriteAction.idle);
      _advance(game, 0.55);
      expect(defender.debugSpriteFrame!.id.value, 'unit.worker.die.1');
      game.skipEffects();
    },
  );
}

Future<void> _load(
  AonwFlameGame game, {
  VisibleUnitKind defenderKind = VisibleUnitKind.warrior,
}) async {
  addTearDown(game.clearScene);
  game.setUnitIdleAnimations(false);
  game.replaceScene(unitCombatSnapshot(defenderKind: defenderKind));
  await game.ready();
  for (final id in ['attacker', 'defender', 'decoy']) {
    await game.world.unitLayer.componentForUnit(id)!.debugLoadSprite();
  }
}

void _advance(AonwFlameGame game, double dt) {
  game.mapCamera.update(1);
  game.world.effectHost.update(dt);
}
