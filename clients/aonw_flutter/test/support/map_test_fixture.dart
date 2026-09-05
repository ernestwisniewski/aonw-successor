import 'package:aonw_flutter/features/artifacts/application/artifact_session_port.dart';
import 'package:aonw_flutter/features/artifacts/read_model/artifact_view.dart';
import 'package:aonw_flutter/features/cities/application/city_session_port.dart';
import 'package:aonw_flutter/features/cities/read_model/city_view.dart';
import 'package:aonw_flutter/features/combat/application/combat_session_port.dart';
import 'package:aonw_flutter/features/combat/read_model/combat_view.dart';
import 'package:aonw_flutter/features/diplomacy/application/diplomacy_session_port.dart';
import 'package:aonw_flutter/features/diplomacy/read_model/diplomacy_view.dart';
import 'package:aonw_flutter/features/local_game/application/local_game_session_port.dart';
import 'package:aonw_flutter/features/logistics/application/unit_logistics_session_port.dart';
import 'package:aonw_flutter/features/logistics/read_model/unit_logistics_view.dart';
import 'package:aonw_flutter/features/map/application/game_session_capabilities.dart';
import 'package:aonw_flutter/features/map/application/map_session_port.dart';
import 'package:aonw_flutter/features/map/application/movement_session_port.dart';
import 'package:aonw_flutter/features/map/read_model/map_reference_bundle.dart';
import 'package:aonw_flutter/features/map/read_model/map_scene.dart';
import 'package:aonw_flutter/features/map/read_model/map_view.dart';
import 'package:aonw_flutter/features/map/read_model/movement_view.dart';
import 'package:aonw_flutter/features/map/read_model/pending_action_view.dart';
import 'package:aonw_flutter/features/map/read_model/player_map_view.dart';
import 'package:aonw_flutter/features/production/application/production_session_port.dart';
import 'package:aonw_flutter/features/production/read_model/production_view.dart';
import 'package:aonw_flutter/features/research/application/research_session_port.dart';
import 'package:aonw_flutter/features/research/read_model/research_view.dart';
import 'package:aonw_flutter/features/save_game/application/game_save_session_port.dart';
import 'package:aonw_flutter/features/turns/application/turn_session_port.dart';
import 'package:aonw_flutter/features/turns/read_model/recipient_turn_view.dart';
import 'package:aonw_flutter/features/turns/read_model/turn_command_view.dart';
import 'package:aonw_flutter/features/unit_actions/application/unit_action_session_port.dart';
import 'package:aonw_flutter/features/unit_actions/read_model/unit_action_view.dart';
import 'package:aonw_flutter/features/workers/application/worker_session_port.dart';
import 'package:aonw_flutter/features/workers/read_model/worker_view.dart';

part 'city_test_fixture.dart';
part 'local_game_test_fixture.dart';
part 'map_combat_test_fixture.dart';
part 'map_unit_test_fixture.dart';

typedef ProductionOverviewFixture = ({
  ProductionOptionsView options,
  StrategicResourceProjectionView resources,
});

ResearchOptionsView testResearchOptionsView({
  int revision = 0,
  TechnologyIdView? activeTechnology,
}) => ResearchOptionsView(
  stamp: testSessionStamp(revision: revision),
  playerId: 'preview-player',
  activeTechnology: activeTechnology,
  scienceOverflow: 0,
  scienceYield: ScienceYieldBreakdownView(
    total: 0,
    byCityId: const {},
    sources: const [],
  ),
  options: [
    for (final technology in TechnologyIdView.values)
      ResearchOptionView(
        technology: technology,
        availability: technology == activeTechnology
            ? TechnologyAvailabilityView.active
            : TechnologyAvailabilityView.available,
        effectiveCost: 1,
        progress: 0,
        boostDiscountBasisPoints: 0,
        prerequisites: const [],
        blockedBy: const [],
        unlocks: const [],
      ),
  ],
);

