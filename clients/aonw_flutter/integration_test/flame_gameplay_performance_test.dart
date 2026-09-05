import 'dart:io';

import 'package:aonw_flutter/design_system/assets/sprite_frames.dart';
import 'package:aonw_flutter/features/cities/read_model/city_view.dart';
import 'package:aonw_flutter/features/map/application/map_interaction_state.dart';
import 'package:aonw_flutter/features/map/presentation/geometry/odd_q_flat_top_geometry.dart';
import 'package:aonw_flutter/features/map/presentation/map_render_snapshot.dart';
import 'package:aonw_flutter/features/map/read_model/map_reference_bundle.dart';
import 'package:aonw_flutter/features/map/read_model/map_view.dart';
import 'package:aonw_flutter/features/map/read_model/map_view_mode.dart';
import 'package:aonw_flutter/features/map/read_model/pending_action_view.dart';
import 'package:aonw_flutter/features/map/read_model/player_map_view.dart';
import 'package:aonw_flutter/features/workers/read_model/worker_view.dart';
import 'package:aonw_flutter/game/aonw_flame_game.dart';
import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/active_frame_timings.dart';
import 'support/camera_focus_performance_probe.dart';
import 'support/city_production_performance_probe.dart';
import 'support/cloud_performance_probe.dart';
import 'support/combat_performance_probe.dart';
import 'support/era_tint_performance_probe.dart';
import 'support/gameplay_performance_record.dart';
import 'support/map_event_performance_probe.dart';
import 'support/map_floating_text_performance_probe.dart';
import 'support/movement_camera_performance_probe.dart';
import 'support/route_performance_probe.dart';
import 'support/unit_combat_presentation_probe.dart';
import 'support/unit_idle_presentation_probe.dart';
import 'support/unit_work_presentation_probe.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('keeps the production Flame workload within its budget', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final rssBefore = ProcessInfo.currentRss;
    final snapshot = _largeSnapshot();
    final game = AonwFlameGame(
      world: AonwWorld(cloudLayer: performanceCloudLayer()),
    );
    final startup = Stopwatch()..start();

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
    startup.stop();

    expect(game.world.unitLayer.debugUnitCount, 120);
    expect(game.world.unitLayer.debugSharedPaintCount, 8);
    expect(game.world.cityLayer.debugCityCount, 40);
    expect(game.world.cityLayer.debugSharedPaintCount, 5);
    expect(game.world.workerInfrastructureLayer.debugImprovementCount, 120);
    expect(game.world.workerInfrastructureLayer.debugRoadCount, 120);
    expect(game.world.workerInfrastructureLayer.debugSharedPaintCount, 9);
    expect(game.world.children, hasLength(23));
    expect(game.paused, isTrue, reason: 'the turn-based world starts idle');
    final idleUpdates = game.world.effectHost.debugActiveUpdateCount;
    for (var frame = 0; frame < 12; frame++) {
      await tester.pump(const Duration(microseconds: 16667));
    }
    expect(game.world.effectHost.debugActiveUpdateCount, idleUpdates);

    expectPerformanceSpritesReady(game, snapshot);
    game.setContinuousRendering(true);
    final frameTimes = await measureActiveFrameTimings(
      tester,
      warmupFrames: 12,
      timedFrames: 60,
    );
    binding.reportData ??= <String, dynamic>{};
    binding.reportData!['flameGameplayFrameTimes'] = frameTimes;
    game.setContinuousRendering(false);
    expect(game.paused, isTrue);
    expect(
      game.world.eraTintLayer.debugRenderedRegionCount,
      inInclusiveRange(1, game.world.eraTintLayer.debugRegionCount - 1),
      reason: 'the real camera must bound culling on the recording canvas',
    );

    final buildP99 =
        frameTimes['99th_percentile_frame_build_time_millis']! as num;
    final rasterP99 =
        frameTimes['99th_percentile_frame_rasterizer_time_millis']! as num;
    final missedBuild = frameTimes['missed_frame_build_budget_count']! as int;
    final missedRaster =
        frameTimes['missed_frame_rasterizer_budget_count']! as int;
    final rssDelta = ProcessInfo.currentRss - rssBefore;

    expect(buildP99, lessThanOrEqualTo(16.667));
    expect(rasterP99, lessThanOrEqualTo(16.667));
    expect(missedBuild, 0);
    expect(missedRaster, 0);
    expect(rssDelta, lessThanOrEqualTo(192 * 1024 * 1024));

    recordGameplayPerformance(
      game,
      frameTimes,
      startupMicros: startup.elapsedMicroseconds,
      rssDelta: rssDelta,
      idleUpdates: idleUpdates,
    );

    await verifyUnitIdlePresentation(
      binding,
      tester,
      game,
      snapshot,
      rssBefore: rssBefore,
    );
    await verifyUnitWorkPresentation(
      binding,
      tester,
      game,
      snapshot,
      rssBefore: rssBefore,
    );
    await verifyUnitCombatPresentation(
      binding,
      tester,
      game,
      snapshot,
      rssBefore: rssBefore,
    );
    await measurePlannedRoute(
      binding,
      tester,
      game,
      snapshot,
      rssBefore: rssBefore,
    );
    await _measureActiveEffects(binding, tester, game, snapshot, rssBefore);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(SpriteFrames.debugAtlasBytes, isEmpty);
    binding.reportData!['spriteAtlasesReleasedOnUnmount'] = true;
  });
}

