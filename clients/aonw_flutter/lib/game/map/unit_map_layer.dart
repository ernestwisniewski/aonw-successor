import 'dart:async';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import '../../design_system/assets/sprite_frame_repository.dart';
import '../../features/artifacts/read_model/artifact_view.dart';
import '../../features/map/presentation/map_palette.dart';
import '../../features/map/read_model/map_view.dart';
import '../../features/map/read_model/pending_action_view.dart';
import '../../features/map/read_model/player_map_view.dart';
import '../presentation/flame_scene_patch.dart';
import 'map_canvas_clip.dart';
import 'map_sprite_catalog.dart';
import 'map_sprite_shadow.dart';
import 'map_unit_frame_clock.dart';
import 'map_unit_sprite_animation.dart';
import 'static_map_layers.dart';
import 'unit_marker_details.dart';

part 'unit_map_component.dart';
part 'unit_map_animation.dart';
part 'unit_map_presentation.dart';

enum _CityUnitPlacement { none, primary, companion }

final class _MapUnitVisualState {
  const _MapUnitVisualState({
    required this.center,
    required this.ownerColor,
    required this.selected,
    required this.skippedTurn,
    required this.onCity,
    required this.workBadgeLabel,
  });

  final ui.Offset center;
  final ui.Color ownerColor;
  final bool selected;
  final bool skippedTurn;
  final bool onCity;
  final String? workBadgeLabel;
}

final class MapUnitLayerComponent extends Component with HasVisibility {
  MapUnitLayerComponent({DateTime Function()? now, this.idlePauseDuration})
    : _now = now,
      super(priority: 50) {
    isVisible = false;
  }

  final _unitsById = <String, MapUnitComponent>{};
  final _retainedUnits = <String, MapUnitComponent>{};
  final _visualOffsetsById = <String, ui.Offset>{};
  final _shadows = MapSpriteShadowCache();
  var _createdCount = 0;
  var _updatedCount = 0;
  var _removedCount = 0;
  final DateTime Function()? _now;
  final double Function()? idlePauseDuration;
  late final _frameClock = MapUnitFrameClock(
    now: _now,
    onFrame: () => onAnimationFrame?.call(),
  );
  void Function()? onAnimationFrame;
  var _idleEnabled = true;
  var _viewportActive = false;
  var _reducedMotion = false;
  var _animationZoom = 0.0;
  var _applyingPatch = false;
  ui.Rect _animationViewport = ui.Rect.zero;

  bool get idleAnimationsEnabled => _idleEnabled;

  @visibleForTesting
  int get debugUnitCount => _unitsById.length;

  @visibleForTesting
  int get debugCreatedCount => _createdCount;

  @visibleForTesting
  int get debugUpdatedCount => _updatedCount;

  @visibleForTesting
  int get debugRemovedCount => _removedCount;

  @visibleForTesting
  int get debugSharedPaintCount => MapUnitComponent.sharedPaintCount;

  @visibleForTesting
  MapUnitComponent? debugComponentForUnit(String unitId) => _unitsById[unitId];

  MapUnitComponent? componentForUnit(String unitId) =>
      _unitsById[unitId] ?? _retainedUnits[unitId];

  void applyPatch(FlameScenePatch patch, MapStaticRenderCache cache) {
    _frameClock.flush();
    _applyingPatch = true;
    try {
      _applyUnitPatch(patch, cache);
    } finally {
      _applyingPatch = false;
      _synchronizeAnimations();
    }
  }

  void _applyUnitPatch(FlameScenePatch patch, MapStaticRenderCache cache) {
    final animatedIds = {for (final value in patch.movements) value.unitId};
    final changedIds = {for (final value in patch.unitUpserts) value.id};
    for (final unitId in patch.removedUnitIds) {
      final component = _unitsById.remove(unitId);
      _visualOffsetsById.remove(unitId);
      if (component != null) {
        if (component._presentationHolds > 0) {
          _retainedUnits[unitId] = component;
        } else {
          component.disposePresentation();
          component.removeFromParent();
        }
        _removedCount += 1;
      }
    }
    final snapshot = patch.snapshot;
    final placements = _cityPlacements(snapshot.player);
    final ownerColors = {
      for (final participant in snapshot.player.participants)
        participant.id: ui.Color(participant.colorValue),
    };
    final excavationTurns = _excavationTurns(snapshot.player.artifacts);
    final skippedUnitId = switch (snapshot.player.turnView.pendingAction) {
      PendingUnitTurnSkipView(:final unitId) => unitId,
      _ => null,
    };
    for (final unit in snapshot.player.units) {
      final placement = placements[unit.id] ?? _CityUnitPlacement.none;
      final visual = _visualState(
        cache: cache,
        player: snapshot.player,
        unit: unit,
        placement: placement,
        ownerColors: ownerColors,
        selectedUnitId: snapshot.interaction.selectedUnitId,
        skippedUnitId: skippedUnitId,
        excavationTurns: excavationTurns,
      );
      _visualOffsetsById[unit.id] =
          visual.center - _center(cache, unit.coordinate);
      final existing = _unitsById[unit.id] ?? _retainedUnits.remove(unit.id);
      if (existing == null) {
        final component = MapUnitComponent._(
          unit: unit,
          visual: visual,
          shadows: _shadows,
          onAnimationChanged: _synchronizeAnimations,
          idlePauseDuration: idlePauseDuration,
        );
        _unitsById[unit.id] = component;
        add(component);
        _createdCount += 1;
      } else {
        _unitsById[unit.id] = existing;
        existing._applyUnit(
          unit,
          visual: visual,
          preserveVisualPosition: animatedIds.contains(unit.id),
        );
        if (changedIds.contains(unit.id)) _updatedCount += 1;
      }
    }
    _updatePresentationVisibility();
  }

