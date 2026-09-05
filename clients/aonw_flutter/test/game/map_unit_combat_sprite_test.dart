import 'dart:ui' as ui;

import 'package:aonw_flutter/features/map/read_model/player_map_view.dart';
import 'package:aonw_flutter/game/map/map_sprite_catalog.dart';
import 'package:aonw_flutter/game/map/map_unit_sprite_animation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('attack and death hold the last frame until the next pose', () async {
    final sprite = MapUnitSpriteAnimation(
      kind: VisibleUnitKind.commander,
      onLoaded: () {},
    );
    addTearDown(sprite.dispose);
    await sprite.load();
    sprite.playAttackToward(ui.Offset.zero, const ui.Offset(-1, 0));
    expect(sprite.frameDuration, 0.13);
    sprite.advance(0.26);
    sprite.playAttackToward(ui.Offset.zero, const ui.Offset(0, 1));
    expect(sprite.mirrored, isTrue);
    expect(sprite.index, 2);
    sprite.playAttackToward(ui.Offset.zero, const ui.Offset(1, 0));
    expect(sprite.mirrored, isFalse);
    expect(sprite.index, 2);
    for (var index = 3; index <= 8; index++) {
      sprite.advance(0.13);
      expect(sprite.index, index.clamp(0, 5));
    }
    sprite.playDie();
    expect(sprite.frameDuration, 0.18);
    expect(sprite.index, 0);
    for (var index = 1; index <= 8; index++) {
      sprite.advance(0.18);
      expect(sprite.index, index.clamp(0, 5));
    }
    sprite.playIdle();
    expect(sprite.frame!.id.value, 'unit.commander.idle.0');
    sprite.playAttack();
    expect(sprite.frame!.id.value, 'unit.commander.attack.0');
  });

  for (final kind in [
    VisibleUnitKind.worker,
    VisibleUnitKind.settler,
    VisibleUnitKind.merchant,
  ]) {
    test('$kind falls back to idle for attack and provides death', () async {
      final sprite = MapUnitSpriteAnimation(kind: kind, onLoaded: () {});
      addTearDown(sprite.dispose);
      await sprite.load();
      sprite.playWork();
      sprite.playAttackToward(ui.Offset.zero, const ui.Offset(-1, 0));
      expect(sprite.frame!.id.value, 'unit.${kind.name}.idle.0');
      expect(sprite.mirrored, isTrue);
      sprite.playDie();
      sprite.advance(0.18 * 7);
      expect(sprite.frame!.id.value, 'unit.${kind.name}.die.5');
    });
  }

  test('renders authored attack and death frames in both directions', () async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)
      ..drawColor(const ui.Color(0xff202024), ui.BlendMode.src);
    final poses = [
      (VisibleUnitKind.commander, MapUnitSpriteAction.attack),
      (VisibleUnitKind.commander, MapUnitSpriteAction.die),
      (VisibleUnitKind.archer, MapUnitSpriteAction.attack),
      (VisibleUnitKind.archer, MapUnitSpriteAction.die),
      (VisibleUnitKind.tank, MapUnitSpriteAction.attack),
      (VisibleUnitKind.tank, MapUnitSpriteAction.die),
      (VisibleUnitKind.worker, MapUnitSpriteAction.die),
    ];
    for (var row = 0; row < poses.length; row++) {
      final (kind, action) = poses[row];
      final sprite = MapUnitSpriteAnimation(kind: kind, onLoaded: () {});
      addTearDown(sprite.dispose);
      await sprite.load();
      for (var column = 0; column < 6; column++) {
        if (action == MapUnitSpriteAction.attack) {
          sprite.playAttackToward(
            ui.Offset.zero,
            ui.Offset(column < 3 ? 1 : -1, 0),
          );
        } else {
          if (column == 0) {
            sprite.playWalkToward(ui.Offset.zero, const ui.Offset(-1, 0));
            sprite.playDie();
          }
        }
        final metrics = MapSpriteCatalog.unitMetrics(kind);
        sprite.paint(
          canvas,
          ui.Rect.fromCenter(
            center: ui.Offset(column * 88 + 42, row * 100 + 50),
            width: metrics.width,
            height: metrics.height,
          ),
        );
        sprite.advance(sprite.frameDuration);
      }
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(528, 700);
    await expectLater(image, matchesGoldenFile('goldens/map_unit_combat.png'));
    image.dispose();
    picture.dispose();
  });
}
