part of 'unit_map_layer.dart';

/// Keeps a disclosed marker alive while a command still presents it.
final class MapUnitPresentationLease {
  MapUnitPresentationLease._(this._layer, this.unit);

  final MapUnitLayerComponent _layer;
  final MapUnitComponent unit;
  var _released = false;

  void release() {
    if (_released) return;
    _released = true;
    _layer._releasePresentation(unit);
  }
}

extension MapUnitPresentation on MapUnitLayerComponent {
  @visibleForTesting
  int get debugRetainedUnitCount => _retainedUnits.length;

  MapUnitPresentationLease? retainForPresentation(String? unitId) {
    final unit = unitId == null ? null : componentForUnit(unitId);
    if (unit == null || unit._presentationDisposed) return null;
    unit._presentationHolds++;
    unit._presentedCoordinate ??= unit._unit.coordinate;
    return MapUnitPresentationLease._(this, unit);
  }

  void _releasePresentation(MapUnitComponent unit) {
    unit._presentationHolds--;
    if (unit._presentationHolds > 0 || unit._presentationDisposed) return;
    final id = unit._unit.id;
    if (identical(_retainedUnits[id], unit)) {
      _retainedUnits.remove(id);
      unit.disposePresentation();
      unit.removeFromParent();
    } else if (identical(_unitsById[id], unit)) {
      unit.cancelMovement();
    }
    _updatePresentationVisibility();
    _synchronizeAnimations();
  }

  void _updatePresentationVisibility() {
    isVisible = _unitsById.isNotEmpty || _retainedUnits.isNotEmpty;
  }
}

extension MapUnitCombatPose on MapUnitComponent {
  ui.Offset presentationCenterAt(
    MapHexCoordinate coordinate,
    ui.Offset center,
  ) => _presentedCoordinate == coordinate ? visualCenter : center;

  void beginCombat(
    Object owner, {
    required MapHexCoordinate coordinate,
    required ui.Offset center,
    required ui.Offset? toward,
    required bool attack,
  }) {
    if (_presentationDisposed) return;
    _combatOwner = owner;
    _moving = false;
    if (_presentedCoordinate != coordinate) setVisualCenter(center);
    _presentedCoordinate = coordinate;
    if (attack) {
      if (toward == null) {
        _sprite.playAttack();
      } else {
        _sprite.playAttackToward(visualCenter, toward);
      }
    }
    _onAnimationChanged();
  }

  void advanceCombat(Object owner, double dt) {
    if (identical(_combatOwner, owner)) _sprite.advance(dt);
  }

  void playCombatDeath(Object owner) {
    if (identical(_combatOwner, owner)) _sprite.playDie();
  }

  void finishCombat(Object owner, {required bool killed}) {
    if (!identical(_combatOwner, owner)) return;
    _combatOwner = null;
    if (!killed) _restoreStationaryPose();
    _onAnimationChanged();
  }
}
