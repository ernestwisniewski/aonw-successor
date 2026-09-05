import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:aonw_flutter/design_system/assets/sprite_animation_adjustments.dart';
import 'package:aonw_flutter/design_system/assets/sprite_frame_id.dart';
import 'package:aonw_flutter/features/map/read_model/player_map_view.dart';
import 'package:aonw_flutter/game/map/map_sprite_catalog.dart';
import 'package:aonw_flutter/game/map/map_unit_sprite_animation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'sprite painting preserves authored clipping through zoom and mirroring',
    () async {
      final adjustments = await SpriteAnimationAdjustments.load();
      for (final kind in [
        VisibleUnitKind.commander,
        VisibleUnitKind.archer,
        VisibleUnitKind.tank,
        VisibleUnitKind.worker,
        VisibleUnitKind.settler,
        VisibleUnitKind.merchant,
      ]) {
        await _compareKind(kind, adjustments);
      }
    },
  );
}

Future<void> _compareKind(
  VisibleUnitKind kind,
  SpriteAnimationAdjustments adjustments,
) async {
  final sprite = MapUnitSpriteAnimation(kind: kind, onLoaded: () {});
  await sprite.load();
  final metrics = MapSpriteCatalog.unitMetrics(kind);
  final size = ui.Size(metrics.width, metrics.height);
  for (final mirror in [false, true]) {
    for (final walk in [false, true]) {
      sprite.playWalkToward(ui.Offset.zero, ui.Offset(mirror ? -1 : 1, 0));
      if (!walk) sprite.playIdle();
      await _compareFrames(sprite, adjustments, size);
    }
    sprite.playAttackToward(ui.Offset.zero, ui.Offset(mirror ? -1 : 1, 0));
    if (sprite.action == MapUnitSpriteAction.attack) {
      await _compareFrames(sprite, adjustments, size);
    }
    sprite.playDie();
    await _compareFrames(sprite, adjustments, size);
    sprite.playWork();
    if (sprite.action == MapUnitSpriteAction.work) {
      await _compareFrames(sprite, adjustments, size);
    }
  }
  sprite.dispose();
}

Future<void> _compareFrames(
  MapUnitSpriteAnimation sprite,
  SpriteAnimationAdjustments adjustments,
  ui.Size size,
) async {
  for (var frame = 0; frame < 6; frame++) {
    for (final zoom in [0.2, 1.0, 5.0]) {
      final actual = await _render(
        sprite,
        adjustments,
        size,
        zoom,
        reference: false,
      );
      final expected = await _render(
        sprite,
        adjustments,
        size,
        zoom,
        reference: true,
      );
      expect(
        _maximumDelta(actual, expected),
        0,
        reason: '${sprite.frame!.id} mirror=${sprite.mirrored} zoom=$zoom',
      );
    }
    sprite.advance(sprite.frameDuration);
  }
}

int _maximumDelta(Uint8List actual, Uint8List expected) {
  var delta = 0;
  for (var index = 0; index < actual.length; index++) {
    delta = math.max(delta, (actual[index] - expected[index]).abs());
  }
  return delta;
}

Future<Uint8List> _render(
  MapUnitSpriteAnimation sprite,
  SpriteAnimationAdjustments adjustments,
  ui.Size size,
  double zoom, {
  required bool reference,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)
    ..translate(10, 10)
    ..scale(zoom);
  final destination = ui.Offset.zero & size;
  if (reference) {
    final frame = sprite.frame!;
    final sequence = frame.id.value.substring(
      0,
      frame.id.value.lastIndexOf('.'),
    );
    final geometry = adjustments
        .forFrame(SpriteSequenceId(sequence), sprite.index)
        .geometryFor(frame, baseSize: size, destination: destination);
    if (sprite.mirrored) {
      canvas
        ..translate(size.width, 0)
        ..scale(-1, 1);
    }
    canvas
      ..clipRect(destination)
      ..drawImageRect(
        frame.image,
        geometry.source,
        geometry.destination,
        ui.Paint()..filterQuality = ui.FilterQuality.medium,
      );
  } else {
    sprite.paint(canvas, destination);
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    (size.width * zoom + 20).ceil(),
    (size.height * zoom + 20).ceil(),
  );
  final bytes = (await image.toByteData())!.buffer.asUint8List();
  picture.dispose();
  image.dispose();
  return bytes;
}
