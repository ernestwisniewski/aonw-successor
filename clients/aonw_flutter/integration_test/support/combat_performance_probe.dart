import 'dart:convert';
import 'dart:io';

import 'package:aonw_flutter/features/combat/application/combat_state.dart';
import 'package:aonw_flutter/features/combat/read_model/combat_view.dart';
import 'package:aonw_flutter/features/map/application/map_interaction_state.dart';
import 'package:aonw_flutter/features/map/presentation/map_render_snapshot.dart';
import 'package:aonw_flutter/features/map/read_model/player_map_view.dart';
import 'package:aonw_flutter/game/aonw_flame_game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'active_frame_timings.dart';

/// Saturates the presentation pool with synthetic accepted city-attack evidence.
Future<void> measureCombatFeedback(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  AonwFlameGame game,
  MapRenderSnapshot snapshot, {
  required int rssBefore,
}) async {
  game.setContinuousRendering(true);
  // Live device pumps include platform waits; keep every pool slot occupied
  // throughout profiling without changing the renderer or its particle count.
  game.setEffectPlaybackSpeed(0.1);
  for (var index = 0; index < 4; index++) {
    game.replaceScene(_combatSnapshot(snapshot, index));
  }
  final effects = game.world.effectHost;
  expect(effects.debugActiveCombatEffectCount, 4);
  expect(effects.debugActiveDamageLabelCount, 8);
  expect(effects.debugActiveParticleCount, 136);
  final frameTimes = await measureActiveFrameTimings(
    tester,
    warmupFrames: 12,
    timedFrames: 60,
  );
  expect(effects.debugActiveCombatEffectCount, 4);
  expect(effects.debugActiveDamageLabelCount, 8);
  expect(effects.debugActiveParticleCount, 136);
  binding.reportData!['flameCombatFrameTimes'] = frameTimes;
  final rssDelta = ProcessInfo.currentRss - rssBefore;
  game.skipEffects();
  game.setContinuousRendering(false);
  game.setEffectPlaybackSpeed(1);
  expect(game.paused, isTrue);
  final updates = effects.debugActiveUpdateCount;
  await tester.pump(const Duration(milliseconds: 100));
  expect(effects.debugActiveUpdateCount, updates);
  final record = {
    'schemaVersion': 1,
    'capturedAt': DateTime.now().toUtc().toIso8601String(),
    'environment': {
      'operatingSystem': Platform.operatingSystemVersion,
      'dart': Platform.version,
      'buildMode': 'flutter-test-device-debug',
      'flame': '1.38.0',
    },
    'workload': {
      'mapDimensions': {'cols': 40, 'rows': 30},
      'units': 120,
      'cities': 40,
      'improvements': 120,
      'roads': 120,
      'concurrentCombats': 4,
      'damageLabels': 8,
      'particles': 136,
      'warmupFrames': 12,
      'effectPlaybackSpeed': 0.1,
      'continuousEffectsAcrossWarmup': true,
      'timingCollector':
          'engine timestamps between consecutive warmup and measured frames',
      'timedFrames': 60,
    },
    'metrics': {
      'residentMemoryDeltaBytes': rssDelta,
      'frameTimes': frameTimes,
      'idleEffectUpdatesAfterSkip': effects.debugActiveUpdateCount - updates,
    },
    'policy': {
      'buildP99MillisMax': 16.667,
      'rasterP99MillisMax': 16.667,
      'missedFrameBudgetMax': 0,
      'residentMemoryDeltaBytesMax': 192 * 1024 * 1024,
    },
  };
  // Stable marker for the reviewed record; thresholds match the scene gate.
  // ignore: avoid_print
  print('AONW_FLAME_COMBAT_BASELINE ${jsonEncode(record)}');
  expect(
    frameTimes['99th_percentile_frame_build_time_millis'],
    lessThanOrEqualTo(16.667),
  );
  expect(
    frameTimes['99th_percentile_frame_rasterizer_time_millis'],
    lessThanOrEqualTo(16.667),
  );
  expect(frameTimes['missed_frame_build_budget_count'], 0);
  expect(frameTimes['missed_frame_rasterizer_budget_count'], 0);
  expect(rssDelta, lessThanOrEqualTo(192 * 1024 * 1024));
}

MapRenderSnapshot _combatSnapshot(MapRenderSnapshot source, int index) {
  final attacker = source.player.units[index * 2];
  final city = source.player.cities[index * 2 + 1];
  final revision = index + 1;
  final stamp = SessionStampView(
    revision: revision,
    stateDigest: '$revision'.padLeft(64, 'd'),
    mapHash: source.player.stamp.mapHash,
    rulesetHash: source.player.stamp.rulesetHash,
  );
  return MapRenderSnapshot(
    map: source.map,
    reference: source.reference,
    player: PlayerMapView.preview(
      actorPlayerId: source.player.actorPlayerId,
      stamp: stamp,
      turn: 1,
      pendingAction: null,
      units: source.player.units,
      cities: source.player.cities,
      fieldImprovements: source.player.fieldImprovements,
      roads: source.player.roads,
    ),
    interaction: MapInteractionState(
      viewMode: source.interaction.viewMode,
      combat: CombatState(
        attackerUnitId: attacker.id,
        defenderCoordinate: city.center,
        lastExecution: CombatExecutionView(
          defenderRetaliated: true,
          revision: revision,
          preview: CombatPreviewView(
            stamp: stamp,
            attackerUnitId: attacker.id,
            defenderCoordinate: city.center,
            target: CombatTargetView(
              kind: CombatTargetKindView.city,
              id: city.id,
            ),
            distance: 5,
            attacker: _stats(),
            defender: _stats(),
            outgoingDamageMin: 3,
            outgoingDamageMax: 5,
            retaliationDamageMin: 1,
            retaliationDamageMax: 3,
          ),
          outcome: const CombatOutcomeView(
            attackerHitPoints: 8,
            defenderHitPoints: 5,
            attackerKilled: false,
            defenderKilled: false,
            defenderRetreat: null,
            outgoingDamage: 5,
            retaliationDamage: 2,
          ),
          events: const [
            CombatEventKindView.cityAttacked,
            CombatEventKindView.combatResolved,
          ],
        ),
      ),
    ),
  );
}

CombatStatsView _stats() => CombatStatsView(
  attack: 7,
  defense: 5,
  hitPoints: 10,
  range: 6,
  mobility: 4,
  modifiers: const [],
);