MapScene testMapScene({
  int cols = 3,
  int rows = 2,
  String? mapId,
  String? contentHash,
  double defaultZoom = 1,
  List<MapObjectiveView> objectives = const [],
  List<VisibleUnitView> units = const [],
  List<CityView> cities = const [],
  List<WorldArtifactView> artifacts = const [],
  List<String> diplomaticCounterpartPlayerIds = const [],
  DiplomacyView? diplomacy,
  List<FieldImprovementView> fieldImprovements = const [],
  List<RoadView> roads = const [],
  CityFoundingDraftView? cityFoundingDraft,
  GameOutcomeView? outcome,
  PendingActionView? pendingAction,
  int actorColorValue = 0xff000000,
}) {
  final terrains = MapTerrain.values;
  final tiles = <MapTileView>[];
  for (var row = 0; row < rows; row++) {
    for (var col = 0; col < cols; col++) {
      final terrain = terrains[(row * cols + col) % terrains.length];
      tiles.add(
        MapTileView(
          coordinate: (col: col, row: row),
          displayTerrain: terrain,
          yieldTerrain: terrain,
          movementTerrains: [terrain],
          terrainTags: [terrain],
          resources: const [],
          height: 0,
        ),
      );
    }
  }
  return MapScene(
    map: MapView(
      mapId: mapId ?? (cols == 7 && rows == 7 ? 'aonw2_starter' : 'test-map'),
      contentHash: contentHash ?? 'a' * 64,
      gridLayout: MapGridLayout.oddQFlatTop,
      cols: cols,
      rows: rows,
      defaultZoom: defaultZoom,
      tiles: tiles,
      objectives: objectives,
    ),
    reference: MapReferenceBundle(
      mapId: mapId ?? (cols == 7 && rows == 7 ? 'aonw2_starter' : 'test-map'),
      mapContentHash: contentHash ?? 'a' * 64,
      worldWidth: 120 + (cols - 1) * 90,
      worldHeight: 103.92304845413263 * (rows + (cols > 1 ? 0.5 : 0)),
      pages: const [],
    ),
    player: PlayerMapView.preview(
      actorPlayerId: 'preview-player',
      stamp: SessionStampView(
        revision: 0,
        stateDigest: 'b' * 64,
        mapHash: contentHash ?? 'a' * 64,
        rulesetHash: 'c' * 64,
      ),
      turn: 1,
      pendingAction: pendingAction,
      outcome: outcome,
      units: units,
      diplomacy:
          diplomacy ??
          DiplomacyView(
            relations: [
              for (final id in diplomaticCounterpartPlayerIds)
                DiplomaticRelationView(
                  counterpartPlayerId: id,
                  status: DiplomaticRelationStatusView.neutral,
                  relationScore: 0,
                  statusExpiresOnTurn: null,
                  lastChangedTurn: null,
                  lastChangeReason: null,
                ),
            ],
            proposals: const [],
            messages: const [],
            resourceTradeAgreements: const [],
          ),
      cities: cities,
      artifacts: artifacts,
      fieldImprovements: fieldImprovements,
      roads: roads,
      cityFoundingDraft: cityFoundingDraft,
      actorColorValue: actorColorValue,
    ),
  );
}

SessionStampView testSessionStamp({int revision = 0, String? stateDigest}) =>
    SessionStampView(
      revision: revision,
      stateDigest: stateDigest ?? 'b' * 64,
      mapHash: 'a' * 64,
      rulesetHash: 'c' * 64,
    );

ReachableView testReachableView({
  String unitId = 'preview-commander',
  List<ReachableTileView> tiles = const [
    ReachableTileView(
      coordinate: (col: 1, row: 0),
      costUnits: 4,
      exhaustsMovement: false,
    ),
  ],
}) => ReachableView(
  stamp: testSessionStamp(),
  unitId: unitId,
  availableMovementUnits: 12,
  tiles: tiles,
);
RoutePlanView testRoutePlanView({
  String unitId = 'preview-commander',
  MapHexCoordinate origin = (col: 0, row: 0),
  MapHexCoordinate target = (col: 1, row: 0),
}) => RoutePlanView(
  stamp: testSessionStamp(),
  unitId: unitId,
  target: target,
  destination: target,
  totalCostUnits: 4,
  availableMovementUnits: 12,
  remainingMovementUnits: 8,
  estimatedTurns: 1,
  steps: [
    MovementStepView(
      coordinate: origin,
      enterCostUnits: 0,
      cumulativeCostUnits: 0,
    ),
    MovementStepView(
      coordinate: target,
      enterCostUnits: 4,
      cumulativeCostUnits: 4,
    ),
  ],
);

