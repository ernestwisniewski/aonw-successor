import 'dart:convert';
import 'dart:io';

import 'package:aonw_flutter/features/map/presentation/map_render_snapshot.dart';
import 'package:aonw_flutter/features/map/read_model/map_command_animation_view.dart';
import 'package:aonw_flutter/features/map/read_model/map_command_frame_view.dart';
import 'package:aonw_flutter/features/map/read_model/player_map_view.dart';
import 'package:aonw_flutter/game/aonw_flame_game.dart';
import 'package:aonw_flutter/game/map/unit_map_layer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

Future<void> verifyUnitCombatPresentation(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  AonwFlameGame game,
  MapRenderSnapshot source, {
  required int rssBefore,
}) async {
  game.setUnitIdleAnimations(false);
  game.setEffectPlaybackSpeed(0.1);
  final layer = game.world.unitLayer;
  final units = [
    for (final unit in source.player.units.take(2))
      layer.componentForUnit(unit.id)!,
  ];
  for (final unit in units) {
    await unit.debugLoadSprite();
  }
  final cache = game.world.debugStaticRenderCache;
  game.replaceScene(_fallenParticipants(source));
  expect(layer.debugUnitCount, source.player.units.length - 2);
  expect(layer.debugRetainedUnitCount, 2);
  final frames = [<String>{}, <String>{}];
  var samples = 0;
  while (game.world.effectHost.debugActiveEffectCount > 0 && samples < 120) {
    for (var index = 0; index < units.length; index++) {
      final frame = units[index].debugSpriteFrame;
      if (frame != null) frames[index].add(frame.id.value);
    }
    await tester.pump(const Duration(milliseconds: 120));
    samples++;
  }
  expect(game.world.effectHost.debugActiveEffectCount, 0);
  expect(layer.debugRetainedUnitCount, 0);
  for (var index = 0; index < units.length; index++) {
    expect(
      frames[index].where((id) => id.contains('.attack.')).length,
      index == 0 ? 4 : 3,
      reason: 'death interrupts attack at 72% and 48% of the marker sequence',
    );
    expect(frames[index].any((id) => id.contains('.die.')), isTrue);
    expect(layer.componentForUnit(units[index].debugUnit.id), isNull);
  }
  expect(game.world.debugStaticRenderCache, same(cache));
  expect(game.paused, isTrue);
  final rssDelta = ProcessInfo.currentRss - rssBefore;
  final record = {
    'schemaVersion': 1,
    'capturedAt': DateTime.now().toUtc().toIso8601String(),
    'mapDimensions': {'cols': source.map.cols, 'rows': source.map.rows},
    'unitsBeforeCombat': source.player.units.length,
    'observedFrames': [
      for (final observed in frames) observed.toList()..sort(),
    ],
    'samples': samples,
    'sampleIntervalMillis': 120,
    'effectPlaybackSpeed': 0.1,
    'retainedParticipants': 2,
    'participantsReleasedAfterCombat': true,
    'flamePausedAfterCombat': true,
    'residentMemoryDeltaBytes': rssDelta,
  };
  binding.reportData!['flameUnitCombatPresentation'] = record;
  // ignore: avoid_print
  print('AONW_FLAME_UNIT_COMBAT_PRESENTATION ${jsonEncode(record)}');
  expect(rssDelta, lessThanOrEqualTo(192 * 1024 * 1024));
  game.setEffectPlaybackSpeed(1);
  game.replaceScene(source);
  game.setUnitIdleAnimations(true);
}

MapRenderSnapshot _fallenParticipants(MapRenderSnapshot source) {
  final base = source.player;
  final participants = base.units.take(2).toList();
  final player = PlayerMapView(
    actorPlayerId: base.actorPlayerId,
    stamp: SessionStampView(
      revision: base.stamp.revision + 1,
      stateDigest: 'c' * 64,
      mapHash: base.stamp.mapHash,
      rulesetHash: base.stamp.rulesetHash,
    ),
    turnMode: base.turnMode,
    participants: base.participants,
    fog: base.fog,
    economy: base.economy,
    research: base.research,
    victory: base.victory,
    turnView: base.turnView,
    diplomacy: base.diplomacy,
    cities: base.cities,
    artifacts: base.artifacts,
    fieldImprovements: base.fieldImprovements,
    roads: base.roads,
    units: base.units.skip(2).toList(),
  );
  return MapRenderSnapshot(
    map: source.map,
    reference: source.reference,
    player: player,
    interaction: source.interaction,
    commandFrame: MapCommandFrameView(
      player: player,
      animations: [
        MapCommandCombatView(
          eventIndex: 0,
          attackerUnitId: participants[0].id,
          defenderUnitId: participants[1].id,
          attacker: participants[0].coordinate,
          defender: participants[1].coordinate,
          outgoingDamage: 10,
          retaliationDamage: 10,
          attackerKilled: true,
          defenderKilled: true,
          defenderRetaliated: true,
        ),
      ],
    ),
  );
}
