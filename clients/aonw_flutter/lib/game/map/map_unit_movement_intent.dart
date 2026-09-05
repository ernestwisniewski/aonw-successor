part of 'map_effect_host.dart';

extension _UnitMovementIntents on MapEffectHostComponent {
  void _discardInterruptedMovements(FlameScenePatch patch) {
    final transitionedIds = {
      for (final movement in patch.movements) movement.unitId,
    };
    for (final unitId in patch.removedUnitIds) {
      _cancelMovement(unitId);
    }
    for (final unit in patch.unitUpserts) {
      if (!transitionedIds.contains(unit.id)) {
        _cancelMovement(unit.id);
      }
    }
  }

  void _startMovements(FlameScenePatch patch, MapStaticRenderCache cache) {
    for (final movement in patch.movements) {
      _startMovement(movement, cache);
    }
  }

  void _startMovement(
    FlameUnitMovementTransition movement,
    MapStaticRenderCache cache,
  ) {
    final lease = _preparedMovements.remove(movement);
    final unit = lease?.unit ?? _units.componentForUnit(movement.unitId);
    if (unit == null) return;
    _cancelMovement(movement.unitId);
    ui.Offset center(MapHexCoordinate coordinate) =>
        _units.centerFor(cache, coordinate);
    final points = movement.path.isEmpty
        ? [center(movement.from), center(movement.to)]
        : [for (final coordinate in movement.path) center(coordinate)];
    final target = _units.settledCenterFor(cache, movement.unitId, movement.to);
    unit.beginMovement();
    unit.setVisualCenter(points.first);
    final presentation = onMovementStart?.call(movement, unit);
    if (_reducedMotion ||
        (!_movementAnimationsEnabled && (presentation?.ready ?? true))) {
      unit.finishMovement(movement.to, target);
      presentation?.complete(interrupted: false);
      _completedMovementCount += 1;
      lease?.release();
    } else {
      _movements[movement.unitId] = _ActiveUnitMovement(
        unit: unit,
        lease: lease,
        points: points,
        target: target,
        destination: movement.to,
        presentation: presentation,
        animate: _movementAnimationsEnabled,
      );
    }
  }

  void _cancelMovement(String unitId) {
    final movement = _movements.remove(unitId);
    if (movement == null) return;
    movement.unit.cancelMovement();
    movement.presentation?.complete(interrupted: true);
    movement.lease?.release();
  }

  void _finishMovements() {
    for (final movement in _movements.values) {
      movement.unit.finishMovement(movement.destination, movement.target);
      movement.presentation?.complete(interrupted: true);
      _completedMovementCount += 1;
      movement.lease?.release();
    }
    _movements.clear();
  }

  bool _updateMovements(double dt) {
    final completed = <String>[];
    for (final entry in _movements.entries) {
      if (_advanceMovement(entry.value, dt)) completed.add(entry.key);
    }
    for (final unitId in completed) {
      final movement = _movements.remove(unitId)!;
      movement.unit.finishMovement(movement.destination, movement.target);
      movement.presentation?.complete(interrupted: false);
      _completedMovementCount += 1;
      movement.lease?.release();
    }
    return completed.isNotEmpty;
  }

  bool _advanceMovement(_ActiveUnitMovement movement, double dt) {
    if (!(movement.presentation?.ready ?? true)) return false;
    if (!movement.animate) return true;
    movement.elapsed += dt * _playbackSpeed;
    final duration =
        MapEffectHostComponent._movementDurationSeconds *
        (movement.points.length - 1);
    if (movement.elapsed + 1e-9 >= duration) return true;
    final segmentTime =
        movement.elapsed / MapEffectHostComponent._movementDurationSeconds;
    final segment = segmentTime.floor();
    final from = movement.points[segment];
    final to = movement.points[segment + 1];
    movement.unit.advanceWalk(from, to, dt * _playbackSpeed);
    movement.unit.setVisualCenter(
      ui.Offset.lerp(from, to, segmentTime - segment)!,
    );
    return false;
  }
}

final class _ActiveUnitMovement {
  _ActiveUnitMovement({
    required this.unit,
    required this.points,
    required this.target,
    required this.destination,
    required this.animate,
    this.presentation,
    this.lease,
  });

  final MapUnitComponent unit;
  final MapUnitPresentationLease? lease;
  final List<ui.Offset> points;
  final bool animate;
  final MapMovementPresentation? presentation;
  final ui.Offset target;
  final MapHexCoordinate destination;
  var elapsed = 0.0;
}
