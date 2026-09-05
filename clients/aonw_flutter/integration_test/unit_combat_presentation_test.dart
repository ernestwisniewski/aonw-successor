import 'dart:io';

import 'package:aonw_flutter/design_system/assets/sprite_frames.dart';
import 'package:aonw_flutter/game/aonw_flame_game.dart';
import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/map_unit_combat_fixture.dart';
import 'support/unit_combat_presentation_probe.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('plays and releases combat participants on the native device', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final rssBefore = ProcessInfo.currentRss;
    final game = AonwFlameGame();
    final snapshot = unitCombatSnapshot();
    game.setUnitIdleAnimations(false);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: GameWidget<AonwFlameGame>(game: game, autofocus: false),
      ),
    );
    game.replaceScene(snapshot);
    await tester.runAsync(game.ready);
    game.setViewportActive(true);
    await tester.pump();
    binding.reportData ??= <String, dynamic>{};
    await verifyUnitCombatPresentation(
      binding,
      tester,
      game,
      snapshot,
      rssBefore: rssBefore,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(SpriteFrames.debugAtlasBytes, isEmpty);
    binding.reportData!['spriteAtlasesReleasedOnUnmount'] = true;
  });
}