MoveUnitExecutionView testMoveUnitExecutionView({
  String unitId = 'preview-commander',
  MapHexCoordinate from = const (col: 0, row: 0),
  MapHexCoordinate to = const (col: 1, row: 0),
}) => MoveUnitExecutionView(
  events: [UnitMovedEventView(unitId: unitId, from: from, to: to)],
  evidence: UnitMovementEvidenceView(
    unitId: unitId,
    from: from,
    steps: [
      MovementStepView(
        coordinate: to,
        enterCostUnits: 4,
        cumulativeCostUnits: 4,
      ),
    ],
  ),
);

final class FakeGameSession
    with FakeLocalGameSessionFixture
    implements
        MapSessionPort,
        MovementSessionPort,
        CitySessionPort,
        CombatSessionPort,
        UnitLogisticsSessionPort,
        WorkerSessionPort,
        ProductionSessionPort,
        ArtifactSessionPort,
        ResearchSessionPort,
        DiplomacySessionPort,
        TurnSessionPort,
        UnitActionSessionPort,
        LocalGameSessionPort {
  FakeGameSession.success(
    this.scene, {
    this.reachableResult,
    this.routeResult,
    this.moveResult,
    this.moveFailure,
    this.unitActionResult,
    this.unitActionFailure,
    this.turnResult,
    this.turnFailure,
    this.logisticsOptions,
    this.logisticsResult,
    this.logisticsFailure,
    this.workerOptionsResult,
    this.workerResult,
    this.workerFailure,
    this.productionOverviewResult,
    this.productionOverviewResults = const [],
    this.productionResult,
    this.productionFailure,
    this.artifactResult,
    this.artifactFailure,
    this.researchOptionsResult,
    this.researchResult,
    this.researchFailure,
    this.diplomacyResult,
    this.diplomacyFailure,
    this.combatPreviewResult,
    this.combatResult,
    this.combatFailure,
    this.cityFoundingOptionsResult,
    this.cityInspection,
    this.cityResult,
    this.cityFailure,
    this.aiTurnResults = const [],
    this.aiTurnFailure,
    this.handoffPlayers = const {},
  }) : failure = null;
  FakeGameSession.failure(this.failure)
    : scene = null,
      reachableResult = null,
      routeResult = null,
      moveResult = null,
      moveFailure = null,
      unitActionResult = null,
      unitActionFailure = null,
      turnResult = null,
      turnFailure = null,
      logisticsOptions = null,
      logisticsResult = null,
      logisticsFailure = null,
      workerOptionsResult = null,
      workerResult = null,
      workerFailure = null,
      productionOverviewResult = null,
      productionOverviewResults = const [],
      productionResult = null,
      productionFailure = null,
      artifactResult = null,
      artifactFailure = null,
      researchOptionsResult = null,
      researchResult = null,
      researchFailure = null,
      diplomacyResult = null,
      diplomacyFailure = null,
      combatPreviewResult = null,
      combatResult = null,
      combatFailure = null,
      cityFoundingOptionsResult = null,
      cityInspection = null,
      cityResult = null,
      cityFailure = null,
      aiTurnResults = const [],
      aiTurnFailure = null,
      handoffPlayers = const {};

  final MapScene? scene;
  final MapLoadException? failure;
  final ReachableView? reachableResult;
  final RoutePlanView? routeResult;
  final MoveUnitResultView? moveResult;
  final MovementSessionException? moveFailure;
  final UnitActionResultView? unitActionResult;
  final UnitActionSessionException? unitActionFailure;
  final TurnCommandResultView? turnResult;
  final TurnSessionException? turnFailure;
  final UnitLogisticsOptionsView? logisticsOptions;
  final UnitLogisticsCommandResultView? logisticsResult;
  final UnitLogisticsSessionException? logisticsFailure;
  final WorkerOptionsView? workerOptionsResult;
  final WorkerCommandResultView? workerResult;
  final WorkerSessionException? workerFailure;
  final ({
    ProductionOptionsView options,
    StrategicResourceProjectionView resources,
  })?
  productionOverviewResult;
  final List<ProductionOverviewFixture> productionOverviewResults;
  final ProductionCommandResultView? productionResult;
  final ProductionSessionException? productionFailure;
  final ArtifactCommandResultView? artifactResult;
  final ArtifactSessionException? artifactFailure;
  final ResearchOptionsView? researchOptionsResult;
  final ResearchCommandResultView? researchResult;
  final ResearchSessionException? researchFailure;
  final DiplomacyCommandResultView? diplomacyResult;
  final DiplomacySessionException? diplomacyFailure;
  final CombatPreviewView? combatPreviewResult;
  final CombatCommandResultView? combatResult;
  final CombatSessionException? combatFailure;
  final CityFoundingOptionsView? cityFoundingOptionsResult;
  final CityInspectionView? cityInspection;
  final CityCommandResultView? cityResult;
  final CitySessionException? cityFailure;
  @override
  final List<LocalAiTurnExecutionView> aiTurnResults;
  @override
  final LocalGameSessionException? aiTurnFailure;
  @override
  final Map<String, PlayerMapView> handoffPlayers;
  var unitActionCalls = 0;
  UnitActionKindView? lastUnitAction;
  int? lastUnitActionExpectedRevision;
  String? lastUnitActionUnitId;
  var endTurnCalls = 0;
  int? lastEndTurnExpectedRevision;
  var logisticsOptionCalls = 0;
  var logisticsCommandCalls = 0;
  int? lastLogisticsExpectedRevision;
  UnitLogisticsActionView? lastLogisticsAction;
  var workerOptionCalls = 0;
  var workerCommandCalls = 0;
  int? lastWorkerExpectedRevision;
  WorkerActionView? lastWorkerAction;
  var productionOverviewCalls = 0;
  var productionCommandCalls = 0;
  ProductionActionView? lastProductionAction;
  int? lastProductionExpectedRevision;
  var artifactCommandCalls = 0;
  ArtifactActionView? lastArtifactAction;
  int? lastArtifactExpectedRevision;
  var researchOptionCalls = 0;
  var researchCommandCalls = 0;
  int? lastResearchExpectedRevision;
  TechnologyIdView? lastResearchTechnology;
  var diplomacyCommandCalls = 0;
  int? lastDiplomacyExpectedRevision;
  DiplomacyActionView? lastDiplomacyAction;
  var combatPreviewCalls = 0;
  var combatAttackCalls = 0;
  MapHexCoordinate? lastCombatDefender;
  CombatAttackView? lastCombatAttack;
  var cityFoundingOptionCalls = 0;
  var cityInspectionCalls = 0;
  var cityCommandCalls = 0;
  CityActionView? lastCityAction;
  var localStartCalls = 0;
  LocalMatchSetupView? lastLocalMatchSetup;
  @override
  var aiTurnCalls = 0;
  @override
  final aiTurnRequests = <LocalAiTurnRequestView>[];
  @override
  final handoffRequests = <String>[];
  final selectionRequestOrder = <String>[];

  @override
  Future<MapScene> load(MapAssetPaths assets) async {
    final error = failure;
    if (error != null) throw error;
    return scene!;
  }

  @override
  Future<MapScene> startLocalMatch(LocalMatchSetupView setup) async {
    localStartCalls += 1;
    lastLocalMatchSetup = setup;
    final error = failure;
    if (error != null) {
      throw LocalGameSessionException(
        code: error.code,
        message: error.message,
        diagnosticCause: error.diagnosticCause,
        diagnosticStackTrace: error.diagnosticStackTrace,
      );
    }
    return scene!;
  }

  @override
  Future<ReachableView> reachable({
    required int expectedRevision,
    required String unitId,
  }) async {
    selectionRequestOrder.add('reachable');
    return reachableResult ?? (throw StateError('No reachable fixture.'));
  }

  @override
  Future<RoutePlanView> routePlan({
    required int expectedRevision,
    required String unitId,
    required MapHexCoordinate target,
  }) async => routeResult ?? (throw StateError('No route fixture.'));

  @override
  Future<MoveUnitResultView> moveUnit({
    required int expectedRevision,
    required String unitId,
    required MapHexCoordinate target,
  }) async {
    final error = moveFailure;
    if (error != null) throw error;
    return moveResult ?? (throw StateError('No move fixture.'));
  }

  @override
  Future<CombatPreviewView> combatPreview({
    required int expectedRevision,
    required String attackerUnitId,
    required MapHexCoordinate defender,
  }) async {
    combatPreviewCalls += 1;
    lastCombatDefender = defender;
    final error = combatFailure;
    if (error != null) throw error;
    return combatPreviewResult ??
        (throw StateError('No combat preview fixture.'));
  }

  @override
  Future<CombatCommandResultView> attack({
    required int expectedRevision,
    required CombatAttackView attack,
  }) async {
    combatAttackCalls += 1;
    lastCombatAttack = attack;
    final error = combatFailure;
    if (error != null) throw error;
    return combatResult ?? (throw StateError('No combat result fixture.'));
  }

  @override
  Future<CityFoundingOptionsView> cityFoundingOptions({
    required int expectedRevision,
    required String founderUnitId,
  }) async {
    cityFoundingOptionCalls += 1;
    final error = cityFailure;
    if (error != null) throw error;
    return cityFoundingOptionsResult ??
        (throw StateError('No city founding fixture.'));
  }

  @override
  Future<CityInspectionView> inspectCity({
    required int expectedRevision,
    required String cityId,
  }) async {
    cityInspectionCalls += 1;
    final error = cityFailure;
    if (error != null) throw error;
    return cityInspection ?? (throw StateError('No city inspection fixture.'));
  }

  @override
  Future<CityCommandResultView> executeCityAction({
    required int expectedRevision,
    required CityActionView action,
  }) async {
    cityCommandCalls += 1;
    lastCityAction = action;
    final error = cityFailure;
    if (error != null) throw error;
    return cityResult ?? (throw StateError('No city command fixture.'));
  }

  @override
  Future<UnitActionResultView> executeUnitAction({
    required int expectedRevision,
    required String unitId,
    required UnitActionKindView action,
  }) async {
    unitActionCalls += 1;
    lastUnitAction = action;
    lastUnitActionExpectedRevision = expectedRevision;
    lastUnitActionUnitId = unitId;
    final error = unitActionFailure;
    if (error != null) throw error;
    return unitActionResult ?? (throw StateError('No unit action fixture.'));
  }

  @override
  Future<TurnCommandResultView> endTurn({required int expectedRevision}) async {
    endTurnCalls += 1;
    lastEndTurnExpectedRevision = expectedRevision;
    final error = turnFailure;
    if (error != null) throw error;
    return turnResult ?? (throw StateError('No turn fixture.'));
  }

  @override
  Future<UnitLogisticsOptionsView> unitLogisticsOptions({
    required int expectedRevision,
    required String unitId,
  }) async {
    selectionRequestOrder.add('logistics');
    logisticsOptionCalls += 1;
    final error = logisticsFailure;
    if (error != null) throw error;
    return logisticsOptions ??
        UnitLogisticsOptionsView(
          stamp: testSessionStamp(revision: expectedRevision),
          unitId: unitId,
          autoExplore: null,
          merchantRouteDestinations: const [],
          merchantTravelDestinations: const [],
          detachments: const [],
        );
  }

  @override
  Future<UnitLogisticsCommandResultView> executeUnitLogistics({
    required int expectedRevision,
    required UnitLogisticsActionView action,
  }) async {
    logisticsCommandCalls += 1;
    lastLogisticsExpectedRevision = expectedRevision;
    lastLogisticsAction = action;
    final error = logisticsFailure;
    if (error != null) throw error;
    return logisticsResult ??
        (throw StateError('No unit logistics result fixture.'));
  }

  @override
  Future<WorkerOptionsView> workerOptions({
    required int expectedRevision,
    required String unitId,
  }) async {
    workerOptionCalls += 1;
    final error = workerFailure;
    if (error != null) throw error;
    return workerOptionsResult ??
        WorkerOptionsView(
          stamp: testSessionStamp(revision: expectedRevision),
          unitId: unitId,
          coordinate:
              scene?.player.controlledUnitById(unitId)?.coordinate ??
              (col: 0, row: 0),
          improvements: const [],
          canAssign: false,
          canBuildRoad: false,
          automation: null,
        );
  }

  @override
  Future<WorkerCommandResultView> executeWorkerAction({
    required int expectedRevision,
    required WorkerActionView action,
  }) async {
    workerCommandCalls += 1;
    lastWorkerExpectedRevision = expectedRevision;
    lastWorkerAction = action;
    final error = workerFailure;
    if (error != null) throw error;
    return workerResult ?? (throw StateError('No worker result fixture.'));
  }

  @override
  Future<
    ({ProductionOptionsView options, StrategicResourceProjectionView resources})
  >
  productionOverview({
    required int expectedRevision,
    required String cityId,
  }) async {
    productionOverviewCalls += 1;
    final error = productionFailure;
    if (error != null) throw error;
    if (productionOverviewResults.isNotEmpty) {
      final index = productionOverviewCalls <= productionOverviewResults.length
          ? productionOverviewCalls - 1
          : productionOverviewResults.length - 1;
      return productionOverviewResults[index];
    }
    return productionOverviewResult ??
        (
          options: ProductionOptionsView(
            stamp: testSessionStamp(revision: expectedRevision),
            cityId: cityId,
            currentTarget: null,
            investedProduction: 0,
            productionOverflow: 0,
            buildings: const [],
            units: const [],
            projects: const [],
            wonders: const [],
            specializations: const [],
          ),
          resources: StrategicResourceProjectionView(
            stamp: testSessionStamp(revision: expectedRevision),
            playerId: scene?.player.actorPlayerId ?? 'preview-player',
            output: const [],
            sources: const [],
          ),
        );
  }

  @override
  Future<ProductionCommandResultView> executeProductionAction({
    required int expectedRevision,
    required ProductionActionView action,
  }) async {
    productionCommandCalls += 1;
    lastProductionExpectedRevision = expectedRevision;
    lastProductionAction = action;
    final error = productionFailure;
    if (error != null) throw error;
    return productionResult ??
        (throw StateError('No production result fixture.'));
  }

  @override
  Future<ArtifactCommandResultView> executeArtifactAction({
    required int expectedRevision,
    required ArtifactActionView action,
  }) async {
    artifactCommandCalls += 1;
    lastArtifactExpectedRevision = expectedRevision;
    lastArtifactAction = action;
    final error = artifactFailure;
    if (error != null) throw error;
    return artifactResult ?? (throw StateError('No artifact result fixture.'));
  }

  @override
  Future<ResearchOptionsView> researchOptions({
    required int expectedRevision,
  }) async {
    researchOptionCalls += 1;
    lastResearchExpectedRevision = expectedRevision;
    final error = researchFailure;
    if (error != null) throw error;
    return researchOptionsResult ??
        testResearchOptionsView(revision: expectedRevision);
  }

  @override
  Future<ResearchCommandResultView> selectTechnology({
    required int expectedRevision,
    required TechnologyIdView technology,
  }) async {
    researchCommandCalls += 1;
    lastResearchExpectedRevision = expectedRevision;
    lastResearchTechnology = technology;
    final error = researchFailure;
    if (error != null) throw error;
    return researchResult ?? (throw StateError('No research result fixture.'));
  }

  @override
  Future<DiplomacyCommandResultView> executeDiplomacyAction({
    required int expectedRevision,
    required DiplomacyActionView action,
  }) async {
    diplomacyCommandCalls += 1;
    lastDiplomacyExpectedRevision = expectedRevision;
    lastDiplomacyAction = action;
    final error = diplomacyFailure;
    if (error != null) throw error;
    return diplomacyResult ??
        (throw StateError('No diplomacy result fixture.'));
  }

  @override
  Future<void> close() async {}
}

GameSessionCapabilities testGameSessionCapabilities(
  FakeGameSession session, {
  CitySessionPort? cities,
  GameSaveSessionPort? save,
}) => GameSessionCapabilities(
  map: session,
  movement: session,
  combat: session,
  cities: cities ?? session,
  logistics: session,
  workers: session,
  production: session,
  artifacts: session,
  research: session,
  diplomacy: session,
  unitActions: session,
  turns: session,
  localGame: session,
  save: save,
);