MapRenderSnapshot _largeSnapshot() {
  const cols = 40;
  const rows = 30;
  const contentHash =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  final terrains = MapTerrain.values;
  final tiles = <MapTileView>[
    for (var row = 0; row < rows; row++)
      for (var col = 0; col < cols; col++)
        MapTileView(
          coordinate: (col: col, row: row),
          displayTerrain: terrains[(row * cols + col) % terrains.length],
          yieldTerrain: terrains[(row * cols + col) % terrains.length],
          movementTerrains: [terrains[(row * cols + col) % terrains.length]],
          terrainTags: [terrains[(row * cols + col) % terrains.length]],
          resources: const [],
          height: 0,
        ),
  ];
  final units = <VisibleUnitView>[
    for (var index = 0; index < 120; index++)
      VisibleUnitView(
        id: 'performance-unit-$index',
        ownerPlayerId: index.isEven ? 'performance-player' : 'foreign-player',
        kind: VisibleUnitKind.commander,
        name: 'Performance unit $index',
        coordinate: (col: index % cols, row: index ~/ cols),
        movementUnits: 12,
        posture: VisibleUnitPosture.active,
      ),
  ];
  final cities = <CityView>[
    for (var index = 0; index < 40; index++)
      CityView(
        id: 'performance-city-$index',
        ownerPlayerId: index.isEven ? 'performance-player' : 'foreign-player',
        name: 'Performance city $index',
        center: (col: index % cols, row: 5 + index ~/ cols),
        visibleControlledHexes: [(col: index % cols, row: 5 + index ~/ cols)],
        hitPoints: 10,
        ownedDetails: null,
      ),
  ];
  final fieldImprovements = <FieldImprovementView>[
    for (var index = 0; index < 120; index++)
      FieldImprovementView(
        coordinate: (col: index % cols, row: 10 + index ~/ cols),
        improvement: FieldImprovementKind
            .values[index % FieldImprovementKind.values.length],
      ),
  ];
  final roads = <RoadView>[
    for (var index = 0; index < 120; index++)
      RoadView(
        coordinate: (col: index % cols, row: 16 + index ~/ cols),
        condition: index.isEven
            ? TransportConditionView.operational
            : TransportConditionView.pillaged,
      ),
  ];
  const geometry = AonwOddQFlatTopGeometry(
    cols: cols,
    rows: rows,
    radius: aonwMapHexRadius,
  );
  final bounds = geometry.bounds;
  final map = MapView(
    mapId: 'flame-performance-40x30',
    contentHash: contentHash,
    gridLayout: MapGridLayout.oddQFlatTop,
    cols: cols,
    rows: rows,
    defaultZoom: 1,
    tiles: tiles,
    objectives: const [],
  );
  return MapRenderSnapshot(
    map: map,
    interaction: const MapInteractionState(viewMode: MapViewMode.tile),
    reference: MapReferenceBundle(
      mapId: map.mapId,
      mapContentHash: contentHash,
      worldWidth: bounds.width,
      worldHeight: bounds.height,
      pages: const [],
    ),
    player: PlayerMapView.preview(
      actorPlayerId: 'performance-player',
      stamp: const SessionStampView(
        revision: 0,
        stateDigest:
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        mapHash: contentHash,
        rulesetHash:
            'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
      ),
      turn: 1,
      pendingAction: null,
      units: units,
      cities: cities,
      fieldImprovements: fieldImprovements,
      roads: roads,
    ),
  );
}

Future<void> _measureActiveEffects(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  AonwFlameGame game,
  MapRenderSnapshot snapshot,
  int rssBefore,
) async {
  await measureCombatFeedback(
    binding,
    tester,
    game,
    snapshot,
    rssBefore: rssBefore,
  );

  await measureEraTintTransition(
    binding,
    tester,
    game,
    snapshot,
    rssBefore: rssBefore,
  );

  await measureMapEventParticles(
    binding,
    tester,
    game,
    snapshot,
    rssBefore: rssBefore,
  );

  await measureMapFloatingText(
    binding,
    tester,
    game,
    snapshot,
    rssBefore: rssBefore,
  );

  await measureCityProductionHints(
    binding,
    tester,
    game,
    snapshot,
    rssBefore: rssBefore,
  );

  await measureCloudDrift(
    binding,
    tester,
    game,
    snapshot,
    rssBefore: rssBefore,
  );

  await measureCameraFocus(
    binding,
    tester,
    game,
    snapshot,
    rssBefore: rssBefore,
  );
  await measureMovementCamera(
    binding,
    tester,
    game,
    snapshot,
    rssBefore: rssBefore,
  );
  await measureMovementCamera(
    binding,
    tester,
    game,
    snapshot,
    rssBefore: rssBefore,
    cinematic: true,
  );
}