  void clearLayer() {
    final components = {..._unitsById.values, ..._retainedUnits.values};
    _unitsById.clear();
    _retainedUnits.clear();
    _frameClock.clear();
    for (final component in components) {
      component.disposePresentation();
      component.removeFromParent();
    }
    _visualOffsetsById.clear();
    _shadows.clear();
    isVisible = false;
  }

  @override
  void onRemove() {
    clearLayer();
    super.onRemove();
  }

  ui.Offset centerFor(
    MapStaticRenderCache cache,
    MapHexCoordinate coordinate,
  ) => _center(cache, coordinate);

  ui.Offset visualCenterFor(
    MapStaticRenderCache cache,
    String unitId,
    MapHexCoordinate coordinate,
  ) =>
      _center(cache, coordinate) +
      (_visualOffsetsById[unitId] ?? ui.Offset.zero);

  ui.Offset settledCenterFor(
    MapStaticRenderCache cache,
    String unitId,
    MapHexCoordinate coordinate,
  ) => _unitsById[unitId]?._unit.coordinate == coordinate
      ? visualCenterFor(cache, unitId, coordinate)
      : centerFor(cache, coordinate);

  static _MapUnitVisualState _visualState({
    required MapStaticRenderCache cache,
    required PlayerMapView player,
    required VisibleUnitView unit,
    required _CityUnitPlacement placement,
    required Map<String, ui.Color> ownerColors,
    required String? selectedUnitId,
    required String? skippedUnitId,
    required Map<String, int> excavationTurns,
  }) {
    final controlled = unit.ownerPlayerId == player.actorPlayerId;
    final ownerColor =
        ownerColors[unit.ownerPlayerId] ??
        (controlled ? MapPalette.controlledUnit : MapPalette.foreignUnit);
    final offset = switch (placement) {
      _CityUnitPlacement.none => ui.Offset.zero,
      _CityUnitPlacement.primary => const ui.Offset(26, 26),
      _CityUnitPlacement.companion => const ui.Offset(-26, 26),
    };
    return _MapUnitVisualState(
      center: _center(cache, unit.coordinate) + offset,
      ownerColor: ownerColor,
      selected: selectedUnitId == unit.id,
      skippedTurn: skippedUnitId == unit.id,
      onCity: placement != _CityUnitPlacement.none,
      workBadgeLabel: _workBadgeLabel(unit, excavationTurns[unit.id]),
    );
  }

  static Map<String, _CityUnitPlacement> _cityPlacements(PlayerMapView player) {
    final cityCenters = {for (final city in player.cities) city.center};
    if (cityCenters.isEmpty) return const {};
    final unitsByCenter = <MapHexCoordinate, List<VisibleUnitView>>{};
    for (final unit in player.units) {
      if (!cityCenters.contains(unit.coordinate)) continue;
      (unitsByCenter[unit.coordinate] ??= []).add(unit);
    }
    final result = <String, _CityUnitPlacement>{};
    for (final units in unitsByCenter.values) {
      final companionMerchant =
          units.length > 1 &&
          units.any((unit) => unit.kind == VisibleUnitKind.merchant);
      for (final unit in units) {
        result[unit.id] =
            companionMerchant && unit.kind == VisibleUnitKind.merchant
            ? _CityUnitPlacement.companion
            : _CityUnitPlacement.primary;
      }
    }
    return result;
  }

  static Map<String, int> _excavationTurns(List<WorldArtifactView> artifacts) =>
      {
        for (final artifact in artifacts)
          if (artifact.location case ExcavationArtifactLocationView(
            :final unitId,
            :final remainingTurns,
          ))
            unitId: remainingTurns,
      };

  static String? _workBadgeLabel(VisibleUnitView unit, int? excavationTurns) {
    final remainingTurns =
        unit.workerJob?.remainingTurns ??
        unit.cityFoundingRemainingTurns ??
        excavationTurns ??
        (unit.excavatingArtifactId == null ? null : 1);
    if (remainingTurns != null) return '${remainingTurns}t';
    if (unit.workerAssignment != null) return '+50%';
    return null;
  }

  static ui.Offset _center(
    MapStaticRenderCache cache,
    MapHexCoordinate coordinate,
  ) {
    final center = cache.projection.hexCenter(coordinate);
    return ui.Offset(center.x, center.y - 12);
  }
}
